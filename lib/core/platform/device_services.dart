import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while a terminal is in use (SPEC 21 Appearance).
///
/// Reference-counted because several terminals can be open at once and each
/// releases independently; the screen should stay awake until the last one is
/// gone, and must not be left awake after that.
class ScreenWakeLock {
  ScreenWakeLock();

  int _holders = 0;
  bool _enabled = false;

  bool get isHeld => _holders > 0;

  Future<void> acquire() async {
    _holders++;
    await _sync();
  }

  Future<void> release() async {
    if (_holders > 0) _holders--;
    await _sync();
  }

  Future<void> releaseAll() async {
    _holders = 0;
    await _sync();
  }

  Future<void> _sync() async {
    final shouldBeOn = _holders > 0;
    if (shouldBeOn == _enabled) return;
    try {
      await WakelockPlus.toggle(enable: shouldBeOn);
      _enabled = shouldBeOn;
    } on PlatformException {
      // Not fatal: the terminal still works, the screen just sleeps normally.
    } on MissingPluginException {
      // Same, on platforms without the plugin (e.g. tests).
    }
  }
}

/// Clears copied secrets from the clipboard after a delay
/// (SPEC 21 Security, "Clear clipboard after copied secrets where practical").
///
/// Only clears when the clipboard still holds the value that was copied, so a
/// timer started for a public key never wipes something the user copied
/// afterwards.
class ClipboardGuard {
  ClipboardGuard();

  Timer? _timer;

  Future<void> copySensitive(
    String value, {
    required Duration clearAfter,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    _timer?.cancel();
    if (clearAfter <= Duration.zero) return;

    _timer = Timer(clearAfter, () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == value) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } on PlatformException {
        // Clipboard access can be denied while backgrounded; nothing to do.
      } on MissingPluginException {
        // Same.
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

/// Opens a TCP connection just long enough to see whether anything answers.
///
/// Backs the advisory reachability indicator (SPEC 7.2). A negative result is
/// never used to block a connection attempt.
Future<bool> probeTcpPort(
  String hostname,
  int port, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(hostname, port, timeout: timeout);
    return true;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } finally {
    socket?.destroy();
  }
}
