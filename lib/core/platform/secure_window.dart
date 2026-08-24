import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hides app content from screenshots and the OS app switcher (SPEC 19).
///
/// Android exposes this as `FLAG_SECURE` on the window; iOS has no equivalent
/// public API, so on iOS the lock screen's opaque overlay is the protection and
/// this class is a no-op. Saying that plainly is better than implying a
/// guarantee the platform does not offer.
class SecureWindow {
  const SecureWindow();

  static const MethodChannel _channel = MethodChannel('relayshell/window');

  /// Whether the current platform can actually enforce this.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Turns screenshot and app-switcher protection on or off.
  ///
  /// Failures are swallowed: not being able to set the flag must never stop the
  /// app from unlocking, and the lock overlay still hides content on screen.
  Future<void> setSecure({required bool secure}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on PlatformException {
      // Best effort.
    } on MissingPluginException {
      // Same, e.g. under tests.
    }
  }
}
