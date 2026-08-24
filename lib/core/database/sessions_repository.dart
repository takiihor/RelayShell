import 'package:sqflite/sqflite.dart';

import '../../shared/models/models.dart';
import 'repository.dart';

/// Reads and writes [SessionRecord] metadata (SPEC 11.5).
///
/// These rows describe how to *find* remote work again; they never claim the
/// work is still running. Liveness is answered by asking the remote machine.
class SessionsRepository extends Repository {
  SessionsRepository(super.database);

  static const String table = 'session_records';

  Future<List<SessionRecord>> all() async {
    final rows = await db.query(table, orderBy: 'last_used_at DESC');
    return rows.map(SessionRecord.fromRow).toList();
  }

  Stream<List<SessionRecord>> watchAll() => watch(all);

  /// Backs the Home "Continue" section (SPEC 7.1).
  Future<List<SessionRecord>> recent({int limit = 5}) async {
    if (limit <= 0) return const [];
    final rows = await db.query(table, orderBy: 'last_used_at DESC');
    final targets = <_RecentSessionTarget>{};
    final records = <SessionRecord>[];
    for (final row in rows) {
      final record = SessionRecord.fromRow(row);
      if (!targets.add(_RecentSessionTarget.from(record))) continue;
      records.add(record);
      if (records.length == limit) break;
    }
    return records;
  }

  Stream<List<SessionRecord>> watchRecent({int limit = 5}) =>
      watch(() => recent(limit: limit));

  Future<List<SessionRecord>> forHost(String hostId) async {
    final rows = await db.query(
      table,
      where: 'host_id = ?',
      whereArgs: [hostId],
      orderBy: 'last_used_at DESC',
    );
    return rows.map(SessionRecord.fromRow).toList();
  }

  Stream<List<SessionRecord>> watchForHost(String hostId) =>
      watch(() => forHost(hostId));

  Future<List<SessionRecord>> forProject(String projectId) async {
    final rows = await db.query(
      table,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'last_used_at DESC',
    );
    return rows.map(SessionRecord.fromRow).toList();
  }

  Future<SessionRecord?> byId(String id) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromRow(rows.first);
  }

  Future<SessionRecord?> byTmuxName({
    required String hostId,
    required String tmuxSessionName,
  }) async {
    final rows = await db.query(
      table,
      where: 'host_id = ? AND tmux_session_name = ?',
      whereArgs: [hostId, tmuxSessionName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SessionRecord.fromRow(rows.first);
  }

  /// Managed tmux names already in use on a host, for collision avoidance.
  Future<Set<String>> tmuxNamesForHost(String hostId) async {
    final rows = await db.query(
      table,
      columns: ['tmux_session_name'],
      where: 'host_id = ? AND tmux_session_name IS NOT NULL',
      whereArgs: [hostId],
    );
    return rows.map((row) => row['tmux_session_name'] as String).toSet();
  }

  Future<void> upsert(SessionRecord record) async {
    await db.insert(
      table,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Future<void> touch(String id, {DateTime? at}) async {
    await db.update(
      table,
      {'last_used_at': (at ?? DateTime.now()).millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChanged();
  }

  Future<void> rename(String id, String displayName) async {
    await db.update(
      table,
      {'display_name': displayName},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChanged();
  }

  Future<void> setTmuxName(String id, String tmuxSessionName) async {
    await db.update(
      table,
      {'tmux_session_name': tmuxSessionName},
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChanged();
  }

  Future<void> delete(String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  /// Drops records for tmux sessions that no longer exist remotely.
  ///
  /// Only managed persistent records are pruned: a direct session has nothing
  /// on the remote side to compare against.
  Future<int> pruneMissingTmux({
    required String hostId,
    required Set<String> liveNames,
  }) async {
    final rows = await db.query(
      table,
      where: 'host_id = ? AND tmux_session_name IS NOT NULL',
      whereArgs: [hostId],
    );
    var removed = 0;
    for (final row in rows) {
      final name = row['tmux_session_name'] as String;
      if (liveNames.contains(name)) continue;
      await db.delete(table, where: 'id = ?', whereArgs: [row['id']]);
      removed++;
    }
    if (removed > 0) notifyChanged();
    return removed;
  }

  Future<List<SessionRecord>> search(String query) async {
    final term = '%${query.trim()}%';
    final rows = await db.query(
      table,
      where: 'display_name LIKE ? OR tmux_session_name LIKE ?',
      whereArgs: [term, term],
      orderBy: 'last_used_at DESC',
    );
    return rows.map(SessionRecord.fromRow).toList();
  }
}

/// Identity of a resumable target shown on Home.
///
/// A tmux session is independently resumable. Direct sessions are equivalent
/// when resuming them would recreate the same work on the same computer.
class _RecentSessionTarget {
  const _RecentSessionTarget({
    required this.hostId,
    required this.mode,
    this.projectId,
    this.tmuxSessionName,
    this.displayName,
    this.workingDirectory,
    this.launchCommandId,
    this.launchCommand,
  });

  factory _RecentSessionTarget.from(SessionRecord record) {
    if (record.isPersistent) {
      return _RecentSessionTarget(
        hostId: record.hostId,
        mode: record.mode,
        tmuxSessionName: record.tmuxSessionName,
      );
    }
    return _RecentSessionTarget(
      hostId: record.hostId,
      mode: record.mode,
      projectId: record.projectId,
      displayName: record.displayName,
      workingDirectory: record.workingDirectory,
      launchCommandId: record.launchCommandId,
      launchCommand: record.launchCommand,
    );
  }

  final String hostId;
  final SessionMode mode;
  final String? projectId;
  final String? tmuxSessionName;
  final String? displayName;
  final String? workingDirectory;
  final String? launchCommandId;
  final String? launchCommand;

  @override
  bool operator ==(Object other) =>
      other is _RecentSessionTarget &&
      other.hostId == hostId &&
      other.mode == mode &&
      other.projectId == projectId &&
      other.tmuxSessionName == tmuxSessionName &&
      other.displayName == displayName &&
      other.workingDirectory == workingDirectory &&
      other.launchCommandId == launchCommandId &&
      other.launchCommand == launchCommand;

  @override
  int get hashCode => Object.hash(
    hostId,
    mode,
    projectId,
    tmuxSessionName,
    displayName,
    workingDirectory,
    launchCommandId,
    launchCommand,
  );
}
