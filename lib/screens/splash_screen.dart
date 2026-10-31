import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/mining_readout.dart';
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
    this.hashrateGhs,
    this.workerCount,
  });

  final VoidCallback onDone;
  final String? network;
  final String? nodeVersion;
  final int? blockCount;
  final double? hashrateGhs;
  final int? workerCount;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

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
              // CRT scanlines over the whole splash. Stronger here than in
              // the tabs: the boot screen is where the console identity is
              // established, so the texture is allowed to be assertive. The
              // spacing is tightened to two pixels and the opacity raised
              // until the raster actually reads on a dark field, where a
              // faint line would disappear entirely.
              Positioned.fill(child: ScanlineOverlay(opacity: 0.32, spacing: 2)),
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
                            // The rain runs for as long as the splash is up.
                            // It used to stop once the readout began typing,
                            // which left the screen plain for the whole time
                            // the user spent deciding to swipe; the boot
                            // texture is the point of this screen, and the
                            // band sits clear of the readout so nothing is
                            // obscured.
                            const _BinaryRain(running: true),
                            const SizedBox(height: Palette.xl),
                            _Readout(
                              network: widget.network,
                              nodeVersion: widget.nodeVersion,
                              blockCount: widget.blockCount,
                              hashrateGhs: widget.hashrateGhs,
                              workerCount: widget.workerCount,
                            ),
                            const SizedBox(height: Palette.xxl),
                            _Emblem(progress: _controller),
                            const SizedBox(height: Palette.md),
                            // The ticker glitches on a slow loop rather than
                            // once: the splash is up for as long as the user
                            // takes to swipe, so a single glitch would be over
                            // before most people looked.
                            const _TickerGlitch(text: 'C . E . N'),
                            const SizedBox(height: Palette.xl),
                            _SwipeDeck(progress: _dragX / _swipeThreshold),
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

}

