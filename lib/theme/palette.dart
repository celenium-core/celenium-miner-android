import 'package:flutter/material.dart';

/// CEN palette: deep navy canvas, gold accent, cream text.
///
/// Gold is the accent, not the base. It marks the active tab, the primary
/// action, and the one number that matters on each screen. Everything else
/// stays navy or cream so the accent keeps its weight.
class Palette {
  const Palette._();

  // Canvas
  static const Color field = Color(0xFF0A0D16);
  static const Color fieldAlt = Color(0xFF0B0E17);

  // Surfaces
  static const Color surface = Color(0xFF151A26);
  static const Color surfaceHigh = Color(0xFF1A2032);
  static const Color surfaceLight = Color(0xFFF8F7F2);

  // Gold accent
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE8C15E);
  static const Color goldPale = Color(0xFFF0D080);
  static const Color goldDim = Color(0xFF6B5620);

  // Text
  static const Color cream = Color(0xFFF2EAD8);
  static const Color creamDim = Color(0xFFE8DCC4);

  /// Pure white, for the numerals and labels the concept prints in white.
  /// Cream is the warm body text; white is the high-contrast punctuation.
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1A1F2B);
  static const Color slate = Color(0xFF64748B);
  static const Color slateLight = Color(0xFF94A3B8);

  // State
  static const Color green = Color(0xFF4ADE80);
  static const Color greenDim = Color(0xFF34D399);
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

  /// Gold, dimmed for tracks and inactive fills.
  static Color goldFade(double opacity) => gold.withValues(alpha: opacity);

  /// Green tint used behind status pills.
  static Color greenTint(double opacity) => green.withValues(alpha: opacity);
}
