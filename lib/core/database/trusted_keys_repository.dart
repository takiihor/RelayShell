import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Stores the host fingerprints the user has explicitly trusted (SPEC 9.2).
///
/// Lookups are by endpoint and key type, never by host id, so that renaming a
/// host or pointing it at a different address cannot inherit an old trust
/// decision (SPEC 8.4).
class TrustedKeysRepository extends Repository {
  TrustedKeysRepository(super.database);

  static const String table = 'trusted_host_keys';

  Future<List<TrustedHostKey>> all() async {
    final rows = await db.query(table, orderBy: 'hostname ASC, port ASC');
    return rows.map(TrustedHostKey.fromRow).toList();
  }

  Stream<List<TrustedHostKey>> watchAll() => watch(all);

  /// The trusted key for an endpoint and key type, or null if never trusted.
  Future<TrustedHostKey?> find({
    required String hostname,
    required int port,
    required String keyType,
  }) async {
    final rows = await db.query(
      table,
      where: 'hostname = ? AND port = ? AND key_type = ?',
      whereArgs: [hostname, port, keyType],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TrustedHostKey.fromRow(rows.first);
  }

  /// Every key trusted for an endpoint, across key types.
  Future<List<TrustedHostKey>> forEndpoint({
    required String hostname,
    required int port,
  }) async {
    final rows = await db.query(
      table,
      where: 'hostname = ? AND port = ?',
      whereArgs: [hostname, port],
    );
    return rows.map(TrustedHostKey.fromRow).toList();
  }

  Future<void> trust(TrustedHostKey key) async {
    await db.insert(
      table,
      key.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  /// Associates pre-save trust decisions with the host that was subsequently
  /// saved. The endpoint remains the identity authority; this is only friendly
  /// metadata for the settings list.
  Future<void> attachUnownedEndpoint({
    required String hostId,
    required String hostname,
    required int port,
  }) async {
    await db.update(
      table,
      {'host_id': hostId},
      where: 'host_id IS NULL AND hostname = ? AND port = ?',
      whereArgs: [hostname, port],
    );
    notifyChanged();
  }

  Future<void> revoke(String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  /// Forgets every key for an endpoint, forcing full re-verification.
  Future<void> revokeEndpoint({
    required String hostname,
    required int port,
  }) async {
    await db.delete(
      table,
      where: 'hostname = ? AND port = ?',
      whereArgs: [hostname, port],
    );
    notifyChanged();
  }
}
