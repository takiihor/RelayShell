import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/shell/shell_quoting.dart';
import '../../shared/models/enums.dart';
import '../terminal/terminal_session.dart';
import 'command_framer.dart';
import 'conversation_models.dart';
import 'transcript_output.dart';

/// Adapts one live [TerminalSession] into command/output blocks.
///
/// Conversation Mode deliberately shares the same PTY as Terminal Mode. The
/// framing protocol uses control-character sentinels instead of trying to parse
/// the user's prompt, which may be arbitrarily customised.
class ConversationController extends ChangeNotifier {
  ConversationController({required this.session})
    : _nonce = const Uuid().v4().replaceAll('-', '') {
    _outputSubscription = session.outputStream.listen(_onOutput);
    session.addListener(_onSessionChanged);
  }

  final TerminalSession session;
  final String _nonce;
  final ConversationCommandFramer _framer = const ConversationCommandFramer();

  static const int maxCommands = 50;
  static const int maxRenderedCharacters = 256 * 1024;
  static const int _markerTail = 192;
  static const Duration _completionTimeout = Duration(seconds: 3);
  static final RegExp _directoryDraft = RegExp(r'^(\s*cd\s+)([^\s]*)$');
  static final RegExp _interactiveCommand = RegExp(
    r'^\s*(?:(?:sudo|env)\s+)*(?:herdr|ctxguard|pi|codex|claude|opencode|gemini|ssh|mosh|vim|nvim|nano|htop|top|less|more)\b',
    caseSensitive: false,
  );
  TranscriptOutput? _output;

  StreamSubscription<String>? _outputSubscription;
  final List<ConversationCommand> _commands = [];
  ConversationCommandFrame? _activeFrame;
  Completer<String?>? _completion;
  Timer? _completionTimer;
  String? _completionMarker;
  String _completionBuffer = '';
  String _buffer = '';
  String? _activeId;
  bool _capturing = false;
  int _sequence = 0;
  int _completionSequence = 0;

  List<ConversationCommand> get commands => List.unmodifiable(_commands);

  ConversationCommand? get activeCommand {
    final id = _activeId;
    if (id == null) return null;
    for (final command in _commands.reversed) {
      if (command.id == id) return command;
    }
    return null;
  }

  bool get supportsConversation =>
      session.host.platform == RemotePlatform.posix;

  bool get canSubmit =>
      supportsConversation &&
      session.isLive &&
      _activeId == null &&
      _completion == null;

  bool get isCompleting => _completion != null;

  bool get canSendProcessInput =>
      supportsConversation && session.isLive && _activeId != null;

  /// Sends [rawCommand] through the current POSIX shell without spawning a new
  /// SSH exec channel. `eval` is a shell special builtin, so state changes such
  /// as `cd`, `export` and environment activation remain in this PTY.
  void submit(String rawCommand) {
    // Preserve the user's shell text exactly. In particular, trailing spaces
    // can be meaningful after a line-continuation backslash, so Conversation
    // Mode must not silently trim or rewrite the command before execution.
    final command = rawCommand;
    if (command.trim().isEmpty || !canSubmit) return;

    final id = '${_sequence++}';
    final now = DateTime.now();
    final frame = _framer.build(nonce: _nonce, id: id, command: command);

    if (_commands.length == maxCommands) _commands.removeAt(0);
    _commands.add(
      ConversationCommand(
        id: id,
        command: command,
        startedAt: now,
        state: ConversationCommandState.running,
        interactiveHint: _interactiveCommand.hasMatch(command),
      ),
    );
    _output = TranscriptOutput(
      columns: session.terminal.viewWidth,
      rows: session.terminal.viewHeight,
    );
    _activeId = id;
    _activeFrame = frame;
    _capturing = false;
    _buffer = '';
    notifyListeners();

    session.sendText(frame.payload, submit: true);
  }

  /// Sends a human-readable line to the foreground process without starting a
  /// second framed shell command. This is the path used to chat with Herdr,
  /// Codex, Claude Code, Pi and other interactive programs while their original
  /// command remains active.
  void sendProcessInput(String text, {bool submit = true}) {
    final id = _activeId;
    if (id == null || !canSendProcessInput || text.isEmpty) return;

    final index = _commands.indexWhere((command) => command.id == id);
    if (index >= 0) {
      final current = _commands[index];
      _commands[index] = current.copyWith(
        processInputs: [
          ...current.processInputs,
          ConversationProcessInput(text: text, sentAt: DateTime.now()),
        ],
      );
      notifyListeners();
    }

    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final payload = session.terminal.bracketedPasteMode
        ? '\x1b[200~$normalized\x1b[201~'
        : normalized.replaceAll('\n', '\r');
    session.sendRaw('$payload${submit ? '\r' : ''}');
  }

