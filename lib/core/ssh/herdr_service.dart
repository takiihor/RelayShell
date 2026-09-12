import 'dart:convert';

import '../shell/session_launch.dart';
import '../shell/shell_quoting.dart';
import '../../shared/models/enums.dart';
import 'ssh_connection.dart';

/// Stable terminal IDs are used for attachment: pane IDs can change on a move.
class HerdrPane {
  const HerdrPane({
    required this.id,
    required this.terminalId,
    required this.title,
    required this.status,
    this.directory,
    this.agent,
  });
  final String id;
  final String terminalId;
  final String title;
  final String status;
  final String? directory;
  final String? agent;
}

class HerdrService {
  const HerdrService();

  static String command(String session, String arguments) =>
      ShellQuoter.posix.loginShell(
        'herdr --session ${ShellQuoter.posix.quote(session)} $arguments',
      );

  static SessionLaunchPlan attach(String session, String terminalId) =>
      SessionLaunchPlan(
        mode: SessionMode.persistent,
        multiplexer: MultiplexerKind.herdr,
        tmuxSessionName: session,
        herdrTerminalId: terminalId,
        shellCommand: command(
          session,
          'terminal session control ${ShellQuoter.posix.quote(terminalId)}',
        ),
      );

  Future<List<HerdrPane>> panes(
    SshConnection connection,
    String session,
  ) async {
    final result = await connection.run(command(session, 'pane list'));
    if (!result.succeeded) throw StateError(result.combined.trim());
    return parsePanes(result.stdout);
  }

  Future<void> submit(
    SshConnection connection,
    String session,
    String terminalId,
    String text,
  ) async {
    if (text.isEmpty || text.length > 16384 || text.contains('\x00')) {
      throw const FormatException('Input is empty, too long, or contains NUL.');
    }
    // Resolve again because moving a pane changes its public pane ID. Never
    // fall back to whichever pane happens to be focused on the computer.
    final current = (await panes(
      connection,
      session,
    )).where((p) => p.terminalId == terminalId);
    if (current.isEmpty) {
      throw StateError('This Herdr terminal no longer exists.');
    }
    final pane = current.single;
    final result = await connection.run(submissionCommand(session, pane, text));
    if (!result.succeeded) throw StateError(result.combined.trim());
  }

  static String submissionCommand(String session, HerdrPane pane, String text) {
    final payload = base64Encode(utf8.encode(text));
    final operation = pane.agent == null ? 'pane run' : 'agent prompt';
    // A sentinel preserves trailing newlines across command substitution. The
    // decoded text is always one quoted argument, never evaluated by this shell.
    return ShellQuoter.posix.loginShell(
      '__relayshell_input=\$(printf %s $payload | base64 -d; printf .); '
      'herdr --session ${ShellQuoter.posix.quote(session)} $operation '
      '${ShellQuoter.posix.quote(pane.id)} "\${__relayshell_input%.}"',
    );
  }

  static List<HerdrPane> parsePanes(String output) {
    final json = jsonDecode(output);
    if (json is! Map ||
        json['result'] is! Map ||
        json['result']['panes'] is! List) {
      throw const FormatException('Herdr returned an invalid pane list.');
    }
    return (json['result']['panes'] as List).map((value) {
      if (value is! Map ||
          value['pane_id'] is! String ||
          value['terminal_id'] is! String ||
          (value['terminal_id'] as String).isEmpty) {
        throw const FormatException(
          'Herdr returned a pane without an identity.',
        );
      }
      final agent =
          value['display_agent'] as String? ?? value['agent'] as String?;
      return HerdrPane(
        id: value['pane_id'] as String,
        terminalId: value['terminal_id'] as String,
        title:
            value['label'] as String? ??
            value['title'] as String? ??
            agent ??
            value['pane_id'] as String,
        status: value['agent_status'] as String? ?? 'unknown',
        agent: agent,
        directory:
            value['foreground_cwd'] as String? ?? value['cwd'] as String?,
      );
    }).toList();
  }
}

/// Herdr 0.8 terminal session control's NDJSON boundary. Frames are rendered
/// screens, NOT raw process output; never feed them into command framing.
class HerdrStreamDecoder {
  HerdrStreamDecoder({required this.onFrame, required this.onClosed});
  static const maxRecordCharacters = 4 * 1024 * 1024;
  final void Function(String) onFrame;
  final void Function(String) onClosed;
  String _pending = '';
  int? _sequence;
  bool _closed = false;

  void add(String chunk) {
    if (_closed) return;
    var start = 0;
    while (start < chunk.length) {
      final end = chunk.indexOf('\n', start);
      final part = chunk.substring(start, end < 0 ? chunk.length : end);
      if (_pending.length + part.length > maxRecordCharacters) {
        throw const FormatException(
          'Herdr frame exceeds the mobile buffer limit.',
        );
      }
      _pending += part;
      if (end < 0) return;
      final line = _pending;
      _pending = '';
      start = end + 1;
      if (line.trim().isEmpty) continue;
      final record = jsonDecode(line);
      if (record is! Map) {
        throw const FormatException('Invalid Herdr stream record.');
      }
      if (record['type'] == 'terminal.closed') {
        _closed = true;
        onClosed(
          record['reason'] as String? ?? 'Herdr terminal stream closed.',
        );
        return;
      }
      if (record['type'] != 'terminal.frame' ||
          record['encoding'] != 'ansi' ||
          record['seq'] is! int ||
          record['bytes'] is! String ||
          record['full'] is! bool) {
        throw const FormatException('Unsupported Herdr terminal stream.');
      }
      final sequence = record['seq'] as int;
      if (_sequence == null && record['full'] != true ||
          _sequence != null &&
              sequence != _sequence! + 1 &&
              record['full'] != true) {
        throw const FormatException(
          'Herdr frame synchronization lost. Reconnect to continue.',
        );
      }
      if (_sequence != null && sequence <= _sequence!) {
        throw const FormatException('Herdr frame sequence moved backwards.');
      }
      _sequence = sequence;
      onFrame(utf8.decode(base64Decode(record['bytes'] as String)));
    }
  }

  void finish() {
    if (_pending.trim().isNotEmpty) {
      throw const FormatException('Incomplete Herdr terminal frame.');
    }
  }

  static String input(String text) =>
      '${jsonEncode({'type': 'terminal.input', 'text': text})}\n';
  static String resize(int columns, int rows) =>
      '${jsonEncode({'type': 'terminal.resize', 'cols': columns.clamp(1, 1000), 'rows': rows.clamp(1, 1000)})}\n';
  static String scroll(bool up, {int lines = 3}) =>
      '${jsonEncode({'type': 'terminal.scroll', 'direction': up ? 'up' : 'down', 'lines': lines, 'source': 'page_key'})}\n';
  static const release = '{"type":"terminal.release"}\n';
}
