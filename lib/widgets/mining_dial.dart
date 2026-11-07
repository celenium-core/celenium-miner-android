import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The mining dial: only the instrument face (ticks and the acceptance ring).
///
/// The ring is a real reading: the fraction of submitted shares the network
/// accepted, drawn as segments that fill clockwise. When no shares have been
/// submitted the ring stays empty rather than showing a decorative fill, so
/// the dial never claims work that has not happened.
///
/// The centre is left empty for the caller: the mining screen drops its own
/// start/stop logo button there.
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
      ..color = Palette.cream.withValues(alpha: 0.70)
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

    // Segmented ring in cream. Filled segments read as the accepted shares;
    // the rest stay on a fainter cream track, so the dial is cream on cream
    // with only the accepted fraction brightened.
    final ringRadius = unit * 0.66;
    final filled = rate == null
        ? 0
        : (rate!.clamp(0.0, 1.0) * segments).round();

    final trackPaint = Paint()
      ..color = Palette.cream.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.075
      ..strokeCap = StrokeCap.round;

    final livePaint = Paint()
      ..color = active ? Palette.white : Palette.cream
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
