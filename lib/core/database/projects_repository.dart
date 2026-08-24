import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Reads and writes [Project] records.
class ProjectsRepository extends Repository {
  ProjectsRepository(super.database);

  static const String table = 'projects';

  Future<List<Project>> all() async {
    final rows = await db.query(
      table,
      orderBy: 'favorite DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(Project.fromRow).toList();
  }

  Stream<List<Project>> watchAll() => watch(all);

  Future<List<Project>> forHost(String hostId) async {
    final rows = await db.query(
      table,
      where: 'host_id = ?',
      whereArgs: [hostId],
      orderBy: 'favorite DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(Project.fromRow).toList();
  }

  Stream<List<Project>> watchForHost(String hostId) =>
      watch(() => forHost(hostId));

  Future<List<Project>> recent({int limit = 6}) async {
    final rows = await db.query(
      table,
      where: 'last_opened_at IS NOT NULL OR favorite = 1',
      orderBy: 'favorite DESC, last_opened_at DESC',
      limit: limit,
    );
    return rows.map(Project.fromRow).toList();
  }

  Stream<List<Project>> watchRecent({int limit = 6}) =>
      watch(() => recent(limit: limit));

  Future<Project?> byId(String id) async {
    final rows =
        await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Project.fromRow(rows.first);
  }

  Stream<Project?> watchById(String id) => watch(() => byId(id));

  Future<void> upsert(Project project) async {
    await db.insert(
      table,
      project.toRow(),
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

  Future<void> markOpened(String id, {DateTime? at}) async {
    await db.update(
      table,
      {'last_opened_at': (at ?? DateTime.now()).millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChanged();
  }

  Future<List<Project>> search(String query) async {
    final term = '%${query.trim()}%';
    final rows = await db.query(
      table,
      where: 'name LIKE ? OR remote_path LIKE ? OR description LIKE ?',
      whereArgs: [term, term, term],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Project.fromRow).toList();
  }
}
