import 'package:flutter_test/flutter_test.dart';
import 'package:celenium_miner/services/block_time.dart';

/// Guards the Unix-seconds parsing bug: the bridge's `timestamp` field is a
/// plain epoch (e.g. "1794062798"), which `DateTime.tryParse` rejects, so every
/// reward-history row used to show the raw number instead of a date.
void main() {
  group('parseBlockTimestamp', () {
    test('parses Unix seconds as the right UTC instant', () {
      // 2021-01-01T00:00:00Z == 1609459200 seconds.
      final dt = parseBlockTimestamp('1609459200');
      expect(dt, isNotNull);
      expect(dt!.toUtc(), DateTime.utc(2021, 1, 1));
    });

    test('parses Unix milliseconds too', () {
      final dt = parseBlockTimestamp('1609459200000');
      expect(dt!.toUtc(), DateTime.utc(2021, 1, 1));
    });

    test('keeps ISO-8601 input working for old builds', () {
      final dt = parseBlockTimestamp('2021-01-01T00:00:00Z');
      expect(dt!.toUtc(), DateTime.utc(2021, 1, 1));
    });

    test('returns null for empty or non-date input', () {
      expect(parseBlockTimestamp(''), isNull);
      expect(parseBlockTimestamp('not-a-date'), isNull);
    });
  });

  group('friendlyBlockTime', () {
    test('renders an epoch as a date instead of leaking it verbatim', () {
      expect(
        friendlyBlockTime('1609459200',
            todayLabel: 'HARI INI', yesterdayLabel: 'KEMARIN'),
        'JAN 1 2021',
      );
    });

    test('uses TODAY for the current day', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(
        friendlyBlockTime('$nowSeconds',
            todayLabel: 'HARI INI', yesterdayLabel: 'KEMARIN'),
        'HARI INI',
      );
    });

    test('uses YESTERDAY for one day ago', () {
      final yesterdaySeconds = DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch ~/
          1000;
      expect(
        friendlyBlockTime('$yesterdaySeconds',
            todayLabel: 'HARI INI', yesterdayLabel: 'KEMARIN'),
        'KEMARIN',
      );
    });
  });
}