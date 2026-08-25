import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/models.dart';
import '../database/trusted_keys_repository.dart';
import '../security/fingerprint.dart';
import 'ssh_failure.dart';

/// What the user is being asked to confirm when a host is seen for the first
/// time (SPEC 9.2).
@immutable
class HostKeyPromptRequest {
  const HostKeyPromptRequest({
    required this.hostDisplayName,
    required this.hostname,
    required this.port,
    required this.keyType,
    required this.fingerprintSha256,
  });

  final String hostDisplayName;
  final String hostname;
  final int port;
  final String keyType;
  final String fingerprintSha256;

  String get fingerprintForDisplay => Fingerprint.forDisplay(fingerprintSha256);
}

/// Asks the user whether to trust an unknown host key.
///
/// Returning `true` trusts and stores the key; `false` aborts the connection.
typedef HostKeyPrompt = Future<bool> Function(HostKeyPromptRequest request);

/// Decides whether to accept a server's host key (SPEC 9.2).
///
/// The rules are deliberately absolute:
///
/// * A key that matches the stored fingerprint connects.
/// * An unknown key is shown to the user and stored only on explicit consent.
/// * A key that *differs* from the stored one blocks the connection. There is
///   no setting anywhere that turns this off (SPEC 44.8); clearing the trust
///   entry is an explicit, per-host action in Settings.
class HostKeyVerifier {
  HostKeyVerifier({required this.trustedKeys, required this.prompt, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final TrustedKeysRepository trustedKeys;
  final HostKeyPrompt prompt;
  final Uuid _uuid;

  /// Set when verification failed, so the connection can report precisely why
  /// rather than surfacing a generic handshake error.
  SshFailure? lastFailure;

  /// Builds the callback dartssh2 invokes during key exchange.
  ///
  /// [hostId] is stored alongside the trust entry for display only; matching is
  /// always by endpoint and key type (SPEC 8.4).
  Future<bool> Function(String, Uint8List) callbackFor(
    Host host, {
    String? hostDisplayName,
  }) {
    return (String keyType, Uint8List fingerprintBytes) async {
      lastFailure = null;
      final received = Fingerprint.fromCallbackBytes(fingerprintBytes);

      final stored = await trustedKeys.find(
        hostname: host.hostname,
        port: host.port,
        keyType: keyType,
      );

      if (stored != null) {
        if (Fingerprint.matches(stored.fingerprintSha256, received)) {
          return true;
        }

        lastFailure = SshFailure.hostKeyChanged(
          hostname: host.hostname,
          saved: Fingerprint.forDisplay(stored.fingerprintSha256),
          received: Fingerprint.forDisplay(received),
        );
        return false;
      }

      final accepted = await prompt(
        HostKeyPromptRequest(
          hostDisplayName: hostDisplayName ?? host.name,
          hostname: host.hostname,
          port: host.port,
          keyType: keyType,
          fingerprintSha256: received,
        ),
      );

      if (!accepted) {
        lastFailure = SshFailure(
          kind: SshFailureKind.hostKeyRejected,
          message: 'The host key for ${host.hostname} was not trusted.',
          action: 'The connection was cancelled.',
        );
        return false;
      }

      // Persisting the decision must not be able to abort the connection: this
      // runs inside dartssh2's key-exchange callback, so a throw here surfaces
      // as an opaque handshake error. If the write fails (for instance the host
      // row was deleted mid-connect), the safe degradation is to honour the
      // user's consent now and ask again next time.
      try {
        await trustedKeys.trust(
          TrustedHostKey(
            id: _uuid.v4(),
            // Endpoint identity is the authority. Keeping this association
            // nullable lets Test Connection remember consent before a new host
            // form has been saved and therefore before its foreign-key row
            // exists.
            hostId: null,
            hostname: host.hostname,
            port: host.port,
            keyType: keyType,
            fingerprintSha256: received,
            trustedAt: DateTime.now(),
          ),
        );
      } on Exception {
        // Trust was granted for this session but not remembered.
      }
      return true;
    };
  }
}
