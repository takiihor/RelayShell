import 'package:flutter/foundation.dart';

import 'enums.dart';

const Object _unset = Object();

/// A reusable command the user can run with a tap (SPEC 13.1).
///
/// The [command] text is treated as intentional shell input and is sent as
/// configured (SPEC 29); the app never rewrites it.
@immutable
class SavedCommand {
  const SavedCommand({
    required this.id,
    required this.name,
    required this.command,
    required this.scope,
    required this.createdAt,
    required this.updatedAt,
    this.hostId,
    this.projectId,
    this.workingDirectory,
    this.executionMode = ExecutionMode.oneShot,
    this.confirmationMode = ConfirmationMode.dangerous,
    this.sessionMode = SessionMode.direct,
    this.favorite = false,
  });

  final String id;
  final String name;
  final String command;
  final CommandScope scope;
  final String? hostId;
  final String? projectId;
  final String? workingDirectory;
  final ExecutionMode executionMode;
  final ConfirmationMode confirmationMode;

  /// Only meaningful when [executionMode] is [ExecutionMode.interactive].
  final SessionMode sessionMode;

  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isInteractive => executionMode == ExecutionMode.interactive;

  SavedCommand copyWith({
    String? name,
    String? command,
    CommandScope? scope,
    Object? hostId = _unset,
    Object? projectId = _unset,
    Object? workingDirectory = _unset,
    ExecutionMode? executionMode,
    ConfirmationMode? confirmationMode,
    SessionMode? sessionMode,
    bool? favorite,
    DateTime? updatedAt,
  }) =>
      SavedCommand(
        id: id,
        name: name ?? this.name,
        command: command ?? this.command,
        scope: scope ?? this.scope,
        hostId: hostId == _unset ? this.hostId : hostId as String?,
        projectId: projectId == _unset ? this.projectId : projectId as String?,
        workingDirectory: workingDirectory == _unset
            ? this.workingDirectory
            : workingDirectory as String?,
        executionMode: executionMode ?? this.executionMode,
        confirmationMode: confirmationMode ?? this.confirmationMode,
        sessionMode: sessionMode ?? this.sessionMode,
        favorite: favorite ?? this.favorite,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'command': command,
        'scope': scope.storageValue,
        'host_id': hostId,
        'project_id': projectId,
        'working_directory': workingDirectory,
        'execution_mode': executionMode.storageValue,
        'confirmation_mode': confirmationMode.storageValue,
        'session_mode': sessionMode.storageValue,
        'favorite': favorite ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory SavedCommand.fromRow(Map<String, Object?> row) => SavedCommand(
        id: row['id']! as String,
        name: row['name']! as String,
        command: row['command']! as String,
        scope: CommandScope.fromStorage(row['scope'] as String?),
        hostId: row['host_id'] as String?,
        projectId: row['project_id'] as String?,
        workingDirectory: row['working_directory'] as String?,
        executionMode:
            ExecutionMode.fromStorage(row['execution_mode'] as String?),
        confirmationMode:
            ConfirmationMode.fromStorage(row['confirmation_mode'] as String?),
        sessionMode: SessionMode.fromStorage(row['session_mode'] as String?),
        favorite: (row['favorite'] as int? ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      );

  Map<String, Object?> toExportJson() => {
        'id': id,
        'name': name,
        'command': command,
        'scope': scope.storageValue,
        'host_id': hostId,
        'project_id': projectId,
        'working_directory': workingDirectory,
        'execution_mode': executionMode.storageValue,
        'confirmation_mode': confirmationMode.storageValue,
        'session_mode': sessionMode.storageValue,
        'favorite': favorite,
      };

  factory SavedCommand.fromExportJson(
    Map<String, Object?> json, {
    required String id,
    String? hostId,
    String? projectId,
  }) {
    final now = DateTime.now();
    return SavedCommand(
      id: id,
      name: (json['name'] as String?) ?? 'Imported command',
      command: (json['command'] as String?) ?? '',
      scope: CommandScope.fromStorage(json['scope'] as String?),
      hostId: hostId,
      projectId: projectId,
      workingDirectory: json['working_directory'] as String?,
      executionMode: ExecutionMode.fromStorage(json['execution_mode'] as String?),
      confirmationMode:
          ConfirmationMode.fromStorage(json['confirmation_mode'] as String?),
      sessionMode: SessionMode.fromStorage(json['session_mode'] as String?),
      favorite: json['favorite'] == true,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  bool operator ==(Object other) => other is SavedCommand && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