  /// Sends an exact terminal sequence to the foreground process. Accessory
  /// keys use this path so Ctrl/Alt/Shift/Tab/arrows behave exactly as they do
  /// in Terminal Mode and do not get recorded as fake chat messages.
  void sendRawToActive(String sequence) {
    if (!canSendProcessInput || sequence.isEmpty) return;
    session.sendRaw(sequence);
  }

  /// Completes an unquoted `cd` directory draft through the existing Bash PTY.
  ///
  /// Conversation Mode keeps the draft locally, so sending a literal Tab to
  /// Bash cannot update the composer. The probe asks Bash for directories in
  /// its current working directory and returns one unique candidate in a
  /// private OSC marker. It does not create a transcript card or run the
  /// draft command.
  Future<String?> completeDirectory(String draft) {
    final match = _directoryDraft.firstMatch(draft);
    if (match == null || !canSubmit) return Future<String?>.value(null);

    final prefix = match.group(2)!;
    final id = '${_completionSequence++}';
    final completion = Completer<String?>();
    _completion = completion;
    _completionMarker = '\x1b]777;RS:$_nonce:C:$id:';
    _completionBuffer = '';
    _completionTimer = Timer(_completionTimeout, () {
      _finishCompletion(null);
    });
    notifyListeners();

    session.sendText(_directoryCompletionProbe(id: id, prefix: prefix));
    return completion.future.then(
      (candidate) => candidate == null ? null : '${match.group(1)}$candidate',
    );
  }

  String _directoryCompletionProbe({
    required String id,
    required String prefix,
  }) {
    final quotedPrefix = ShellQuoter.posix.quote(prefix);
    return '''
__rs_completion_candidate= __rs_completion_count=0;
while IFS= read -r __rs_completion_item; do
  __rs_completion_candidate="\$__rs_completion_item";
  __rs_completion_count=\$((__rs_completion_count + 1));
  (( __rs_completion_count > 1 )) && break;
done < <(compgen -d -- $quotedPrefix);
if (( __rs_completion_count == 1 )); then
  __rs_completion_result="\${__rs_completion_candidate%/}/";
else
  __rs_completion_result=;
fi;
builtin printf '\\033]777;RS:$_nonce:C:$id:%s\\007' "\$(builtin printf %s "\$__rs_completion_result" | base64 | tr -d '\\n')";
unset __rs_completion_candidate __rs_completion_count __rs_completion_item __rs_completion_result
'''
        .replaceAll('\n', ' ');
  }

  /// Interrupts the foreground command while leaving the SSH transport and
  /// shell session alive. The wrapper should subsequently emit its exit status.
  void interrupt() {
    if (_activeId == null || !session.isLive) return;
    session.sendRaw('\x03');
  }

  void _onOutput(String chunk) {
    _consumeCompletion(chunk);
    if (_activeId == null) return;
    _buffer += chunk;
    _drainBuffer();
  }

  void _consumeCompletion(String chunk) {
    final marker = _completionMarker;
    if (marker == null) return;

    _completionBuffer += chunk;
    final start = _completionBuffer.indexOf(marker);
    if (start < 0) {
      if (_completionBuffer.length > marker.length + _markerTail) {
        _completionBuffer = _completionBuffer.substring(
          _completionBuffer.length - marker.length - _markerTail,
        );
      }
      return;
    }

    final payloadStart = start + marker.length;
    final end = _completionBuffer.indexOf('\x07', payloadStart);
    if (end < 0) return;

    final encoded = _completionBuffer.substring(payloadStart, end);
    String? candidate;
    if (encoded.isNotEmpty) {
      try {
        candidate = utf8.decode(base64Decode(encoded));
      } on FormatException {
        // A malformed response is indistinguishable from no unique match.
      }
    }
    _finishCompletion(candidate?.isEmpty == true ? null : candidate);
  }

  void _finishCompletion(String? candidate) {
    final completion = _completion;
    if (completion == null) return;
    _completionTimer?.cancel();
    _completionTimer = null;
    _completion = null;
    _completionMarker = null;
    _completionBuffer = '';
    completion.complete(candidate);
    notifyListeners();
  }