/// The swipe deck at the foot of the splash.
///
/// A capsule track holding a row of hex that decodes left to right as the drag
/// advances, a gold fill behind it, and a handle that carries the drag. The
/// label beneath splits into chromatic offsets once the threshold is reached,
/// so the armed state is felt rather than only read.
class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck({required this.progress});

  /// Drag distance divided by the threshold: 0 at rest, 1 at the point the
  /// app opens. Negative when swiping the other way.
  final double progress;

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck> with SingleTickerProviderStateMixin {
  /// Fast tick that re-rolls the undecoded characters, so the right half of the
  /// track never holds still.
  late final AnimationController _scramble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
  )..repeat();

  /// Slow breathing of the handle glow at rest.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  static const _hex = '0123456789ABCDEF';

  /// The string the track decodes into. Reads as a key fragment, which is what
  /// a swipe on a console would plausibly be checking.
  static const _target = '0x4F2A9B1EC7D3';

  final _rng = math.Random();

  @override
  void dispose() {
    _scramble.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magnitude = widget.progress.abs().clamp(0.0, 1.0);
    final armed = magnitude >= 1;

    return Semantics(
      button: true,
      label: 'Swipe to enter the mining console',
      child: Column(
        children: [
          SizedBox(
            height: 62,
            // The track width decides how far the handle can travel, so the
            // deck has to be measured rather than assuming a fixed offset.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                const handleSize = 48.0;
                const inset = 7.0;
                // Travel is the whole track minus the handle, so the thumb
                // rests inside the capsule at both ends of the drag.
                final travel = (trackWidth - handleSize - inset * 2).clamp(0.0, trackWidth);

                return AnimatedBuilder(
                  animation: Listenable.merge([_scramble, _pulse]),
                  builder: (context, _) {
                    // How many characters have decoded. Never all of them: a
                    // fully decoded track would stop moving and read as
                    // finished rather than as in progress.
                    final decoded = (magnitude * (_target.length - 2)).round();

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The track itself: glass, with a hairline edge.
                        Container(
                          height: 62,
                          decoration: BoxDecoration(
                            color: Palette.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(Palette.pill),
                            border: Border.all(
                              color: armed
                                  ? Palette.gold.withValues(alpha: 0.55)
                                  : Palette.white.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        // Gold fill, clipped to the capsule so it never
                        // squares off at the ends.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Palette.pill),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: magnitude.clamp(0.0, 1.0),
                              child: Container(
                                height: 62,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Palette.gold.withValues(alpha: 0.30),
                                      Palette.gold.withValues(alpha: 0.10),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The hex row. Decoded characters are bright and
                        // stable; the rest re-roll every tick. The right
                        // padding reserves the space the handle occupies, so
                        // no character is ever hidden behind it.
                        Padding(
                          padding: EdgeInsets.only(
                            left: inset + handleSize + Palette.sm,
                            right: Palette.lg,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < _target.length; i++)
                                Text(
                                  i < decoded
                                      ? _target[i]
                                      : _hex[_rng.nextInt(_hex.length)],
                                  style: TypeScale.mono(context, size: 13).copyWith(
                                    color: i < decoded
                                        ? Palette.gold
                                        : Palette.creamDim.withValues(alpha: 0.35),
                                    fontWeight: i < decoded ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // The handle, travelling left to right across the
                        // track as the drag advances.
                        Positioned(
                          left: inset + magnitude * travel,
                          top: (62 - handleSize) / 2,
                          child: Container(
                            width: handleSize,
                            height: handleSize,
                            decoration: BoxDecoration(
                              color: armed ? Palette.gold : Palette.surfaceHigh,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: armed
                                    ? Palette.goldPale
                                    : Palette.white.withValues(alpha: 0.22),
                              ),
                              boxShadow: armed
                                  ? [
                                      BoxShadow(
                                        color: Palette.gold.withValues(alpha: 0.5),
                                        blurRadius: 18,
                                      )
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Palette.white
                                            .withValues(alpha: 0.05 + _pulse.value * 0.06),
                                        blurRadius: 12,
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.chevron_right,
                                size: 24,
                                color: armed ? Palette.ink : Palette.cream,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: Palette.md),
          _DeckLabel(armed: armed, pulse: _pulse),
        ],
      ),
    );
  }
}

/// The prompt under the deck. Once armed it splits into chromatic offsets, the
/// same glitch the wordmark uses, so the state change is visible at a glance.
class _DeckLabel extends StatelessWidget {
  const _DeckLabel({required this.armed, required this.pulse});

  final bool armed;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final text = armed ? 'LEPAS UNTUK MASUK' : 'GESER UNTUK MASUK';
    final base = TypeScale.eyebrow(context).copyWith(
      color: armed ? Palette.gold : Palette.creamDim,
      letterSpacing: 2.6,
      fontWeight: FontWeight.w700,
    );

    if (!armed) {
      return AnimatedBuilder(
        animation: pulse,
        builder: (context, _) => Opacity(
          opacity: 0.55 + pulse.value * 0.45,
          child: Text(text, style: base),
        ),
      );
    }

    // Armed: two offset copies either side of the real text, in the CRT's
    // red and cyan. The offsets are small enough to read as a glitch rather
    // than as a blur.
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(-1.6, 0),
          child: Text(text, style: base.copyWith(color: Palette.redDeep)),
        ),
        Transform.translate(
          offset: const Offset(1.6, 0),
          child: Text(text, style: base.copyWith(color: Palette.greenDim)),
        ),
        Text(text, style: base),
      ],
    );
  }
}

/// The ticker under the emblem, glitching on a slow loop.
///
/// Chromatic offsets plus a horizontal shear, applied in short bursts with long
/// quiet stretches between. A continuous glitch would be unreadable; the
/// spacing is what makes each burst read as a fault rather than as a style.
class _TickerGlitch extends StatefulWidget {
  const _TickerGlitch({required this.text});

  final String text;

  @override
  State<_TickerGlitch> createState() => _TickerGlitchState();
}

class _TickerGlitchState extends State<_TickerGlitch> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TypeScale.eyebrow(context).copyWith(
      color: Palette.creamDim,
      letterSpacing: 5,
      fontWeight: FontWeight.w700,
    );

    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value;
        // Two short bursts per cycle, each about a twentieth of the loop.
        final inBurst = (t % 0.5) < 0.05;
        final offset = inBurst ? 2.2 : 0.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            if (inBurst) ...[
              Transform.translate(
                offset: Offset(-offset, 0),
                child: Text(widget.text, style: base.copyWith(color: Palette.redDeep)),
              ),
              Transform.translate(
                offset: Offset(offset, 0),
                child: Text(widget.text, style: base.copyWith(color: Palette.greenDim)),
              ),
            ],
            Text(widget.text, style: base),
          ],
        );
      },
    );
  }
}

/// Columns of binary. Decorative only: it marks the boot moment and carries no
/// Falling binary, played for as long as the splash is up.
///
/// The band sits clear of the readout below it, so the rain can run for the
/// whole time the user spends on this screen without obscuring anything.
class _BinaryRain extends StatelessWidget {
  const _BinaryRain({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    // Denser and taller than the ambient rain in the tabs: the splash is the
    // one screen whose whole job is to look like a terminal booting.
    return BinaryRain(running: running, height: 150, columns: 11);
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
    this.hashrateGhs,
    this.workerCount,
  });

  final String? network;
  final String? nodeVersion;
  final int? blockCount;
  final double? hashrateGhs;
  final int? workerCount;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[];

    if (network != null) entries.add(('NETWORK', network!));
    if (nodeVersion != null) entries.add(('NODE', nodeVersion!));
    if (blockCount != null) entries.add(('BLOCK', '#$blockCount'));
    if (hashrateGhs != null) entries.add(('HASHRATE', formatHashrate(hashrateGhs!)));
    if (workerCount != null && workerCount! > 0) entries.add(('WORKERS', '$workerCount'));

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Palette.lg),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        border: Border.all(color: Palette.greenDim.withValues(alpha: 0.18)),
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
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadoutRow extends StatefulWidget {
  const _ReadoutRow(this.label, this.value, {this.delay = Duration.zero});

  final String label;
  final String value;

  /// How long to wait before this line starts typing. The first line waits
  /// long enough for the binary rain to be seen before the screen settles.
  final Duration delay;

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
