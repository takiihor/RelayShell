import 'package:flutter/foundation.dart';

import 'enums.dart';

const Object _unset = Object();

/// Local metadata required to reconnect to remote work (SPEC 11.5).
///
/// The actual process state lives on the remote computer. This record only
/// stores enough to find it again.
@immutable
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.hostId,
    required this.displayName,
    required this.mode,
    required this.createdAt,
    required this.lastUsedAt,
    this.projectId,
    this.tmuxSessionName,
    this.workingDirectory,
    this.launchCommandId,
    this.launchCommand,
  });

  final String id;
  final String hostId;
  final String? projectId;

  /// Null for direct sessions; set for managed tmux sessions.
  final String? tmuxSessionName;

  final String displayName;
  final SessionMode mode;
  final String? workingDirectory;

  /// Optional saved command that launched this session.
  final String? launchCommandId;

  /// Literal command run at launch, kept so a resumed direct session can be
  /// recreated. Stored locally only and never logged (SPEC 35).
  final String? launchCommand;

  final DateTime createdAt;
  final DateTime lastUsedAt;

  bool get isPersistent =>
      mode == SessionMode.persistent && tmuxSessionName != null;

  SessionRecord copyWith({
    String? displayName,
    SessionMode? mode,
    Object? projectId = _unset,
    Object? tmuxSessionName = _unset,
    Object? workingDirectory = _unset,
    Object? launchCommandId = _unset,
    Object? launchCommand = _unset,
    DateTime? lastUsedAt,
  }) => SessionRecord(
    id: id,
    hostId: hostId,
    projectId: projectId == _unset ? this.projectId : projectId as String?,
    tmuxSessionName: tmuxSessionName == _unset
        ? this.tmuxSessionName
        : tmuxSessionName as String?,
    displayName: displayName ?? this.displayName,
    mode: mode ?? this.mode,
    workingDirectory: workingDirectory == _unset
        ? this.workingDirectory
        : workingDirectory as String?,
    launchCommandId: launchCommandId == _unset
        ? this.launchCommandId
        : launchCommandId as String?,
    launchCommand: launchCommand == _unset
        ? this.launchCommand
        : launchCommand as String?,
    createdAt: createdAt,
    lastUsedAt: lastUsedAt ?? DateTime.now(),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'host_id': hostId,
    'project_id': projectId,
    'tmux_session_name': tmuxSessionName,
    'display_name': displayName,
    'mode': mode.storageValue,
    'working_directory': workingDirectory,
    'launch_command_id': launchCommandId,
    'launch_command': launchCommand,
    'created_at': createdAt.millisecondsSinceEpoch,
    'last_used_at': lastUsedAt.millisecondsSinceEpoch,
  };

  factory SessionRecord.fromRow(Map<String, Object?> row) => SessionRecord(
    id: row['id']! as String,
    hostId: row['host_id']! as String,
    projectId: row['project_id'] as String?,
    tmuxSessionName: row['tmux_session_name'] as String?,
    displayName: row['display_name']! as String,
    mode: SessionMode.fromStorage(row['mode'] as String?),
    workingDirectory: row['working_directory'] as String?,
    launchCommandId: row['launch_command_id'] as String?,
    launchCommand: row['launch_command'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    lastUsedAt: DateTime.fromMillisecondsSinceEpoch(
      row['last_used_at']! as int,
    ),
  );

  Map<String, Object?> toExportJson() => {
    'id': id,
    'host_id': hostId,
    'project_id': projectId,
    'tmux_session_name': tmuxSessionName,
    'display_name': displayName,
    'mode': mode.storageValue,
    'working_directory': workingDirectory,
  };

  @override
  bool operator ==(Object other) => other is SessionRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
