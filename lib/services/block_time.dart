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

/// Renders [raw] as TODAY / YESTERDAY / `MON DD` (plus the year when it is not
/// the current one). Falls back to [raw] when the value cannot be parsed, so a
/// broken timestamp is shown verbatim rather than silently dropped.
String friendlyBlockTime(
  String raw, {
  required String todayLabel,
  required String yesterdayLabel,
}) {
  final dt = parseBlockTimestamp(raw);
  if (dt == null) return raw;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final elapsed = today.difference(day).inDays;

  if (elapsed == 0) return todayLabel;
  if (elapsed == 1) return yesterdayLabel;

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
  return '${months[dt.month - 1]} ${dt.day}$suffix';
}