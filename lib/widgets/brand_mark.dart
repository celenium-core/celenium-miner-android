import 'dart:math' as math;

import 'package:flutter/material.dart';


/// The CEN brand mark: a five-petal flower.
///
/// Drawn rather than shipped as an asset so it stays crisp at every size,
/// from the 18 px active-tab dot to the splash emblem, and so the petal and
/// core colours can invert for light and dark backgrounds.
///
/// The shape follows the reference logo: five navy petals in five-fold
/// symmetry, each carrying a cream diamond, around a gold core with six navy
/// spokes.
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
  /// backgrounds it flips to gold.
  final Color petal;

  /// Colour of the diamond inside each petal. Matches the background the
  /// mark sits on, which is what makes the diamond read as a cut-out.
  final Color diamond;

  /// Core colour at the centre of the flower.
  final Color core;

  /// Colour of the six spokes inside the core.
  final Color spoke;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          petal: petal,
          diamond: diamond,
          core: core,
          spoke: spoke,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({
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
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 2;

    // The flower fills most of the box, leaving a small margin.
    final outerRadius = unit * 0.92;
    final coreRadius = unit * 0.20;
    final innerRadius = coreRadius * 0.92;

    final petalPaint = Paint()..color = petal;

    // Five petals, 72 degrees apart, one pointing straight up.
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * (math.pi * 2 / 5);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // A petal in local coordinates points up the -y axis: a rounded tip at
      // the inner end near the core, a broad bulb at the outer end, and a
      // shallow notch across the outer edge.
      final bulb = outerRadius;
      final halfWidth = unit * 0.30;
      final notch = unit * 0.055;

      final path = Path()
        ..moveTo(0, innerRadius)
        ..cubicTo(-halfWidth, innerRadius * 0.35, -halfWidth, -bulb * 0.86, -halfWidth * 0.52, -bulb)
        ..quadraticBezierTo(0, -bulb + notch, halfWidth * 0.52, -bulb)
        ..cubicTo(halfWidth, -bulb * 0.86, halfWidth, innerRadius * 0.35, 0, innerRadius)
        ..close();

      canvas.drawPath(path, petalPaint);

      // The diamond sits in the outer half of the petal, standing on its
      // point. Drawn as a rotated square.
      final diamondRadius = unit * 0.085;
      final diamondCenter = Offset(0, -bulb * 0.62);
      final diamondPath = Path()
        ..moveTo(diamondCenter.dx, diamondCenter.dy - diamondRadius)
        ..lineTo(diamondCenter.dx + diamondRadius, diamondCenter.dy)
        ..lineTo(diamondCenter.dx, diamondCenter.dy + diamondRadius)
        ..lineTo(diamondCenter.dx - diamondRadius, diamondCenter.dy)
        ..close();
      canvas.drawPath(diamondPath, Paint()..color = diamond);

      canvas.restore();
    }

    // Gold core.
    canvas.drawCircle(center, coreRadius, Paint()..color = core);

    // Six navy spokes, evenly spaced, stopping short of the core edge.
    final spokePaint = Paint()
      ..color = spoke
      ..strokeWidth = math.max(unit * 0.035, 1.0)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * coreRadius * 0.74,
          center.dy + math.sin(angle) * coreRadius * 0.74,
        ),
        spokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) =>
      old.petal != petal ||
      old.diamond != diamond ||
      old.core != core ||
      old.spoke != spoke;
}
