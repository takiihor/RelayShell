import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Opens and migrates the local SQLite database (SPEC 23).
///
/// The database holds configuration only. Secret material never reaches it;
/// see `core/storage/secret_store.dart` for where secrets actually live.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const String defaultFileName = 'relayshell.db';

  /// Opens the database at [path], creating and migrating it as needed.
  ///
  /// Pass [factory] to open with a non-default sqflite implementation, which is
  /// how tests run the real schema against an in-memory database.
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        path ?? p.join(await dbFactory.getDatabasesPath(), defaultFileName);

    final database = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _configure,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    return AppDatabase._(database);
  }

  /// Foreign keys are off by default in SQLite; the schema's ON DELETE rules
  /// are load-bearing (deleting a host must not strand its projects).
  static Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    for (final statement in createSchemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
    await _applyMigrations(db, from: 1, to: version);
  }

  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) =>
      _applyMigrations(db, from: oldVersion, to: newVersion);

  static Future<void> _applyMigrations(
    Database db, {
    required int from,
    required int to,
  }) async {
    for (final migration in schemaMigrations) {
      if (migration.version <= from || migration.version > to) continue;
      final batch = db.batch();
      for (final statement in migration.statements) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      db.transaction(action);

  Future<void> close() => db.close();

  /// Deletes every row while leaving the schema in place (SPEC 21 "Reset app").
  ///
  /// Secrets are not touched here; the caller is responsible for clearing
  /// secure storage too, so that a reset cannot leave orphaned key material.
  Future<void> deleteAllRows() async {
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      for (final table in const [
        'recent_items',
        'app_preferences',
        'wol_profiles',
        'port_forward_profiles',
        'session_records',
        'terminal_profiles',
        'commands',
        'projects',
        'trusted_host_keys',
        'hosts',
        'credentials',
      ]) {
        await txn.delete(table);
      }
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }
}
