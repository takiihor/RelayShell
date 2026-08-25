import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Reads and writes [Host] records.
class HostsRepository extends Repository {
  HostsRepository(super.database);

  static const String table = 'hosts';

  Future<List<Host>> all() async {
    final rows = await db.query(
      table,
      orderBy: 'favorite DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(Host.fromRow).toList();
  }

  Stream<List<Host>> watchAll() => watch(all);

  Future<List<Host>> recent({int limit = 6}) async {
    final rows = await db.query(
      table,
      where: 'last_connected_at IS NOT NULL OR favorite = 1',
      orderBy: 'favorite DESC, last_connected_at DESC',
      limit: limit,
    );
    return rows.map(Host.fromRow).toList();
  }

  Stream<List<Host>> watchRecent({int limit = 6}) =>
      watch(() => recent(limit: limit));

  Future<Host?> byId(String id) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Host.fromRow(rows.first);
  }

  Stream<Host?> watchById(String id) => watch(() => byId(id));

  /// Hosts using [credentialId], so the keys screen can warn before deletion.
  Future<List<Host>> usingCredential(String credentialId) async {
    final rows = await db.query(
      table,
      where: 'credential_id = ?',
      whereArgs: [credentialId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Host.fromRow).toList();
  }

  Future<void> upsert(Host host) async {
    await db.insert(
      table,
      host.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Future<void> delete(String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  Future<void> setFavorite(String id, bool favorite) async {
    await db.update(
      table,
      {
        'favorite': favorite ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChanged();
  }

  Future<void> markConnected(String id, {DateTime? at}) async {
    await db.update(
      table,
      {'last_connected_at': (at ?? DateTime.now()).millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChanged();
  }

  /// Detaches a credential from every host that referenced it.
  Future<void> clearCredential(String credentialId) async {
    await db.update(
      table,
      {'credential_id': null},
      where: 'credential_id = ?',
      whereArgs: [credentialId],
    );
    notifyChanged();
  }

  Future<List<Host>> search(String query) async {
    final term = '%${query.trim()}%';
    final rows = await db.query(
      table,
      where: 'name LIKE ? OR hostname LIKE ? OR username LIKE ?',
      whereArgs: [term, term, term],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Host.fromRow).toList();
  }
}
