import 'package:flutter/material.dart';

/// CEN palette: dark canvas, blue accent, light slate text.
///
/// Blue is the accent, not the base. It marks the active tab, the primary
/// action, and the one number that matters on each screen. Everything else
/// stays dark or slate so the accent keeps its weight.
///
/// The `gold*` token names are retained from the original dark/gold console so
/// the names stay stable across the codebase; they now carry the blue accent
/// family instead of metallic gold.
class Palette {
  const Palette._();

  // Canvas
  static const Color field = Color(0xFF0B1220);
  static const Color fieldAlt = Color(0xFF0E1727);

  // Surfaces
  static const Color surface = Color(0xFF162136);
  static const Color surfaceHigh = Color(0xFF1D2A40);
  static const Color surfaceLight = Color(0xFF21304A);

  // Blue accent
  static const Color gold = Color(0xFF3B82F6);
  static const Color goldLight = Color(0xFF60A5FA);
  static const Color goldPale = Color(0xFF1E3A8A);
  static const Color goldDim = Color(0xFF2563EB);

  /// Neon yellow: the one accent outside the blue family. Reserved for the
  /// "protect your key" backup action, so it can't be missed among the blue
  /// primaries. Its ink is the dark canvas, matching the light-card contrast
  /// pair rather than the usual white-on-colour.
  static const Color neon = Color(0xFFE6FF00);

  // Text
  static const Color cream = Color(0xFFE6EDF7);
  static const Color creamDim = Color(0xFF9AA7BD);

  /// Pure white, kept for on-accent text and light effects.
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFFF5F8FD);
  static const Color slate = Color(0xFF94A3B8);
  static const Color slateLight = Color(0xFFA6B4C8);

  // Cream panel ink. The cream card (built on Palette.cream) carries dark
  // figures, so it needs its own ink pair rather than the light text used on
  // dark surfaces: deep navy for values, a darker slate for secondary lines.
  static const Color creamInk = Color(0xFF0B1220);
  static const Color creamInkDim = Color(0xFF475569);

  // Mining summary chips on the cream card: hashrate in warm yellow, the
  // bridge "connect" notif in the blue accent, share difficulty in neutral
  // grey — three fills that never compete for the eye.
  static const Color amber = Color(0xFFFBBF24);
  static const Color amberInk = Color(0xFF78350F);
  static const Color slateSoft = Color(0xFFE2E8F0);

  // State
  static const Color green = Color(0xFF22C55E);
  static const Color greenDim = Color(0xFF16A34A);
  static const Color red = Color(0xFFF87171);
  static const Color redDeep = Color(0xFFEF4444);

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Radii. Cards get one generous radius, controls get full pills.
  static const double cardRadius = 22;
  static const double rowRadius = 16;
  static const double pill = 999;

  /// Accent, dimmed for tracks and inactive fills.
  static Color goldFade(double opacity) => gold.withValues(alpha: opacity);

  /// Green tint used behind status pills.
  static Color greenTint(double opacity) => green.withValues(alpha: opacity);
}