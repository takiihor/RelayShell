import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/security/fingerprint.dart';

void main() {
  // A real ed25519 host key blob and the fingerprint `ssh-keygen -lf` reports
  // for it, so the implementation is checked against OpenSSH's own answer
  // rather than against itself.
  const publicKeyBase64 =
      'AAAAC3NzaC1lZDI1NTE5AAAAIOGikA1P67cyU/uPVvdCHhYvmaov3ZxI56+ZA49a5KN7';
  const expectedFingerprint =
      'SHA256:3/XMM8QdBDzl5pBdh5DaN9nU8tEhiGwYOAI+fzqfV3g';

  group('normalize', () {
    test('adds the SHA256 prefix when absent', () {
      expect(Fingerprint.normalize('abc123'), 'SHA256:abc123');
    });

    test('keeps an existing prefix without doubling it', () {
      expect(Fingerprint.normalize('SHA256:abc123'), 'SHA256:abc123');
    });

    test(
      'strips base64 padding so padded and unpadded forms compare equal',
      () {
        expect(Fingerprint.normalize('SHA256:abc='), 'SHA256:abc');
        expect(Fingerprint.normalize('SHA256:abc=='), 'SHA256:abc');
      },
    );

    test('trims surrounding whitespace', () {
      expect(Fingerprint.normalize('  SHA256:abc  '), 'SHA256:abc');
    });
  });

  group('ofPublicKeyBytes', () {
    test('matches the fingerprint ssh-keygen reports', () {
      final bytes = Uint8List.fromList(base64.decode(publicKeyBase64));
      expect(Fingerprint.ofPublicKeyBytes(bytes), expectedFingerprint);
    });
  });

  group('ofAuthorizedKeyLine', () {
    test('parses a standard authorized_keys line', () {
      expect(
        Fingerprint.ofAuthorizedKeyLine(
          'ssh-ed25519 $publicKeyBase64 user@host',
        ),
        expectedFingerprint,
      );
    });

    test('parses a line with no comment', () {
      expect(
        Fingerprint.ofAuthorizedKeyLine('ssh-ed25519 $publicKeyBase64'),
        expectedFingerprint,
      );
    });

    test('returns null for text that is not a key', () {
      expect(Fingerprint.ofAuthorizedKeyLine('not a key'), isNull);
      expect(Fingerprint.ofAuthorizedKeyLine(''), isNull);
      expect(
        Fingerprint.ofAuthorizedKeyLine('ssh-ed25519 !!!not-base64!!!'),
        isNull,
      );
    });
  });

  group('fromCallbackBytes', () {
    test('decodes the UTF-8 fingerprint dartssh2 supplies', () {
      final bytes = Uint8List.fromList(utf8.encode(expectedFingerprint));
      expect(Fingerprint.fromCallbackBytes(bytes), expectedFingerprint);
    });
  });

  group('matches', () {
    test('accepts identical fingerprints', () {
      expect(
        Fingerprint.matches(expectedFingerprint, expectedFingerprint),
        isTrue,
      );
    });

    test('accepts equivalent fingerprints written differently', () {
      expect(Fingerprint.matches('SHA256:abc', 'abc'), isTrue);
      expect(Fingerprint.matches('SHA256:abc=', 'SHA256:abc'), isTrue);
    });

    test('rejects a fingerprint differing in one character', () {
      // This is the case that must never pass: a changed host key.
      const altered = 'SHA256:4/XMM8QdBDzl5pBdh5DaN9nU8tEhiGwYOAI+fzqfV3g';
      expect(Fingerprint.matches(expectedFingerprint, altered), isFalse);
    });

    test('rejects a fingerprint that is a prefix of the other', () {
      expect(Fingerprint.matches('SHA256:abc', 'SHA256:abcd'), isFalse);
    });

    test('rejects an empty fingerprint against a real one', () {
      expect(Fingerprint.matches('', expectedFingerprint), isFalse);
    });

    test('is case sensitive, because base64 is', () {
      expect(Fingerprint.matches('SHA256:aBc', 'SHA256:abc'), isFalse);
    });
  });

  group('forDisplay', () {
    test('groups the body for readability without altering it', () {
      final display = Fingerprint.forDisplay(expectedFingerprint);
      expect(display.startsWith('SHA256:'), isTrue);
      expect(display.replaceAll(' ', ''), expectedFingerprint);
    });

    test('handles a body shorter than one group', () {
      expect(Fingerprint.forDisplay('SHA256:abc'), 'SHA256:abc');
    });
  });
}
