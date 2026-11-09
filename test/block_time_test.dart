import 'package:flutter_test/flutter_test.dart';
import 'package:celenium_miner/services/block_time.dart';

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// The expected `MON DD [YYYY] HH:mm` for a raw timestamp, built from the same
/// parsed instant the function formats, so the assertion is timezone-safe.
String _expectedDate(String raw) {
  final dt = parseBlockTimestamp(raw)!;
  final now = DateTime.now();
  final suffix = dt.year == now.year ? '' : ' ${dt.year}';
  return '${_months[dt.month - 1]} ${dt.day}$suffix ${_hhmm(dt)}';
}

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
    test(
      'renders an epoch as a date and time instead of leaking it verbatim',
      () {
        expect(
          friendlyBlockTime(
            '1609459200',
            todayLabel: 'HARI INI',
            yesterdayLabel: 'KEMARIN',
          ),
          _expectedDate('1609459200'),
        );
      },
    );

    test('uses TODAY plus the time for the current day', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final dt = parseBlockTimestamp('$nowSeconds')!;
      expect(
        friendlyBlockTime(
          '$nowSeconds',
          todayLabel: 'HARI INI',
          yesterdayLabel: 'KEMARIN',
        ),
        'HARI INI ${_hhmm(dt)}',
      );
    });

    test('uses YESTERDAY plus the time for one day ago', () {
      final now = DateTime.now();
      final yesterdaySeconds =
          now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
      final dt = parseBlockTimestamp('$yesterdaySeconds')!;
      expect(
        friendlyBlockTime(
          '$yesterdaySeconds',
          todayLabel: 'HARI INI',
          yesterdayLabel: 'KEMARIN',
        ),
        'KEMARIN ${_hhmm(dt)}',
      );
    });

    test(
      'surfaces a pre-network timestamp as a raw value, not a 1970 date',
      () {
        expect(
          friendlyBlockTime(
            '0',
            todayLabel: 'HARI INI',
            yesterdayLabel: 'KEMARIN',
          ),
          '0',
        );
      },
    );
  });
}
