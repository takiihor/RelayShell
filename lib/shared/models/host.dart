import 'package:flutter/foundation.dart';

import 'enums.dart';

const Object _unset = Object();

/// One SSH destination (SPEC 8.1).
///
/// A [Host] never holds secret material. [credentialId] points at a
/// `Credential` record whose secret lives in platform secure storage.
@immutable
class Host {
  const Host({
    required this.id,
    required this.name,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authMethod,
    required this.createdAt,
    required this.updatedAt,
    this.credentialId,
    this.startupDirectory,
    this.environmentNotes,
    this.colorValue,
    this.platform = RemotePlatform.posix,
    this.favorite = false,
    this.lastConnectedAt,
  });

  static const int defaultPort = 22;

  final String id;
  final String name;
  final String hostname;
  final int port;
  final String username;
  final AuthMethod authMethod;
  final String? credentialId;
  final String? startupDirectory;
  final String? environmentNotes;
  final int? colorValue;
  final RemotePlatform platform;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConnectedAt;

  /// Stable identity of the SSH endpoint. Used as the trusted-host-key lookup
  /// key so that editing hostname or port forces re-verification (SPEC 8.4).
  String get endpointKey => '$hostname:$port';

  String get displaySubtitle =>
      port == defaultPort ? '$username@$hostname' : '$username@$hostname:$port';

  Host copyWith({
    String? name,
    String? hostname,
    int? port,
    String? username,
    AuthMethod? authMethod,
    Object? credentialId = _unset,
    Object? startupDirectory = _unset,
    Object? environmentNotes = _unset,
    Object? colorValue = _unset,
    RemotePlatform? platform,
    bool? favorite,
    DateTime? updatedAt,
    Object? lastConnectedAt = _unset,
  }) {
    return Host(
      id: id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      credentialId:
          credentialId == _unset ? this.credentialId : credentialId as String?,
      startupDirectory: startupDirectory == _unset
          ? this.startupDirectory
          : startupDirectory as String?,
      environmentNotes: environmentNotes == _unset
          ? this.environmentNotes
          : environmentNotes as String?,
      colorValue: colorValue == _unset ? this.colorValue : colorValue as int?,
      platform: platform ?? this.platform,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastConnectedAt: lastConnectedAt == _unset
          ? this.lastConnectedAt
          : lastConnectedAt as DateTime?,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'hostname': hostname,
        'port': port,
        'username': username,
        'auth_method': authMethod.storageValue,
        'credential_id': credentialId,
        'startup_directory': startupDirectory,
        'environment_notes': environmentNotes,
        'color_value': colorValue,
        'platform': platform.storageValue,
        'favorite': favorite ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'last_connected_at': lastConnectedAt?.millisecondsSinceEpoch,
      };

  factory Host.fromRow(Map<String, Object?> row) => Host(
        id: row['id']! as String,
        name: row['name']! as String,
        hostname: row['hostname']! as String,
        port: row['port']! as int,
        username: row['username']! as String,
        authMethod: AuthMethod.fromStorage(row['auth_method'] as String?),
        credentialId: row['credential_id'] as String?,
        startupDirectory: row['startup_directory'] as String?,
        environmentNotes: row['environment_notes'] as String?,
        colorValue: row['color_value'] as int?,
        platform: RemotePlatform.fromStorage(row['platform'] as String?),
        favorite: (row['favorite'] as int? ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
        lastConnectedAt: row['last_connected_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['last_connected_at']! as int),
      );

  /// Export representation. Deliberately omits [credentialId] so that a config
  /// export can never imply possession of a secret (SPEC 22).
  Map<String, Object?> toExportJson() => {
        'id': id,
        'name': name,
        'hostname': hostname,
        'port': port,
        'username': username,
        'auth_method': authMethod.storageValue,
        'startup_directory': startupDirectory,
        'environment_notes': environmentNotes,
        'color_value': colorValue,
        'platform': platform.storageValue,
        'favorite': favorite,
      };

  factory Host.fromExportJson(Map<String, Object?> json, {required String id}) {
    final now = DateTime.now();
    return Host(
      id: id,
      name: (json['name'] as String?) ?? 'Imported computer',
      hostname: (json['hostname'] as String?) ?? '',
      port: (json['port'] as num?)?.toInt() ?? defaultPort,
      username: (json['username'] as String?) ?? '',
      authMethod: AuthMethod.fromStorage(json['auth_method'] as String?),
      startupDirectory: json['startup_directory'] as String?,
      environmentNotes: json['environment_notes'] as String?,
      colorValue: (json['color_value'] as num?)?.toInt(),
      platform: RemotePlatform.fromStorage(json['platform'] as String?),
      favorite: json['favorite'] == true,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  bool operator ==(Object other) => other is Host && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
