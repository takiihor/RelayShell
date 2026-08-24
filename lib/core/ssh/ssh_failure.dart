import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// What went wrong, at a level the UI can offer a next step for (SPEC 31).
enum SshFailureKind {
  /// Hostname did not resolve.
  hostNotFound,

  /// TCP connection refused.
  connectionRefused,

  /// Connection attempt timed out.
  timeout,

  /// Network unreachable, or the device has no route.
  networkUnreachable,

  /// The SSH transport handshake failed (protocol/algorithm mismatch).
  handshakeFailed,

  /// The server's host key does not match the one previously trusted.
  hostKeyChanged,

  /// The user declined to trust an unknown host key.
  hostKeyRejected,

  /// Authentication was refused by the server.
  authenticationFailed,

  /// The configured credential is missing or unreadable.
  credentialUnavailable,

  /// The private key needs a passphrase, or the passphrase was wrong.
  passphraseRequired,

  /// Biometric/device authentication was required and not satisfied.
  authorizationRequired,

  /// The connection dropped after it had been established.
  connectionLost,

  /// The remote side closed the session.
  closedByRemote,

  /// A requested feature is unavailable on this remote machine.
  featureUnavailable,

  /// Anything not recognised.
  unknown,
}

/// A connection or session failure with a user-facing explanation.
///
/// [message] and [action] are what the user reads; [technicalDetail] is kept
/// behind a "technical details" expander (SPEC 31) and is scrubbed of secrets
/// before it is ever logged.
@immutable
class SshFailure implements Exception {
  const SshFailure({
    required this.kind,
    required this.message,
    this.action,
    this.technicalDetail,
  });

  final SshFailureKind kind;

  /// Plain-language description of what happened.
  final String message;

  /// What the user can do about it, if anything.
  final String? action;

  /// Raw exception text, for the details expander only.
  final String? technicalDetail;

  /// True when retrying the same connection could plausibly succeed.
  bool get isRetryable => const {
        SshFailureKind.timeout,
        SshFailureKind.networkUnreachable,
        SshFailureKind.connectionLost,
        SshFailureKind.connectionRefused,
      }.contains(kind);

  /// True when the user must change configuration before retrying.
  bool get needsUserFix => const {
        SshFailureKind.authenticationFailed,
        SshFailureKind.credentialUnavailable,
        SshFailureKind.passphraseRequired,
        SshFailureKind.hostKeyChanged,
        SshFailureKind.hostNotFound,
      }.contains(kind);

  @override
  String toString() => 'SshFailure(${kind.name}): $message';

  /// Maps a raw exception onto an actionable failure.
  ///
  /// Everything reaching the UI goes through here, so a socket errno never
  /// becomes the primary message the user sees.
  static SshFailure from(
    Object error, {
    required String hostname,
    required int port,
  }) {
    if (error is SshFailure) return error;

    if (error is SocketException) {
      final osError = error.osError;
      final detail = '${error.message}${osError == null ? '' : ' (${osError.message})'}';

      if (error.osError?.errorCode == 111 ||
          error.message.toLowerCase().contains('refused')) {
        return SshFailure(
          kind: SshFailureKind.connectionRefused,
          message: 'SSH connection refused on port $port.',
          action: 'Check that the SSH server is running and the port is correct.',
          technicalDetail: detail,
        );
      }
      if (error.message.toLowerCase().contains('failed host lookup') ||
          error.osError?.errorCode == -2 ||
          error.osError?.errorCode == 7) {
        return SshFailure(
          kind: SshFailureKind.hostNotFound,
          message: 'Cannot find this computer.',
          action: 'Check the hostname or your network connection.',
          technicalDetail: detail,
        );
      }
      if (error.message.toLowerCase().contains('unreachable')) {
        return SshFailure(
          kind: SshFailureKind.networkUnreachable,
          message: 'This network cannot reach $hostname.',
          action: 'Check your connection, or whether a VPN is needed.',
          technicalDetail: detail,
        );
      }
      return SshFailure(
        kind: SshFailureKind.unknown,
        message: 'Could not connect to $hostname.',
        action: 'Check the address, port and network connection.',
        technicalDetail: detail,
      );
    }

    if (error is TimeoutException) {
      return SshFailure(
        kind: SshFailureKind.timeout,
        message: 'Connecting to $hostname timed out.',
        action: 'The computer may be asleep or behind a firewall.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHAuthFailError || error is SSHAuthAbortError) {
      return SshFailure(
        kind: SshFailureKind.authenticationFailed,
        message: 'Authentication failed.',
        action: 'Check the username and credential for this computer.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHKeyDecryptError) {
      return SshFailure(
        kind: SshFailureKind.passphraseRequired,
        message: 'The private key could not be unlocked.',
        action: 'Check the key passphrase.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHHostkeyError) {
      return SshFailure(
        kind: SshFailureKind.hostKeyRejected,
        message: 'The host key for $hostname was not accepted.',
        action: 'Verify the fingerprint before connecting again.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHHandshakeError) {
      // dartssh2 raises this class for every handshake-phase failure, not only
      // an algorithm mismatch — including its own internal timeout. Reporting
      // a timeout as "unsupported algorithms" would send the user chasing the
      // wrong cause, so the message text is checked to tell them apart.
      final isTimeout = error.message.toLowerCase().contains('timed out');
      return SshFailure(
        kind: isTimeout ? SshFailureKind.timeout : SshFailureKind.handshakeFailed,
        message: isTimeout
            ? 'Connecting to $hostname timed out during the handshake.'
            : 'Could not agree on an SSH connection method.',
        action: isTimeout
            ? 'The computer may be slow to respond, or the connection may '
                'have dropped.'
            : 'The server may use algorithms this app does not support.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHSocketError) {
      return SshFailure(
        kind: SshFailureKind.connectionLost,
        message: 'The connection to $hostname was lost.',
        action: 'Reconnect to continue.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHDisconnectError) {
      return SshFailure(
        kind: SshFailureKind.closedByRemote,
        message: 'The computer closed the connection.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHChannelOpenError || error is SSHChannelRequestError) {
      return SshFailure(
        kind: SshFailureKind.featureUnavailable,
        message: 'The computer refused to open this session.',
        action: 'The SSH server may restrict shells, PTYs or forwarding.',
        technicalDetail: error.toString(),
      );
    }

    if (error is SSHStateError || error is SSHInternalError) {
      return SshFailure(
        kind: SshFailureKind.unknown,
        message: 'The SSH connection ended unexpectedly.',
        action: 'Reconnect to continue.',
        technicalDetail: error.toString(),
      );
    }

    return SshFailure(
      kind: SshFailureKind.unknown,
      message: 'Could not complete the SSH operation.',
      technicalDetail: error.toString(),
    );
  }

  /// The blocking warning shown when a fingerprint no longer matches
  /// (SPEC 9.2, 31).
  static SshFailure hostKeyChanged({
    required String hostname,
    required String saved,
    required String received,
  }) =>
      SshFailure(
        kind: SshFailureKind.hostKeyChanged,
        message: 'The SSH identity of $hostname has changed.',
        action: 'Connection has been blocked. Verify the computer before '
            'trusting the new key.',
        technicalDetail: 'Saved:\n$saved\n\nReceived:\n$received',
      );
}
