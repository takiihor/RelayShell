import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/enums.dart';
import '../terminal/terminal_session.dart';
import 'conversation_models.dart';

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

  static const int maxRenderedCharacters = 256 * 1024;
  static const String _recordSeparator = '\x1e';
  static const String _unitSeparator = '\x1f';
  static const int _markerTail = 192;
  static final RegExp _ansiEscape = RegExp(
    r'\x1B(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))',
  );
  static final RegExp _interactiveCommand = RegExp(
    r'^\s*(?:(?:sudo|env)\s+)*(?:herdr|ctxguard|pi|codex|claude|opencode|gemini|ssh|mosh|vim|nvim|nano|htop|top|less|more)\b',
    caseSensitive: false,
  );
  static const List<String> _alternateScreenEnable = [
    '\x1b[?1049h',
    '\x1b[?1047h',
    '\x1b[?47h',
  ];

  StreamSubscription<String>? _outputSubscription;
  final List<ConversationCommand> _commands = [];
  String _buffer = '';
  String? _activeId;
  bool _capturing = false;
  int _sequence = 0;

  List<ConversationCommand> get commands => List.unmodifiable(_commands);

  ConversationCommand? get activeCommand {
    final id = _activeId;
    if (id == null) return null;
    for (final command in _commands.reversed) {
      if (command.id == id) return command;
    }
    return null;
  }

  bool get supportsConversation => session.host.platform == RemotePlatform.posix;

  bool get canSubmit =>
      supportsConversation && session.isLive && _activeId == null;

  bool get canSendProcessInput =>
      supportsConversation && session.isLive && _activeId != null;

  /// Sends [rawCommand] through the current POSIX shell without spawning a new
  /// SSH exec channel. `eval` is a shell special builtin, so state changes such
  /// as `cd`, `export` and environment activation remain in this PTY.
  ///
  /// A quoted heredoc stages multi-line input without evaluating it while the
  /// framing wrapper itself is being parsed. The BEGIN marker is emitted only
  /// after staging, so the PTY's echo and continuation prompts are discarded
  /// instead of being mistaken for command output.
  ///
  /// The eval + END marker live in one shell compound command on one input line.
  /// This is critical for interactive programs: the shell parses the footer
  /// before starting eval, so Herdr/read/Codex cannot consume RelayShell's own
  /// footer bytes as if they were user stdin.
  void submit(String rawCommand) {
    // Preserve the user's shell text exactly. In particular, trailing spaces
    // can be meaningful after a line-continuation backslash, so Conversation
    // Mode must not silently trim or rewrite the command before execution.
    final command = rawCommand;
    if (command.trim().isEmpty || !canSubmit) return;

    final id = '${_sequence++}';
    final token = '$_nonce-$id';
    final now = DateTime.now();

    _commands.add(
      ConversationCommand(
        id: id,
        command: command,
        startedAt: now,
        state: ConversationCommandState.running,
        interactiveHint: _interactiveCommand.hasMatch(command),
      ),
    );
    _activeId = id;
    _capturing = false;
    _buffer = '';
    notifyListeners();

    final delimiter = '__RELAYSHELL_$token__';
    final wrapper = StringBuffer()
      ..writeln('__relayshell_cmd="\$(cat <<\'$delimiter\'')
      ..writeln(command)
      ..writeln(delimiter)
      ..writeln(')"')
      ..write('{ ')
      ..write("printf '\\036RELAYSHELL_BEGIN:$token\\037\\n'; ")
      ..write('eval "\$__relayshell_cmd"; ')
      ..write('__relayshell_status=\$?; ')
      ..write(
        "printf '\\036RELAYSHELL_END:$token:%s\\037\\n' \"\$__relayshell_status\"; ",
      )
      ..writeln('unset __relayshell_cmd __relayshell_status; }');

    session.sendText(wrapper.toString(), submit: true);
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

    session.sendText(text, submit: submit);
  }

  /// Sends an exact terminal sequence to the foreground process. Accessory
  /// keys use this path so Ctrl/Alt/Shift/Tab/arrows behave exactly as they do
  /// in Terminal Mode and do not get recorded as fake chat messages.
  void sendRawToActive(String sequence) {
    if (!canSendProcessInput || sequence.isEmpty) return;
    session.sendRaw(sequence);
  }

  /// Interrupts the foreground command while leaving the SSH transport and
  /// shell session alive. The wrapper should subsequently emit its exit status.
  void interrupt() {
    if (_activeId == null || !session.isLive) return;
    session.sendRaw('\x03');
  }

  String _beginMarker(String id) {
    final token = '$_nonce-$id';
    return '$_recordSeparatorRELAYSHELL_BEGIN:$token$_unitSeparator';
  }

  String _endPrefix(String id) {
    final token = '$_nonce-$id';
    return '$_recordSeparatorRELAYSHELL_END:$token:';
  }

  void _onOutput(String chunk) {
    if (_activeId == null) return;
    _buffer += chunk;
    _drainBuffer();
  }

  void _drainBuffer() {
    final id = _activeId;
    if (id == null) return;

    if (!_capturing) {
      final begin = _beginMarker(id);
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

    final endPrefix = _endPrefix(id);
    final endStart = _buffer.indexOf(endPrefix);
    if (endStart >= 0) {
      final markerEnd = _buffer.indexOf(
        _unitSeparator,
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

    // Stream output incrementally while preserving a short suffix in case the
    // end marker is split across chunks.
    if (_buffer.length > _markerTail) {
      final safeLength = _buffer.length - _markerTail;
      _appendOutput(id, _buffer.substring(0, safeLength));
      _buffer = _buffer.substring(safeLength);
    }
  }

  void _appendOutput(String id, String text) {
    if (text.isEmpty) return;
    final index = _commands.indexWhere((command) => command.id == id);
    if (index < 0) return;

    final current = _commands[index];
    final fullScreenDetected =
        current.fullScreenDetected ||
        _alternateScreenEnable.any(text.contains);
    var output = _plainText(current.output + text);
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

  static String _plainText(String value) => value
      .replaceAll(_ansiEscape, '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '');

  void _complete(String id, int? exitCode) {
    final index = _commands.indexWhere((command) => command.id == id);
    if (index < 0) return;
    final current = _commands[index];
    _commands[index] = current.copyWith(
      state: ConversationCommandState.completed,
      exitCode: exitCode,
      clearExitCode: exitCode == null,
      completedAt: DateTime.now(),
    );
    _activeId = null;
    _capturing = false;
    _buffer = '';
    notifyListeners();
  }

  void _onSessionChanged() {
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
    _capturing = false;
    _buffer = '';
    notifyListeners();
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    unawaited(_outputSubscription?.cancel());
    super.dispose();
  }
}
