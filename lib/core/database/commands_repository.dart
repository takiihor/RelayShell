import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Reads and writes [SavedCommand] records (SPEC 13).
class CommandsRepository extends Repository {
  CommandsRepository(super.database);

  static const String table = 'commands';

  Future<List<SavedCommand>> all() async {
    final rows = await db.query(
      table,
      orderBy: 'favorite DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(SavedCommand.fromRow).toList();
  }

  Stream<List<SavedCommand>> watchAll() => watch(all);

  /// Commands offered in a given context, widest scope last.
  ///
  /// A project screen shows the project's own commands, its host's commands and
  /// the global ones; a host screen shows host and global. Scoping the query
  /// here keeps that rule in one place instead of in every screen.
  Future<List<SavedCommand>> visibleIn({
    String? hostId,
    String? projectId,
  }) async {
    final clauses = <String>['scope = ?'];
    final args = <Object?>[CommandScope.global.storageValue];

    if (hostId != null) {
      clauses.add('(scope = ? AND host_id = ?)');
      args
        ..add(CommandScope.host.storageValue)
        ..add(hostId);
    }
    if (projectId != null) {
      clauses.add('(scope = ? AND project_id = ?)');
      args
        ..add(CommandScope.project.storageValue)
        ..add(projectId);
    }

    final rows = await db.query(
      table,
      where: clauses.join(' OR '),
      whereArgs: args,
      orderBy: 'favorite DESC, scope DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(SavedCommand.fromRow).toList();
  }

  Stream<List<SavedCommand>> watchVisibleIn({
    String? hostId,
    String? projectId,
  }) =>
      watch(() => visibleIn(hostId: hostId, projectId: projectId));

  Future<List<SavedCommand>> forProject(String projectId) async {
    final rows = await db.query(
      table,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'favorite DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(SavedCommand.fromRow).toList();
  }

  Stream<List<SavedCommand>> watchForProject(String projectId) =>
      watch(() => forProject(projectId));

  Future<List<SavedCommand>> forHost(String hostId) async {
    final rows = await db.query(
      table,
      where: 'host_id = ?',
      whereArgs: [hostId],
      orderBy: 'favorite DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(SavedCommand.fromRow).toList();
  }

  /// Favourites shown as Home quick actions (SPEC 7.1).
  Future<List<SavedCommand>> favorites({int limit = 8}) async {
    final rows = await db.query(
      table,
      where: 'favorite = 1',
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
    return rows.map(SavedCommand.fromRow).toList();
  }

  Stream<List<SavedCommand>> watchFavorites({int limit = 8}) =>
      watch(() => favorites(limit: limit));

  Future<SavedCommand?> byId(String id) async {
    final rows =
        await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return SavedCommand.fromRow(rows.first);
  }

  Future<void> upsert(SavedCommand command) async {
    await db.insert(
      table,
      command.toRow(),
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

  Future<List<SavedCommand>> search(String query) async {
    final term = '%${query.trim()}%';
    final rows = await db.query(
      table,
      where: 'name LIKE ? OR command LIKE ?',
      whereArgs: [term, term],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(SavedCommand.fromRow).toList();
  }
}
