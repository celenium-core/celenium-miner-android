import 'package:flutter/material.dart';

/// The CEN brand mark: the five-petal flower.
///
/// This is the user's own artwork, shipped as an asset rather than redrawn, so
/// what the app shows is exactly the logo that was supplied. The source comes
/// as a matched pair on flat fields, navy and cream; tool/make_transparent_logo.py
/// keys those fields out so the mark can sit on any container, and the two
/// transparent results are what this widget picks between.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.onDark = false});

  /// Diameter of the mark in logical pixels.
  final double size;

  /// Which of the two supplied versions to show.
  ///
  /// True picks the cream-petal mark for a dark field; false picks the
  /// navy-petal mark for a light one. The pair is the same artwork inverted,
  /// so either reads correctly against the matching background.
  final bool onDark;

  /// The cream-petal version, for dark backgrounds.
  static const _forDark = 'assets/logo/cen_mark_for_dark.png';

  /// The navy-petal version, for light backgrounds.
  static const _forLight = 'assets/logo/cen_mark_for_light.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark ? _forDark : _forLight,
      width: size,
      height: size,
      // The mark is a flat graphic, so no smoothing is wanted when it scales;
      // none keeps the petal edges crisp at the small sizes.
      filterQuality: FilterQuality.none,
      excludeFromSemantics: true,
    );
  }
}
