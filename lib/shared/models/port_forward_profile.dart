import 'package:flutter/foundation.dart';

import 'enums.dart';

/// A saved SSH forwarding configuration (SPEC 16).
@immutable
class PortForwardProfile {
  const PortForwardProfile({
    required this.id,
    required this.hostId,
    required this.name,
    required this.type,
    required this.listenPort,
    required this.createdAt,
    required this.updatedAt,
    this.listenAddress = '127.0.0.1',
    this.targetHost,
    this.targetPort,
    this.autoStart = false,
  });

  final String id;
  final String hostId;
  final String name;
  final ForwardType type;

  /// The port opened by whichever side listens: the phone for
  /// [ForwardType.local] and [ForwardType.dynamicSocks], the server for
  /// [ForwardType.remote].
  final int listenPort;
  final String listenAddress;

  /// Destination of forwarded traffic. Unused for dynamic SOCKS forwards.
  final String? targetHost;
  final int? targetPort;

  final bool autoStart;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get summary {
    switch (type) {
      case ForwardType.local:
        return 'localhost:$listenPort → $targetHost:$targetPort';
      case ForwardType.remote:
        return 'remote:$listenPort → $targetHost:$targetPort';
      case ForwardType.dynamicSocks:
        return 'SOCKS5 on localhost:$listenPort';
    }
  }

  PortForwardProfile copyWith({
    String? name,
    ForwardType? type,
    int? listenPort,
    String? listenAddress,
    String? targetHost,
    int? targetPort,
    bool? autoStart,
    DateTime? updatedAt,
  }) =>
      PortForwardProfile(
        id: id,
        hostId: hostId,
        name: name ?? this.name,
        type: type ?? this.type,
        listenPort: listenPort ?? this.listenPort,
        listenAddress: listenAddress ?? this.listenAddress,
        targetHost: targetHost ?? this.targetHost,
        targetPort: targetPort ?? this.targetPort,
        autoStart: autoStart ?? this.autoStart,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'host_id': hostId,
        'name': name,
        'type': type.storageValue,
        'listen_port': listenPort,
        'listen_address': listenAddress,
        'target_host': targetHost,
        'target_port': targetPort,
        'auto_start': autoStart ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory PortForwardProfile.fromRow(Map<String, Object?> row) =>
      PortForwardProfile(
        id: row['id']! as String,
        hostId: row['host_id']! as String,
        name: row['name']! as String,
        type: ForwardType.fromStorage(row['type'] as String?),
        listenPort: row['listen_port']! as int,
        listenAddress: (row['listen_address'] as String?) ?? '127.0.0.1',
        targetHost: row['target_host'] as String?,
        targetPort: row['target_port'] as int?,
        autoStart: (row['auto_start'] as int? ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      );

  Map<String, Object?> toExportJson() => {
        'id': id,
        'host_id': hostId,
        'name': name,
        'type': type.storageValue,
        'listen_port': listenPort,
        'listen_address': listenAddress,
        'target_host': targetHost,
        'target_port': targetPort,
        'auto_start': autoStart,
      };

  @override
  bool operator ==(Object other) =>
      other is PortForwardProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