  @visibleForTesting
  void addOutputForTesting(String chunk) => _onOutput(chunk);

  void _drainBuffer() {
    final id = _activeId;
    final frame = _activeFrame;
    if (id == null || frame == null) return;

    if (!_capturing) {
      final begin = frame.beginMarker;
      final index = _buffer.indexOf(begin);
      if (index < 0) {
        // Retain only enough tail to recognise a marker split across chunks.
        if (_buffer.length > begin.length + _markerTail) {
          _buffer = _buffer.substring(
            _buffer.length - begin.length - _markerTail,
          );
        }
        return;
      }
      _buffer = _buffer.substring(index + begin.length);
      if (_buffer.startsWith('\r\n')) {
        _buffer = _buffer.substring(2);
      } else if (_buffer.startsWith('\n')) {
        _buffer = _buffer.substring(1);
      }
      _capturing = true;
    }

    final endPrefix = frame.endPrefix;
    final endStart = _buffer.indexOf(endPrefix);
    if (endStart >= 0) {
      final markerEnd = _buffer.indexOf(
        ConversationCommandFramer.unitSeparator,
        endStart + endPrefix.length,
      );
      if (markerEnd < 0) {
        // The marker started but its status/terminator is in the next chunk.
        if (endStart > 0) {
          _appendOutput(id, _buffer.substring(0, endStart));
          _buffer = _buffer.substring(endStart);
        }
        return;
      }

      if (endStart > 0) {
        _appendOutput(id, _buffer.substring(0, endStart));
      }
      final statusText = _buffer.substring(
        endStart + endPrefix.length,
        markerEnd,
      );
      final exitCode = int.tryParse(statusText);
      _buffer = _buffer.substring(markerEnd + 1);
      _complete(id, exitCode);
      return;
    }

    // Retain only an actual partial marker, never an arbitrary prompt tail.
    var retained = 0;
    final limit = (_buffer.length < endPrefix.length)
        ? _buffer.length
        : endPrefix.length - 1;
    for (var length = limit; length > 0; length--) {
      if (_buffer.endsWith(endPrefix.substring(0, length))) {
        retained = length;
        break;
      }
    }
    final safeLength = _buffer.length - retained;
    _appendOutput(id, _buffer.substring(0, safeLength));
    _buffer = _buffer.substring(safeLength);
  }

  void _appendOutput(String id, String text) {
    if (text.isEmpty) return;
    final index = _commands.indexWhere((command) => command.id == id);
    if (index < 0) return;

    final current = _commands[index];
    _output!.write(text);
    final fullScreenDetected =
        current.fullScreenDetected || _output!.fullScreen;
    var output = _output!.text;
    var truncated = current.truncated;
    if (output.length > maxRenderedCharacters) {
      output = output.substring(output.length - maxRenderedCharacters);
      truncated = true;
    }
    _commands[index] = current.copyWith(
      output: output,
      truncated: truncated,
      fullScreenDetected: fullScreenDetected,
    );
    notifyListeners();
  }

  void _complete(String id, int? exitCode) {
    final index = _commands.indexWhere((command) => command.id == id);
    if (index < 0) return;
    final current = _commands[index];
    _commands[index] = current.copyWith(
      state: exitCode == 130
          ? ConversationCommandState.interrupted
          : ConversationCommandState.completed,
      exitCode: exitCode,
      clearExitCode: exitCode == null,
      completedAt: DateTime.now(),
    );
    _activeId = null;
    _activeFrame = null;
    _capturing = false;
    _buffer = '';
    notifyListeners();
  }

  void _onSessionChanged() {
    if (!session.isLive) _finishCompletion(null);
    final id = _activeId;
    if (id == null || session.isLive) {
      notifyListeners();
      return;
    }

    final index = _commands.indexWhere((command) => command.id == id);
    if (index >= 0) {
      final current = _commands[index];
      _commands[index] = current.copyWith(
        state: session.state == TerminalSessionState.disconnected
            ? ConversationCommandState.disconnected
            : ConversationCommandState.interrupted,
        completedAt: DateTime.now(),
      );
    }
    _activeId = null;
    _activeFrame = null;
    _capturing = false;
    _buffer = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _completion?.complete(null);
    session.removeListener(_onSessionChanged);
    unawaited(_outputSubscription?.cancel());
    super.dispose();
  }
}
