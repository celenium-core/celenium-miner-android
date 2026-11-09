import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/block_time.dart';
import '../services/mining_readout.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/cen_ui.dart';
import '../widgets/mining_dial.dart';

/// Mining console.
///
/// The top card is the one light surface in the app: it holds the reading the
/// user opens the app to see, so it gets the contrast. Everything below it is
/// supporting detail.
class MiningScreen extends StatelessWidget {
  const MiningScreen({
    super.key,
    required this.readout,
    required this.nodeAddress,
    required this.onOpenActivity,
    this.onConnectNode,
    this.onSetMining,
  });

  final MiningReadout readout;
  final String? nodeAddress;
  final VoidCallback onOpenActivity;
  final VoidCallback? onConnectNode;

  /// Starts or stops the local miner. The dial's inner disc calls this with
  /// the new switch position; the engine does the hashing.
  final ValueChanged<bool>? onSetMining;

  @override
  Widget build(BuildContext context) {
    final readout = this.readout;
    final layout = CenLayout.of(context);

    final summary = _SummaryCard(
      readout: readout,
      nodeAddress: nodeAddress,
    );
    final dial = _DialBlock(
      readout: readout,
      onTap: onOpenActivity,
      onSetMining: onSetMining,
    );
    final stats = _StatsStrip(readout: readout);
    final latest = _LatestLine(readout: readout, onTap: onOpenActivity);

    // Phone: one column, top to bottom, exactly as designed.
    if (!layout.isExpanded) {
      return CenContent(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: Palette.sm),
            summary,
            const SizedBox(height: Palette.xl),
            dial,
            const SizedBox(height: Palette.xl),
            stats,
            const SizedBox(height: Palette.lg),
            latest,
            const SizedBox(height: Palette.xxl),
          ],
        ),
      );
    }

    // Desktop: the reading and the dial share the left column, the supporting
    // detail stacks on the right. The dial wants less than half the width or
    // it floats in dead space, so the split leans left.
    return CenContent(
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.only(top: Palette.lg, bottom: Palette.xxl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: Palette.xl),
                  dial,
                ],
              ),
            ),
            const SizedBox(width: Palette.xl),
            Expanded(
              flex: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stats,
                  const SizedBox(height: Palette.lg),
                  latest,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light card: the worker label and the live readings as coloured chips, or
/// a labelled status pill when the engine is not hashing.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.readout,
    required this.nodeAddress,
  });

  final MiningReadout readout;
  final String? nodeAddress;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final status = readout.status ?? MinerStatus.idle;
    // A bridge snapshot has no engine lifecycle (`status` is null) yet still
    // reports hashing through `active`, so that flag also drives the streaming
    // chips instead of a false "idle" pill.
    final streaming = readout.active ||
        status == MinerStatus.mining ||
        status == MinerStatus.connecting;
    final statusLabel = switch (status) {
      MinerStatus.mining => l10n.mineMiningOn,
      MinerStatus.connecting => l10n.mineConnecting,
      MinerStatus.needsWallet => l10n.mineNeedsWallet,
      MinerStatus.limitReached => l10n.mineLimitReached,
      MinerStatus.error => l10n.mineError,
      _ => l10n.statusIdle,
    };

    return Container(
      padding: const EdgeInsets.all(Palette.lg),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(Palette.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Palette.field,
              shape: BoxShape.circle,
            ),
            child: Center(child: BrandMark(size: 22, onDark: true)),
          ),
          const SizedBox(width: Palette.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mineCardLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.title(context).copyWith(
                    color: Palette.creamInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nodeAddress ?? l10n.mineNodeNotSet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.mono(
                    context,
                    size: 10,
                  ).copyWith(color: Palette.creamInkDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: Palette.sm),
          // Hashing (or connecting): hashrate, link and difficulty as a stack.
          // Any other state: a pill that names it (idle, wallet, limit, error).
          if (streaming)
            _ReadingChips(readout: readout)
          else
            LiveStatus(
              label: statusLabel,
              active: false,
              tint: Palette.greenDim,
              idleColor: Palette.creamInkDim,
            ),
        ],
      ),
    );
  }
}

/// The live numbers as a right-aligned column of chips against the worker
/// name. Yellow is the hashrate, blue says the pool link is live, and the
/// share difficulty — a separate pool target, not a unit of hashrate — earns
/// its own neutral grey chip.
class _ReadingChips extends StatelessWidget {
  const _ReadingChips({required this.readout});

