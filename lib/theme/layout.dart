import 'package:flutter/material.dart';

/// How much horizontal room the shell has to work with.
///
/// The app was designed on a phone, so every screen reads top-to-bottom in one
/// column. On a desktop window that column stretches into an unreadable ribbon,
/// so the shell switches its furniture at a breakpoint: the bottom pill becomes
/// a side rail, and the single column becomes two.
enum CenLayout {
  /// Phone width. Bottom pill nav, one column, full-bleed cards.
  compact,

  /// Tablet or a narrow desktop window. Bottom pill nav, content capped.
  medium,

  /// Desktop window. Side rail nav, two columns, capped and centred content.
  expanded;

  /// Width below which the shell keeps the phone layout.
  static const double _compactCeiling = 640;

  /// Width above which the shell switches to the desktop furniture.
  static const double _expandedFloor = 1080;

  static CenLayout of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= _expandedFloor) return CenLayout.expanded;
    if (width >= _compactCeiling) return CenLayout.medium;
    return CenLayout.compact;
  }

  /// True while the window is too narrow for the side rail.
  bool get isCompact => this == CenLayout.compact;

  /// True once the window is wide enough for the desktop furniture.
  bool get isExpanded => this == CenLayout.expanded;

  /// Widest a content column may grow before it starts reading as a ribbon.
  /// Null means no cap, which is what the phone layout wants.
  ///
  /// Desktop deliberately keeps the cap off: the miner reads as a console, so
  /// the panels are meant to fill whatever window they are given rather than
  /// float in dead space at the edges of a wide screen.
  double? get contentMaxWidth => null;

  /// Horizontal gutter around content. Phones stay tight; desktop breathes.
  double get gutter => switch (this) {
    CenLayout.compact => _gutterCompact,
    CenLayout.medium => _gutterMedium,
    CenLayout.expanded => _gutterExpanded,
  };
}

// Spacing kept out of the enum so the class above stays a pure decision.
const double _gutterCompact = 16;
const double _gutterMedium = 24;
const double _gutterExpanded = 32;

/// Wraps a screen body so it behaves on a desktop window.
///
/// Three things happen here, and only on the wide layout: the content is
/// centred, it stops growing past [CenLayout.contentMaxWidth], and the gutter
/// widens. On a phone this is a pass-through, so the mobile layout is
/// untouched.
///
/// [scrollable] is false by default because most screens already scroll
/// themselves. Turning it on wraps the child in a [SingleChildScrollView],
/// which is only correct when the child is a plain column of widgets.
class CenContent extends StatelessWidget {
  const CenContent({super.key, required this.child, this.scrollable = false});

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final layout = CenLayout.of(context);
    final maxWidth = layout.contentMaxWidth;
    final gutter = layout.gutter;

    Widget body = child;
    if (scrollable) {
      body = SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: body,
      );
    } else {
      body = Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: body,
      );
    }

    if (maxWidth == null) return body;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: body,
      ),
    );
  }
}

/// Two columns on a desktop window, one on a phone.
///
/// The split is a plain ratio rather than a fixed width so the columns keep
/// their proportion as the window resizes. Below the expanded breakpoint the
/// children stack in order, which is the phone layout unchanged.
class CenColumns extends StatelessWidget {
  const CenColumns({
    super.key,
    required this.left,
    required this.right,
    this.ratio = 0.62,
    this.gap = 24,
  });

  final Widget left;
  final Widget right;

  /// Share of the width the left column takes. The mining dial wants less than
  /// half; the profile wants more.
  final double ratio;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!CenLayout.of(context).isExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          SizedBox(height: gap),
          right,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: (ratio * 100).round(), child: left),
        SizedBox(width: gap),
        Expanded(flex: 100 - (ratio * 100).round(), child: right),
      ],
    );
  }
}
