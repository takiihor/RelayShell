import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../../core/shell/session_launch.dart';
import '../../core/ssh/connection_manager.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../shared/models/models.dart';
import 'terminal_input_modifiers.dart';

/// Lifecycle of one terminal tab.
enum TerminalSessionState {
  /// Opening the SSH connection and the shell channel.
  starting,

  /// Attached and interactive.
  running,

  /// The connection dropped; the buffer is intact and reconnect is offered.
  disconnected,

  /// The remote shell exited normally.
  ended,

  /// Something failed before or during the session.
  failed,
}

/// One interactive terminal (SPEC 10).
///
/// Owns an xterm [Terminal] and the SSH channel feeding it. The buffer belongs
/// to this object rather than to a widget, so switching tabs, rotating the
/// device or backgrounding the app never loses scrollback, and a reconnect can
/// reuse the same buffer instead of clearing the screen.
class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this.id,
    required this.host,
    required this.launchPlan,
    required this.preferences,
    required this.connections,
    this.project,
    this.sessionRecordId,
    String? title,
  }) : _title = title ?? host.name,
       terminal = Terminal(
         maxLines: preferences.scrollbackLines,
         platform: TerminalTargetPlatform.linux,
       );

  final String id;
  final Host host;
  final Project? project;
  final SessionLaunchPlan launchPlan;
  final ConnectionManager connections;

  /// The local session record this terminal resumes or created, if any.
  final String? sessionRecordId;

  /// Settings captured when the terminal opened.
  ///
  /// Held rather than watched because changing scrollback would mean rebuilding
  /// the buffer and losing history; new settings apply to the next terminal.
  final AppPreferences preferences;

  final Terminal terminal;
  final TerminalController controller = TerminalController();
  final TerminalInputModifiers inputModifiers = TerminalInputModifiers();

  SSHSession? _shell;
  StreamSubscription<Uint8List>? _stdout;
  StreamSubscription<Uint8List>? _stderr;
  StreamSubscription<SshConnectionStatus>? _connectionStatus;
  bool _restoringAfterReconnect = false;

  TerminalSessionState _state = TerminalSessionState.starting;
  TerminalSessionState get state => _state;

  SshFailure? _failure;
  SshFailure? get failure => _failure;

  int? _exitCode;
  int? get exitCode => _exitCode;

  String _title;
  String get title => _title;

  /// The managed tmux session this terminal is attached to, if any.
  String? get tmuxSessionName => launchPlan.tmuxSessionName;

  bool get isPersistent => launchPlan.mode == SessionMode.persistent;

  bool get isLive => _state == TerminalSessionState.running;

  bool get canReconnect =>
      _state == TerminalSessionState.disconnected ||
      _state == TerminalSessionState.failed ||
      _state == TerminalSessionState.ended;

  /// Subtitle shown in the terminal switcher, e.g. `Home PC · tmux`.
  String get subtitle {
    final parts = <String>[host.name];
    final tmux = tmuxSessionName;
    if (tmux != null) {
      parts.add('tmux: $tmux');
    } else {
      parts.add('shell');
    }
    return parts.join(' · ');
  }

  /// Opens the connection and starts the shell.
  Future<void> start() async {
    _setState(TerminalSessionState.starting);
    _failure = null;

    try {
      final connection = await connections.connect(host);
      _watchConnection(connection);
      await _openShell(connection);
      _setState(TerminalSessionState.running);
    } on SshFailure catch (failure) {
      _failure = failure;
      _writeSystemLine(failure.message);
      if (failure.action != null) _writeSystemLine(failure.action!);
      _setState(TerminalSessionState.failed);
    } catch (error) {
      _failure = SshFailure.from(
        error,
        hostname: host.hostname,
        port: host.port,
      );
      _writeSystemLine(_failure!.message);
      _setState(TerminalSessionState.failed);
    }
  }

  Future<void> _openShell(SshConnection connection) async {
    final plan = launchPlan;

    final SSHSession shell;
    if (plan.usesExec) {
      // A persistent session execs `tmux new-session -A`, so the channel *is*
      // the tmux client; detaching or killing tmux ends the channel cleanly.
      shell = await connection.execute(
        plan.shellCommand!,
        pty: true,
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
      );
    } else {
      shell = await connection.openShell(
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
        terminalType: preferences.terminalType,
      );
    }

    _shell = shell;

    _stdout = shell.stdout.listen(
      _writeToTerminal,
      onError: (_) {},
      cancelOnError: false,
    );
    _stderr = shell.stderr.listen(
      _writeToTerminal,
      onError: (_) {},
      cancelOnError: false,
    );

    terminal.onOutput = (data) {
      final session = _shell;
      if (session == null) return;
      final output = inputModifiers.applyTerminalInput(data);
      session.write(Uint8List.fromList(utf8.encode(output)));
    };

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _shell?.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };

    terminal.onTitleChange = (title) {
      if (title.trim().isEmpty) return;
      _title = title.trim();
      notifyListeners();
    };

    unawaited(_watchShellExit(shell));

    // A direct session types its setup into the shell instead of exec'ing it,
    // so a bad path leaves the user at a prompt rather than disconnecting them.
    final initialInput = plan.initialInput;
    if (initialInput != null && initialInput.isNotEmpty) {
      shell.write(Uint8List.fromList(utf8.encode(initialInput)));
    }
  }

  void _writeToTerminal(Uint8List data) {
    terminal.write(const Utf8Decoder(allowMalformed: true).convert(data));
  }

  Future<void> _watchShellExit(SSHSession shell) async {
    try {
      await shell.done;
    } catch (_) {
      // Reported through the connection status watcher.
    }
    if (_shell != shell) return;
    _exitCode = shell.exitCode;
    _shell = null;

    if (_state == TerminalSessionState.running) {
      _writeSystemLine(
        _exitCode == null ? 'Session ended.' : 'Session ended ($_exitCode).',
      );
      _setState(TerminalSessionState.ended);
    }
  }

  void _watchConnection(SshConnection connection) {
    _connectionStatus?.cancel();
    _connectionStatus = connection.statusStream.listen((status) {
      if (status.state == SshConnectionState.failed &&
          _state == TerminalSessionState.running) {
        _failure = status.failure;
        _writeSystemLine(status.failure?.message ?? 'Connection lost.');
        _setState(TerminalSessionState.disconnected);
      }
      if (status.state == SshConnectionState.connected &&
          _state == TerminalSessionState.disconnected) {
        unawaited(_restoreAfterAutoReconnect(connection));
      }
    });
  }

  /// Reopens the channel after [ConnectionManager] restores the shared SSH
  /// transport. Persistent tabs reattach to their existing tmux session;
  /// direct tabs get a new shell, which is all that can survive a dropped
  /// network connection.
  Future<void> _restoreAfterAutoReconnect(SshConnection connection) async {
    if (_restoringAfterReconnect ||
        _state != TerminalSessionState.disconnected) {
      return;
    }
    _restoringAfterReconnect = true;
    _writeSystemLine('Connection restored. Reattaching…');
    _setState(TerminalSessionState.starting);

    try {
      await _detachShell();
      await _openShell(connection);
      _failure = null;
      _exitCode = null;
      _setState(TerminalSessionState.running);
    } catch (error) {
      final failure = error is SshFailure
          ? error
          : SshFailure.from(error, hostname: host.hostname, port: host.port);
      _failure = failure;
      _writeSystemLine(failure.message);
      _setState(TerminalSessionState.failed);
    } finally {
      _restoringAfterReconnect = false;
    }
  }

  /// Reconnects and, for a persistent session, reattaches to the same tmux
  /// session so the user lands back in their work (SPEC 9.4, 40.4).
  Future<void> reconnect() async {
    if (_state == TerminalSessionState.starting) return;

    await _detachShell();
    _writeSystemLine('Reconnecting…');
    _setState(TerminalSessionState.starting);

    _restoringAfterReconnect = true;
    try {
      final connection = await connections.reconnect(host);
      _watchConnection(connection);
      await _openShell(connection);
      _failure = null;
      _exitCode = null;
      _setState(TerminalSessionState.running);
    } catch (error) {
      final failure = error is SshFailure
          ? error
          : SshFailure.from(error, hostname: host.hostname, port: host.port);
      _failure = failure;
      _writeSystemLine(failure.message);
      _setState(TerminalSessionState.failed);
    } finally {
      _restoringAfterReconnect = false;
    }
  }

  /// Sends text as if typed, appending a newline when [submit] is set.
  void sendText(String text, {bool submit = true}) {
    final session = _shell;
    if (session == null) return;
    final payload = submit && !text.endsWith('\n') ? '$text\n' : text;
    session.write(Uint8List.fromList(utf8.encode(payload)));
  }

  /// Sends a raw control sequence, e.g. Ctrl+C.
  void sendRaw(String sequence) {
    final session = _shell;
    if (session == null) return;
    session.write(Uint8List.fromList(utf8.encode(sequence)));
  }

  /// Pastes text through the terminal so bracketed-paste mode is respected.
  void paste(String text) => terminal.paste(text);

  /// The currently selected text, or null when nothing is selected.
  String? selectedText() {
    final selection = controller.selection;
    if (selection == null) return null;
    final text = terminal.buffer.getText(selection);
    return text.isEmpty ? null : text;
  }

  void clearSelection() => controller.clearSelection();

  /// Detaches from tmux without ending the remote session.
  ///
  /// Sends the tmux detach binding rather than closing the channel, so tmux
  /// tears the client down in its own time and the work keeps running.
  void detachTmux() {
    if (!isPersistent) return;
    sendRaw('\x02d');
  }

  Future<void> _detachShell() async {
    await _stdout?.cancel();
    await _stderr?.cancel();
    _stdout = null;
    _stderr = null;
    terminal.onOutput = null;
    terminal.onResize = null;
    _shell?.close();
    _shell = null;
  }

  void _writeSystemLine(String message) {
    // Marked and coloured so app messages are never mistaken for remote output.
    terminal.write('\r\n\x1b[38;5;245m— $message\x1b[0m\r\n');
  }

  void _setState(TerminalSessionState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  /// Closes this terminal. Remote work in a persistent session keeps running.
  Future<void> close() async {
    await _connectionStatus?.cancel();
    _connectionStatus = null;
    await _detachShell();
    _setState(TerminalSessionState.ended);
  }

  @override
  void dispose() {
    unawaited(_connectionStatus?.cancel());
    unawaited(_stdout?.cancel());
    unawaited(_stderr?.cancel());
    _shell?.close();
    controller.dispose();
    inputModifiers.dispose();
    super.dispose();
  }
}
