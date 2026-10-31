import 'package:flutter/material.dart';

import 'brand_mark_geometry.dart';

/// The CEN brand mark: a five-petal flower.
///
/// Drawn rather than shipped as an asset so it stays crisp at every size,
/// from the 18 px active-tab dot to the splash emblem, and so the petal and
/// core colours can invert for light and dark backgrounds.
///
/// The shape follows the reference logo: five petals in five-fold symmetry,
/// each carrying a diamond cut out in the background colour, around a gold
/// core ringed by eight short spokes. The reference ships as a matched pair,
/// cream petals on navy and navy petals on cream, which is why every colour
/// here is a parameter. The geometry itself lives in brand_mark_geometry.dart
/// so the launcher icon generator can share it.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 32,
    this.petal = const Color(0xFF1F2A4A),
    this.diamond = const Color(0xFFF5F0E6),
    this.core = const Color(0xFFC89B3C),
    this.spoke = const Color(0xFF1F2A4A),
  });

  /// Diameter of the mark in logical pixels.
  final double size;

  /// Petal colour. On the light splash emblem this is navy; on dark
  /// backgrounds it flips to cream.
  final Color petal;

  /// Colour of the diamond inside each petal. Matches the background the
  /// mark sits on, which is what makes the diamond read as a cut-out.
  final Color diamond;

  /// Core colour at the centre of the flower.
  final Color core;

  /// Colour of the eight spokes and the thin ring around the core.
  final Color spoke;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: BrandMarkPainter(
          petal: petal,
          diamond: diamond,
          core: core,
          spoke: spoke,
        ),
      ),
    );
  }
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    required this.petal,
    required this.diamond,
    required this.core,
    required this.spoke,
  });

  final Color petal;
  final Color diamond;
  final Color core;
  final Color spoke;

  @override
  void paint(Canvas canvas, Size size) {
    paintBrandMark(canvas, size, petal: petal, diamond: diamond, core: core, spoke: spoke);
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.petal != petal ||
      old.diamond != diamond ||
      old.core != core ||
      old.spoke != spoke;
}
