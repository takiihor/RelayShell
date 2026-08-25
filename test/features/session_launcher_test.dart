import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/database/app_database.dart';
import 'package:relayshell/core/database/commands_repository.dart';
import 'package:relayshell/core/database/credentials_repository.dart';
import 'package:relayshell/core/database/hosts_repository.dart';
import 'package:relayshell/core/database/projects_repository.dart';
import 'package:relayshell/core/database/sessions_repository.dart';
import 'package:relayshell/core/database/trusted_keys_repository.dart';
import 'package:relayshell/core/security/biometric_gate.dart';
import 'package:relayshell/core/shell/session_launch.dart';
import 'package:relayshell/core/ssh/connection_manager.dart';
import 'package:relayshell/core/ssh/credential_resolver.dart';
import 'package:relayshell/core/ssh/host_key_verifier.dart';
import 'package:relayshell/core/ssh/tmux_service.dart';
import 'package:relayshell/core/storage/secret_store.dart';
import 'package:relayshell/features/sessions/session_launcher.dart';
import 'package:relayshell/features/terminal/terminal_manager.dart';
import 'package:relayshell/features/terminal/terminal_session.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase database;
  late HostsRepository hosts;
  late SessionsRepository sessions;
  late ConnectionManager connections;
  late Host host;

  setUp(() async {
    database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    hosts = HostsRepository(database);
    sessions = SessionsRepository(database);
    connections = ConnectionManager(
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
    await connections.dispose();
    await database.close();
  });

  SessionLauncher launcherFor(_MatchingTerminalManager terminals) =>
      SessionLauncher(
        terminals: terminals,
        connections: connections,
        hosts: hosts,
        projects: ProjectsRepository(database),
        commands: CommandsRepository(database),
        sessions: sessions,
      );

  TerminalSession terminal({required String id}) => TerminalSession(
    id: id,
    host: host,
    launchPlan: const SessionLaunchBuilder(
      platform: RemotePlatform.posix,
      prefix: 'rdc',
    ).directShell(),
    preferences: const AppPreferences(),
    connections: connections,
  );

  test(
    'Connect focuses a matching terminal instead of opening another',
    () async {
      final existing = terminal(id: 'existing');
      final terminals = _MatchingTerminalManager(
        connections: connections,
        sessions: sessions,
        match: existing,
      );

      final result = await launcherFor(terminals)
          .openHostTerminal(host: host, preferences: const AppPreferences());

      expect(result, same(existing));
      expect(terminals.selectedId, existing.id);
      expect(terminals.opened, isFalse);
      expect(terminals.matchingPlan?.mode, SessionMode.direct);
    },
  );

  test(
    'Connect retries a matching failed terminal instead of opening another',
    () async {
      final existing = _ReconnectableTerminalSession(
        id: 'failed',
        host: host,
        launchPlan: const SessionLaunchBuilder(
          platform: RemotePlatform.posix,
          prefix: 'rdc',
        ).directShell(),
        preferences: const AppPreferences(),
        connections: connections,
      );
      final terminals = _MatchingTerminalManager(
        connections: connections,
        sessions: sessions,
        match: existing,
      );

      final result = await launcherFor(terminals)
          .openHostTerminal(host: host, preferences: const AppPreferences());

      expect(result, same(existing));
      expect(existing.reconnected, isTrue);
      expect(terminals.opened, isFalse);
    },
  );

  test(
    'New Terminal deliberately bypasses the matching-terminal lookup',
    () async {
      final opened = terminal(id: 'new');
      final terminals = _MatchingTerminalManager(
        connections: connections,
        sessions: sessions,
        match: terminal(id: 'existing'),
        openResult: opened,
      );

      final result = await launcherFor(terminals).openAdditionalHostTerminal(
        host: host,
        preferences: const AppPreferences(),
      );

      expect(result, same(opened));
      expect(terminals.lookedUp, isFalse);
      expect(terminals.opened, isTrue);
    },
  );

  test(
    'a failed terminal launch does not record a successful connection',
    () async {
      await hosts.upsert(host);
      final terminals = _MatchingTerminalManager(
        connections: connections,
        sessions: sessions,
        match: terminal(id: 'existing'),
        openResult: terminal(id: 'failed'),
      );

      await launcherFor(terminals).openAdditionalHostTerminal(
        host: host,
        preferences: const AppPreferences(),
      );

      expect((await hosts.byId(host.id))?.lastConnectedAt, isNull);
    },
  );

  test('persistent Connect uses one stable tmux session name', () async {
    final terminals = _MatchingTerminalManager(
      connections: connections,
      sessions: sessions,
      match: terminal(id: 'existing'),
    );

    await launcherFor(terminals).openHostTerminal(
      host: host,
      preferences: const AppPreferences(
        defaultSessionMode: SessionMode.persistent,
      ),
    );

    expect(terminals.matchingPlan?.tmuxSessionName, 'rdc-home-pc-shell');
  });

  test(
    'Resume reuses and reconnects a matching disconnected terminal',
    () async {
      await hosts.upsert(host);
      final now = DateTime.now();
      final record = SessionRecord(
        id: 'session-1',
        hostId: host.id,
        tmuxSessionName: 'rdc-home-pc-shell',
        displayName: 'Home shell',
        mode: SessionMode.persistent,
        createdAt: now,
        lastUsedAt: now,
      );
      await sessions.upsert(record);

      final existing = _ReconnectableTerminalSession(
        id: 'disconnected',
        host: host,
        launchPlan: const SessionLaunchBuilder(
          platform: RemotePlatform.posix,
          prefix: 'rdc',
        ).persistentSession(sessionName: 'rdc-home-pc-shell'),
        preferences: const AppPreferences(),
        connections: connections,
      );
      final terminals = _MatchingTerminalManager(
        connections: connections,
        sessions: sessions,
        match: existing,
      );

      final result = await launcherFor(terminals)
          .resumeSession(record: record, preferences: const AppPreferences());

      expect(result, same(existing));
      expect(existing.reconnected, isTrue);
      expect(terminals.opened, isFalse);
      expect(terminals.selectedId, existing.id);
    },
  );
}

class _MatchingTerminalManager extends TerminalManager {
  _MatchingTerminalManager({
    required super.connections,
    required super.sessions,
    required this.match,
    this.openResult,
  }) : super(tmux: const TmuxService());

  final TerminalSession match;
  final TerminalSession? openResult;

  SessionLaunchPlan? matchingPlan;
  String? selectedId;
  bool lookedUp = false;
  bool opened = false;

  @override
  TerminalSession? findMatching({
    required String hostId,
    String? projectId,
    required SessionLaunchPlan plan,
  }) {
    lookedUp = true;
    matchingPlan = plan;
    return match;
  }

  @override
  void setActive(String id) {
    selectedId = id;
  }

  @override
  Future<TerminalSession> open({
    required Host host,
    required SessionLaunchPlan plan,
    required AppPreferences preferences,
    Project? project,
    String? title,
    String? sessionRecordId,
  }) async {
    opened = true;
    return openResult ?? (throw StateError('Unexpected terminal open.'));
  }
}

class _ReconnectableTerminalSession extends TerminalSession {
  _ReconnectableTerminalSession({
    required super.id,
    required super.host,
    required super.launchPlan,
    required super.preferences,
    required super.connections,
  });

  bool reconnected = false;

  @override
  bool get canReconnect => true;

  @override
  Future<void> reconnect() async {
    reconnected = true;
  }
}
