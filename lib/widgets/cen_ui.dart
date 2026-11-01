import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// The standard dark card. Every panel in the app sits on this.
///
/// [CenCard.glass] is the translucent layered variant and [CenCard.light] the
/// cream one; both are the same widget with different fills, so the app keeps
/// one card shape everywhere.
class CenCard extends StatelessWidget {
  const CenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Palette.lg),
    this.color = Palette.surface,
    this.border,
    this.radius = Palette.cardRadius,
    this.glow,
  });

  /// A layered, faintly translucent panel.
  ///
  /// The fill is semi-opaque rather than solid and the hairline border is
  /// brighter at the top edge than the bottom, which reads as a pane of glass
  /// sitting over the background instead of a flat rectangle.
  ///
  /// Not const: the translucent fill is built with `withValues`, which is not
  /// a constant expression.
  CenCard.glass({
    required this.child,
    this.padding = const EdgeInsets.all(Palette.lg),
    this.radius = Palette.cardRadius,
    this.glow,
  }) : color = Palette.surfaceHigh.withValues(alpha: 0.62),
       border = const BorderSide(color: Color(0x1FFFFFFF));

  /// The cream panel. Used where the concept puts a light card against the
  /// dark canvas: the identity card on Profile and the balance on Wallet.
  const CenCard.light({
    required this.child,
    this.padding = const EdgeInsets.all(Palette.lg),
    this.radius = Palette.cardRadius,
    this.glow,
  }) : color = Palette.surfaceLight,
       border = null;

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final BorderSide? border;
  final double radius;

  /// Optional accent drawn as a soft pool of light behind the card. Gives the
  /// panel depth against the flat background without a drop shadow, which
  /// would read as a material elevation rather than a glow.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.fromBorderSide(border!),
      ),
      child: child,
    );

    if (glow == null) return card;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: glow!.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: -6,
          ),
        ],
      ),
      child: card,
    );
  }
}

/// A soft pool of light, used behind the dial and the balance to lift them off
/// the canvas. Purely decorative and never interactive.
class GlowOrb extends StatelessWidget {
  const GlowOrb({
    super.key,
    required this.color,
    this.size = 260,
    this.opacity = 0.14,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slow band of light travelling down the screen once.
///
/// The scanlines imply a CRT; this is the refresh beam that makes the
/// implication literal. It runs a single pass and holds at the bottom rather
/// than repeating, so it reads as a one-off sweep instead of a looping
/// animation that competes with the readings.
class ScanSweep extends StatefulWidget {
  const ScanSweep({super.key});

  @override
  State<ScanSweep> createState() => _ScanSweepState();
}

class _ScanSweepState extends State<ScanSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  @override
  void initState() {
    super.initState();
    // One pass, then hold. Repeating would turn a texture into a distraction.
    _controller.forward();
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
        final t = _controller.value;
        // The band travels from just above the top to just below the bottom,
        // then parks out of sight.
        final top = (t * 1.4 - 0.2) * MediaQuery.sizeOf(context).height;

        return Stack(
          children: [
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Palette.white.withValues(alpha: 0),
                      Palette.white.withValues(alpha: 0.045),
                      Palette.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small tracked label that sits above a value.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = Palette.slate});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TypeScale.eyebrow(context).copyWith(color: color),
    );
  }
}

/// Fully rounded badge. Used for CEL, VERIFIED, LV, ON.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.background = Palette.surfaceHigh,
    this.foreground = Palette.creamDim,
    this.border,
    this.dense = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final BorderSide? border;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Palette.sm : Palette.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Palette.pill),
        border: border == null ? null : Border.fromBorderSide(border!),
      ),
      child: Text(
        label,
        style: TypeScale.caption(context).copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A dot that marks a real state: mining active, node reachable.
///
/// The dot only appears when something is genuinely in that state. No dot is
/// drawn for decoration.
class StateDot extends StatelessWidget {
  const StateDot({
    super.key,
    required this.active,
    this.color = Palette.green,
    this.size = 7,
  });

  final bool active;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Green-tinted status pill with a live dot.
class LiveStatus extends StatelessWidget {
  const LiveStatus({
    super.key,
    required this.label,
    this.active = true,
    this.tint = Palette.green,
  });

  final String label;
  final bool active;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final color = active ? tint : Palette.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Palette.md, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Palette.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StateDot(active: active, color: color),
          const SizedBox(width: Palette.sm),
          Text(
            label,
            style: TypeScale.caption(context).copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid gold capsule: the one primary action on a screen.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17),
          const SizedBox(width: Palette.sm),
        ],
        Text(label),
      ],
    );

    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: Palette.ink,
        disabledBackgroundColor: Palette.surfaceHigh,
        disabledForegroundColor: Palette.slate,
        minimumSize: Size(expand ? double.infinity : 0, 46),
        padding: const EdgeInsets.symmetric(horizontal: Palette.lg),
      ),
      child: child,
    );

    return expand ? button : Center(child: button);
  }
}

