import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/ssh/connection_manager.dart';
import 'package:relayshell/core/ssh/herdr_service.dart';
import 'package:relayshell/core/ssh/ssh_connection.dart';
import 'package:relayshell/features/terminal/terminal_session.dart';
import 'package:relayshell/shared/models/models.dart';

/// Opt-in native integration. Use ONLY an isolated session created for this
/// test, with one disposable shell pane. SSH authentication remains covered by
/// the existing suite; this adapter executes the exact SSH command locally.
void main() {
  final name = Platform.environment['RELAY_HERDR_TEST_SESSION'];
  test('Herdr native frames, submission, exclusive control and process-preserving reconnect', () async {
    final connection = _LocalConnection();
    final panes = await const HerdrService().panes(connection, name!);
    expect(panes, hasLength(1));
    final pane = panes.single;
    final now = DateTime.now();
    final host = Host(
      id: 'local',
      name: 'test',
      hostname: 'localhost',
      port: 22,
      username: 'test',
      authMethod: AuthMethod.privateKey,
      createdAt: now,
      updatedAt: now,
      multiplexer: MultiplexerKind.herdr,
    );
    TerminalSession makeSession(String id) => TerminalSession(
      id: id,
      host: host,
      launchPlan: HerdrService.attach(name, pane.terminalId),
      preferences: const AppPreferences(),
      connections: _LocalManager(connection),
    );
    final session = makeSession('first');
    final contender = makeSession('second');
    String screen() => List.generate(
      session.terminal.buffer.lines.length,
      (i) => session.terminal.buffer.lines[i].toString(),
    ).join('\n');
    try {
      await session.start();
      expect(session.isLive, isTrue, reason: '${session.failure}');
      await session.submitPane(
        "export RELAY_HERDR_VALUE=kept; printf 'RS_%s\\n' ready",
      );
      await _until(() => screen().contains('RS_ready'));
      await contender.start();
      expect(
        contender.isLive,
        isFalse,
        reason: 'Must not take control from another client',
      );
      expect(session.isLive, isTrue);
      await session.submitPane("sleep 1; printf 'RS_%s\\n' survived");
      await session.reconnect();
      expect(session.isLive, isTrue, reason: '${session.failure}');
      await _until(() => screen().contains('RS_survived'));
      await session.submitPane(r'''printf 'RS_%s\n' "$RELAY_HERDR_VALUE"''');
      await _until(() => screen().contains('RS_kept'));
      await session.submitPane(
        "printf 'RS_%s\\n' '你好';\nprintf 'RS_%s\\n' multiline\n",
      );
      await _until(
        () => screen().contains('RS_你好') && screen().contains('RS_multiline'),
      );
      session.terminal.resize(72, 18);
      session.scrollHerdr(true);
      session.scrollHerdr(false);
      session.detach();
      await _until(() => session.state == TerminalSessionState.ended);
      final after = await const HerdrService().panes(connection, name);
      expect(after.single.terminalId, pane.terminalId);
    } finally {
      await contender.close();
      contender.dispose();
      await session.close();
      session.dispose();
    }
  }, skip: name == null);
}

Future<void> _until(bool Function() condition) async {
  final until = DateTime.now().add(const Duration(seconds: 8));
  while (!condition()) {
    if (DateTime.now().isAfter(until)) {
      fail('Herdr did not reach the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

class _LocalManager implements ConnectionManager {
  _LocalManager(this.connection);
  final SshConnection connection;
  @override
  SshConnection? connectionFor(String hostId) => connection;
  @override
  Future<SshConnection> connect(Host host) async => connection;
  @override
  Future<SshConnection> reconnect(Host host) async => connection;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalConnection implements SshConnection {
  @override
  Stream<SshConnectionStatus> get statusStream => Stream.value(
    const SshConnectionStatus(state: SshConnectionState.connected),
  );
  @override
  Future<SSHSession> execute(
    String command, {
    bool pty = false,
    int columns = 120,
    int rows = 40,
  }) async {
    expect(pty, isFalse, reason: 'A PTY would echo or alter the NDJSON stream');
    return _ProcessSession(
      await Process.start(
        '/bin/sh',
        ['-c', command],
        environment: {'SHELL': '/bin/bash'},
      ),
    );
  }

  @override
  Future<CommandResult> run(
    String command, {
    int maxOutputBytes = 256 * 1024,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await Process.run(
      '/bin/sh',
      ['-c', command],
      environment: {'SHELL': '/bin/bash'},
    ).timeout(timeout);
    return CommandResult(
      stdout: result.stdout as String,
      stderr: result.stderr as String,
      exitCode: result.exitCode,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProcessSession implements SSHSession {
  _ProcessSession(this.process) {
    done = process.exitCode.then((value) {
      exitCode = value;
    });
  }
  final Process process;
  @override
  late final Future<void> done;
  @override
  int? exitCode;
  @override
  Stream<Uint8List> get stdout => process.stdout.map(Uint8List.fromList);
  @override
  Stream<Uint8List> get stderr => process.stderr.map(Uint8List.fromList);
  @override
  void write(Uint8List data) => process.stdin.add(data);
  @override
  void close() {
    unawaited(process.stdin.close().catchError((_) {}));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
