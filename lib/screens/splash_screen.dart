import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brand_mark.dart';

/// Boot screen.
///
/// Shows the wordmark, the brand emblem, and a short machine readout. The
/// readout carries real values (network, node version, block height) when the
/// bridge has answered, and stays blank when it has not, so the screen never
/// claims a connection it does not have.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onDone,
    this.network,
    this.nodeVersion,
    this.blockCount,
  });

  final VoidCallback onDone;
  final String? network;
  final String? nodeVersion;
  final int? blockCount;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // The splash is a transition, not a destination: leave once the emblem
    // has finished its single sweep, whether or not the bridge answered.
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.field,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Palette.xl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const SizedBox(height: Palette.xxl),
                      Text('CELENIUM', style: TypeScale.wordmark(context)),
                      const SizedBox(height: Palette.sm),
                      Text('C E L E N I U M   C O R E', style: TypeScale.monoMuted(context, size: 9)),
                      const SizedBox(height: Palette.xl),
                      const _BinaryRain(),
                      const SizedBox(height: Palette.xl),
                      _Readout(
                        network: widget.network,
                        nodeVersion: widget.nodeVersion,
                        blockCount: widget.blockCount,
                      ),
                      const SizedBox(height: Palette.xxl),
                      _Emblem(progress: _controller),
                      const SizedBox(height: Palette.md),
                      Text('C . E . L', style: TypeScale.eyebrow(context).copyWith(color: Palette.creamDim, letterSpacing: 5)),
                      const SizedBox(height: Palette.lg),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Columns of binary. Decorative only: it marks the boot moment and carries no
/// state, so it does not need to mean anything.
class _BinaryRain extends StatelessWidget {
  const _BinaryRain();

  static const List<String> _lines = [
    '01101001 01100100',
    '11010010 00110110',
    '01100011 01100101',
    '10001110 11001001',
    '01101100 01100101',
    '01001110 10011001',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final line in _lines) ...[
            Text(
              line,
              style: TypeScale.mono(context, size: 10).copyWith(
                color: Palette.greenDim.withValues(alpha: 0.55),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: Palette.md),
          ],
        ],
      ),
    );
  }
}

/// Real values only. Each line is dropped when its value is unknown.
class _Readout extends StatelessWidget {
  const _Readout({this.network, this.nodeVersion, this.blockCount});

  final String? network;
  final String? nodeVersion;
  final int? blockCount;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (network != null) {
      rows.add(_ReadoutRow('NETWORK', network!));
    }
    if (nodeVersion != null) {
      rows.add(_ReadoutRow('NODE', nodeVersion!));
    }
    if (blockCount != null) {
      rows.add(_ReadoutRow('BLOCK', '#$blockCount'));
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Palette.lg),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Palette.rowRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: Palette.sm),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ReadoutRow extends StatelessWidget {
  const _ReadoutRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: TypeScale.monoMuted(context, size: 9).copyWith(letterSpacing: 1.4)),
        ),
        Expanded(
          child: Text(value, style: TypeScale.mono(context, size: 11).copyWith(color: Palette.greenDim)),
        ),
      ],
    );
  }
}

/// Cream disc with the navy flower inside, and a gold arc that sweeps once.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        return SizedBox.square(
          dimension: 132,
          child: CustomPaint(
            painter: _EmblemPainter(sweep: progress.value),
            child: Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: Palette.cream, shape: BoxShape.circle),
                child: Center(child: BrandMark(size: 58)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter({required this.sweep});

  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final track = Paint()
      ..color = Palette.goldDim.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = Palette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Starts at the top and sweeps once as the splash loads.
    const start = -math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      math.pi * 2 * sweep.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.sweep != sweep;
}
