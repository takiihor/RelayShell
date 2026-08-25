import 'package:flutter/foundation.dart';

import 'enums.dart';

const Object _unset = Object();

/// A remote working directory on a [Host], with its own actions and sessions
/// (SPEC 12.1).
@immutable
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.hostId,
    required this.remotePath,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.defaultSessionMode = SessionMode.direct,
    this.defaultTmuxName,
    this.favorite = false,
    this.lastOpenedAt,
  });

  final String id;
  final String name;
  final String hostId;
  final String remotePath;
  final String? description;
  final SessionMode defaultSessionMode;
  final String? defaultTmuxName;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;

  Project copyWith({
    String? name,
    String? hostId,
    String? remotePath,
    Object? description = _unset,
    SessionMode? defaultSessionMode,
    Object? defaultTmuxName = _unset,
    bool? favorite,
    DateTime? updatedAt,
    Object? lastOpenedAt = _unset,
  }) => Project(
    id: id,
    name: name ?? this.name,
    hostId: hostId ?? this.hostId,
    remotePath: remotePath ?? this.remotePath,
    description: description == _unset
        ? this.description
        : description as String?,
    defaultSessionMode: defaultSessionMode ?? this.defaultSessionMode,
    defaultTmuxName: defaultTmuxName == _unset
        ? this.defaultTmuxName
        : defaultTmuxName as String?,
    favorite: favorite ?? this.favorite,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    lastOpenedAt: lastOpenedAt == _unset
        ? this.lastOpenedAt
        : lastOpenedAt as DateTime?,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'host_id': hostId,
    'remote_path': remotePath,
    'description': description,
    'default_session_mode': defaultSessionMode.storageValue,
    'default_tmux_name': defaultTmuxName,
    'favorite': favorite ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'last_opened_at': lastOpenedAt?.millisecondsSinceEpoch,
  };

  factory Project.fromRow(Map<String, Object?> row) => Project(
    id: row['id']! as String,
    name: row['name']! as String,
    hostId: row['host_id']! as String,
    remotePath: row['remote_path']! as String,
    description: row['description'] as String?,
    defaultSessionMode: SessionMode.fromStorage(
      row['default_session_mode'] as String?,
    ),
    defaultTmuxName: row['default_tmux_name'] as String?,
    favorite: (row['favorite'] as int? ?? 0) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
    lastOpenedAt: row['last_opened_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['last_opened_at']! as int),
  );

  Map<String, Object?> toExportJson() => {
    'id': id,
    'name': name,
    'host_id': hostId,
    'remote_path': remotePath,
    'description': description,
    'default_session_mode': defaultSessionMode.storageValue,
    'default_tmux_name': defaultTmuxName,
    'favorite': favorite,
  };

  factory Project.fromExportJson(
    Map<String, Object?> json, {
    required String id,
    required String hostId,
  }) {
    final now = DateTime.now();
    return Project(
      id: id,
      name: (json['name'] as String?) ?? 'Imported project',
      hostId: hostId,
      remotePath: (json['remote_path'] as String?) ?? '.',
      description: json['description'] as String?,
      defaultSessionMode: SessionMode.fromStorage(
        json['default_session_mode'] as String?,
      ),
      defaultTmuxName: json['default_tmux_name'] as String?,
      favorite: json['favorite'] == true,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  bool operator ==(Object other) => other is Project && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
