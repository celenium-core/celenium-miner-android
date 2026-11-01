import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/brand_mark.dart';

/// The mining dial.
///
/// The ring is a real reading: the fraction of submitted shares the network
/// accepted, drawn as segments that fill clockwise. When no shares have been
/// submitted the ring stays empty rather than showing a decorative fill, so
/// the dial never claims work that has not happened.
class MiningDial extends StatelessWidget {
  const MiningDial({
    super.key,
    required this.rate,
    this.active = false,
    this.size = 240,
    this.segments = 44,
  });

  /// Acceptance rate in 0..1, or null when there is nothing to show.
  final double? rate;

  /// Whether the bridge reports live hashing.
  final bool active;

  final double size;
  final int segments;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DialPainter(rate: rate, active: active, segments: segments),
        child: Center(
          child: Container(
            width: size * 0.46,
            height: size * 0.46,
            decoration: const BoxDecoration(
              color: Palette.cream,
              shape: BoxShape.circle,
            ),
            child: Center(child: BrandMark(size: size * 0.24)),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.rate,
    required this.active,
    required this.segments,
  });

  final double? rate;
  final bool active;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 2;

    // Radiating ticks around the ring, like an instrument face.
    final tickInner = unit * 0.80;
    final tickOuter = unit * 0.94;
    final tickPaint = Paint()
      ..color = Palette.goldDim.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi * 2 / 60 - math.pi / 2;
      // Every fifth tick is longer, so the face has a readable scale.
      final isMajor = i % 5 == 0;
      final inner = isMajor ? tickInner - unit * 0.05 : tickInner;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * inner,
          center.dy + math.sin(angle) * inner,
        ),
        Offset(
          center.dx + math.cos(angle) * tickOuter,
          center.dy + math.sin(angle) * tickOuter,
        ),
        tickPaint,
      );
    }

    // Segmented ring. Filled segments are gold; the rest stay on the track.
    final ringRadius = unit * 0.66;
    final filled = rate == null
        ? 0
        : (rate!.clamp(0.0, 1.0) * segments).round();

    final trackPaint = Paint()
      ..color = Palette.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.075
      ..strokeCap = StrokeCap.round;

    final livePaint = Paint()
      ..color = active ? Palette.gold : Palette.goldDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.075
      ..strokeCap = StrokeCap.round;

    // Leave a small gap between segments so they read as separate arcs.
    const gap = 0.028;
    final sweep = math.pi * 2 / segments - gap;

    for (var i = 0; i < segments; i++) {
      final start = i * math.pi * 2 / segments - math.pi / 2 + gap / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        start,
        sweep,
        false,
        i < filled ? livePaint : trackPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.rate != rate || old.active != active || old.segments != segments;
}
