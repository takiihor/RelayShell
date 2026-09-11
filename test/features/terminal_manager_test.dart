import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/database/app_database.dart';
import 'package:relayshell/core/database/credentials_repository.dart';
import 'package:relayshell/core/database/hosts_repository.dart';
import 'package:relayshell/core/database/sessions_repository.dart';
import 'package:relayshell/core/database/trusted_keys_repository.dart';
import 'package:relayshell/core/security/biometric_gate.dart';
import 'package:relayshell/core/shell/session_launch.dart';
import 'package:relayshell/core/ssh/connection_manager.dart';
import 'package:relayshell/core/ssh/credential_resolver.dart';
import 'package:relayshell/core/ssh/host_key_verifier.dart';
import 'package:relayshell/core/ssh/ssh_connection.dart';
import 'package:relayshell/core/ssh/multiplexer_service.dart';
import 'package:relayshell/core/storage/secret_store.dart';
import 'package:relayshell/features/terminal/terminal_manager.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase database;
  late _PendingConnectionManager connections;
  late TerminalManager terminals;
  late Host host;
  final plan = SessionLaunchBuilder(
    platform: RemotePlatform.posix,
    prefix: 'rdc',
  ).directShell();

  setUp(() async {
    database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final hosts = HostsRepository(database);
    connections = _PendingConnectionManager(
      hosts: hosts,
      credentials: CredentialResolver(
        credentials: CredentialsRepository(database),
        secrets: InMemorySecretStore(),
        biometrics: BiometricGate(),
        promptForSecret: (_) async => null,
        promptForKeyboardInteractive: (_) async => null,
      ),
      verifier: HostKeyVerifier(
        trustedKeys: TrustedKeysRepository(database),
        prompt: (_) async => false,
      ),
      preferences: const AppPreferences(),
    );
    terminals = TerminalManager(
      connections: connections,
      sessions: SessionsRepository(database),
      multiplexer: const MultiplexerService(),
    );
    final now = DateTime.now();
    host = Host(
      id: 'h1',
      name: 'Home PC',
      hostname: '10.0.0.5',
      port: 22,
      username: 'dev',
      authMethod: AuthMethod.privateKey,
      createdAt: now,
      updatedAt: now,
    );
  });

  tearDown(() async {
    await terminals.closeAll();
    terminals.dispose();
    await connections.dispose();
    await database.close();
  });

  test(
    'registers a starting terminal before awaiting its connection',
    () async {
      final opening = terminals.open(
        host: host,
        plan: plan,
        preferences: const AppPreferences(),
      );

      expect(terminals.findMatching(hostId: host.id, plan: plan), isNotNull);

      connections.fail();
      await opening;
    },
  );
}

class _PendingConnectionManager extends ConnectionManager {
  _PendingConnectionManager({
    required super.hosts,
    required super.credentials,
    required super.verifier,
    required super.preferences,
  });

  final _connection = Completer<SshConnection>();

  @override
  Future<SshConnection> connect(Host host) => _connection.future;

  void fail() => _connection.completeError(StateError('Connection pending.'));
}
