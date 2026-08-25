import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/database/app_database.dart';
import 'package:relayshell/core/database/credentials_repository.dart';
import 'package:relayshell/core/database/hosts_repository.dart';
import 'package:relayshell/core/database/trusted_keys_repository.dart';
import 'package:relayshell/core/security/redaction.dart';
import 'package:relayshell/core/security/ssh_key_material.dart';
import 'package:relayshell/core/ssh/host_key_verifier.dart';
import 'package:relayshell/core/storage/secret_store.dart';
import 'package:relayshell/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Executable form of the release gates in SPEC 44.
///
/// Each numbered requirement there says the release must not ship if the
/// condition holds. Encoding them as tests turns a checklist someone has to
/// remember into something CI enforces.
void main() {
  sqfliteFfiInit();

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });
  tearDown(() async => database.close());

  group('44.1 private keys are never stored in plain SQLite', () {
    test(
      'importing a key puts the private half only in secure storage',
      () async {
        final secrets = InMemorySecretStore();
        final credentials = CredentialsRepository(database);
        final generated = const SshKeyMaterial().generateEd25519();
        final now = DateTime.now();

        // The flow the UI performs on import.
        await secrets.write(
          SecretKind.privateKey,
          'c1',
          generated.privateKeyPem,
        );
        await credentials.upsert(
          Credential(
            id: 'c1',
            name: 'Key',
            type: CredentialType.privateKey,
            publicKey: generated.description.publicKey,
            keyType: generated.description.keyType,
            fingerprintSha256: generated.description.fingerprintSha256,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Dump every value in every table and confirm the key body is absent.
        final tables = await database.db.query(
          'sqlite_master',
          columns: ['name'],
          where: 'type = ?',
          whereArgs: ['table'],
        );

        for (final table in tables) {
          final name = table['name']! as String;
          if (name.startsWith('sqlite_')) continue;
          final rows = await database.db.query(name);
          final dump = rows.toString();

          expect(
            dump,
            isNot(contains('PRIVATE KEY')),
            reason: 'table $name contains private key material',
          );
          expect(
            dump,
            isNot(contains(generated.privateKeyPem.trim())),
            reason: 'table $name contains the private key',
          );
        }

        // But it is retrievable from secure storage.
        expect(
          await secrets.read(SecretKind.privateKey, 'c1'),
          generated.privateKeyPem,
        );
      },
    );

    test('the Credential model has no field that can carry a secret', () {
      final credential = Credential(
        id: 'c1',
        name: 'Key',
        type: CredentialType.privateKey,
        publicKey: 'ssh-ed25519 AAAA...',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final row = credential.toRow().toString().toLowerCase();
      expect(row, isNot(contains('private key')));
      // hasPassphrase is a boolean flag, never the passphrase itself.
      expect(credential.toRow()['has_passphrase'], isA<int>());
    });
  });

  group('44.2 passwords never appear in logs', () {
    test('a log line carrying a password is scrubbed', () {
      const redactor = Redactor();
      expect(
        redactor.scrub('auth failed password=hunter2'),
        isNot(contains('hunter2')),
      );
    });

    test('a wrapped secret cannot be interpolated into a log line', () {
      const secret = Sensitive<String>('hunter2');
      expect('connecting with $secret', isNot(contains('hunter2')));
    });
  });

  group('44.3 host-key changes are never silently accepted', () {
    late TrustedKeysRepository trusted;

    Host host() => Host(
      id: 'h1',
      name: 'Server',
      hostname: 'example.com',
      port: 22,
      username: 'dev',
      authMethod: AuthMethod.privateKey,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() async {
      // Most connections run against a saved host. A separate test below
      // covers Test Connection before the form is saved.
      await HostsRepository(database).upsert(host());
      trusted = TrustedKeysRepository(database);
      await trusted.trust(
        TrustedHostKey(
          id: 't1',
          hostname: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprintSha256: 'SHA256:originalfingerprint',
          trustedAt: DateTime.now(),
        ),
      );
    });

    test('a matching fingerprint connects without prompting', () async {
      var prompted = false;
      final verifier = HostKeyVerifier(
        trustedKeys: trusted,
        prompt: (_) async {
          prompted = true;
          return true;
        },
      );

      final accepted = await verifier.callbackFor(host())(
        'ssh-ed25519',
        _fingerprintBytes('SHA256:originalfingerprint'),
      );

      expect(accepted, isTrue);
      expect(prompted, isFalse);
    });

    test('a changed fingerprint is rejected and never prompts', () async {
      // The critical case: the user must not be offered a way to wave this
      // through in the connection flow.
      var prompted = false;
      final verifier = HostKeyVerifier(
        trustedKeys: trusted,
        prompt: (_) async {
          prompted = true;
          return true;
        },
      );

      final accepted = await verifier.callbackFor(host())(
        'ssh-ed25519',
        _fingerprintBytes('SHA256:attackerfingerprint'),
      );

      expect(accepted, isFalse);
      expect(prompted, isFalse, reason: 'a changed key must not be promptable');
      expect(verifier.lastFailure, isNotNull);
      // The detail carries both fingerprints, grouped for readability.
      final detail = verifier.lastFailure!.technicalDetail!;
      expect(
        detail.replaceAll(' ', ''),
        contains('SHA256:originalfingerprint'),
      );
      expect(
        detail.replaceAll(' ', ''),
        contains('SHA256:attackerfingerprint'),
      );
    });

    test('the stored key survives a rejected connection', () async {
      final verifier = HostKeyVerifier(
        trustedKeys: trusted,
        prompt: (_) async => true,
      );

      await verifier.callbackFor(host())(
        'ssh-ed25519',
        _fingerprintBytes('SHA256:attackerfingerprint'),
      );

      final stored = await trusted.find(
        hostname: 'example.com',
        port: 22,
        keyType: 'ssh-ed25519',
      );
      expect(stored!.fingerprintSha256, 'SHA256:originalfingerprint');
    });

    test('an unknown key requires explicit consent', () async {
      final verifier = HostKeyVerifier(
        trustedKeys: trusted,
        prompt: (_) async => false,
      );

      final accepted = await verifier.callbackFor(host())(
        'ssh-rsa', // not yet trusted for this endpoint
        _fingerprintBytes('SHA256:brandnew'),
      );

      expect(accepted, isFalse);
      expect(
        await trusted.find(
          hostname: 'example.com',
          port: 22,
          keyType: 'ssh-rsa',
        ),
        isNull,
        reason: 'a declined key must not be stored',
      );
    });

    test('consent stores the key so the next connection is silent', () async {
      final verifier = HostKeyVerifier(
        trustedKeys: trusted,
        prompt: (_) async => true,
      );

      final accepted = await verifier.callbackFor(host())(
        'ssh-rsa',
        _fingerprintBytes('SHA256:brandnew'),
      );

      expect(accepted, isTrue);
      final stored = await trusted.find(
        hostname: 'example.com',
        port: 22,
        keyType: 'ssh-rsa',
      );
      expect(stored, isNotNull);
      expect(stored!.fingerprintSha256, 'SHA256:brandnew');
    });

    test('Test Connection keeps consent before a computer is saved', () async {
      final unsaved = Host(
        id: 'not-yet-saved',
        name: 'Preview server',
        hostname: 'preview.example.com',
        port: 2222,
        username: 'dev',
        authMethod: AuthMethod.privateKey,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final verifier = HostKeyVerifier(
        trustedKeys: trusted,
        prompt: (_) async => true,
      );

      final accepted = await verifier.callbackFor(unsaved)(
        'ssh-ed25519',
        _fingerprintBytes('SHA256:previewfingerprint'),
      );

      expect(accepted, isTrue);
      final stored = await trusted.find(
        hostname: unsaved.hostname,
        port: unsaved.port,
        keyType: 'ssh-ed25519',
      );
      expect(stored, isNotNull);
      expect(stored!.hostId, isNull);

      await HostsRepository(database).upsert(unsaved);
      await trusted.attachUnownedEndpoint(
        hostId: unsaved.id,
        hostname: unsaved.hostname,
        port: unsaved.port,
      );
      final attached = await trusted.find(
        hostname: unsaved.hostname,
        port: unsaved.port,
        keyType: 'ssh-ed25519',
      );
      expect(attached!.hostId, unsaved.id);
    });
  });

  group('44.8 verification is never globally disabled', () {
    test('no setting exists that turns host verification off', () {
      // AppPreferences is the complete set of user-changeable behaviour; a
      // "skip host key check" switch must not appear in it.
      final keys = const AppPreferences().toMap().keys.join(' ').toLowerCase();

      for (final forbidden in const [
        'verify',
        'insecure',
        'skip_host',
        'strict_host',
        'trust_all',
        'disable_host',
      ]) {
        expect(keys, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('the source never disables dartssh2 host key verification', () {
      // dartssh2 exposes `disableHostkeyVerification`; setting it anywhere
      // would defeat every check above.
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('disableHostkeyVerification')) {
          offenders.add(entity.path);
        }
      }

      expect(offenders, isEmpty);
    });

    test('onVerifyHostKey is always supplied to the SSH client', () {
      // A null handler makes dartssh2 accept every host key automatically.
      final source = File('lib/core/ssh/ssh_connection.dart')
          .readAsStringSync();
      expect(source, contains('onVerifyHostKey:'));
      expect(source, isNot(contains('onVerifyHostKey: null')));
    });
  });

  group('44.4 export cannot leak credentials by default', () {
    test('the exported host shape carries no credential reference', () {
      final host = Host(
        id: 'h1',
        name: 'Server',
        hostname: 'example.com',
        port: 22,
        username: 'dev',
        authMethod: AuthMethod.password,
        credentialId: 'super-secret-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final exported = host.toExportJson();
      expect(exported.containsKey('credential_id'), isFalse);
      expect(exported.toString(), isNot(contains('super-secret-id')));
    });
  });

  group('44.7 no debug SSH logging in production', () {
    test('printDebug and printTrace are never wired up', () {
      // dartssh2's trace handlers print packet contents, including auth.
      final source = File('lib/core/ssh/ssh_connection.dart')
          .readAsStringSync();
      expect(source, isNot(contains('printDebug:')));
      expect(source, isNot(contains('printTrace:')));
    });
  });
}

/// Builds the bytes dartssh2 hands to its verify callback: the UTF-8 text of
/// `SHA256:<base64>`.
Uint8List _fingerprintBytes(String fingerprint) =>
    Uint8List.fromList(utf8.encode(fingerprint));
