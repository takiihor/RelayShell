import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/models.dart';
import '../database/credentials_repository.dart';
import '../security/biometric_gate.dart';
import '../security/redaction.dart';
import '../security/ssh_key_material.dart';
import '../storage/secret_store.dart';
import 'ssh_failure.dart';

/// What the app needs the user to type before a connection can proceed.
enum SecretPromptKind { password, passphrase }

@immutable
class SecretPromptRequest {
  const SecretPromptRequest({
    required this.kind,
    required this.hostName,
    this.credentialName,
    this.retry = false,
  });

  final SecretPromptKind kind;
  final String hostName;
  final String? credentialName;

  /// True when a previous attempt with a stored value failed.
  final bool retry;
}

/// Asks the user for a password or passphrase. Returns null if they cancel.
typedef SecretPrompt = Future<Sensitive<String>?> Function(
  SecretPromptRequest request,
);

/// Answers a server's keyboard-interactive challenge. Returns null to cancel.
typedef KeyboardInteractivePrompt = Future<List<String>?> Function(
  SSHUserInfoRequest request,
);

/// The authentication material for one connection attempt.
///
/// Held only for the duration of the attempt. Nothing here is logged, and
/// [Sensitive] wrappers make an accidental interpolation produce a placeholder
/// rather than the secret (SPEC 35, 44.2).
class ResolvedCredential {
  ResolvedCredential({this.identities, this.password, this.onUserInfoRequest});

  final List<SSHKeyPair>? identities;
  final Sensitive<String>? password;
  final KeyboardInteractivePrompt? onUserInfoRequest;
}

/// Turns a [Host]'s configured authentication method into usable credentials
/// (SPEC 8.2, 18).
///
/// Secrets are read from [SecretStore] at the moment of use and never cached on
/// this object. When a credential is marked biometric-protected, the device
/// prompt runs *before* the secret is read, so a failed prompt means the secret
/// is never fetched at all.
class CredentialResolver {
  CredentialResolver({
    required this.credentials,
    required this.secrets,
    required this.biometrics,
    required this.promptForSecret,
    required this.promptForKeyboardInteractive,
    this.keyMaterial = const SshKeyMaterial(),
  });

  final CredentialsRepository credentials;
  final SecretStore secrets;
  final BiometricGate biometrics;
  final SecretPrompt promptForSecret;
  final KeyboardInteractivePrompt promptForKeyboardInteractive;
  final SshKeyMaterial keyMaterial;

  /// Resolves credentials for [host], prompting the user where necessary.
  ///
  /// Throws [SshFailure] when the credential is missing, cannot be unlocked, or
  /// the user cancels a prompt.
  Future<ResolvedCredential> resolve(Host host) async {
    switch (host.authMethod) {
      case AuthMethod.privateKey:
        return _resolvePrivateKey(host);
      case AuthMethod.password:
        return _resolvePassword(host);
      case AuthMethod.keyboardInteractive:
        return ResolvedCredential(
          onUserInfoRequest: promptForKeyboardInteractive,
        );
      case AuthMethod.agent:
        throw const SshFailure(
          kind: SshFailureKind.credentialUnavailable,
          message: 'SSH agent authentication is not available on this device.',
          action: 'Choose a private key or password for this computer.',
        );
    }
  }

