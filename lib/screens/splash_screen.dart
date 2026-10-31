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

  /// Drives the entry button's fade-in, which starts once the emblem has
  /// finished its sweep so the two do not compete for attention.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // The button waits for the emblem to settle, then fades in. A delay
    // rather than a shared animation, because the two have different curves
    // and different lengths.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.field,
      body: SafeArea(
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
                            _EnterButton(onTap: widget.onDone, fade: _entry),
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
    );
  }
}

/// The entry control: one hairline pill, nothing else.
///
/// A gesture was tried first and read as fussy, so this is a plain button. It
/// carries no fill, only a thin gold edge, and fades in once the emblem has
/// settled so the two never compete. Pressing it dims the edge rather than
/// filling the capsule, which keeps the surface as quiet as it was.
class _EnterButton extends StatelessWidget {
  const _EnterButton({required this.onTap, required this.fade});

  final VoidCallback onTap;

  /// Drives the fade-in. Zero until the emblem finishes its sweep.
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    final label = TypeScale.eyebrow(context).copyWith(
      color: Palette.cream,
      letterSpacing: 3.4,
      fontWeight: FontWeight.w700,
    );

    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) {
        final t = Curves.easeOut.transform(fade.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            // Rises the last few pixels as it appears, so the button arrives
            // rather than simply being switched on.
            offset: Offset(0, 8 * (1 - t)),
            child: Semantics(
              button: true,
              label: 'Enter the mining console',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(Palette.pill),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: Palette.xxl),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Palette.pill),
                      border: Border.all(color: Palette.gold.withValues(alpha: 0.45)),
                    ),
                    child: Center(child: Text('MASUK', style: label)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
