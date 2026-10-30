import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What an ad slot is currently doing.
///
/// Every state is reachable and handled. An ad area that only draws its happy
/// path either shifts the layout when the ad fails or reserves space that
/// shows nothing (R-27, R-40).
enum AdSlotState {
  /// No ad unit id is configured, so the slot reserves no space at all.
  unconfigured,

  /// A unit is configured but no ad has arrived yet. The slot reserves no
  /// space: a placeholder holding room for an ad is not an ad.
  awaitingSdk,

  /// A real ad is on screen. Only reachable once an ad SDK is wired in.
  loaded,

  /// The request came back with no ad to show, so the slot collapses.
  noFill,

  /// The user closed the slot. It stays closed.
  dismissed,
}

/// A dismissible banner slot pinned above the navigation.
///
/// It draws only when a real ad is loaded. A configured-but-empty slot is
/// completely invisible, so the app never holds screen space for an ad that
/// has not arrived (R-38).
///
/// Why the bottom: this app exists to answer "is my rig healthy", and that
/// answer sits at the top of the screen. Advertising is not that decision, so
/// the slot goes as far from it as the layout allows (R-03, C-3).
///
/// Why a fixed height: once an ad appears it must not grow or shrink, because
/// a slot that resizes mid-session pushes the navigation and the content
/// under the user's thumb. The height is reserved up front so nothing moves
/// (R-40).
///
/// Why a solid surface and not glass: the top bar already holds the app's one
/// glass element. A second frosted surface would blow the R-10 dose cap and
/// compete with it for the foreground.
class AdBanner extends StatelessWidget {
  const AdBanner({
    required this.state,
    required this.onDismiss,
    this.child,
    super.key,
  });

  final AdSlotState state;

  /// Called when the user closes the slot. The caller persists the dismissal;
  /// this widget only reports the intent.
  final VoidCallback onDismiss;

  /// The ad itself, supplied once an ad SDK is loaded.
  final Widget? child;

  /// Reserved height of the slot. Also the minimum touch target row for the
  /// close button (R-03).
  static const double height = 56;

  /// Vertical space the banner occupies, margins included. The screen pads its
  /// content by exactly this much so the floating banner never covers the last
  /// row of a list (R-03).
  static const double footprint = height + Space.sm;

  /// True only when a real ad will actually be drawn.
  ///
  /// The screen asks this so it reserves the slot's space exactly when a
  /// banner is really on screen. Without it, a configured-but-empty slot
  /// would push the content aside for an ad that never arrived.
  static bool willShow(AdSlotState state, Widget? ad) =>
      state == AdSlotState.loaded && ad != null;

  @override
  Widget build(BuildContext context) {
    // Only a real ad draws. Every other state is invisible, so the banner
    // appears when an ad actually arrives and never as a placeholder (R-38).
    if (!willShow(state, child)) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    // Floating card, not an inline bar: it overlays the content instead of
    // pushing it, so the layout never moves when the ad loads or fails.
    return Padding(
      padding: const EdgeInsets.only(
        left: Space.md,
        right: Space.md,
        bottom: Space.sm,
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: Palette.surfaceHigh),
          // The only shadow in the app: it is what reads as "floating above
          // the content" rather than "a row that shifted in" (R-12).
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: Space.lg, right: Space.xs),
        child: Row(
        children: [
          // The "Ad" label is required by ad-network policy and keeps the slot
          // honest about what it is (R-38).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            decoration: BoxDecoration(
              border: Border.all(color: Palette.surfaceHigh),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(
              'Ad',
              style: textTheme.labelSmall?.copyWith(color: Palette.textSecondary),
            ),
          ),
          const SizedBox(width: Space.md),
          // Reaching here means an ad is really loaded, so child is non-null.
          Expanded(child: child!),
          SizedBox(
            // 44px minimum touch target with the icon centred inside it.
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Close ad',
              icon: const Icon(Icons.close, size: 18),
              color: Palette.textSecondary,
              onPressed: onDismiss,
            ),
          ),
          ],
        ),
      ),
    );
  }
}