  Future<ResolvedCredential> _resolvePrivateKey(Host host) async {
    final credential = await _requireCredential(host);
    await _requireAuthorization(credential, host);

    final pem = await secrets.read(SecretKind.privateKey, credential.id);
    if (pem == null) {
      throw SshFailure(
        kind: SshFailureKind.credentialUnavailable,
        message: 'The private key "${credential.name}" is missing.',
        action: 'Re-import the key, or choose a different credential.',
      );
    }

    var passphrase = credential.hasPassphrase
        ? await secrets.read(SecretKind.passphrase, credential.id)
        : null;

    // A stored passphrase can go stale if the key was replaced elsewhere; ask
    // once rather than failing the whole connection.
    if (credential.hasPassphrase &&
        !keyMaterial.canUnlock(pem, passphrase: passphrase)) {
      final entered = await promptForSecret(
        SecretPromptRequest(
          kind: SecretPromptKind.passphrase,
          hostName: host.name,
          credentialName: credential.name,
          retry: passphrase != null,
        ),
      );
      if (entered == null) {
        throw const SshFailure(
          kind: SshFailureKind.passphraseRequired,
          message: 'A passphrase is needed to use this key.',
          action: 'Enter the key passphrase to connect.',
        );
      }
      passphrase = entered.expose();
    }

    try {
      return ResolvedCredential(
        identities: keyMaterial.identities(pem, passphrase: passphrase),
      );
    } on KeyMaterialException catch (error) {
      throw SshFailure(
        kind: error.needsPassphrase
            ? SshFailureKind.passphraseRequired
            : SshFailureKind.credentialUnavailable,
        message: error.message,
        action: 'Check the key and its passphrase.',
      );
    }
  }

  Future<ResolvedCredential> _resolvePassword(Host host) async {
    final credentialId = host.credentialId;

    // A host may legitimately have no saved password, in which case we ask
    // every time rather than storing one behind the user's back.
    if (credentialId == null) {
      final entered = await promptForSecret(
        SecretPromptRequest(
          kind: SecretPromptKind.password,
          hostName: host.name,
        ),
      );
      if (entered == null) {
        throw const SshFailure(
          kind: SshFailureKind.credentialUnavailable,
          message: 'A password is needed to connect.',
        );
      }
      return ResolvedCredential(password: entered);
    }

    final credential = await _requireCredential(host);
    await _requireAuthorization(credential, host);

    final stored = await secrets.read(SecretKind.password, credential.id);
    if (stored != null) {
      return ResolvedCredential(password: Sensitive(stored));
    }

    final entered = await promptForSecret(
      SecretPromptRequest(
        kind: SecretPromptKind.password,
        hostName: host.name,
        credentialName: credential.name,
      ),
    );
    if (entered == null) {
      throw const SshFailure(
        kind: SshFailureKind.credentialUnavailable,
        message: 'A password is needed to connect.',
      );
    }
    return ResolvedCredential(password: entered);
  }

  Future<Credential> _requireCredential(Host host) async {
    final id = host.credentialId;
    if (id == null) {
      throw SshFailure(
        kind: SshFailureKind.credentialUnavailable,
        message: 'No credential is set for ${host.name}.',
        action: 'Choose a key or password for this computer.',
      );
    }
    final credential = await credentials.byId(id);
    if (credential == null) {
      throw SshFailure(
        kind: SshFailureKind.credentialUnavailable,
        message: 'The credential for ${host.name} no longer exists.',
        action: 'Choose a different credential for this computer.',
      );
    }
    return credential;
  }

  /// Runs the device prompt for biometric-protected credentials (SPEC 18.3).
  ///
  /// Fails closed: anything other than success stops the connection before the
  /// secret is read.
  Future<void> _requireAuthorization(Credential credential, Host host) async {
    if (!credential.requireBiometric) return;

    final result = await biometrics.authenticate(
      'Use "${credential.name}" to connect to ${host.name}',
    );
    switch (result) {
      case BiometricResult.success:
        return;
      case BiometricResult.unavailable:
        throw SshFailure(
          kind: SshFailureKind.authorizationRequired,
          message:
              '"${credential.name}" requires device authentication, '
              'which is not set up on this device.',
          action:
              'Set up a screen lock, or turn off protection for this '
              'credential.',
        );
      case BiometricResult.lockedOut:
        throw const SshFailure(
          kind: SshFailureKind.authorizationRequired,
          message: 'Device authentication is temporarily locked.',
          action: 'Unlock your device, then try again.',
        );
      case BiometricResult.failed:
        throw const SshFailure(
          kind: SshFailureKind.authorizationRequired,
          message: 'Device authentication was not completed.',
          action: 'Authenticate to use this credential.',
        );
    }
  }
}
