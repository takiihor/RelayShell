import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as nacl;

import 'fingerprint.dart';

/// Everything the app knows about a key after parsing or generating it.
///
/// The private key text is *not* held here — it goes straight to secure
/// storage. Only the public, non-sensitive facts survive for display.
class KeyDescription {
  const KeyDescription({
    required this.keyType,
    required this.publicKey,
    required this.fingerprintSha256,
    required this.isEncrypted,
    this.comment,
  });

  /// e.g. `ssh-ed25519`, `ssh-rsa`, `ecdsa-sha2-nistp256`.
  final String keyType;

  /// OpenSSH `authorized_keys` line. Safe to display, copy and share.
  final String publicKey;

  final String fingerprintSha256;

  /// Whether the private key requires a passphrase to use.
  final bool isEncrypted;

  final String? comment;
}

/// Raised when key text cannot be understood or a passphrase is wrong.
class KeyMaterialException implements Exception {
  const KeyMaterialException(this.message, {this.needsPassphrase = false});

  final String message;

  /// True when the key is valid but the supplied passphrase was missing/wrong,
  /// so the UI can ask again instead of rejecting the file.
  final bool needsPassphrase;

  @override
  String toString() => message;
}

/// A freshly generated key pair, held only long enough to store it.
class GeneratedKeyPair {
  const GeneratedKeyPair({
    required this.privateKeyPem,
    required this.description,
  });

  /// OpenSSH-format private key text. Write it to secure storage and drop it.
  final String privateKeyPem;

  final KeyDescription description;
}

/// Parses, describes and generates SSH key material (SPEC 18.1).
///
/// Import accepts whatever the user has: OpenSSH, PKCS#1 RSA and SEC1 EC keys,
/// encrypted or not. Generation produces Ed25519 keys, which are short enough
/// to be pasted into `authorized_keys` by hand from a phone.
class SshKeyMaterial {
  const SshKeyMaterial();

  /// Reads [pemText] and returns its public facts.
  ///
  /// Throws [KeyMaterialException] with [KeyMaterialException.needsPassphrase]
  /// set when the key is encrypted and [passphrase] is absent or wrong.
  KeyDescription describe(String pemText, {String? passphrase}) {
    final bool encrypted;
    try {
      encrypted = SSHKeyPair.isEncryptedPem(pemText);
    } on Exception {
      throw const KeyMaterialException(
        'This does not look like a supported SSH private key.',
      );
    }

    if (encrypted && (passphrase == null || passphrase.isEmpty)) {
      throw const KeyMaterialException(
        'This key is protected by a passphrase.',
        needsPassphrase: true,
      );
    }

    final List<SSHKeyPair> pairs;
    try {
      pairs = SSHKeyPair.fromPem(pemText, passphrase);
    } on SSHKeyDecryptError {
      throw const KeyMaterialException(
        'That passphrase did not unlock the key.',
        needsPassphrase: true,
      );
    } on Exception {
      throw const KeyMaterialException(
        'This key could not be read. It may be corrupt or in an '
        'unsupported format.',
      );
    }

    if (pairs.isEmpty) {
      throw const KeyMaterialException('No key was found in that file.');
    }

    final pair = pairs.first;
    final publicBytes = pair.toPublicKey().encode();
    final encoded = base64.encode(publicBytes);
    final comment = pair.comment;

    return KeyDescription(
      keyType: pair.name,
      publicKey: [
        pair.name,
        encoded,
        if (comment != null && comment.isNotEmpty) comment,
      ].join(' '),
      fingerprintSha256: Fingerprint.ofPublicKeyBytes(publicBytes),
      isEncrypted: encrypted,
      comment: comment,
    );
  }

