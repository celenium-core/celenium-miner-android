import 'package:flutter_test/flutter_test.dart';
import 'package:celenium_miner/services/mining_readout.dart';

void main() {
  group('formatCenAsPradha', () {
    test('1 diff-1 share (~0.0136656 CEN) = 1.366.560 pradha', () {
      expect(formatCenAsPradha(0.0136656, locale: 'id'), '1.366.560');
    });

    test('zero stays zero', () {
      expect(formatCenAsPradha(0, locale: 'id'), '0');
    });

    test('1 CEN = 100.000.000 pradha', () {
      expect(formatCenAsPradha(1.0, locale: 'id'), '100.000.000');
    });

    test('en locale groups with a comma', () {
      expect(formatCenAsPradha(0.0136656, locale: 'en'), '1,366,560');
    });
  });
}