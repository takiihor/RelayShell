import 'package:flutter_test/flutter_test.dart';
import 'package:relayshell/core/platform/wake_on_lan.dart';

void main() {
  group('parseMac', () {
    test('accepts colon-separated', () {
      expect(
        WakeOnLan.parseMac('00:1A:2B:3C:4D:5E'),
        [0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E],
      );
    });

    test('accepts dash-separated and lower case', () {
      expect(
        WakeOnLan.parseMac('00-1a-2b-3c-4d-5e'),
        [0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E],
      );
    });

    test('accepts bare hex', () {
      expect(
        WakeOnLan.parseMac('001a2b3c4d5e'),
        [0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E],
      );
    });

    test('rejects the wrong length', () {
      expect(
        () => WakeOnLan.parseMac('00:1A:2B:3C:4D'),
        throwsA(isA<WakeOnLanException>()),
      );
      expect(
        () => WakeOnLan.parseMac('00:1A:2B:3C:4D:5E:6F'),
        throwsA(isA<WakeOnLanException>()),
      );
    });

    test('rejects non-hex characters', () {
      expect(
        () => WakeOnLan.parseMac('ZZ:1A:2B:3C:4D:5E'),
        throwsA(isA<WakeOnLanException>()),
      );
    });

    test('rejects empty input', () {
      expect(
        () => WakeOnLan.parseMac(''),
        throwsA(isA<WakeOnLanException>()),
      );
    });
  });

  group('isValidMac', () {
    test('reports validity without throwing', () {
      expect(WakeOnLan.isValidMac('00:1A:2B:3C:4D:5E'), isTrue);
      expect(WakeOnLan.isValidMac('nope'), isFalse);
    });
  });

  group('buildPacket', () {
    test('is 102 bytes: 6 sync bytes plus the MAC 16 times', () {
      final packet = WakeOnLan.buildPacket('00:1A:2B:3C:4D:5E');
      expect(packet, hasLength(102));
    });

    test('starts with six 0xFF sync bytes', () {
      final packet = WakeOnLan.buildPacket('00:1A:2B:3C:4D:5E');
      expect(packet.sublist(0, 6), everyElement(0xFF));
    });

    test('repeats the MAC exactly 16 times', () {
      final packet = WakeOnLan.buildPacket('00:1A:2B:3C:4D:5E');
      const mac = [0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E];
      for (var repeat = 0; repeat < 16; repeat++) {
        final start = 6 + repeat * 6;
        expect(packet.sublist(start, start + 6), mac);
      }
    });

    test('rejects an invalid MAC before building', () {
      expect(
        () => WakeOnLan.buildPacket('bad'),
        throwsA(isA<WakeOnLanException>()),
      );
    });
  });
}
