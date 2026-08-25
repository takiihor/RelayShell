import 'package:flutter/foundation.dart';

import 'enums.dart';

/// Metadata about a stored secret (SPEC 18, 23.2).
///
/// The secret itself (private key body, password, passphrase) is *never* stored
/// on this object or in SQLite. It lives in platform secure storage keyed by
/// [id]. Only non-sensitive descriptive fields appear here.
@immutable
class Credential {
  const Credential({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.publicKey,
    this.keyType,
    this.fingerprintSha256,
    this.hasPassphrase = false,
    this.requireBiometric = false,
  });

  final String id;
  final String name;
  final CredentialType type;

  /// OpenSSH-format public key. Not sensitive; safe to display and copy.
  final String? publicKey;

  /// e.g. `ssh-ed25519`, `ssh-rsa`.
  final String? keyType;

  /// SHA-256 fingerprint of the *public* key, for display.
  final String? fingerprintSha256;

  /// Whether the private key is passphrase-protected. The passphrase itself is
  /// in secure storage.
  final bool hasPassphrase;

  /// Require biometric/device authentication before this secret is read
  /// (SPEC 18.3).
  final bool requireBiometric;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isKey => type == CredentialType.privateKey;

  Credential copyWith({
    String? name,
    Object? publicKey = _unset,
    Object? keyType = _unset,
    Object? fingerprintSha256 = _unset,
    bool? hasPassphrase,
    bool? requireBiometric,
    DateTime? updatedAt,
  }) => Credential(
    id: id,
    name: name ?? this.name,
    type: type,
    publicKey: publicKey == _unset ? this.publicKey : publicKey as String?,
    keyType: keyType == _unset ? this.keyType : keyType as String?,
    fingerprintSha256: fingerprintSha256 == _unset
        ? this.fingerprintSha256
        : fingerprintSha256 as String?,
    hasPassphrase: hasPassphrase ?? this.hasPassphrase,
    requireBiometric: requireBiometric ?? this.requireBiometric,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'type': type.storageValue,
    'public_key': publicKey,
    'key_type': keyType,
    'fingerprint_sha256': fingerprintSha256,
    'has_passphrase': hasPassphrase ? 1 : 0,
    'require_biometric': requireBiometric ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory Credential.fromRow(Map<String, Object?> row) => Credential(
    id: row['id']! as String,
    name: row['name']! as String,
    type: CredentialType.fromStorage(row['type'] as String?),
    publicKey: row['public_key'] as String?,
    keyType: row['key_type'] as String?,
    fingerprintSha256: row['fingerprint_sha256'] as String?,
    hasPassphrase: (row['has_passphrase'] as int? ?? 0) == 1,
    requireBiometric: (row['require_biometric'] as int? ?? 0) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
  );

  @override
  bool operator ==(Object other) => other is Credential && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

const Object _unset = Object();
