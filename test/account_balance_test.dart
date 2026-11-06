import 'package:celenium_miner/models/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bridge answers `{"address": ..., "balancePradha": <u64>}` and the model
/// is the only place CEN is derived from pradha, so formatting and parsing are
/// the contract: a wrong radix here (10^8) misreports every balance on screen.
void main() {
  group('formattedCen', () {
    test('zero pradha renders as 0', () {
      const b = AccountBalance(address: 'a', pradha: 0);
      expect(b.formattedCen, '0');
    });

    test('one pradha renders as the smallest visible unit', () {
      const b = AccountBalance(address: 'a', pradha: 1);
      expect(b.formattedCen, '0.00000001');
    });

    test('exactly 1 CEN renders without a fraction', () {
      const b = AccountBalance(address: 'a', pradha: 100000000);
      expect(b.formattedCen, '1');
    });

    test('trailing zeros are trimmed', () {
      const b = AccountBalance(address: 'a', pradha: 250000000);
      expect(b.formattedCen, '2.5');
    });

    test('full precision survives beyond 2^53 pradha', () {
      // 2^53 + 1 cannot be represented exactly as a double; the integer path
      // must still format it losslessly.
      const pradha = 9007199254740993;
      const b = AccountBalance(address: 'a', pradha: pradha);
      expect(b.formattedCen, '90071992.54740993');
    });
  });

  group('tryParse', () {
    test('parses a well-formed balance', () {
      final result = AccountBalance.tryParse(
        {'address': 'cen69sim:qq', 'balancePradha': 123456789},
      );
      expect(result, isNotNull);
      expect(result!.pradha, 123456789);
      expect(result.address, 'cen69sim:qq');
    });

    test('zero is a valid balance, not a parse failure', () {
      final result = AccountBalance.tryParse(
        {'address': 'cen69sim:qq', 'balancePradha': 0},
      );
      expect(result, isNotNull);
      expect(result!.pradha, 0);
    });

    test('an error body is not mistaken for a balance', () {
      expect(
        AccountBalance.tryParse({'error': 'node api not ready'}),
        isNull,
      );
    });

    test('a missing balancePradha field yields null', () {
      expect(AccountBalance.tryParse({'address': 'cen69sim:qq'}), isNull);
    });

    test('non-map input yields null', () {
      expect(AccountBalance.tryParse('not json'), isNull);
      expect(AccountBalance.tryParse(null), isNull);
      expect(AccountBalance.tryParse([1, 2, 3]), isNull);
    });
  });
}