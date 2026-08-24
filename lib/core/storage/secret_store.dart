import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The kinds of secret material the app holds.
///
/// Each kind gets its own key namespace so a lookup can never return a password
/// where a private key was expected.
enum SecretKind {
  privateKey('pk'),
  passphrase('pp'),
  password('pw');

  const SecretKind(this.prefix);
  final String prefix;
}

/// The only place secret material is read or written (SPEC 18.2, 23.2).
///
/// Backed by the iOS Keychain and Android's Keystore-wrapped storage. Nothing
/// here is ever copied into SQLite, logs, exports or crash reports — the
/// release gate in SPEC 44 depends on that staying true.
abstract class SecretStore {
  Future<void> write(SecretKind kind, String credentialId, String value);

  Future<String?> read(SecretKind kind, String credentialId);

  Future<bool> has(SecretKind kind, String credentialId);

  Future<void> delete(SecretKind kind, String credentialId);

  /// Removes every secret belonging to one credential.
  Future<void> deleteCredential(String credentialId);

  /// Wipes all secret material. Used by "Reset app" (SPEC 21).
  Future<void> deleteAll();
}

/// [SecretStore] backed by platform secure storage.
class PlatformSecretStore implements SecretStore {
  PlatformSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static String _key(SecretKind kind, String credentialId) =>
      '${kind.prefix}:$credentialId';

  @override
  Future<void> write(SecretKind kind, String credentialId, String value) =>
      _storage.write(key: _key(kind, credentialId), value: value);

  @override
  Future<String?> read(SecretKind kind, String credentialId) =>
      _storage.read(key: _key(kind, credentialId));

  @override
  Future<bool> has(SecretKind kind, String credentialId) =>
      _storage.containsKey(key: _key(kind, credentialId));

  @override
  Future<void> delete(SecretKind kind, String credentialId) =>
      _storage.delete(key: _key(kind, credentialId));

  @override
  Future<void> deleteCredential(String credentialId) async {
    for (final kind in SecretKind.values) {
      await delete(kind, credentialId);
    }
  }

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// In-memory [SecretStore] for tests and for platforms without secure storage.
///
/// Deliberately not used in production: it offers no protection at rest.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  static String _key(SecretKind kind, String credentialId) =>
      '${kind.prefix}:$credentialId';

  @override
  Future<void> write(SecretKind kind, String credentialId, String value) async {
    _values[_key(kind, credentialId)] = value;
  }

  @override
  Future<String?> read(SecretKind kind, String credentialId) async =>
      _values[_key(kind, credentialId)];

  @override
  Future<bool> has(SecretKind kind, String credentialId) async =>
      _values.containsKey(_key(kind, credentialId));

  @override
  Future<void> delete(SecretKind kind, String credentialId) async {
    _values.remove(_key(kind, credentialId));
  }

  @override
  Future<void> deleteCredential(String credentialId) async {
    for (final kind in SecretKind.values) {
      _values.remove(_key(kind, credentialId));
    }
  }

  @override
  Future<void> deleteAll() async => _values.clear();
}
