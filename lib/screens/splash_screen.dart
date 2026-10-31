import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/hacker_fx.dart';

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

  /// Set once the boot readout begins typing, which stops the binary rain so
  /// the screen settles into something readable.
  bool _readoutStarted = false;

  /// How far the swipe has travelled, in logical pixels. Reset when the
  /// gesture ends without reaching the threshold.
  double _dragX = 0;

  /// Distance the swipe must cover before the app opens. Wide enough that a
  /// stray thumb does not trigger it, short enough to feel deliberate.
  static const _swipeThreshold = 110;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // No timer here: the splash waits for the swipe. Leaving on its own would
    // make the gesture pointless, since the screen would already be gone.
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
        child: GestureDetector(
          // Horizontal only, so a vertical scroll inside the readout still
          // works and the swipe never fights it.
          onHorizontalDragUpdate: (d) {
            setState(() => _dragX = (_dragX + d.delta.dx).clamp(-160, 160));
          },
          onHorizontalDragEnd: (_) {
            if (_dragX.abs() >= _swipeThreshold) {
              widget.onDone();
            } else {
              setState(() => _dragX = 0);
            }
          },
          child: Stack(
            children: [
              // Faint CRT scanlines over the whole splash.
              Positioned.fill(child: ScanlineOverlay(opacity: 0.06, spacing: 3)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Palette.xl),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            const SizedBox(height: Palette.xxl),
                            // The wordmark glitches once as it lands, then
                            // settles so it stays readable.
                            GlitchText(
                              text: 'CELENIUM',
                              style: TypeScale.wordmark(context),
                            ),
                            const SizedBox(height: Palette.sm),
                            Text('C E L E N I U M   C O R E',
                                style: TypeScale.monoMuted(context, size: 9)),
                            const SizedBox(height: Palette.xl),
                            _BinaryRain(running: !_readoutStarted),
                            const SizedBox(height: Palette.xl),
                            _Readout(
                              network: widget.network,
                              nodeVersion: widget.nodeVersion,
                              blockCount: widget.blockCount,
                              onStarted: _markReadoutStarted,
                            ),
                            const SizedBox(height: Palette.xxl),
                            _Emblem(progress: _controller),
                            const SizedBox(height: Palette.md),
                            Text('C . E . N',
                                style: TypeScale.eyebrow(context)
                                    .copyWith(color: Palette.creamDim, letterSpacing: 5)),
                            const SizedBox(height: Palette.xl),
                            _SwipeHint(progress: _dragX / _swipeThreshold),
                            const SizedBox(height: Palette.lg),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markReadoutStarted() {
    if (mounted) setState(() => _readoutStarted = true);
  }
}

/// The swipe affordance at the foot of the splash.
///
/// The chevrons slide and brighten as the drag approaches the threshold, so
/// the gesture is discoverable and its progress is visible rather than a
/// label that only says what to do.
class _SwipeHint extends StatefulWidget {
  const _SwipeHint({required this.progress});

  /// Drag distance divided by the threshold: 0 at rest, 1 at the point the
  /// app opens. Negative when swiping the other way.
  final double progress;

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final armed = widget.progress.abs() >= 1;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        // At rest the chevrons breathe; once armed they hold at full
        // brightness so the state change is unmistakable.
        final glow = armed ? 1.0 : 0.35 + _pulse.value * 0.4;

        return Semantics(
          button: true,
          label: 'Swipe to enter the mining console',
          child: Column(
            children: [
              Transform.translate(
                offset: Offset(widget.progress * 18, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Opacity(
                        opacity: (glow - i * 0.18).clamp(0.15, 1.0),
                        child: Icon(
                          Icons.chevron_right,
                          size: 26 - i * 3,
                          color: armed ? Palette.gold : Palette.creamDim,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Palette.sm),
              Text(
                armed ? 'LEPAS UNTUK MASUK' : 'GESER UNTUK MASUK',
                style: TypeScale.eyebrow(context).copyWith(
                  color: armed ? Palette.gold : Palette.creamDim,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Columns of binary. Decorative only: it marks the boot moment and carries no
/// Falling binary, played while the splash is up.
///
/// The effect stops as soon as the boot readout starts typing, so the screen
/// settles into something readable instead of raining for the whole session.
class _BinaryRain extends StatelessWidget {
  const _BinaryRain({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return BinaryRain(running: running, height: 110, columns: 7);
  }
}

/// Real values only. Each line is dropped when its value is unknown.
///
/// The values type themselves out, so the splash reads as a machine reporting
/// what it found rather than as a static label.
class _Readout extends StatelessWidget {
  const _Readout({
    this.network,
    this.nodeVersion,
    this.blockCount,
    this.onStarted,
  });

  final String? network;
  final String? nodeVersion;
  final int? blockCount;

  /// Called once typing begins, which stops the binary rain.
  final VoidCallback? onStarted;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[];

    if (network != null) entries.add(('NETWORK', network!));
    if (nodeVersion != null) entries.add(('NODE', nodeVersion!));
    if (blockCount != null) entries.add(('BLOCK', '#$blockCount'));

    if (entries.isEmpty) {
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
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: Palette.sm),
            _ReadoutRow(
              entries[i].$1,
              entries[i].$2,
              // The first line waits 1500ms so the binary rain is on screen
              // long enough to be seen before the boot readout starts typing
              // and stops it. Later lines stagger behind so they arrive one
              // after another.
              delay: Duration(milliseconds: 1500 + 260 * i),
              onStarted: onStarted,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadoutRow extends StatefulWidget {
  const _ReadoutRow(this.label, this.value, {this.delay = Duration.zero, this.onStarted});

  final String label;
  final String value;

  /// How long to wait before this line starts typing. The first line waits
  /// long enough for the binary rain to be seen before the screen settles.
  final Duration delay;
  final VoidCallback? onStarted;

  @override
  State<_ReadoutRow> createState() => _ReadoutRowState();
}

class _ReadoutRowState extends State<_ReadoutRow> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  Future<void> _arm() async {
    await Future<void>.delayed(widget.delay);
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final valueStyle = TypeScale.mono(context, size: 11).copyWith(color: Palette.greenDim);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            widget.label,
            style: TypeScale.monoMuted(context, size: 9).copyWith(letterSpacing: 1.4),
          ),
        ),
        Expanded(
          child: _ready
              ? TypewriterText(
                  text: widget.value,
                  style: valueStyle,
                  duration: const Duration(milliseconds: 420),
                  onDone: widget.onStarted,
                )
              : const SizedBox(height: 15),
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
