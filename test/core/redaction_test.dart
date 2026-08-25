import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/security/redaction.dart';

void main() {
  const redactor = Redactor();

  group('scrub', () {
    test('removes a PEM private key block', () {
      const log = '''
Connection failed with key:
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gt
ZWQyNTUxOQAAACDhopANT+u3MlP7j1b3Qh4WL5mqL92cSOevmQOPWuSjew
-----END OPENSSH PRIVATE KEY-----
after''';

      final scrubbed = redactor.scrub(log);
      expect(scrubbed, isNot(contains('BEGIN OPENSSH PRIVATE KEY')));
      expect(scrubbed, isNot(contains('b3BlbnNzaC1rZXktdjEA')));
      expect(scrubbed, contains(Redactor.placeholder));
      expect(scrubbed, contains('after'));
    });

    test('removes an RSA private key block', () {
      const log =
          '-----BEGIN RSA PRIVATE KEY-----\nMIIE\n-----END RSA PRIVATE KEY-----';
      expect(redactor.scrub(log), isNot(contains('MIIE')));
    });

    test('redacts labelled secrets but keeps the label', () {
      for (final line in const [
        'password=hunter2',
        'password: hunter2',
        'passphrase = hunter2',
        'PASSWORD=hunter2',
        'secret: hunter2',
        'token=hunter2',
        'api_key=hunter2',
        'api-key: hunter2',
      ]) {
        final scrubbed = redactor.scrub(line);
        expect(scrubbed, isNot(contains('hunter2')), reason: line);
        expect(scrubbed, contains(Redactor.placeholder), reason: line);
      }
    });

    test('redacts an Authorization header', () {
      final scrubbed = redactor.scrub('Authorization: Bearer abc123');
      expect(scrubbed, isNot(contains('abc123')));
    });

    test('leaves ordinary log lines untouched', () {
      const line = 'Connected to 10.0.0.5:22 in 340ms';
      expect(redactor.scrub(line), line);
    });

    test('leaves the word password alone when it carries no value', () {
      const line = 'Authentication failed: check the password for this host.';
      expect(redactor.scrub(line), line);
    });
  });

  group('mask', () {
    test('keeps only the last characters visible', () {
      expect(redactor.mask('abcdefgh'), '****efgh');
    });

    test('fully masks a value shorter than the visible window', () {
      expect(redactor.mask('abc'), '***');
    });

    test('honours a custom window', () {
      expect(redactor.mask('abcdefgh', visible: 2), '******gh');
    });
  });

  group('Sensitive', () {
    test('toString does not reveal the value', () {
      const secret = Sensitive<String>('hunter2');
      expect(secret.toString(), isNot(contains('hunter2')));
      expect(secret.toString(), contains(Redactor.placeholder));
    });

    test('string interpolation cannot leak it', () {
      const secret = Sensitive<String>('hunter2');
      expect('$secret', isNot(contains('hunter2')));
    });

    test('expose returns the real value at the point of use', () {
      const secret = Sensitive<String>('hunter2');
      expect(secret.expose(), 'hunter2');
    });
  });
}
