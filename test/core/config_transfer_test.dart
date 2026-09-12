import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/database/app_database.dart';
import 'package:relayshell/core/database/commands_repository.dart';
import 'package:relayshell/core/database/credentials_repository.dart';
import 'package:relayshell/core/database/forwards_repository.dart';
import 'package:relayshell/core/database/hosts_repository.dart';
import 'package:relayshell/core/database/preferences_repository.dart';
import 'package:relayshell/core/database/projects_repository.dart';
import 'package:relayshell/core/database/sessions_repository.dart';
import 'package:relayshell/core/storage/config_transfer.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late ConfigTransfer transfer;
  late HostsRepository hosts;
  late ProjectsRepository projects;
  late CommandsRepository commands;

  setUp(() async {
    database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    hosts = HostsRepository(database);
    projects = ProjectsRepository(database);
    commands = CommandsRepository(database);
    transfer = ConfigTransfer(
      hosts: hosts,
      projects: projects,
      commands: commands,
      forwards: ForwardsRepository(database),
      wol: WolRepository(database),
      sessions: SessionsRepository(database),
      preferences: PreferencesRepository(database),
    );
  });

  tearDown(() async => database.close());

  Future<void> seed() async {
    final now = DateTime.now();
    // The host references a credential, so the credential must exist — the
    // foreign key is what guarantees a host never points at a missing secret.
    await CredentialsRepository(database).upsert(
      Credential(
        id: 'secret-credential-id',
        name: 'Home key',
        type: CredentialType.privateKey,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await hosts.upsert(
      Host(
        id: 'h1',
        name: 'Home PC',
        hostname: '10.0.0.5',
        port: 2222,
        username: 'dev',
        authMethod: AuthMethod.privateKey,
        credentialId: 'secret-credential-id',
        createdAt: now,
        updatedAt: now,
      ),
    );
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
    await commands.upsert(
      SavedCommand(
        id: 'c1',
        name: 'Status',
        command: 'git status',
        scope: CommandScope.project,
        projectId: 'p1',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('export', () {
    test('includes configuration', () async {
      await seed();
      final document = await transfer.export();

      expect(document['format'], ConfigTransfer.formatName);
      expect(document['hosts'], hasLength(1));
      expect(document['projects'], hasLength(1));
      expect(document['commands'], hasLength(1));
    });

    test('never writes credential references or secret material', () async {
      // SPEC 22 / 44.4: an export must not leak credentials by default.
      await seed();
      final json = await transfer.exportToJson();

      expect(json, isNot(contains('secret-credential-id')));
      expect(json, isNot(contains('credential_id')));
      expect(json, isNot(contains('PRIVATE KEY')));
      expect(json, isNot(contains('password')));
      expect(jsonDecode(json)['contains_secrets'], isFalse);
    });

    test('suggests a dated file name', () {
      final name = ConfigTransfer.suggestedFileName(now: DateTime(2026, 3, 7));
      expect(name, 'relayshell-backup-20260307.json');
    });
  });

  group('import', () {
    test(
      'restores stable Herdr terminal identity with the remapped host',
      () async {
        await seed();
        await SessionsRepository(database).upsert(
          SessionRecord(
            id: 'pane',
            hostId: 'h1',
            displayName: 'Agent',
            mode: SessionMode.persistent,
            tmuxSessionName: 'daily',
            herdrTerminalId: 'term_stable',
            createdAt: DateTime.now(),
            lastUsedAt: DateTime.now(),
          ),
        );
        final json = await transfer.exportToJson();
        await database.deleteAllRows();
        await transfer.import(json);
        final restored = (await SessionsRepository(database).all()).single;
        expect(restored.herdrTerminalId, 'term_stable');
        expect(restored.tmuxSessionName, 'daily');
        expect(restored.hostId, (await hosts.all()).single.id);
      },
    );

    test('restores an exported document', () async {
      await seed();
      final json = await transfer.exportToJson();
      await database.deleteAllRows();

      final summary = await transfer.import(json);

      expect(summary.hosts, 1);
      expect(summary.projects, 1);
      expect(summary.commands, 1);
      expect(summary.warnings, isEmpty);

      final host = (await hosts.all()).single;
      expect(host.name, 'Home PC');
      expect(host.port, 2222);
      // Deliberately not restored: the user re-picks a credential.
      expect(host.credentialId, isNull);
    });

    test('remaps ids so an import merges rather than overwrites', () async {
      await seed();
      final json = await transfer.exportToJson();

      await transfer.import(json, includePreferences: false);

      final all = await hosts.all();
      expect(all, hasLength(2));
      expect(all.map((h) => h.id).toSet(), hasLength(2));

      // The imported project points at the imported host, not the original.
      final importedProjects = await projects.all();
      expect(importedProjects, hasLength(2));
      final hostIds = importedProjects.map((p) => p.hostId).toSet();
      expect(hostIds, hasLength(2));
    });

    test('rejects a file that is not a backup', () async {
      expect(
        () => transfer.import('{"format":"something-else"}'),
        throwsA(isA<ConfigImportException>()),
      );
    });

    test('rejects malformed JSON', () async {
      expect(
        () => transfer.import('{not json'),
        throwsA(isA<ConfigImportException>()),
      );
    });

    test('rejects a newer format version rather than guessing', () async {
      expect(
        () => transfer.import(
          jsonEncode({'format': ConfigTransfer.formatName, 'version': 99}),
        ),
        throwsA(isA<ConfigImportException>()),
      );
    });

    test('promotes an orphaned scoped command to global and warns', () async {
      // Keeping the command is better than dropping it; making it global is
      // the only scope that stays reachable.
      final json = jsonEncode({
        'format': ConfigTransfer.formatName,
        'version': 1,
        'commands': [
          {
            'name': 'Orphan',
            'command': 'echo hi',
            'scope': 'host',
            'host_id': 'missing-host',
          },
        ],
      });

      final summary = await transfer.import(json);

      expect(summary.commands, 1);
      expect(summary.warnings, isNotEmpty);
      expect((await commands.all()).single.scope, CommandScope.global);
    });

    test('skips a project whose host is absent, and says so', () async {
      final json = jsonEncode({
        'format': ConfigTransfer.formatName,
        'version': 1,
        'projects': [
          {'name': 'Orphan', 'host_id': 'missing', 'remote_path': '/x'},
        ],
      });

      final summary = await transfer.import(json);

      expect(summary.projects, 0);
      expect(summary.warnings, isNotEmpty);
    });

    test('skips a host with no hostname', () async {
      final json = jsonEncode({
        'format': ConfigTransfer.formatName,
        'version': 1,
        'hosts': [
          {'name': 'Broken', 'username': 'dev'},
        ],
      });

      final summary = await transfer.import(json);
      expect(summary.hosts, 0);
      expect(summary.warnings, isNotEmpty);
    });

    test(
      'rolls back the entire import when a later record is invalid',
      () async {
        final json = jsonEncode({
          'format': ConfigTransfer.formatName,
          'version': 1,
          'hosts': [
            {
              'id': 'host-1',
              'name': 'Valid first host',
              'hostname': 'example.com',
              'username': 'dev',
            },
          ],
          'wol_profiles': [
            {'host_id': 'host-1', 'mac_address': 123},
          ],
        });

        await expectLater(
          transfer.import(json),
          throwsA(isA<ConfigImportException>()),
        );
        expect(await hosts.all(), isEmpty);
      },
    );

    test('can skip preferences on request', () async {
      final repository = PreferencesRepository(database);
      await repository.save(const AppPreferences(themeMode: AppThemeMode.dark));

      final json = jsonEncode({
        'format': ConfigTransfer.formatName,
        'version': 1,
        'preferences': {'theme_mode': 'light'},
      });

      await transfer.import(json, includePreferences: false);
      expect((await repository.load()).themeMode, AppThemeMode.dark);

      await transfer.import(json);
      expect((await repository.load()).themeMode, AppThemeMode.light);
    });

    test('bounds imported preferences to the supported UI ranges', () async {
      final json = jsonEncode({
        'format': ConfigTransfer.formatName,
        'version': 1,
        'preferences': {
          'scrollback_lines': '999999999',
          'terminal_font_size': '-10',
          'connect_timeout_seconds': '0',
        },
      });

      await transfer.import(json);
      final restored = await PreferencesRepository(database).load();
      expect(restored.scrollbackLines, 20000);
      expect(restored.terminalFontSize, 8);
      expect(restored.connectTimeoutSeconds, 5);
    });

    test('tolerates a document with no collections at all', () async {
      final summary = await transfer.import(
        jsonEncode({'format': ConfigTransfer.formatName, 'version': 1}),
      );
      expect(summary.total, 0);
    });
  });
}
