import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/shell/session_launch.dart';
import '../../core/shell/shell_quoting.dart';
import '../../shared/models/enums.dart';

enum ConversationCommandState { running, completed, interrupted, unknown }

class ConversationCommand {
  ConversationCommand(this.id, this.command) : submittedAt = DateTime.now();

  final int id;
  final String command;
  final DateTime submittedAt;
  DateTime? completedAt;
  ConversationCommandState state = ConversationCommandState.running;
  int? exitCode;
  String output = '';
  bool truncated = false;
  bool interactive = false;
}

/// A bounded, in-memory presentation of an explicitly owned Bash PTY.
/// OSC markers are independent of the visible prompt. No command is replayed
/// after a disconnect, and terminal input invalidates synchronization.
class ConversationSession extends ChangeNotifier {
  ConversationSession({String? nonce}) : nonce = nonce ?? const Uuid().v4();

  static const maxCommands = 50;
  static const maxOutputCharacters = 32768;
  static const maxCommandCharacters = 16384;
  final String nonce;
  final List<ConversationCommand> _commands = [];
  List<ConversationCommand> get commands => List.unmodifiable(_commands);
  ConversationCommand? get active => _active;
  ConversationCommand? _active;
  bool ready = false;
  bool unavailable = false;
  int generation = 0;
  String draft = '';
  int _nextId = 0;
  String _escape = '';
  bool _discardEscape = false;
  bool _begun = false;
  Timer? _refresh;
  Timer? _handshake;
  void Function(String)? send;

  // Bash ANSI-C quoting keeps multiline input on ONE readline input line.
  // No expansion or evaluation happens until eval executes in the current shell.
  static String quoteCommand(String value) {
    if (value.contains('\x00') || value.length > maxCommandCharacters) {
      throw ArgumentError('Command contains NUL or exceeds the input limit.');
    }
    final escaped = value
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAllMapped(
          RegExp(r'[\x01-\x1f\x7f]'),
          (match) =>
              '\\x${match[0]!.codeUnitAt(0).toRadixString(16).padLeft(2, '0')}',
        );
    return "\$'$escaped'";
  }

  SessionLaunchPlan launchPlan({String? workingDirectory}) {
    final hook =
        "__rs_status=\$?; builtin printf '\\033]777;RS:$nonce:E:%s:%s\\007' "
        r'"${__rs_id:-0}" "$__rs_status"';
    final command =
        'exec env HISTFILE=/dev/null '
        'PROMPT_COMMAND=${ShellQuoter.posix.quote(hook)} '
        'bash --noprofile --norc -i';
    return SessionLaunchPlan(
      mode: SessionMode.direct,
      workingDirectory: workingDirectory,
      shellCommand: workingDirectory == null || workingDirectory.isEmpty
          ? command
          : '${ShellQuoter.posix.changeDirectory(workingDirectory)} && $command',
    );
  }

  void connecting() {
    disconnected();
    generation++;
    unavailable = false;
    _escape = '';
    _discardEscape = false;
    _handshake = Timer(const Duration(seconds: 10), () {
      if (!ready) {
        unavailable = true;
        notifyListeners();
      }
    });
  }

  bool submit(String command) {
    if (!ready || _active != null || command.trim().isEmpty || send == null) {
      return false;
    }
    final quoted = quoteCommand(command);
    final entry = ConversationCommand(++_nextId, command);
    if (_commands.length == maxCommands) _commands.removeAt(0);
    _commands.add(entry);
    _active = entry;
    _begun = false;
    ready = false;
    send!(
      "__rs_id=${entry.id}; builtin printf "
      "'\\033]777;RS:$nonce:B:${entry.id}\\007'; "
      '(exit "\$__rs_status"); builtin eval -- $quoted\n',
    );
    notifyListeners();
    return true;
  }

  void interrupt() {
    if (_active == null) return;
    send?.call('\x03');
  }

  void terminalInput() {
    // Even input sent to a foreground program could queue a subsequent shell
    // command. Finish its existing card, but require a fresh shell afterwards.
    ready = false;
    unavailable = true;
    notifyListeners();
  }

  void disconnected() {
    _handshake?.cancel();
    ready = false;
    final entry = _active;
    if (entry != null) {
      entry.state = ConversationCommandState.unknown;
      entry.completedAt = DateTime.now();
      _active = null;
    }
    notifyListeners();
  }

  void clear() {
    _commands.removeWhere((entry) => entry != _active);
    notifyListeners();
  }

  /// Incremental escape parser: network chunks may end inside any marker or
  /// ANSI sequence. Escape payloads have a cap even for a malformed remote OSC.
  void addOutput(String chunk) {
    final plain = StringBuffer();
    void flush() {
      if (plain.isNotEmpty && _begun && _active != null) {
        final entry = _active!;
        entry.output += plain.toString();
        if (entry.output.length > maxOutputCharacters) {
          var cut = entry.output.length - maxOutputCharacters;
          // Keep UTF-16 surrogate pairs intact at the retention boundary.
          if (cut > 0 && (entry.output.codeUnitAt(cut) & 0xfc00) == 0xdc00) {
            cut++;
          }
          entry.output = entry.output.substring(cut);
          entry.truncated = true;
        }
      }
      plain.clear();
    }

    for (final rune in chunk.runes) {
      final char = String.fromCharCode(rune);
      if (_escape.isEmpty) {
        if (rune == 27) {
          flush();
          _escape = char;
        } else if (rune == 10 || rune == 9 || rune >= 32 && rune != 127) {
          plain.write(char);
        }
        continue;
      }
      _escape += char;
      final osc = _escape.startsWith('\x1b]');
      final csi = _escape.startsWith('\x1b[');
      final finished = osc
          ? rune == 7 || _escape.endsWith('\x1b\\')
          : csi
          ? _escape.length > 2 && rune >= 0x40 && rune <= 0x7e
          : _escape.length >= 2;
      if (finished) {
        if (!_discardEscape) {
          if (osc) _marker(_escape);
          if (csi && RegExp(r'^\x1b\[\?(47|1047|1049)h$').hasMatch(_escape)) {
            _active?.interactive = true;
          }
        }
        _escape = '';
        _discardEscape = false;
      } else if (_escape.length > 512) {
        _escape = osc ? '\x1b]' : '\x1b[';
        _discardEscape = true;
      }
    }
    flush();
    // Rebuild at most 20 times/second for an unbounded remote log stream.
    _refresh ??= Timer(const Duration(milliseconds: 50), () {
      _refresh = null;
      notifyListeners();
    });
  }

  void _marker(String sequence) {
    final prefix = '\x1b]777;RS:$nonce:';
    if (!sequence.startsWith(prefix)) return;
    final payload = sequence
        .substring(prefix.length)
        .replaceAll(RegExp(r'[\x07\x1b\\]'), '');
    final parts = payload.split(':');
    if (parts.length == 2 && parts[0] == 'B' && parts[1] == '${_active?.id}') {
      _begun = true;
    } else if (parts.length == 3 && parts[0] == 'E') {
      final code = int.tryParse(parts[2]);
      if (code == null || code < 0 || code > 255) return;
      if (parts[1] == '0' && _active == null && !unavailable) {
        ready = true;
        _handshake?.cancel();
      } else if (_begun && parts[1] == '${_active?.id}') {
        final entry = _active!;
        entry.exitCode = code;
        entry.completedAt = DateTime.now();
        entry.state = code == 130
            ? ConversationCommandState.interrupted
            : ConversationCommandState.completed;
        _active = null;
        _begun = false;
        ready = !unavailable;
      }
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _handshake?.cancel();
    super.dispose();
  }
}
