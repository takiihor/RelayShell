import 'package:flutter/foundation.dart';

/// Optional Wake-on-LAN configuration for a host (SPEC 17).
///
/// Best-effort by design: magic packets are not routable across arbitrary
/// external networks and the UI must not promise success.
@immutable
class WolProfile {
  const WolProfile({
    required this.hostId,
    required this.macAddress,
    this.broadcastAddress = '255.255.255.255',
    this.port = 9,
  });

  final String hostId;
  final String macAddress;
  final String broadcastAddress;
  final int port;

  WolProfile copyWith({
    String? macAddress,
    String? broadcastAddress,
    int? port,
  }) =>
      WolProfile(
        hostId: hostId,
        macAddress: macAddress ?? this.macAddress,
        broadcastAddress: broadcastAddress ?? this.broadcastAddress,
        port: port ?? this.port,
      );

  Map<String, Object?> toRow() => {
        'host_id': hostId,
        'mac_address': macAddress,
        'broadcast_address': broadcastAddress,
        'port': port,
      };

  factory WolProfile.fromRow(Map<String, Object?> row) => WolProfile(
        hostId: row['host_id']! as String,
        macAddress: row['mac_address']! as String,
        broadcastAddress:
            (row['broadcast_address'] as String?) ?? '255.255.255.255',
        port: row['port'] as int? ?? 9,
      );

  Map<String, Object?> toExportJson() => toRow();

  @override
  bool operator ==(Object other) => other is WolProfile && other.hostId == hostId;

  @override
  int get hashCode => hostId.hashCode;
}
