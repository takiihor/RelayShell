import 'package:flutter/foundation.dart';

/// A host fingerprint the user has explicitly trusted (SPEC 9.2).
///
/// Keyed by endpoint (`hostname:port`) plus key type rather than by host id, so
/// that editing a [Host]'s hostname or port cannot silently reuse a trust
/// decision made for a different machine (SPEC 8.4).
@immutable
class TrustedHostKey {
  const TrustedHostKey({
    required this.id,
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprintSha256,
    required this.trustedAt,
    this.hostId,
  });

  final String id;
  final String hostname;
  final int port;
  final String keyType;
  final String fingerprintSha256;
  final DateTime trustedAt;

  /// The host record that first trusted this key. Advisory only; used to show
  /// a friendly name in the trusted-keys settings screen.
  final String? hostId;

  String get endpointKey => '$hostname:$port';

  Map<String, Object?> toRow() => {
        'id': id,
        'host_id': hostId,
        'hostname': hostname,
        'port': port,
        'key_type': keyType,
        'fingerprint_sha256': fingerprintSha256,
        'trusted_at': trustedAt.millisecondsSinceEpoch,
      };

  factory TrustedHostKey.fromRow(Map<String, Object?> row) => TrustedHostKey(
        id: row['id']! as String,
        hostId: row['host_id'] as String?,
        hostname: row['hostname']! as String,
        port: row['port']! as int,
        keyType: row['key_type']! as String,
        fingerprintSha256: row['fingerprint_sha256']! as String,
        trustedAt:
            DateTime.fromMillisecondsSinceEpoch(row['trusted_at']! as int),
      );

  @override
  bool operator ==(Object other) => other is TrustedHostKey && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
