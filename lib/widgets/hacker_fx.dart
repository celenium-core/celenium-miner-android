import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// Terminal effects for the console aesthetic.
///
/// Every effect here is bounded. The binary rain and the typewriter run for
/// the length of the splash and stop; the scanlines are static; the hex ticker
/// only moves while the bridge reports live hashing. Nothing pulses forever,
/// because a screen that never stops moving competes with the reading it is
/// supposed to show (R-19).

/// Columns of binary falling down the screen, with a brighter head character.
///
/// Runs while the splash is up, which is the one moment the app is allowed to
/// look busy: it is booting, and the rain says so. [running] false freezes it.
class BinaryRain extends StatefulWidget {
  const BinaryRain({
    super.key,
    this.running = true,
    this.height = 120,
    this.columns = 9,
    this.color = Palette.greenDim,
    this.expand = false,
    this.fontSize = 13.0,
  });

  final bool running;
  final double height;
  final int columns;
  final Color color;

  /// Glyph height for the falling digits (default 13). Reduced for the
  /// full-screen splash rain so the digits read as texture, not text.
  final double fontSize;

  /// Fill the space offered instead of taking [height].
  ///
  /// Used for the ambient rain behind a whole screen, where the effect has to
  /// cover the viewport rather than sit in a fixed band.
  final bool expand;

  @override
  State<BinaryRain> createState() => _BinaryRainState();
}

class _BinaryRainState extends State<BinaryRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  /// Per-column offset and speed, fixed at construction so the rain has
  /// structure instead of pure noise.
  late final List<_Column> _cols = List.generate(
    widget.columns,
    (i) => _Column(offset: (i * 37 % 100) / 100, speed: 0.6 + (i % 3) * 0.25),
  );

  @override
  void didUpdateWidget(BinaryRain old) {
    super.didUpdateWidget(old);
    if (widget.running != old.running) {
      if (widget.running) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.running) {
      return SizedBox(height: widget.height);
    }
    final rain = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _RainPainter(
          progress: _controller.value,
          columns: _cols,
          color: widget.color,
          fontSize: widget.fontSize,
        ),
        size: Size.infinite,
      ),
    );

    // Expanded, the rain takes whatever height the parent offers; otherwise
    // it holds its own band.
    if (widget.expand) return SizedBox.expand(child: rain);
    return SizedBox(height: widget.height, child: rain);
  }
}

class _Column {
  const _Column({required this.offset, required this.speed});

  /// Where the column starts, 0..1 of the rain height.
  final double offset;

  /// How fast this column falls relative to the others.
  final double speed;
}

class _RainPainter extends CustomPainter {
  const _RainPainter({
    required this.progress,
    required this.columns,
    required this.color,
    this.fontSize = 13.0,
  });

  final double progress;
  final List<_Column> columns;
  final Color color;
  final double fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final columnWidth = size.width / columns.length;
    const glyphs = '01';
    final rng = math.Random(7);

    // Characters are spaced by the line height so they read as separate
    // digits. Packing them tighter turns the column into a solid streak.
    final step = fontSize * 1.35;

    for (var i = 0; i < columns.length; i++) {
      final col = columns[i];
      final x = columnWidth * (i + 0.5);

      // The whole column slides down by one full height per cycle.
      final head =
          ((progress * col.speed + col.offset) % 1.0) *
          (size.height + step * 8);
      const trail = 8;

      for (var t = 0; t < trail; t++) {
        final y = head - t * step;
        if (y < -step || y > size.height) continue;

        // Older characters are dimmer, so the head reads as the leading edge.
        final fade = 1.0 - t / trail;
        final glyph = glyphs[rng.nextInt(glyphs.length)];

        final painter = TextPainter(
          text: TextSpan(
            text: glyph,
            style: TextStyle(
              fontFamily: TypeScale.monoFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: color.withValues(alpha: 0.85 * fade),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        painter.paint(canvas, Offset(x - painter.width / 2, y));
      }
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) =>
      old.progress != progress || old.fontSize != fontSize;
}

/// Text that types itself out, one character at a time.
///
/// Used on the splash readout so the boot sequence reads as a machine
/// reporting, not as a static label. [onDone] fires once the last character
/// lands.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.onDone,
  });

  final String text;
  final TextStyle? style;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final count = (widget.text.length * _controller.value).round();
        final shown = widget.text.substring(
          0,
          count.clamp(0, widget.text.length),
        );

        // The caret blinks only while characters are still arriving.
        final caret = _controller.isCompleted ? '' : '_';

        return Text('$shown$caret', style: widget.style);
      },
    );
  }
}

/// Static CRT scanlines.
///
/// Drawn once, no animation, and kept faint. It is the cheapest way to say
/// "this is a console" without adding motion to the screen.
class ScanlineOverlay extends StatelessWidget {
  const ScanlineOverlay({super.key, this.opacity = 0.05, this.spacing = 3});

  final double opacity;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScanlinePainter(opacity: opacity, spacing: spacing),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter({required this.opacity, required this.spacing});

  final double opacity;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    var y = 0.0;
    while (y < size.height) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
      y += spacing;
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) =>
      old.opacity != opacity || old.spacing != spacing;
}

/// A brief RGB-split glitch, played once when the widget mounts.
///
/// Short by design: a glitch that repeats is wallpaper, and the wordmark it
/// sits on has to stay readable.
class GlitchText extends StatefulWidget {
  const GlitchText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final String text;
  final TextStyle style;
  final Duration duration;

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // The split is strongest at the start and settles to zero.
        final amount = (1 - t) * 4;

        return Stack(
          children: [
            // Cyan channel, shifted left.
            Transform.translate(
              offset: Offset(-amount, 0),
              child: Text(
                widget.text,
                style: widget.style.copyWith(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                ),
              ),
            ),
            // Magenta channel, shifted right.
            Transform.translate(
              offset: Offset(amount, 0),
              child: Text(
                widget.text,
                style: widget.style.copyWith(
                  color: const Color(0xFFFF4FD8).withValues(alpha: 0.5),
                ),
              ),
            ),
            // The real text on top.
            Text(widget.text, style: widget.style),
          ],
        );
      },
    );
  }
}

/// A scrolling hex stream that moves only while the bridge reports hashing.
///
/// The motion is the point: it is the app saying "data is arriving right
/// now". When hashing stops, the stream stops with it.
class HexTicker extends StatefulWidget {
  const HexTicker({
    super.key,
    this.active = true,
    this.height = 18,
    this.length = 48,
  });

  final bool active;
  final double height;
  final int length;

  @override
  State<HexTicker> createState() => _HexTickerState();
}

class _HexTickerState extends State<HexTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  late final String _hex = _buildHex(widget.length);

  static String _buildHex(int length) {
    final rng = math.Random(11);
    const chars = '0123456789abcdef';
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  @override
  void didUpdateWidget(HexTicker old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final shift = _controller.value * 200;
            return Stack(
              children: [
                Positioned(
                  left: -shift,
                  child: Text(
                    _hex,
                    maxLines: 1,
                    style:
                        TextStyle(
                          fontFamily: TypeScale.monoFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ).copyWith(
                          color: Palette.greenDim.withValues(alpha: 0.55),
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                Positioned(
                  left: 400 - shift,
                  child: Text(
                    _hex,
                    maxLines: 1,
                    style:
                        TextStyle(
                          fontFamily: TypeScale.monoFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ).copyWith(
                          color: Palette.greenDim.withValues(alpha: 0.55),
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
