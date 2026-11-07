import 'package:flutter/material.dart';

import 'palette.dart';

/// CEN type scale.
///
/// Three families, each with a job:
///
/// - `display` (Manrope): the wordmark and page titles. A clean geometric
///   sans-serif shared with the body, so screens read as one system. Used only
///   where the product name or a screen name appears.
/// - `body` (Manrope): every label, row, and sentence.
/// - `mono` (JetBrains Mono): anything that is a reading off a machine.
///   Hashrates, addresses, hashes, timestamps. Monospace keeps digits from
///   shifting as values change, so a live number does not jitter.
class TypeScale {
  const TypeScale._();

  static const String displayFamily = 'Manrope';
  static const String bodyFamily = 'Manrope';
  static const String monoFamily = 'JetBrains Mono';
  static const String pixelFamily = 'Press Start 2P';

  /// Wide tracking for the display face, so CELENIUM reads as engraved.
  static const double displayTracking = 4.0;

  static TextStyle wordmark(BuildContext context) => TextStyle(
    fontFamily: displayFamily,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: displayTracking,
    color: Palette.cream,
    height: 1.1,
  );

  static TextStyle screenTitle(BuildContext context) => TextStyle(
    fontFamily: displayFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: displayTracking * 0.6,
    color: Palette.cream,
    height: 1.15,
  );

  /// The one big number on a screen: balance, hashrate.
  static TextStyle hero(BuildContext context) => TextStyle(
    fontFamily: displayFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: Palette.cream,
    height: 1.05,
  );

  static TextStyle headline(BuildContext context) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Palette.cream,
    height: 1.25,
  );

  static TextStyle title(BuildContext context) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Palette.cream,
    height: 1.3,
  );

  static TextStyle label(BuildContext context) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Palette.slateLight,
    height: 1.35,
  );

  static TextStyle caption(BuildContext context) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: Palette.slate,
    height: 1.35,
  );

  /// Small uppercase tracked label above a value.
  static TextStyle eyebrow(BuildContext context) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: Palette.slate,
    height: 1.4,
  );

  /// Machine readings: hashrate, address, hash, timestamp.
  static TextStyle mono(BuildContext context, {double size = 12}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: Palette.creamDim,
    height: 1.4,
  );

  static TextStyle monoGold(BuildContext context, {double size = 12}) =>
      mono(context, size: size).copyWith(color: Palette.gold);

  static TextStyle monoMuted(BuildContext context, {double size = 11}) =>
      mono(context, size: size).copyWith(color: Palette.slate);

  /// The balance figure, in an 8-bit pixel face that reads like an arcade
  /// score. Glyphs are square and wide, so the size is kept modest; callers
  /// that show a variable-length value wrap this in a FittedBox so a long
  /// balance scales instead of overflowing.
  static TextStyle pixel(BuildContext context, {double size = 24, Color? color}) =>
      TextStyle(
        fontFamily: pixelFamily,
        fontSize: size,
        color: color ?? Palette.cream,
        height: 1.35,
      );
}
