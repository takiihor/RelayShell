import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Reads and writes saved port-forward configurations (SPEC 16).
class ForwardsRepository extends Repository {
  ForwardsRepository(super.database);

  static const String table = 'port_forward_profiles';

  Future<List<PortForwardProfile>> all() async {
    final rows = await db.query(table, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(PortForwardProfile.fromRow).toList();
  }

  Stream<List<PortForwardProfile>> watchAll() => watch(all);

  Future<List<PortForwardProfile>> forHost(String hostId) async {
    final rows = await db.query(
      table,
      where: 'host_id = ?',
      whereArgs: [hostId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(PortForwardProfile.fromRow).toList();
  }

  Stream<List<PortForwardProfile>> watchForHost(String hostId) =>
      watch(() => forHost(hostId));

  Future<PortForwardProfile?> byId(String id) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PortForwardProfile.fromRow(rows.first);
  }

  Future<void> upsert(PortForwardProfile profile) async {
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

/// Reads and writes optional Wake-on-LAN settings (SPEC 17).
class WolRepository extends Repository {
  WolRepository(super.database);

  static const String table = 'wol_profiles';

  Future<WolProfile?> forHost(String hostId) async {
    final rows = await db.query(
      table,
      where: 'host_id = ?',
      whereArgs: [hostId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WolProfile.fromRow(rows.first);
  }

  Stream<WolProfile?> watchForHost(String hostId) =>
      watch(() => forHost(hostId));

  Future<List<WolProfile>> all() async {
    final rows = await db.query(table);
    return rows.map(WolProfile.fromRow).toList();
  }

  Future<void> upsert(WolProfile profile) async {
    await db.insert(
      table,
      profile.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Future<void> delete(String hostId) async {
    await db.delete(table, where: 'host_id = ?', whereArgs: [hostId]);
    notifyChanged();
  }
}
