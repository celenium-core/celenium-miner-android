import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// The standard dark card. Every panel in the app sits on this.
class CenCard extends StatelessWidget {
  const CenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Palette.lg),
    this.color = Palette.surface,
    this.border,
    this.radius = Palette.cardRadius,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final BorderSide? border;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.fromBorderSide(border!),
      ),
      child: child,
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
    return Text(text.toUpperCase(), style: TypeScale.eyebrow(context).copyWith(color: color));
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
      padding: EdgeInsets.symmetric(horizontal: dense ? Palette.sm : Palette.md, vertical: dense ? 3 : 5),
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
  const StateDot({super.key, required this.active, this.color = Palette.green, this.size = 7});

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
  const LiveStatus({super.key, required this.label, this.active = true, this.tint = Palette.green});

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
            style: TypeScale.caption(context).copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

/// Solid gold capsule: the one primary action on a screen.
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, this.onPressed, this.icon, this.expand = true});

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
        if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: Palette.sm)],
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
  const GhostButton({super.key, required this.label, this.onPressed, this.icon, this.expand = true});

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
        if (icon != null) ...[Icon(icon, size: 17, color: Palette.creamDim), const SizedBox(width: Palette.sm)],
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
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color tint;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? Palette.red : tint;

    return Material(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(Palette.rowRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        child: Padding(
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
                    color: danger ? Palette.red : Palette.cream,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              ?trailing,
              if (trailing == null && onTap != null)
                const Icon(Icons.chevron_right, size: 18, color: Palette.slate),
            ],
          ),
        ),
      ),
    );
  }
}

/// One column of the stats strip: value over unit over label.
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

  /// The unit line between the value and the label, as in the concept
  /// (`12.4` / `CEL` / `SESSION`). Omitted when there is nothing to say.
  final String? unit;

  final bool mono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = mono
        ? TypeScale.mono(context, size: 16).copyWith(color: color ?? Palette.cream, fontWeight: FontWeight.w700)
        : TypeScale.headline(context).copyWith(color: color ?? Palette.cream);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
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