  final MiningReadout readout;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hashrate first: it sits on the same line as the address.
        _MetricChip(
          label: readout.hashrateGhs == null
              ? '—'
              : formatHashrate(readout.hashrateGhs!),
          fill: Palette.amber,
          style: TypeScale.mono(context, size: 11).copyWith(
            color: Palette.amberInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Palette.xs),
        _MetricChip(
          label: l10n.mineConnected,
          fill: Palette.goldDim,
          style: TypeScale.caption(context).copyWith(
            color: Palette.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (readout.difficulty != null) ...[
          const SizedBox(height: Palette.xs),
          _MetricChip(
            label: 'DIFF ${readout.difficulty!.toStringAsFixed(2)}',
            fill: Palette.slateSoft,
            style: TypeScale.mono(context, size: 10).copyWith(
              color: Palette.creamInkDim,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// One machine reading as a small filled pill. The caller picks the fill and
/// text style, so the three chips share a shape without sharing a meaning.
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.fill,
    required this.style,
  });

  final String label;
  final Color fill;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Palette.md, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Palette.pill),
      ),
      child: Text(label, style: style),
    );
  }
}

/// A centred readout under the dial: the engine phase and the session uptime as
/// slim cards, then the reward estimate in the concept's shell-prompt style.
class _DialCaption extends StatelessWidget {
  const _DialCaption({required this.readout, required this.onTap});

  final MiningReadout readout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final status = readout.status ?? MinerStatus.idle;
    final mining = status == MinerStatus.mining;

