import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of a device-authentication prompt.
enum BiometricResult {
  /// The user proved presence.
  success,

  /// The user dismissed the prompt or authentication failed.
  failed,

  /// The device has no biometric or device-credential capability enrolled.
  unavailable,

  /// Authentication is locked out and cannot be retried right now.
  lockedOut,
}

/// Wraps platform biometric / device-credential authentication (SPEC 18.3, 19).
///
/// Two rules shape this class:
///
/// * Biometrics are an *additional* access control, never a replacement for SSH
///   authentication. Failing open would silently downgrade security, so any
///   outcome other than [BiometricResult.success] means callers must refuse.
/// * A device with nothing enrolled reports [BiometricResult.unavailable], so
///   the settings UI can explain why a toggle cannot be turned on rather than
///   leaving the user stuck against a prompt that will never succeed.
class BiometricGate {
  BiometricGate({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Whether any form of device authentication can be used.
  Future<bool> get isAvailable async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  /// Whether biometric hardware specifically is present and enrolled.
  Future<bool> get hasBiometrics async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  /// Biometric types the device offers, for describing the setting accurately.
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    } on LocalAuthException {
      return const [];
    }
  }

  /// Prompts for device authentication.
  ///
  /// [reason] is shown by the platform dialog and should name the specific
  /// action, e.g. "Unlock Remote Dev Console" or "Use the key for Home PC".
  ///
  /// Device credential (PIN/pattern/passcode) is allowed as a fallback so that
  /// a user whose fingerprint sensor is failing is not locked out of their own
  /// computers.
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          BiometricResult.unavailable,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          BiometricResult.lockedOut,
        _ => BiometricResult.failed,
      };
    } on PlatformException {
      return BiometricResult.failed;
    }
  }

  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } on PlatformException {
      // Nothing was in progress; not worth surfacing.
    } on LocalAuthException {
      // Same.
    }
  }
}