/// Dark bordered capsule: secondary actions.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: Palette.creamDim),
          const SizedBox(width: Palette.sm),
        ],
        Text(label),
      ],
    );

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.cream,
        side: const BorderSide(color: Palette.surfaceHigh),
        disabledForegroundColor: Palette.slate,
        minimumSize: Size(expand ? double.infinity : 0, 46),
        padding: const EdgeInsets.symmetric(horizontal: Palette.lg),
      ),
      child: child,
    );
  }
}

/// A row in the profile settings list: tinted icon square, label, trailing.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.tint = Palette.green,
    this.danger = false,
    this.flat = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color tint;
  final bool danger;

  /// Drop this row's own panel and border.
  ///
  /// A stack of flat rows shares one card and is separated by hairlines,
  /// which reads as a single settings group rather than five tiles that
  /// happen to be adjacent.
  final bool flat;

  /// Suppress the hairline under the final row of a flat stack.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? Palette.red : tint;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Palette.lg, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: Palette.md),
          Expanded(
            child: Text(
              label,
              style: TypeScale.title(context).copyWith(
                // White, as the concept prints its menu labels. Cream is
                // the body text; the settings list is the accent.
                color: danger ? Palette.red : Palette.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ?trailing,
          if (trailing == null && onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: Palette.creamDim),
        ],
      ),
    );

    if (flat) {
      return Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0x0FFFFFFF))),
        ),
        child: InkWell(onTap: onTap, child: content),
      );
    }

    return Material(
      // Translucent fill with a hairline top edge: the row reads as a pane
      // over the background rather than a solid block, which is what keeps
      // the stack of settings from looking like a table.
      color: Palette.surfaceHigh.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        side: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        child: content,
      ),
    );
  }
}

/// One column of the stats strip: value over label.
///
/// The unit line is optional and every column in a strip should agree on
/// whether it has one, otherwise the row goes ragged. Centred rather than
/// left-aligned: in a four-column strip the labels differ in length, and
/// centring is what keeps the columns reading as a grid.
class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.mono = true,
    this.color,
  });

  final String value;
  final String label;

  /// Optional line between the value and the label, as in the concept
  /// (`12.4` / `CEL` / `SESSION`). Use it in every column of a strip or in
  /// none of them.
  final String? unit;

  final bool mono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // White by default, as the concept prints its stat numerals. Gold is
    // passed explicitly where one figure is the one that matters.
    final style = mono
        ? TypeScale.mono(
            context,
            size: 16,
          ).copyWith(color: color ?? Palette.white, fontWeight: FontWeight.w700)
        : TypeScale.headline(context).copyWith(color: color ?? Palette.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(value, style: style),
        ),
        if (unit != null) Eyebrow(unit!, color: Palette.goldLight),
        Eyebrow(label, color: Palette.slate),
      ],
    );
  }
}

/// Thin vertical rule between stat cells.
class StatDivider extends StatelessWidget {
  const StatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: Palette.surfaceHigh);
  }
}

/// Honest empty state: says why it is empty and what fills it.
class CenEmpty extends StatelessWidget {
  const CenEmpty({super.key, required this.reason, this.action, this.onAction});

  final String reason;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Palette.lg),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        border: Border.all(color: Palette.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason, style: TypeScale.label(context)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: Palette.md),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}
