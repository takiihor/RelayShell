import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/database/app_database.dart';
import 'package:relayshell/core/database/commands_repository.dart';
import 'package:relayshell/core/database/credentials_repository.dart';
import 'package:relayshell/core/database/hosts_repository.dart';
import 'package:relayshell/core/database/preferences_repository.dart';
import 'package:relayshell/core/database/projects_repository.dart';
import 'package:relayshell/core/database/schema.dart';
import 'package:relayshell/core/database/sessions_repository.dart';
import 'package:relayshell/core/database/trusted_keys_repository.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;

  Future<AppDatabase> openMemory() =>
      AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);

  Host makeHost({String id = 'h1', String name = 'Home PC'}) {
    final now = DateTime.now();
    return Host(
      id: id,
      name: name,
      hostname: '10.0.0.5',
      port: 22,
      username: 'dev',
      authMethod: AuthMethod.privateKey,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async => database = await openMemory());
  tearDown(() async => database.close());

  group('schema', () {
    test('creates every table the data model requires', () async {
      final rows = await database.db.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ?',
        whereArgs: ['table'],
      );
      final tables = rows.map((row) => row['name'] as String).toSet();

      for (final expected in const [
        'hosts',
        'credentials',
        'trusted_host_keys',
        'projects',
        'commands',
        'terminal_profiles',
        'session_records',
        'port_forward_profiles',
        'wol_profiles',
        'app_preferences',
        'recent_items',
      ]) {
        expect(tables, contains(expected), reason: 'missing table $expected');
      }
    });

    test('reports the current schema version', () async {
      final result = await database.db.rawQuery('PRAGMA user_version');
      expect(result.first.values.first, schemaVersion);
    });

    test('enforces foreign keys', () async {
      final result = await database.db.rawQuery('PRAGMA foreign_keys');
      expect(result.first.values.first, 1);
    });

    test('credentials table holds no column for secret material', () async {
      // The release gate depends on secrets never reaching SQLite (SPEC 44.1).
      final columns = await database.db.rawQuery(
        'PRAGMA table_info(credentials)',
      );
      final names = columns
          .map((c) => (c['name']! as String).toLowerCase())
          .toList();

      for (final forbidden in const [
        'private_key',
        'password',
        'passphrase',
        'secret',
        'key_data',
      ]) {
        expect(names, isNot(contains(forbidden)));
      }
    });
  });

  group('migrations', () {
    test(
      'v3 preserves legacy session rows and adds nullable pane identity',
      () async {
        final legacy = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        try {
          for (final sql in createSchemaStatements) {
            await legacy.execute(sql);
          }
          for (final sql in schemaMigrations.first.statements) {
            await legacy.execute(sql);
          }
          await legacy.insert('hosts', makeHost().toRow());
          final record = SessionRecord(
            id: 'legacy',
            hostId: 'h1',
            displayName: 'Daily',
            mode: SessionMode.persistent,
            tmuxSessionName: 'daily',
            createdAt: DateTime.now(),
            lastUsedAt: DateTime.now(),
          );
          await legacy.insert(
            'session_records',
            record.toRow()..remove('herdr_terminal_id'),
          );
          for (final sql in schemaMigrations.last.statements) {
            await legacy.execute(sql);
          }
          final restored = SessionRecord.fromRow(
            (await legacy.query('session_records')).single,
          );
          expect(restored.tmuxSessionName, 'daily');
          expect(restored.herdrTerminalId, isNull);
        } finally {
          await legacy.close();
        }
      },
    );

    test('a fresh database lands on the current version', () async {
      final reopened = await openMemory();
      final result = await reopened.db.rawQuery('PRAGMA user_version');
      expect(result.first.values.first, schemaVersion);
      await reopened.close();
    });

    test('every registered migration is reachable and ordered', () {
      // A gap or a repeat here would silently skip a migration on upgrade.
      final versions = schemaMigrations.map((m) => m.version).toList();
      expect(versions, List.generate(versions.length, (i) => i + 2));
      expect(schemaMigrations.last.version, schemaVersion);
    });

    test('v2 gives every host a multiplexer defaulting to tmux', () async {
      // Replayed over a fresh database too, so a new install and an upgraded
      // one are the same shape -- which is why the column is absent from
      // createSchemaStatements.
      final columns = await database.db.rawQuery('PRAGMA table_info(hosts)');
      final multiplexer = columns.firstWhere(
        (column) => column['name'] == 'multiplexer',
      );
      expect(multiplexer['dflt_value'], "'tmux'");

      // A host saved before the column existed still reads back as tmux.
      await database.db.insert('hosts', {
        'id': 'legacy',
        'name': 'Legacy',
        'hostname': '10.0.0.9',
        'port': 22,
        'username': 'dev',
        'auth_method': 'private_key',
        'created_at': 0,
        'updated_at': 0,
      });
      final loaded = await HostsRepository(database).byId('legacy');
      expect(loaded!.multiplexer, MultiplexerKind.tmux);
    });
  });

  group('HostsRepository', () {
    test(
      'pane shortcuts stay distinct from each other and the workspace',
      () async {
        await HostsRepository(database).upsert(makeHost());
        final repository = SessionsRepository(database);
        for (final terminal in [null, 'term_one', 'term_two']) {
          await repository.upsert(
            SessionRecord(
              id: terminal ?? 'workspace',
              hostId: 'h1',
              displayName: 'Daily',
              mode: SessionMode.persistent,
              tmuxSessionName: 'daily',
              herdrTerminalId: terminal,
              createdAt: DateTime.now(),
              lastUsedAt: DateTime.now(),
            ),
          );
        }
        expect(await repository.recent(), hasLength(3));
        expect(
          (await repository.byTmuxName(
            hostId: 'h1',
            tmuxSessionName: 'daily',
          ))!.id,
          'workspace',
        );
        expect(
          (await repository.byTmuxName(
            hostId: 'h1',
            tmuxSessionName: 'daily',
            herdrTerminalId: 'term_two',
          ))!.id,
          'term_two',
        );
      },
    );

    test('round-trips a host', () async {
      final repository = HostsRepository(database);
      await repository.upsert(makeHost());

      final loaded = await repository.byId('h1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Home PC');
      expect(loaded.hostname, '10.0.0.5');
      expect(loaded.authMethod, AuthMethod.privateKey);
    });

    test('orders favourites first', () async {
      final repository = HostsRepository(database);
      await repository.upsert(makeHost(id: 'a', name: 'Alpha'));
      await repository.upsert(makeHost(id: 'b', name: 'Beta'));
      await repository.setFavorite('b', true);

      final all = await repository.all();
      expect(all.first.id, 'b');
    });

    test('searches by name, hostname and username', () async {
      final repository = HostsRepository(database);
      await repository.upsert(makeHost(id: 'a', name: 'Production VPS'));

      expect(await repository.search('Produc'), hasLength(1));
      expect(await repository.search('10.0.0'), hasLength(1));
      expect(await repository.search('dev'), hasLength(1));
      expect(await repository.search('nothing'), isEmpty);
    });

    test('emits the current rows, then again after a write', () async {
      final repository = HostsRepository(database);

      // Waiting for exactly two emissions rather than sleeping keeps this
      // deterministic: the first is the initial read, the second the write.
      final emissions = repository.watchAll().take(2).toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repository.upsert(makeHost());

      final results = await emissions.timeout(const Duration(seconds: 5));
      expect(results.first, isEmpty);
      expect(results.last, hasLength(1));
      expect(results.last.single.name, 'Home PC');
    });
  });

  group('cascading deletes', () {
    test('deleting a host removes its projects and sessions', () async {
      final hosts = HostsRepository(database);
      final projects = ProjectsRepository(database);
      final sessions = SessionsRepository(database);
      final now = DateTime.now();

      await hosts.upsert(makeHost());
      await projects.upsert(
        Project(
          id: 'p1',
          name: 'App',
          hostId: 'h1',
          remotePath: '/srv/app',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await sessions.upsert(
        SessionRecord(
          id: 's1',
          hostId: 'h1',
          displayName: 'shell',
          mode: SessionMode.direct,
          createdAt: now,
          lastUsedAt: now,
        ),
      );

      await hosts.delete('h1');

      expect(await projects.all(), isEmpty);
      expect(await sessions.all(), isEmpty);
    });

    test(
      'deleting a credential detaches it without deleting the host',
      () async {
        final hosts = HostsRepository(database);
        final credentials = CredentialsRepository(database);
        final now = DateTime.now();

        await credentials.upsert(
          Credential(
            id: 'c1',
            name: 'Key',
            type: CredentialType.privateKey,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await hosts.upsert(makeHost().copyWith(credentialId: 'c1'));

        await credentials.delete('c1');

        final host = await hosts.byId('h1');
        expect(host, isNotNull);
        expect(host!.credentialId, isNull);
      },
    );
  });

  group('TrustedKeysRepository', () {
    test('finds a key by endpoint and type', () async {
      final repository = TrustedKeysRepository(database);
      await repository.trust(
        TrustedHostKey(
          id: 't1',
          hostname: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprintSha256: 'SHA256:abc',
          trustedAt: DateTime.now(),
        ),
      );

      expect(
        await repository.find(
          hostname: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
        ),
        isNotNull,
      );
    });

    test('a different port is a different endpoint', () async {
      // Editing a host's port must not inherit the old trust (SPEC 8.4).
      final repository = TrustedKeysRepository(database);
      await repository.trust(
        TrustedHostKey(
          id: 't1',
          hostname: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprintSha256: 'SHA256:abc',
          trustedAt: DateTime.now(),
        ),
      );

      expect(
        await repository.find(
          hostname: 'example.com',
          port: 2222,
          keyType: 'ssh-ed25519',
        ),
        isNull,
      );
    });

    test('a different key type is tracked separately', () async {
      final repository = TrustedKeysRepository(database);
      await repository.trust(
        TrustedHostKey(
          id: 't1',
          hostname: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprintSha256: 'SHA256:abc',
          trustedAt: DateTime.now(),
        ),
      );

      expect(
        await repository.find(
          hostname: 'example.com',
          port: 22,
          keyType: 'ssh-rsa',
        ),
        isNull,
      );
    });

    test('revoking an endpoint forgets every key type for it', () async {
      final repository = TrustedKeysRepository(database);
      for (final type in ['ssh-ed25519', 'ssh-rsa']) {
        await repository.trust(
          TrustedHostKey(
            id: 't-$type',
            hostname: 'example.com',
            port: 22,
            keyType: type,
            fingerprintSha256: 'SHA256:$type',
            trustedAt: DateTime.now(),
          ),
        );
      }

      await repository.revokeEndpoint(hostname: 'example.com', port: 22);
      expect(
        await repository.forEndpoint(hostname: 'example.com', port: 22),
        isEmpty,
      );
    });

    test(
      're-trusting the same endpoint replaces rather than duplicates',
      () async {
        final repository = TrustedKeysRepository(database);
        for (final fingerprint in ['SHA256:old', 'SHA256:new']) {
          await repository.trust(
            TrustedHostKey(
              id: 't-$fingerprint',
              hostname: 'example.com',
              port: 22,
              keyType: 'ssh-ed25519',
              fingerprintSha256: fingerprint,
              trustedAt: DateTime.now(),
            ),
          );
        }

        final keys = await repository.forEndpoint(
          hostname: 'example.com',
          port: 22,
        );
        expect(keys, hasLength(1));
        expect(keys.single.fingerprintSha256, 'SHA256:new');
      },
    );
  });

  group('CommandsRepository scoping', () {
    Future<void> seed() async {
      final hosts = HostsRepository(database);
      final projects = ProjectsRepository(database);
      final commands = CommandsRepository(database);
      final now = DateTime.now();

      await hosts.upsert(makeHost());
      await projects.upsert(
        Project(
          id: 'p1',
          name: 'App',
          hostId: 'h1',
          remotePath: '/srv/app',
          createdAt: now,
          updatedAt: now,
        ),
      );

      for (final (id, scope, hostId, projectId) in [
        ('g', CommandScope.global, null, null),
        ('h', CommandScope.host, 'h1', null),
        ('p', CommandScope.project, null, 'p1'),
      ]) {
        await commands.upsert(
          SavedCommand(
            id: id,
            name: id,
            command: 'echo $id',
            scope: scope,
            hostId: hostId,
            projectId: projectId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    test('global commands are visible everywhere', () async {
      await seed();
      final visible = await CommandsRepository(database).visibleIn();
      expect(visible.map((c) => c.id), ['g']);
    });

    test('a host context adds that host\'s commands', () async {
      await seed();
      final visible = await CommandsRepository(database)
          .visibleIn(hostId: 'h1');
      expect(visible.map((c) => c.id).toSet(), {'g', 'h'});
    });

    test('a project context adds host and project commands', () async {
      await seed();
      final visible = await CommandsRepository(database)
          .visibleIn(hostId: 'h1', projectId: 'p1');
      expect(visible.map((c) => c.id).toSet(), {'g', 'h', 'p'});
    });

    test('another host does not see the first host\'s commands', () async {
      await seed();
      final visible = await CommandsRepository(database)
          .visibleIn(hostId: 'other');
      expect(visible.map((c) => c.id), ['g']);
    });
  });

  group('SessionsRepository', () {
    test(
      'recent collapses equivalent direct sessions without hiding targets',
      () async {
        final hosts = HostsRepository(database);
        final sessions = SessionsRepository(database);
        final now = DateTime.now();

        await hosts.upsert(makeHost());
        await hosts.upsert(makeHost(id: 'h2', name: 'Work PC'));
        for (var index = 0; index < 5; index++) {
          await sessions.upsert(
            SessionRecord(
              id: 'duplicate-$index',
              hostId: 'h1',
              displayName: 'Home PC',
              mode: SessionMode.direct,
              workingDirectory: '/home/dev',
              createdAt: now.subtract(Duration(minutes: index)),
              lastUsedAt: now.subtract(Duration(minutes: index)),
            ),
          );
        }
        await sessions.upsert(
          SessionRecord(
            id: 'other-host',
            hostId: 'h2',
            displayName: 'Work PC',
            mode: SessionMode.direct,
            createdAt: now.subtract(const Duration(minutes: 10)),
            lastUsedAt: now.subtract(const Duration(minutes: 10)),
          ),
        );

        final recent = await sessions.recent(limit: 3);

        expect(recent.map((record) => record.id), [
          'duplicate-0',
          'other-host',
        ]);
        expect(await sessions.all(), hasLength(6));
      },
    );

    test('merges duplicate direct-session shortcuts for one target', () async {
      final hosts = HostsRepository(database);
      final sessions = SessionsRepository(database);
      final earlier = DateTime.fromMillisecondsSinceEpoch(1000);
      final latest = DateTime.fromMillisecondsSinceEpoch(2000);

      await hosts.upsert(makeHost());
      for (final (id, lastUsedAt) in [('older', earlier), ('newer', latest)]) {
        await sessions.upsert(
          SessionRecord(
            id: id,
            hostId: 'h1',
            displayName: 'Home PC',
            mode: SessionMode.direct,
            workingDirectory: '/home/dev',
            createdAt: earlier,
            lastUsedAt: lastUsedAt,
          ),
        );
      }

      final refreshedAt = DateTime.fromMillisecondsSinceEpoch(3000);
      await sessions.upsertDirectTarget(
        SessionRecord(
          id: 'unused-new-id',
          hostId: 'h1',
          displayName: 'Home PC',
          mode: SessionMode.direct,
          workingDirectory: '/home/dev',
          createdAt: refreshedAt,
          lastUsedAt: refreshedAt,
        ),
      );

      final records = await sessions.all();
      expect(records, hasLength(1));
      expect(records.single.id, 'newer');
      expect(records.single.lastUsedAt, refreshedAt);
    });

    test('recent keeps separate projects and persistent sessions', () async {
      final hosts = HostsRepository(database);
      final projects = ProjectsRepository(database);
      final sessions = SessionsRepository(database);
      final now = DateTime.now();

      await hosts.upsert(makeHost());
      for (final (id, name) in [('p1', 'API'), ('p2', 'Web')]) {
        await projects.upsert(
          Project(
            id: id,
            name: name,
            hostId: 'h1',
            remotePath: '/srv/${name.toLowerCase()}',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      for (final record in [
        SessionRecord(
          id: 'project-a',
          hostId: 'h1',
          projectId: 'p1',
          displayName: 'API',
          mode: SessionMode.direct,
          createdAt: now,
          lastUsedAt: now,
        ),
        SessionRecord(
          id: 'project-b',
          hostId: 'h1',
          projectId: 'p2',
          displayName: 'Web',
          mode: SessionMode.direct,
          createdAt: now.subtract(const Duration(minutes: 1)),
          lastUsedAt: now.subtract(const Duration(minutes: 1)),
        ),
        SessionRecord(
          id: 'tmux-a',
          hostId: 'h1',
          tmuxSessionName: 'rdc-api',
          displayName: 'API tmux',
          mode: SessionMode.persistent,
          createdAt: now.subtract(const Duration(minutes: 2)),
          lastUsedAt: now.subtract(const Duration(minutes: 2)),
        ),
        SessionRecord(
          id: 'tmux-b',
          hostId: 'h1',
          tmuxSessionName: 'rdc-web',
          displayName: 'Web tmux',
          mode: SessionMode.persistent,
          createdAt: now.subtract(const Duration(minutes: 3)),
          lastUsedAt: now.subtract(const Duration(minutes: 3)),
        ),
      ]) {
        await sessions.upsert(record);
      }

      expect(await sessions.recent(), hasLength(4));
    });

    test('prunes records whose tmux session no longer exists', () async {
      final hosts = HostsRepository(database);
      final sessions = SessionsRepository(database);
      final now = DateTime.now();

      await hosts.upsert(makeHost());
      for (final name in ['rdc-alive', 'rdc-gone']) {
        await sessions.upsert(
          SessionRecord(
            id: name,
            hostId: 'h1',
            tmuxSessionName: name,
            displayName: name,
            mode: SessionMode.persistent,
            createdAt: now,
            lastUsedAt: now,
          ),
        );
      }

      final removed = await sessions.pruneMissingTmux(
        hostId: 'h1',
        liveNames: {'rdc-alive'},
      );

      expect(removed, 1);
      expect((await sessions.all()).single.id, 'rdc-alive');
    });

    test('leaves direct sessions alone when pruning', () async {
      final hosts = HostsRepository(database);
      final sessions = SessionsRepository(database);
      final now = DateTime.now();

      await hosts.upsert(makeHost());
      await sessions.upsert(
        SessionRecord(
          id: 'direct',
          hostId: 'h1',
          displayName: 'shell',
          mode: SessionMode.direct,
          createdAt: now,
          lastUsedAt: now,
        ),
      );

      await sessions.pruneMissingTmux(hostId: 'h1', liveNames: const {});
      expect(await sessions.all(), hasLength(1));
    });

    test('collects tmux names in use on a host', () async {
      final hosts = HostsRepository(database);
      final sessions = SessionsRepository(database);
      final now = DateTime.now();

      await hosts.upsert(makeHost());
      await sessions.upsert(
        SessionRecord(
          id: 's1',
          hostId: 'h1',
          tmuxSessionName: 'rdc-api',
          displayName: 'api',
          mode: SessionMode.persistent,
          createdAt: now,
          lastUsedAt: now,
        ),
      );

      expect(await sessions.tmuxNamesForHost('h1'), {'rdc-api'});
    });
  });

  group('PreferencesRepository', () {
    test('returns defaults when nothing is saved', () async {
      final preferences = await PreferencesRepository(database).load();
      expect(preferences.themeMode, AppThemeMode.system);
      expect(preferences.scrollbackLines, 2000);
    });

    test('round-trips every setting', () async {
      final repository = PreferencesRepository(database);
      const saved = AppPreferences(
        themeMode: AppThemeMode.dark,
        terminalFontSize: 16,
        scrollbackLines: 5000,
        appLockEnabled: true,
        appLockTimeout: AppLockTimeout.fiveMinutes,
        tmuxSessionPrefix: 'custom',
        accessoryKeyRows: [
          ['esc', 'ctrl'],
          ['pipe'],
        ],
      );

      await repository.save(saved);
      final loaded = await repository.load();

      expect(loaded.themeMode, AppThemeMode.dark);
      expect(loaded.terminalFontSize, 16);
      expect(loaded.scrollbackLines, 5000);
      expect(loaded.appLockEnabled, isTrue);
      expect(loaded.appLockTimeout, AppLockTimeout.fiveMinutes);
      expect(loaded.tmuxSessionPrefix, 'custom');
      expect(loaded.accessoryKeyRows, [
        ['esc', 'ctrl'],
        ['pipe'],
      ]);
    });

    test('falls back per key when a stored value is corrupt', () async {
      await database.db.insert('app_preferences', {
        'key': 'scrollback_lines',
        'value': 'not a number',
      });
      await database.db.insert('app_preferences', {
        'key': 'accessory_key_rows',
        'value': '{not json',
      });

      final loaded = await PreferencesRepository(database).load();
      expect(loaded.scrollbackLines, 2000);
      expect(loaded.accessoryKeyRows, AppPreferences.defaultAccessoryRows);
    });
  });

  group('deleteAllRows', () {
    test('empties every table but keeps the schema', () async {
      final hosts = HostsRepository(database);
      await hosts.upsert(makeHost());
      await PreferencesRepository(database)
          .save(const AppPreferences(themeMode: AppThemeMode.dark));

      await database.deleteAllRows();

      expect(await hosts.all(), isEmpty);
      final result = await database.db.rawQuery('PRAGMA user_version');
      expect(result.first.values.first, schemaVersion);
    });
  });
}
