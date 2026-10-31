import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The CEN brand mark: a four-petal flower.
///
/// Drawn rather than shipped as an asset so it stays crisp at every size,
/// from the 24 px active-tab dot to the splash emblem, and so the petal and
/// core colours can invert for light and dark backgrounds.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 32,
    this.petal = const Color(0xFF1E3A8A),
    this.core = Palette.gold,
    this.coreScale = 0.34,
  });

  /// Diameter of the mark in logical pixels.
  final double size;

  /// Petal colour. On the light splash emblem this is navy; on dark
  /// backgrounds it flips to gold and the core flips to navy.
  final Color petal;

  /// Core colour at the centre of the flower.
  final Color core;

  /// Core diameter as a fraction of [size].
  final double coreScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandMarkPainter(petal: petal, core: core, coreScale: coreScale)),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.petal, required this.core, required this.coreScale});

  final Color petal;
  final Color core;
  final double coreScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 2;

    // Petal: a teardrop from the centre outwards. Four of them at 90 degrees
    // make the clover. Each petal is an ellipse offset from the centre so the
    // inner ends overlap and the core sits on top of the join.
    final petalLength = unit * 0.86;
    final petalWidth = unit * 0.56;
    final petalOffset = unit * 0.42;

    final paint = Paint()..color = petal;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final petal = Path()
        ..moveTo(0, 0)
        ..cubicTo(petalWidth, -petalOffset * 0.5, petalWidth, -petalLength, 0, -petalLength)
        ..cubicTo(-petalWidth, -petalLength, -petalWidth, -petalOffset * 0.5, 0, 0)
        ..close();

      canvas.drawPath(petal, paint);
      canvas.restore();
    }

    // Core covers the four petal bases so the join reads as one flower.
    canvas.drawCircle(center, unit * coreScale, Paint()..color = core);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) =>
      old.petal != petal || old.core != core || old.coreScale != coreScale;
}
