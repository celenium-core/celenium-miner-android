import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A frosted surface.
///
/// Glass is an accent in this app, not its character. It is used on exactly
/// two elements: the mining status panel, which is the one surface the eye
/// must land on first, and the top app bar, which floats above the field as
/// chrome rather than content. Everything else stays solid graphite so that
/// hierarchy stays legible.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.radius = Radii.lg,
    this.accentBorder = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Draws the hairline accent border. Only for a surface whose contents are
  /// live right now, so the border marks a real state rather than decorating.
  final bool accentBorder;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: accentBorder ? Palette.accentDim : Palette.surfaceHigh,
              width: 1,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