    // One line that answers "what do I do now?", keyed to the phase. The state
    // bar above names the phase (MINING ON, 24H LIMIT REACHED…); this line
    // names the action. It is suppressed for connecting / needs-wallet / error,
    // where the next move is not the logo.
    final String? hint = switch (status) {
      MinerStatus.mining => l10n.mineTapToStop,
      MinerStatus.limitReached => l10n.mineRestartHint,
      MinerStatus.connecting ||
      MinerStatus.needsWallet ||
      MinerStatus.error => null,
      _ => l10n.mineTapToStart,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateBar(status: status),
        // The session clock only means something while hashing, so it gets its
        // own card and only appears then.
        if (mining) ...[
          const SizedBox(height: Palette.sm),
          _ReadoutChip(
            child: Text(
              'UPTIME ${_uptime(readout.sessionUptime)}',
              textAlign: TextAlign.center,
              style: TypeScale.mono(context, size: 11).copyWith(
                color: Palette.creamDim,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
        if (hint != null) ...[
          const SizedBox(height: Palette.sm),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TypeScale.monoMuted(context, size: 10).copyWith(
              color: Palette.creamDim,
              letterSpacing: 0.4,
            ),
          ),
        ],
        if (readout.estimatedCen != null) ...[
          const SizedBox(height: Palette.md),
          Text(
            l10n.walletMiningReward.toUpperCase(),
            textAlign: TextAlign.center,
            style: TypeScale.monoMuted(context, size: 9).copyWith(
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '≈ ${formatCoin(readout.estimatedCen!, locale: Localizations.localeOf(context).toString())}',
            textAlign: TextAlign.center,
            style: TypeScale.mono(
              context,
              size: 14,
            ).copyWith(
              color: Palette.goldLight,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

/// A single translucent bar under the dial that pairs a status dot with the
/// engine phase. While mining it tints green and carries a green border, so
/// ON/OFF reads at a glance and not only through the word. The instruction line
/// below tells the user how to continue when the bar shows a limit or an error.
class _StateBar extends StatelessWidget {
  const _StateBar({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final mining = status == MinerStatus.mining;
    final String statusLine = switch (status) {
      MinerStatus.mining => l10n.mineMiningOn,
      MinerStatus.connecting => l10n.mineConnecting,
      MinerStatus.needsWallet => l10n.mineNeedsWallet,
      MinerStatus.limitReached => l10n.mineLimitReached,
      MinerStatus.error => l10n.mineError,
      _ => l10n.mineMiningOff,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Palette.lg, vertical: 12),
      decoration: BoxDecoration(
        color: mining
            ? Palette.green.withValues(alpha: 0.10)
            : Palette.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        border: Border.all(
          color: mining
              ? Palette.green.withValues(alpha: 0.45)
              : const Color(0x1AFFFFFF),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StateDot(active: true, color: mining ? Palette.green : Palette.slate),
          const SizedBox(width: Palette.sm),
          Text(
            statusLine,
            style: TypeScale.mono(context, size: 12).copyWith(
              color: mining ? Palette.green : Palette.creamDim,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A slim, translucent card shared by the engine-phase and uptime readouts so
/// the two lines sit as one family beneath the dial instead of floating bare.
class _ReadoutChip extends StatelessWidget {
  const _ReadoutChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Palette.lg, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: child,
    );
  }
}

/// Formats seconds as HH:MM:SS, the concept's uptime shape. Returns 00:00:00
/// when no session uptime has been reported.
String _uptime(int? seconds) {
  if (seconds == null) return '00:00:00';
  final d = Duration(seconds: seconds);
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Dial plus the caption that says what tapping it does.
class _DialBlock extends StatelessWidget {
  const _DialBlock({
    required this.readout,
    required this.onTap,
    this.onSetMining,
  });

  final MiningReadout readout;
  final VoidCallback onTap;
  final ValueChanged<bool>? onSetMining;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final rate = readout.acceptanceRate;

    return Column(
      children: [
        Semantics(
          label: l10n.mineAcceptanceSemantics,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: MiningDial(rate: rate, active: readout.active, size: 232),
              ),
              _MiningToggle(
                size: 232,
                enabled: readout.miningEnabled,
                available: readout.miningAvailable,
                onSetMining: onSetMining,
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.lg),
        // Acceptance is what the ring shows, so the percentage is printed only
        // once a share exists. Before the first share there is nothing to
        // measure — an empty ring is the honest state, with no label at all.
        if (rate != null)
          Text(
            l10n.mineAcceptanceRate((rate * 100).toStringAsFixed(0)),
            textAlign: TextAlign.center,
            style: TypeScale.mono(
              context,
              size: 12,
            ).copyWith(color: Palette.goldLight, letterSpacing: 1.4),
          ),
        const SizedBox(height: Palette.md),
        _DialCaption(readout: readout, onTap: onTap),
      ],
    );
  }
}

/// The big logo in the dial centre, repurposed as the mining on/off button.
///
/// A white neon halo lifts the disc off the dial while mining is on, so the
/// switch position is legible at a glance; off is flat and slightly dimmed.
/// The local engine always exposes a start/stop control, so `available` only
/// needs [onSetMining] to be non-null for the disc to respond.
class _MiningToggle extends StatelessWidget {
  const _MiningToggle({
    required this.size,
    required this.enabled,
    required this.available,
    required this.onSetMining,
  });

  /// The dial's size, keeping the disc proportional to the ring.
  final double size;

  final bool enabled;
  final bool available;
  final ValueChanged<bool>? onSetMining;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final canToggle = available && onSetMining != null;
    final disc = available ? size * 0.46 : size * 0.40;

    return Semantics(
      button: true,
      enabled: canToggle,
      label: l10n.mineToggleSemantics,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: disc,
        height: disc,
        decoration: BoxDecoration(
          color: Palette.cream,
          shape: BoxShape.circle,
          // On: a soft dark rim raises the disc (timbul), then two white halos
          // give the neon rim around the logo. Off: a flat, faint drop shadow.
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    offset: const Offset(0, 3),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: Palette.white.withValues(alpha: 0.90),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Palette.white.withValues(alpha: 0.40),
                    blurRadius: 44,
                    spreadRadius: 10,
                  ),
                ]
              : const [
                  BoxShadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 3),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canToggle ? () => onSetMining!(!enabled) : null,
            customBorder: const CircleBorder(),
            child: Center(
              child: Opacity(
                opacity: available ? 1.0 : 0.45,
                child: BrandMark(size: size * 0.30, onDark: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three session counts for a local phone miner: accepted shares, rejected
/// shares and the live hashrate. No block count — a phone submits shares, it
/// does not find blocks — and no price, because CEN is not listed anywhere.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.readout});

  final MiningReadout readout;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return CenCard(
      child: Row(
        children: [
          Expanded(
            child: StatCell(
              value: readout.shares?.toString() ?? '—',
              unit: l10n.mineSharesUnit,
              label: l10n.mineAcceptedLabel,
              color: Palette.goldLight,
            ),
          ),
          const StatDivider(),
          Expanded(
            child: StatCell(
              value: readout.stale?.toString() ?? '—',
              unit: l10n.mineSharesUnit,
              label: l10n.mineRejectedLabel,
            ),
          ),
          const StatDivider(),
          Expanded(
            child: StatCell(
              value: readout.hashrateGhs == null
                  ? '—'
                  : formatHashrate(readout.hashrateGhs!),
              label: l10n.mineHashRate,
            ),
          ),
        ],
      ),
    );
  }
}

/// Last accepted block, straight from the bridge.
class _LatestLine extends StatelessWidget {
  const _LatestLine({required this.readout, required this.onTap});

  final MiningReadout readout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final hash = readout.latestBlockHash;
    final rawTime = readout.latestBlockTime;
    final timeLabel = rawTime == null
        ? ''
        : ' · ${friendlyBlockTime(rawTime, todayLabel: l10n.commonToday, yesterdayLabel: l10n.commonYesterday)}';

    return Material(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(Palette.rowRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Palette.lg,
            vertical: 14,
          ),
          child: Row(
            children: [
              Text('>', style: TypeScale.monoGold(context, size: 13)),
              const SizedBox(width: Palette.sm),
              Expanded(
                child: Text(
                  hash == null
                      ? l10n.mineNoBlock
                      : '${l10n.mineBlockAccepted(shortHash(hash))}$timeLabel',
                  style: TypeScale.mono(
                    context,
                    size: 11,
                  ).copyWith(color: Palette.slateLight),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Palette.slate),
            ],
          ),
        ),
      ),
    );
  }
}