import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../../core/shell/multiplexer.dart';
import '../../core/shell/session_launch.dart';
import '../../core/shell/shell_quoting.dart';
import '../../core/ssh/connection_manager.dart';
import '../../core/ssh/ssh_connection.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../core/ssh/herdr_service.dart';
import '../../shared/models/models.dart';
import 'terminal_input_modifiers.dart';
import '../conversation_shell/conversation_session.dart';

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
    this.conversation,
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
  final ConversationSession? conversation;
  bool get isHerdrPane => launchPlan.herdrTerminalId != null;
  String paneDraft = '';

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
  bool _herdrAttached = false;
  bool _intentionalDetach = false;

  /// Presentation-neutral copy of remote PTY output.
  ///
  /// Terminal Mode continues to consume the xterm buffer, while Conversation
  /// Mode subscribes here to frame the same bytes into command/output blocks.
  /// This is a broadcast stream because opening a second presentation must not
  /// steal output from the terminal emulator.
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  Stream<String> get outputStream => _outputController.stream;

  TerminalSessionState _state = TerminalSessionState.starting;
  TerminalSessionState get state => _state;

  SshFailure? _failure;
  SshFailure? get failure => _failure;

  int? _exitCode;
  int? get exitCode => _exitCode;

  String _title;
  String get title => _title;

  /// The managed multiplexer session this terminal is attached to, if any.
  String? get tmuxSessionName => launchPlan.tmuxSessionName;

  /// The backend anchoring this terminal, or null for a direct shell.
  MultiplexerKind? get multiplexer => launchPlan.multiplexer;

  bool get isPersistent => launchPlan.mode == SessionMode.persistent;

  bool get isLive => _state == TerminalSessionState.running;

  bool get canReconnect =>
      _state == TerminalSessionState.disconnected ||
      _state == TerminalSessionState.failed ||
      _state == TerminalSessionState.ended;

  /// Subtitle shown in the terminal switcher, e.g. `Home PC · tmux: rdc-api`.
  String get subtitle {
    final parts = <String>[host.name];
    final name = tmuxSessionName;
    if (name != null) {
      final label = multiplexer?.storageValue ?? 'session';
      parts.add('$label: $name');
      if (isHerdrPane) parts.add(launchPlan.herdrTerminalId!);
    } else {
      parts.add('shell');
      // A conversation shell starts at one known directory; showing it keeps
      // the header an anchor for where the work happened (design 5.1). It is
      // the launch directory, not a live `pwd`, which framing does not track.
      final directory = launchPlan.workingDirectory;
      if (conversation != null && directory != null && directory.isNotEmpty) {
        parts.add(directory);
      }
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
      // A persistent session execs the backend's attach-or-create, so the
      // channel *is* the multiplexer client; detaching or killing the session
      // ends the channel cleanly.
      shell = await connection.execute(
        plan.shellCommand!,
        pty: !isHerdrPane,
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
    _herdrAttached = false;
    _intentionalDetach = false;
    final bridgeReady = Completer<void>();
    void bridgeFailure(Object error) {
      final failure = SshFailure(
        kind: SshFailureKind.featureUnavailable,
        message: 'Herdr pane connection ended: $error',
        action: 'Reconnect to the same pane. Herdr 0.8 or newer is required; another controller is never taken over automatically.',
      );
      _failure = failure;
      if (!bridgeReady.isCompleted) bridgeReady.completeError(failure);
      _setState(TerminalSessionState.failed);
      shell.close();
    }

    final bridge = isHerdrPane
        ? HerdrStreamDecoder(
            onFrame: (data) {
              _herdrAttached = true;
              terminal.write(data);
              if (!bridgeReady.isCompleted) bridgeReady.complete();
            },
            onClosed: (reason) {
              if (_intentionalDetach) {
                _setState(TerminalSessionState.ended);
                shell.close();
              } else {
                bridgeFailure(reason);
              }
            },
          )
        : null;
    conversation?.connecting();
    conversation?.send = (data) {
      _shell?.write(Uint8List.fromList(utf8.encode(data)));
    };
    // Decode incrementally: a UTF-8 character can span SSH packets.
    final stdoutDecoder = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(
          StringConversionSink.fromStringSink(
            _TerminalOutputSink((data) {
              if (bridge == null) {
                _writeToTerminal(data);
              } else {
                try {
                  bridge.add(data);
                } catch (error) {
                  bridgeFailure(error);
                }
              }
            }),
          ),
        );
    final stderrDecoder = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(
          StringConversionSink.fromStringSink(
            _TerminalOutputSink(_writeToTerminal),
          ),
        );

    _stdout = shell.stdout.listen(
      stdoutDecoder.add,
      onDone: () {
        stdoutDecoder.close();
        if (bridge != null) {
          try {
            bridge.finish();
          } catch (error) {
            bridgeFailure(error);
          }
          if (!bridgeReady.isCompleted) {
            bridgeFailure('No terminal frame received.');
          }
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
    _stderr = shell.stderr.listen(
      stderrDecoder.add,
      onDone: stderrDecoder.close,
      onError: (_) {},
      cancelOnError: false,
    );

    terminal.onOutput = (data) {
      final session = _shell;
      if (session == null) return;
      conversation?.terminalInput();
      final output = inputModifiers.applyTerminalInput(data);
      _writeInput(output);
    };

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (isHerdrPane) {
        _writeBridge(HerdrStreamDecoder.resize(width, height));
      } else {
        _shell?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      }
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
    if (bridge != null) {
      try {
        await bridgeReady.future.timeout(const Duration(seconds: 10));
        _writeBridge(
          HerdrStreamDecoder.resize(terminal.viewWidth, terminal.viewHeight),
        );
      } catch (_) {
        shell.close();
        rethrow;
      }
    }
  }

  void _writeToTerminal(String data) {
    terminal.write(data);
    conversation?.addOutput(data);
    if (!_outputController.isClosed) _outputController.add(data);
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
          (_state == TerminalSessionState.running ||
              isHerdrPane &&
                  _herdrAttached &&
                  !_intentionalDetach &&
                  (_state == TerminalSessionState.ended ||
                      _state == TerminalSessionState.failed))) {
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
    conversation?.terminalInput();
    final payload = submit && !text.endsWith('\n') ? '$text\n' : text;
    _writeInput(payload);
  }

  /// Sends a raw control sequence, e.g. Ctrl+C.
  void sendRaw(String sequence) {
    final session = _shell;
    if (session == null) return;
    conversation?.terminalInput();
    _writeInput(sequence);
  }

  void _writeInput(String text) =>
      _writeBridge(isHerdrPane ? HerdrStreamDecoder.input(text) : text);
  void _writeBridge(String data) =>
      _shell?.write(Uint8List.fromList(utf8.encode(data)));

  void scrollHerdr(bool up) {
    if (isHerdrPane && isLive) _writeBridge(HerdrStreamDecoder.scroll(up));
  }

  Future<void> submitPane(String text) async {
    if (!isHerdrPane || !isLive) {
      throw StateError('The Herdr pane is not connected.');
    }
    final connection = connections.connectionFor(host.id);
    if (connection == null) {
      throw StateError('The SSH connection is not available.');
    }
    await const HerdrService().submit(
      connection,
      tmuxSessionName!,
      launchPlan.herdrTerminalId!,
      text,
    );
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

  /// Detaches from the multiplexer without ending the remote session.
  ///
  /// Sends the backend's detach binding rather than closing the channel, so it
  /// tears its client down in its own time and the work keeps running. tmux and
  /// Herdr share the `Ctrl+B` prefix but differ in the key that follows, so the
  /// sequence comes from the backend rather than being hard-coded here.
  void detach() {
    if (isHerdrPane) {
      _intentionalDetach = true;
      _writeBridge(HerdrStreamDecoder.release);
      return;
    }
    final kind = multiplexer;
    if (!isPersistent || kind == null) return;
    sendRaw(Multiplexer.of(kind, quoter: ShellQuoter.posix).detachSequence);
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
    if (next == TerminalSessionState.disconnected ||
        next == TerminalSessionState.failed ||
        next == TerminalSessionState.ended) {
      conversation?.disconnected();
    }
    notifyListeners();
  }

  /// Closes this terminal. Remote work in a persistent session keeps running.
  Future<void> close() async {
    _intentionalDetach = true;
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
    unawaited(_outputController.close());
    _shell?.close();
    controller.dispose();
    inputModifiers.dispose();
    conversation?.dispose();
    super.dispose();
  }
}

class _TerminalOutputSink implements StringSink {
  _TerminalOutputSink(this.onData);
  final void Function(String) onData;
  @override
  void write(Object? object) => onData('$object');
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      onData(objects.join(separator));
  @override
  void writeCharCode(int charCode) => onData(String.fromCharCode(charCode));
  @override
  void writeln([Object? object = '']) => onData('$object\n');
}
