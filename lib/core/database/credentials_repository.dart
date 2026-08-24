import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Reads and writes credential *metadata* only.
///
/// This repository can never see a private key, password or passphrase: those
/// are held by `SecretStore` in platform secure storage and referenced by id
/// (SPEC 23.2). Keeping the split at the repository boundary is what makes the
/// "no secrets in SQLite" acceptance requirement checkable (SPEC 44.1).
class CredentialsRepository extends Repository {
  CredentialsRepository(super.database);

  static const String table = 'credentials';

  Future<List<Credential>> all() async {
    final rows = await db.query(table, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Credential.fromRow).toList();
  }

  Stream<List<Credential>> watchAll() => watch(all);

  Future<List<Credential>> ofType(CredentialType type) async {
    final rows = await db.query(
      table,
      where: 'type = ?',
      whereArgs: [type.storageValue],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Credential.fromRow).toList();
  }

  Future<Credential?> byId(String id) async {
    final rows =
        await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Credential.fromRow(rows.first);
  }

  Stream<Credential?> watchById(String id) => watch(() => byId(id));

  Future<void> upsert(Credential credential) async {
    await db.insert(
      table,
      credential.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Future<void> delete(String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }
}
