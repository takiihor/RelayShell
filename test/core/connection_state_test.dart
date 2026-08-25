import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/ssh/ssh_connection.dart';
import 'package:relayshell/core/ssh/ssh_failure.dart';
import 'package:relayshell/shared/models/enums.dart';

void main() {
  group('SshConnectionState classification', () {
    test('only connected and reconnecting count as active', () {
      expect(SshConnectionState.connected.isActive, isTrue);
      expect(SshConnectionState.reconnecting.isActive, isTrue);
      expect(SshConnectionState.idle.isActive, isFalse);
      expect(SshConnectionState.failed.isActive, isFalse);
      expect(SshConnectionState.closed.isActive, isFalse);
    });

    test('failed and closed are terminal', () {
      expect(SshConnectionState.failed.isTerminal, isTrue);
      expect(SshConnectionState.closed.isTerminal, isTrue);
      expect(SshConnectionState.connected.isTerminal, isFalse);
    });

    test('every step toward connected reports busy', () {
      for (final state in const [
        SshConnectionState.resolving,
        SshConnectionState.connecting,
        SshConnectionState.handshaking,
        SshConnectionState.verifyingHost,
        SshConnectionState.authenticating,
        SshConnectionState.reconnecting,
      ]) {
        expect(state.isBusy, isTrue, reason: state.name);
      }
    });

    test('settled states do not report busy', () {
      for (final state in const [
        SshConnectionState.idle,
        SshConnectionState.connected,
        SshConnectionState.failed,
        SshConnectionState.closed,
      ]) {
        expect(state.isBusy, isFalse, reason: state.name);
      }
    });

    test('covers every state named in the specification', () {
      expect(SshConnectionState.values, hasLength(10));
    });
  });

  group('SshConnectionStatus', () {
    test('copyWith preserves untouched fields', () {
      const status = SshConnectionStatus(
        state: SshConnectionState.connected,
        reconnectAttempt: 2,
        banner: 'welcome',
      );

      final next = status.copyWith(state: SshConnectionState.failed);
      expect(next.state, SshConnectionState.failed);
      expect(next.reconnectAttempt, 2);
      expect(next.banner, 'welcome');
    });
  });

  group('SshFailure retry classification', () {
    test('transport problems are worth retrying', () {
      for (final kind in const [
        SshFailureKind.timeout,
        SshFailureKind.networkUnreachable,
        SshFailureKind.connectionLost,
        SshFailureKind.connectionRefused,
      ]) {
        expect(
          SshFailure(kind: kind, message: 'x').isRetryable,
          isTrue,
          reason: kind.name,
        );
      }
    });

    test('a wrong credential or changed host key is never auto-retried', () {
      // Retrying these replays the user's prompts and cannot succeed, so the
      // connection manager must not schedule a retry for them.
      for (final kind in const [
        SshFailureKind.authenticationFailed,
        SshFailureKind.hostKeyChanged,
        SshFailureKind.hostKeyRejected,
        SshFailureKind.credentialUnavailable,
        SshFailureKind.passphraseRequired,
        SshFailureKind.authorizationRequired,
      ]) {
        expect(
          SshFailure(kind: kind, message: 'x').isRetryable,
          isFalse,
          reason: kind.name,
        );
      }
    });

    test('flags the failures the user must fix before retrying', () {
      expect(
        const SshFailure(
          kind: SshFailureKind.authenticationFailed,
          message: 'x',
        ).needsUserFix,
        isTrue,
      );
      expect(
        const SshFailure(
          kind: SshFailureKind.timeout,
          message: 'x',
        ).needsUserFix,
        isFalse,
      );
    });
  });

  group('SshFailure.from', () {
    test('passes an existing failure through unchanged', () {
      const original = SshFailure(
        kind: SshFailureKind.hostKeyChanged,
        message: 'changed',
      );
      expect(
        SshFailure.from(original, hostname: 'h', port: 22),
        same(original),
      );
    });

    test('maps an unknown error to an actionable message', () {
      final failure = SshFailure.from(
        StateError('boom'),
        hostname: 'example.com',
        port: 22,
      );
      expect(failure.kind, SshFailureKind.unknown);
      expect(failure.message, isNotEmpty);
      expect(failure.technicalDetail, contains('boom'));
    });

    test('keeps raw detail out of the primary message', () {
      // SPEC 31: raw exceptions belong behind the details expander.
      final failure = SshFailure.from(
        StateError('SqliteException(787): gory internals'),
        hostname: 'example.com',
        port: 22,
      );
      expect(failure.message, isNot(contains('SqliteException')));
    });
  });

  group(
    'SshFailure.from distinguishes handshake timeout from real mismatch',
    () {
      // dartssh2 raises SSHHandshakeError for every handshake-phase failure,
      // including its own internal timeout — which fires if the user takes
      // longer than the old handshakeTimeout to approve an unknown host key
      // (a real incident: see ssh_connection.dart, handshakeTimeout is
      // deliberately omitted for exactly this reason). Reporting that as
      // "unsupported algorithms" sends the user chasing the wrong cause.
      test('a timeout is reported as a timeout, not an algorithm mismatch', () {
        final failure = SshFailure.from(
          SSHHandshakeError('Handshake timed out'),
          hostname: 'example.com',
          port: 22,
        );
        expect(failure.kind, SshFailureKind.timeout);
        expect(failure.message, contains('timed out'));
        expect(failure.message, isNot(contains('agree')));
        expect(failure.isRetryable, isTrue);
      });

      test(
        'a non-timeout handshake error still reports an algorithm mismatch',
        () {
          final failure = SshFailure.from(
            SSHHandshakeError('no matching key exchange method found'),
            hostname: 'example.com',
            port: 22,
          );
          expect(failure.kind, SshFailureKind.handshakeFailed);
          expect(failure.message, contains('agree'));
        },
      );
    },
  );

  group('SshFailure.hostKeyChanged', () {
    test('states both fingerprints and that the connection was blocked', () {
      final failure = SshFailure.hostKeyChanged(
        hostname: 'example.com',
        saved: 'SHA256:old',
        received: 'SHA256:new',
      );

      expect(failure.kind, SshFailureKind.hostKeyChanged);
      expect(failure.message, contains('example.com'));
      expect(failure.action, contains('blocked'));
      expect(failure.technicalDetail, contains('SHA256:old'));
      expect(failure.technicalDetail, contains('SHA256:new'));
    });
  });

  group('CommandResult', () {
    test('succeeds only on exit code zero', () {
      expect(
        const CommandResult(stdout: '', stderr: '', exitCode: 0).succeeded,
        isTrue,
      );
      expect(
        const CommandResult(stdout: '', stderr: '', exitCode: 1).succeeded,
        isFalse,
      );
      expect(
        const CommandResult(stdout: '', stderr: '', exitCode: null).succeeded,
        isFalse,
      );
    });

    test('combines streams without losing either', () {
      expect(
        const CommandResult(stdout: 'out', stderr: '', exitCode: 0).combined,
        'out',
      );
      expect(
        const CommandResult(stdout: '', stderr: 'err', exitCode: 1).combined,
        'err',
      );
      expect(
        const CommandResult(stdout: 'out', stderr: 'err', exitCode: 1).combined,
        'out\nerr',
      );
    });
  });
}
