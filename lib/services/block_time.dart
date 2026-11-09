/// Timestamp helpers for bridge block data.
///
/// The bridge sends a mined block's `timestamp` as Unix **seconds** (for
/// example `"1794062798"`). Older builds and the preview fixture used ISO-8601
/// strings. [parseBlockTimestamp] accepts both and returns null for anything
/// else, so the caller can fall back to the raw value instead of inventing a
/// date that was never there.
library;

/// Parses a block timestamp into a local [DateTime].
///
/// Accepts Unix epoch seconds (the bridge's current format), epoch
/// milliseconds, or an ISO-8601 string. Returns null when [raw] is empty or
/// matches neither shape.
DateTime? parseBlockTimestamp(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;

  // The bridge reports seconds (10 digits). Tolerate milliseconds too, and
  // decide by magnitude rather than guessing at the caller's intent.
  final epoch = int.tryParse(t);
  if (epoch != null) {
    final ms = epoch >= 1000000000000 ? epoch : epoch * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  final parsed = DateTime.tryParse(t);
  return parsed?.toLocal();
}

/// Renders [raw] as `TODAY HH:mm` / `YESTERDAY HH:mm` / `MON DD HH:mm` (plus
/// the year when it is not the current one), so blocks mined minutes and days
/// apart are no longer shown under the same bare date. Falls back to [raw]
/// when the value cannot be parsed or predates the network — a broken
/// timestamp is surfaced verbatim rather than invented as a 1970 date.
String friendlyBlockTime(
  String raw, {
  required String todayLabel,
  required String yesterdayLabel,
}) {
  final dt = parseBlockTimestamp(raw);
  // A block cannot predate the network. An empty or zeroed timestamp parses to
  // the 1970 epoch; letting it render as "JAN 1 1970" would read as a real
  // date, so show the raw value instead.
  if (dt == null || dt.year < 2000) return raw;

  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final elapsed = today.difference(day).inDays;

  if (elapsed == 0) return '$todayLabel $time';
  if (elapsed == 1) return '$yesterdayLabel $time';

  const months = [
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
  final suffix = dt.year == now.year ? '' : ' ${dt.year}';
  return '${months[dt.month - 1]} ${dt.day}$suffix $time';
}
