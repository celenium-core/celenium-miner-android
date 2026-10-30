/// Design tokens for the Cenium miner app.
///
/// Every decision here carries its reason, per the project's design rules.
/// Palette is capped at two core colours plus one accent.
library;

import 'package:flutter/material.dart';

/// Two core colours plus one accent. Neutrals do not count toward the cap.
class Palette {
  /// Near-black field. A mining app runs for hours; a near-black field keeps
  /// the screen calm and lets the live accent carry all the attention.
  static const Color field = Color(0xFF070B0F);

  /// Graphite surface. Separates surfaces from the field without introducing
  /// a third hue.
  static const Color surface = Color(0xFF111820);

  /// Raised surface for inputs and list rows.
  static const Color surfaceHigh = Color(0xFF18212B);

  /// Electric neon blue, the coin's brand accent.
  ///
  /// Used only where something is live: mining state, live hashrate, the
  /// active navigation destination. This is the app's identity motif, so the
  /// accent means "this is running right now" everywhere it appears.
  static const Color accent = Color(0xFF00F0FF);

  /// Dimmed accent for borders and hairlines on live surfaces.
  static const Color accentDim = Color(0xFF0A6E78);

  static const Color textPrimary = Color(0xFFF2F6F8);
  static const Color textSecondary = Color(0xFF8A9BA8);

  /// Warning, used only for a real degraded state (stale or invalid shares).
  static const Color warn = Color(0xFFFFB454);

  static const Color danger = Color(0xFFFF6B6B);
}

/// A small, deliberate radius set. Not every element is a pill.
class Radii {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;

  /// Reserved for the single live-state indicator, nothing else.
  static const double pill = 999;
}

/// Spacing scale, used at a mobile register on narrow widths.
class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Type scale.
///
/// Sora carries display and headings; Manrope carries body and UI text.
/// Numbers use Manrope with tabular figures because hashrate updates several
/// times a second and fixed-width digits stop the layout jittering.
class Type {
  static const String display = 'Sora';
  static const String body = 'Manrope';

  /// Forces fixed-width digits for rapidly changing values.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  final scheme = const ColorScheme.dark(
    surface: Palette.surface,
    primary: Palette.accent,
    onPrimary: Palette.field,
    secondary: Palette.accent,
    onSecondary: Palette.field,
    error: Palette.danger,
    onSurface: Palette.textPrimary,
  );

  final textTheme = TextTheme(
    displaySmall: TextStyle(
      fontFamily: Type.display,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      color: Palette.textPrimary,
      height: 1.1,
    ),
    headlineMedium: TextStyle(
      fontFamily: Type.display,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Palette.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: Type.body,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Palette.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: Type.body,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Palette.textPrimary,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontFamily: Type.body,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: Palette.textSecondary,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: Type.body,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Palette.textPrimary,
    ),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.field,
    textTheme: textTheme,
    dividerTheme: const DividerThemeData(
      color: Palette.surfaceHigh,
      thickness: 1,
      space: 1,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