  /// Verifies that [pemText] with [passphrase] can actually be used.
  ///
  /// Called before saving so a bad passphrase is caught at import time rather
  /// than mid-connection.
  bool canUnlock(String pemText, {String? passphrase}) {
    try {
      final pairs = SSHKeyPair.fromPem(pemText, passphrase);
      return pairs.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// Builds the dartssh2 identities used to authenticate.
  List<SSHKeyPair> identities(String pemText, {String? passphrase}) {
    try {
      return SSHKeyPair.fromPem(pemText, passphrase);
    } on SSHKeyDecryptError {
      throw const KeyMaterialException(
        'That passphrase did not unlock the key.',
        needsPassphrase: true,
      );
    } on Exception catch (error) {
      throw KeyMaterialException('The key could not be used: $error');
    }
  }

  /// Generates an Ed25519 key pair in OpenSSH format.
  ///
  /// The private key is written unencrypted *inside the PEM*, because it is
  /// immediately handed to platform secure storage, which is what actually
  /// protects it at rest; layering a passphrase on top would mean prompting for
  /// it on every connection without adding protection the Keychain/Keystore
  /// does not already give. Users who want a passphrase-protected key can
  /// generate one elsewhere and import it.
  GeneratedKeyPair generateEd25519({String? comment}) {
    final signingKey = nacl.SigningKey.generate();
    final seed = Uint8List.fromList(signingKey.seed);
    final publicKey = Uint8List.fromList(signingKey.verifyKey.asTypedList);

    // OpenSSH stores the Ed25519 private scalar as seed || public key.
    final privateBlob = Uint8List(64)
      ..setRange(0, 32, seed)
      ..setRange(32, 64, publicKey);

    final label = comment ?? 'relayshell';
    final publicKeyBlob = _writeEd25519PublicBlob(publicKey);
    final pem = _encodeOpenSshPrivateKey(
      publicKeyBlob: publicKeyBlob,
      privateKeyBlob: privateBlob,
      publicKey: publicKey,
      comment: label,
    );

    return GeneratedKeyPair(
      privateKeyPem: pem,
      description: KeyDescription(
        keyType: 'ssh-ed25519',
        publicKey: 'ssh-ed25519 ${base64.encode(publicKeyBlob)} $label',
        fingerprintSha256: Fingerprint.ofPublicKeyBytes(publicKeyBlob),
        isEncrypted: false,
        comment: label,
      ),
    );
  }

  static Uint8List _writeEd25519PublicBlob(Uint8List publicKey) {
    final writer = _SshWriter()
      ..writeString(utf8.encode('ssh-ed25519'))
      ..writeString(publicKey);
    return writer.take();
  }

  /// Encodes the `openssh-key-v1` container described by OpenSSH's PROTOCOL.key.
  static String _encodeOpenSshPrivateKey({
    required Uint8List publicKeyBlob,
    required Uint8List privateKeyBlob,
    required Uint8List publicKey,
    required String comment,
  }) {
    final checkInt = Random.secure().nextInt(0xFFFFFFFF);

    final inner = _SshWriter()
      ..writeUint32(checkInt)
      ..writeUint32(checkInt)
      ..writeString(utf8.encode('ssh-ed25519'))
      ..writeString(publicKey)
      ..writeString(privateKeyBlob)
      ..writeString(utf8.encode(comment));

    // Pad to the cipher block size; with no cipher OpenSSH uses 8.
    const blockSize = 8;
    var padding = 1;
    while ((inner.length + padding) % blockSize != 0) {
      padding++;
    }
    if (padding == blockSize + 1) padding = 0;
    for (var i = 1; i <= padding; i++) {
      inner.writeByte(i);
    }

    final outer = _SshWriter()
      ..writeRaw(utf8.encode('openssh-key-v1'))
      ..writeByte(0)
      ..writeString(utf8.encode('none')) // ciphername
      ..writeString(utf8.encode('none')) // kdfname
      ..writeString(Uint8List(0)) // kdfoptions
      ..writeUint32(1) // number of keys
      ..writeString(publicKeyBlob)
      ..writeString(inner.take());

    final body = base64.encode(outer.take());
    final buffer = StringBuffer('-----BEGIN OPENSSH PRIVATE KEY-----\n');
    for (var i = 0; i < body.length; i += 70) {
      buffer
        ..write(body.substring(i, min(i + 70, body.length)))
        ..write('\n');
    }
    buffer.write('-----END OPENSSH PRIVATE KEY-----\n');
    return buffer.toString();
  }
}

/// Minimal SSH wire-format writer (RFC 4251 §5).
class _SshWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  int get length => _builder.length;

  void writeByte(int value) => _builder.addByte(value);

  void writeRaw(List<int> bytes) => _builder.add(bytes);

  void writeUint32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    _builder.add(data.buffer.asUint8List());
  }

  void writeString(List<int> bytes) {
    writeUint32(bytes.length);
    _builder.add(bytes);
  }

  Uint8List take() => _builder.toBytes();
}
