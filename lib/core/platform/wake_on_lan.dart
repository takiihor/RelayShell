import 'dart:io';
import 'dart:typed_data';

import '../../shared/models/models.dart';

/// Raised when a Wake-on-LAN profile cannot be used.
class WakeOnLanException implements Exception {
  const WakeOnLanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sends Wake-on-LAN magic packets (SPEC 17).
///
/// Best-effort by definition. A magic packet is a broadcast UDP datagram, and
/// broadcasts do not cross routers, so this reliably works only on the same
/// network segment. The UI must say so rather than implying the machine will
/// wake from anywhere.
class WakeOnLan {
  const WakeOnLan();

  /// Accepts `AA:BB:CC:DD:EE:FF`, `aa-bb-cc-dd-ee-ff` and `aabbccddeeff`.
  static Uint8List parseMac(String mac) {
    final cleaned = mac.replaceAll(RegExp(r'[:\-.\s]'), '');
    if (cleaned.length != 12 || !RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(cleaned)) {
      throw const WakeOnLanException(
        'That does not look like a MAC address. '
        'Use a form like 00:1A:2B:3C:4D:5E.',
      );
    }
    final bytes = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      bytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static bool isValidMac(String mac) {
    try {
      parseMac(mac);
      return true;
    } on WakeOnLanException {
      return false;
    }
  }

  /// Builds the 102-byte magic packet: six 0xFF bytes then the MAC 16 times.
  static Uint8List buildPacket(String mac) {
    final address = parseMac(mac);
    final packet = Uint8List(6 + 16 * 6);
    for (var i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    for (var repeat = 0; repeat < 16; repeat++) {
      packet.setRange(6 + repeat * 6, 6 + repeat * 6 + 6, address);
    }
    return packet;
  }

  /// Sends the magic packet described by [profile].
  ///
  /// Returns normally once the datagram is handed to the OS. That is not proof
  /// the machine woke — nothing acknowledges a magic packet — so callers must
  /// phrase success as "sent", not "woken".
  Future<void> wake(WolProfile profile) async {
    final packet = buildPacket(profile.macAddress);

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final destination = InternetAddress.tryParse(profile.broadcastAddress);
      if (destination == null) {
        throw WakeOnLanException(
          '"${profile.broadcastAddress}" is not a valid broadcast address.',
        );
      }

      final sent = socket.send(packet, destination, profile.port);
      if (sent <= 0) {
        throw const WakeOnLanException(
          'The wake packet could not be sent on this network.',
        );
      }
    } on SocketException catch (error) {
      throw WakeOnLanException(
        'The wake packet could not be sent: ${error.message}',
      );
    } finally {
      socket?.close();
    }
  }
}
