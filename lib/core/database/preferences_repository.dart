import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Persists [AppPreferences] as a key/value table (SPEC 21).
///
/// Writing whole-object snapshots keeps the API simple, and reading falls back
/// to defaults per key, so a partially written or older row can never leave the
/// app without usable settings.
class PreferencesRepository extends Repository {
  PreferencesRepository(super.database);

  static const String table = 'app_preferences';

  Future<AppPreferences> load() async {
    final rows = await db.query(table);
    final map = <String, String>{
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    return AppPreferences.fromMap(map);
  }

  Stream<AppPreferences> watchPreferences() => watch(load);

  Future<void> save(AppPreferences preferences) async {
    final entries = preferences.toMap();
    await db.transaction((txn) async {
      for (final entry in entries.entries) {
        await txn.insert(table, {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    notifyChanged();
  }

  Future<void> reset() async {
    await db.delete(table);
    notifyChanged();
  }
}

/// Persists named terminal appearance presets (SPEC 23 `terminal_profiles`).
class TerminalProfilesRepository extends Repository {
  TerminalProfilesRepository(super.database);

  static const String table = 'terminal_profiles';

  Future<List<TerminalProfile>> all() async {
    final rows = await db.query(table, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(TerminalProfile.fromRow).toList();
  }

  Stream<List<TerminalProfile>> watchAll() => watch(all);

  Future<void> upsert(TerminalProfile profile) async {
    await db.insert(
      table,
      profile.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Future<void> delete(String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }
}

/// Tracks what the user touched most recently, for the Home screen (SPEC 41).
class RecentsRepository extends Repository {
  RecentsRepository(super.database);

  static const String table = 'recent_items';

  Future<List<RecentItem>> recent({int limit = 12}) async {
    final rows = await db.query(
      table,
      orderBy: 'last_used_at DESC',
      limit: limit,
    );
    return rows.map(RecentItem.fromRow).toList();
  }

  Stream<List<RecentItem>> watchRecent({int limit = 12}) =>
      watch(() => recent(limit: limit));

  Future<void> record(
    RecentItemKind kind,
    String targetId, {
    DateTime? at,
  }) async {
    await db.insert(
      table,
      RecentItem(
        kind: kind,
        targetId: targetId,
        lastUsedAt: at ?? DateTime.now(),
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Future<void> forget(RecentItemKind kind, String targetId) async {
    await db.delete(
      table,
      where: 'kind = ? AND target_id = ?',
      whereArgs: [kind.storageValue, targetId],
    );
    notifyChanged();
  }

  Future<void> clear() async {
    await db.delete(table);
    notifyChanged();
  }
}
