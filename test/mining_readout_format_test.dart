import 'package:flutter_test/flutter_test.dart';
import 'package:celenium_miner/services/mining_readout.dart';

void main() {
  group('adaptive coin display', () {
    test('a diff-1 share (~0.0136656 CEN) renders as whole pradha', () {
      expect(formatCoin(0.0136656, locale: 'id'), '1.366.560 pradha');
    });

    test('en locale groups pradha with a comma', () {
      expect(formatCoin(0.0136656, locale: 'en'), '1,366,560 pradha');
    });

    test('zero still shows as pradha below one CEN', () {
      expect(formatCoin(0, locale: 'id'), '0 pradha');
    });

    test('the unit flips to CEN at one whole CEN', () {
      expect(formatCoin(1.0, locale: 'id'), '1 CEN');
    });

    test('a fractional CEN above one keeps decimal precision', () {
      expect(formatPradha(150000000, locale: 'en'), '1.5 CEN');
    });

    test('integer pradha below 1 CEN stays grouped pradha', () {
      expect(formatPradha(99999999, locale: 'id'), '99.999.999 pradha');
    });

    test('coinUnit follows the same threshold', () {
      expect(coinUnit(0), 'pradha');
      expect(coinUnit(99999999), 'pradha');
      expect(coinUnit(100000000), 'CEN');
    });

    test('formatPradhaNumber drops trailing zeros and unit', () {
      expect(formatPradhaNumber(150000000, locale: 'en'), '1.5');
      expect(formatPradhaNumber(100000000, locale: 'en'), '1');
      expect(formatPradhaNumber(0, locale: 'id'), '0');
    });
  });
}