import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/security/ssh_key_material.dart';

void main() {
  const material = SshKeyMaterial();

  group('generateEd25519', () {
    test('produces an OpenSSH private key block', () {
      final generated = material.generateEd25519(comment: 'test');
      expect(
        generated.privateKeyPem,
        startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
      );
      expect(
        generated.privateKeyPem.trim(),
        endsWith('-----END OPENSSH PRIVATE KEY-----'),
      );
    });

    test('describes the key it just made', () {
      final generated = material.generateEd25519(comment: 'phone');
      expect(generated.description.keyType, 'ssh-ed25519');
      expect(generated.description.publicKey, startsWith('ssh-ed25519 '));
      expect(generated.description.publicKey, endsWith(' phone'));
      expect(generated.description.fingerprintSha256, startsWith('SHA256:'));
      expect(generated.description.isEncrypted, isFalse);
    });

    test('re-parsing its own key yields the same public key', () {
      final generated = material.generateEd25519(comment: 'roundtrip');
      final reparsed = material.describe(generated.privateKeyPem);

      expect(reparsed.publicKey, generated.description.publicKey);
      expect(
        reparsed.fingerprintSha256,
        generated.description.fingerprintSha256,
      );
    });

    test('generates a different key each time', () {
      final a = material.generateEd25519();
      final b = material.generateEd25519();
      expect(a.description.publicKey, isNot(b.description.publicKey));
    });

    test('can be used to authenticate', () {
      final generated = material.generateEd25519();
      expect(material.canUnlock(generated.privateKeyPem), isTrue);
      expect(material.identities(generated.privateKeyPem), isNotEmpty);
    });
  });

  group('describe rejects bad input', () {
    test('refuses text that is not a key', () {
      expect(
        () => material.describe('hello world'),
        throwsA(isA<KeyMaterialException>()),
      );
    });

    test('refuses an empty string', () {
      expect(() => material.describe(''), throwsA(isA<KeyMaterialException>()));
    });

    test('refuses a truncated key', () {
      final generated = material.generateEd25519();
      final truncated = generated.privateKeyPem.substring(
        0,
        generated.privateKeyPem.length ~/ 2,
      );
      expect(
        () => material.describe(truncated),
        throwsA(isA<KeyMaterialException>()),
      );
    });
  });

  group('canUnlock', () {
    test('reports false instead of throwing for junk', () {
      expect(material.canUnlock('not a key'), isFalse);
    });
  });

  // The strongest available check: OpenSSH itself must accept the key we
  // generated and derive the same public half we claim.
  group('interoperates with ssh-keygen', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('relayshell-key'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('ssh-keygen derives the same public key and fingerprint', () async {
      final generated = material.generateEd25519(comment: 'interop@test');

      final keyFile = File('${temp.path}/id_test')
        ..writeAsStringSync(generated.privateKeyPem);
      // ssh-keygen refuses world-readable private keys.
      await Process.run('chmod', ['600', keyFile.path]);

      final derived = await Process.run('ssh-keygen', [
        '-y',
        '-f',
        keyFile.path,
      ]);
      expect(derived.exitCode, 0, reason: derived.stderr.toString());
      expect(
        (derived.stdout as String).trim(),
        generated.description.publicKey.trim(),
      );

      final fingerprint = await Process.run('ssh-keygen', [
        '-l',
        '-f',
        keyFile.path,
      ]);
      expect(fingerprint.exitCode, 0, reason: fingerprint.stderr.toString());
      expect(
        fingerprint.stdout as String,
        contains(generated.description.fingerprintSha256),
      );
    });
  }, skip: !Platform.isLinux && !Platform.isMacOS);
}
