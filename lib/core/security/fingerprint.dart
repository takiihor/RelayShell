import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Host-key fingerprint handling (SPEC 9.2).
///
/// Comparison is constant-time and normalisation is explicit, because the whole
/// value of host verification rests on "these two strings differ" being decided
/// correctly.
class Fingerprint {
  const Fingerprint._();

  static const String sha256Prefix = 'SHA256:';

  /// Normalises an OpenSSH-style fingerprint for storage and comparison.
  ///
  /// Accepts `SHA256:abc…`, bare `abc…`, and values with trailing base64
  /// padding, and always returns `SHA256:abc…` without padding.
  static String normalize(String raw) {
    var value = raw.trim();
    if (value.toUpperCase().startsWith(sha256Prefix)) {
      value = value.substring(sha256Prefix.length);
    }
    value = value.replaceAll('=', '').trim();
    return '$sha256Prefix$value';
  }

  /// Decodes the fingerprint bytes dartssh2 hands to its verify callback, which
  /// are the UTF-8 text of `SHA256:<base64>`.
  static String fromCallbackBytes(Uint8List bytes) =>
      normalize(utf8.decode(bytes, allowMalformed: true));

  /// Computes the OpenSSH SHA-256 fingerprint of a wire-format public key.
  ///
  /// Used for public keys the user imports, so the keys screen can show the
  /// same fingerprint `ssh-keygen -lf` would.
  static String ofPublicKeyBytes(Uint8List keyBytes) {
    final digest = sha256.convert(keyBytes);
    final encoded = base64.encode(digest.bytes).replaceAll('=', '');
    return '$sha256Prefix$encoded';
  }

  /// Parses an OpenSSH `authorized_keys` line and returns its fingerprint.
  ///
  /// Returns null when the line is not a recognisable public key rather than
  /// throwing, because this runs against user-pasted text.
  static String? ofAuthorizedKeyLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    try {
      final bytes = base64.decode(parts[1]);
      return ofPublicKeyBytes(Uint8List.fromList(bytes));
    } on FormatException {
      return null;
    }
  }

  /// Compares two fingerprints without leaking timing information.
  static bool matches(String a, String b) {
    final left = normalize(a);
    final right = normalize(b);
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }

  /// Breaks a fingerprint into groups for readable display.
  ///
  /// Users compare these by eye against `ssh-keygen` output, so the rendering
  /// needs to be scannable rather than one long run of base64.
  static String forDisplay(String fingerprint, {int groupSize = 8}) {
    final normalized = normalize(fingerprint);
    final body = normalized.substring(sha256Prefix.length);
    final buffer = StringBuffer(sha256Prefix);
    for (var i = 0; i < body.length; i += groupSize) {
      if (i > 0) buffer.write(' ');
      buffer.write(
        body.substring(i, i + groupSize > body.length ? body.length : i + groupSize),
      );
    }
    return buffer.toString();
  }
}
