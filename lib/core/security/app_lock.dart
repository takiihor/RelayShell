import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/models/models.dart';
import 'biometric_gate.dart';

/// Whether the app is currently showing content or hiding it behind the lock.
enum AppLockState {
  /// Locking is switched off in settings.
  disabled,

  /// Unlocked and usable.
  unlocked,

  /// Locked; the UI must show the lock screen and hide content.
  locked,

  /// An unlock prompt is on screen.
  authenticating,
}

/// Optional app-level lock (SPEC 19).
///
/// The lock is about shoulder-surfing and a borrowed phone, not about
/// cryptography: it hides content and gates credential use behind a device
/// prompt. It deliberately does *not* encrypt anything itself, because the real
/// protection for secrets is platform secure storage.
class AppLock extends ChangeNotifier {
  AppLock({required this.biometrics});

  final BiometricGate biometrics;

  AppLockState _state = AppLockState.disabled;
  AppLockState get state => _state;

  AppPreferences _preferences = const AppPreferences();

  DateTime? _backgroundedAt;

  bool get isLocked =>
      _state == AppLockState.locked || _state == AppLockState.authenticating;

  /// True while content must be hidden from the app switcher and the screen.
  bool get shouldObscureContent => isLocked || _state == AppLockState.locked;

  /// Applies settings. Turning the lock on locks immediately so the user sees
  /// that it works; turning it off unlocks.
  void applyPreferences(AppPreferences preferences) {
    final wasEnabled = _preferences.appLockEnabled;
    _preferences = preferences;

    if (!preferences.appLockEnabled) {
      _setState(AppLockState.disabled);
      return;
    }
    if (!wasEnabled) {
      _setState(AppLockState.locked);
    }
  }

  /// Called when the app leaves the foreground.
  void onBackgrounded() {
    if (!_preferences.appLockEnabled) return;
    _backgroundedAt = DateTime.now();
  }

  /// Called when the app returns to the foreground.
  ///
  /// The grace period is measured from when the app was backgrounded, so
  /// switching away to copy a password and straight back does not force a
  /// re-unlock, while leaving the phone on a table does.
  void onForegrounded() {
    if (!_preferences.appLockEnabled) return;
    if (_state == AppLockState.locked) return;

    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;

    final elapsed = DateTime.now().difference(since);
    if (elapsed >= _preferences.appLockTimeout.duration) {
      _setState(AppLockState.locked);
    }
  }

  /// Locks right now, at the user's request.
  void lockNow() {
    if (!_preferences.appLockEnabled) return;
    _setState(AppLockState.locked);
  }

  /// Prompts for device authentication and unlocks on success.
  ///
  /// Fails closed: any outcome other than success leaves the app locked.
  Future<bool> unlock() async {
    if (_state == AppLockState.disabled) return true;
    if (_state == AppLockState.authenticating) return false;

    _setState(AppLockState.authenticating);
    final result = await biometrics.authenticate('Unlock RelayShell');

    switch (result) {
      case BiometricResult.success:
        _setState(AppLockState.unlocked);
        return true;
      case BiometricResult.unavailable:
        _setState(AppLockState.locked);
        return false;
      case BiometricResult.failed:
      case BiometricResult.lockedOut:
        _setState(AppLockState.locked);
        return false;
    }
  }

  void _setState(AppLockState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }
}
