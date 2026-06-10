import 'package:flutter_test/flutter_test.dart';

import 'package:no_hangs/services/whc06_protocol.dart';

void main() {
  group('Whc06Protocol.parseWeight', () {
    // Manufacturer data payload as exposed by flutter_blue_plus: the 2-byte
    // company ID is stripped into the map key, weight (big-endian, 10 g
    // units) sits at bytes 10-11.
    List<int> payloadWithWeight(int rawWeight) {
      final data = List<int>.filled(14, 0);
      data[10] = (rawWeight >> 8) & 0xff;
      data[11] = rawWeight & 0xff;
      return data;
    }

    test('decodes big-endian weight at offset 10', () {
      // 0x1234 = 4660 -> 46.60 kg
      expect(
        Whc06Protocol.parseWeight({0x0100: payloadWithWeight(0x1234)}),
        46.60,
      );
    });

    test('decodes zero weight', () {
      expect(Whc06Protocol.parseWeight({0x0100: payloadWithWeight(0)}), 0.0);
    });

    test('returns null for too-short payload', () {
      expect(Whc06Protocol.parseWeight({0x0100: List.filled(11, 0)}), isNull);
    });

    test('returns null for empty manufacturer data', () {
      expect(Whc06Protocol.parseWeight({}), isNull);
    });

    test('skips invalid entry and decodes a valid one', () {
      expect(
        Whc06Protocol.parseWeight({
          0x004c: [1, 2],
          0x0100: payloadWithWeight(2550), // 25.50 kg
        }),
        25.50,
      );
    });
  });
}
