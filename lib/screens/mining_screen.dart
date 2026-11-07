import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../services/block_time.dart';
import '../services/mining_readout.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/cen_ui.dart';
import '../widgets/hacker_fx.dart';
import '../widgets/mining_dial.dart';

/// Mining console.
///
/// The top card is the one light surface in the app: it holds the reading the
/// user opens the app to see, so it gets the contrast. Everything below it is
/// supporting detail.
class MiningScreen extends StatelessWidget {
  const MiningScreen({
    super.key,
    required this.snapshot,
    required this.nodeAddress,
    required this.onOpenWorkers,
    required this.onOpenActivity,
    required this.onConnectNode,
    this.onSetMining,
  });

  final MinerSnapshot snapshot;
  final String? nodeAddress;
  final VoidCallback onOpenWorkers;
  final VoidCallback onOpenActivity;
  final VoidCallback onConnectNode;

  /// Starts or stops mining. Null disables the control (an external ASIC
  /// bridge has no internal miner to start or stop).
  final ValueChanged<bool>? onSetMining;

  @override
  Widget build(BuildContext context) {
    final readout = MiningReadout.from(snapshot);
    final layout = CenLayout.of(context);

    final summary = _SummaryCard(
      readout: readout,
      nodeAddress: nodeAddress,
      onConnectNode: onConnectNode,
    );
    final dial = _DialBlock(
      readout: readout,
      onTap: onOpenWorkers,
      onSetMining: onSetMining,
    );
    final stats = _StatsStrip(readout: readout);
    // A hex stream that runs only while the bridge reports hashing: the
    // motion is the app saying data is arriving right now.
    final hex = HexTicker(active: readout.active);
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
            hex,
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
                  hex,
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

/// Light card: worker identity and the live readings as coloured chips.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.readout,
    required this.nodeAddress,
    required this.onConnectNode,
  });

  final MiningReadout readout;
  final String? nodeAddress;
  final VoidCallback onConnectNode;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final connected = readout.hashrateGhs != null || readout.workerName != null;

    return Container(
      padding: const EdgeInsets.all(Palette.lg),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(Palette.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Worker identity on the left; the live numbers form a column of
          // coloured chips on the right. The name clamps to one line so a long
          // name cannot shove the chips off the card.
          Row(
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
                      readout.workerName ?? l10n.commonNoWorker,
                      maxLines: 1,
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
              // Connected: hashrate, bridge "connect", and difficulty as a
              // stack. Not connected: the idle pill, exactly as before.
              if (connected)
                _ReadingChips(readout: readout)
              else
                LiveStatus(
                  label: l10n.statusIdle,
                  active: false,
                  tint: Palette.greenDim,
                  idleColor: Palette.creamInkDim,
                ),
            ],
          ),
          if (!connected) ...[
            const SizedBox(height: Palette.lg),
            Text(
              l10n.mineBridgeSilent,
              style: TypeScale.caption(context).copyWith(color: Palette.creamInkDim),
            ),
            const SizedBox(height: Palette.sm),
            TextButton(
              onPressed: onConnectNode,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.mineSetBridge),
            ),
          ],
        ],
      ),
    );
  }
}

/// The live numbers as a right-aligned column of chips against the worker
/// name. Yellow is the hashrate, blue says the bridge is connected, and the
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
        // Hashrate first: it sits on the same line as the worker name.
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

/// A centred readout line under the dial: the session uptime and the last
/// accepted share, in the concept's shell-prompt style.
class _DialCaption extends StatelessWidget {
  const _DialCaption({required this.readout, required this.onTap});

  final MiningReadout readout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final latest = readout.latestBlockHash;
    return Column(
      children: [
        // The dial centre is now the start/stop control, so the caption states
        // the switch position. Where no internal miner runs (no mining address
        // configured — the common pre-release state), say so plainly instead
        // of steering the reader to the worker list.
        Text(
          readout.miningAvailable
              ? (readout.miningEnabled ? l10n.mineMiningOn : l10n.mineMiningOff)
              : l10n.mineNoInternalMiner,
          style: TypeScale.monoMuted(
            context,
            size: 10,
          ).copyWith(letterSpacing: 1.6),
        ),
        const SizedBox(height: Palette.sm),
        Text(
          'UPTIME ${_uptime(readout.bridgeUptime)}',
          style: TypeScale.mono(
            context,
            size: 11,
          ).copyWith(color: Palette.creamDim),
        ),
        const SizedBox(height: Palette.sm),
        Text(
          latest == null
              ? l10n.mineWaitingShare
              : '${l10n.mineShareAccepted(shortHash(latest, head: 8, tail: 6))}'
                    '${readout.difficulty == null ? '' : ' diff-${readout.difficulty!.toStringAsFixed(2)}'}',
          style: TypeScale.mono(
            context,
            size: 10,
          ).copyWith(color: Palette.greenDim),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Formats seconds as HH:MM:SS, the concept's uptime shape. Returns 00:00:00
/// when the bridge has not reported an uptime.
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
        // Acceptance is what the dial shows, so it is stated once here rather
        // than repeated in the stats strip below.
        Text(
          rate == null
              ? l10n.mineAcceptanceNoShares
              : l10n.mineAcceptanceRate((rate * 100).toStringAsFixed(0)),
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
/// When no internal miner exists (an external ASIC) the disc shrinks, dims,
/// and stops responding — the ring still opens the worker list.
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

/// Three real counts, each with its unit on its own line as in the concept.
///
/// No price: CEN is not listed anywhere, so a price here would be invented.
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
              value: readout.sessionBlocks?.toString() ?? '—',
              unit: 'CEN',
              label: l10n.mineSessionLabel,
              color: Palette.goldLight,
            ),
          ),
          const StatDivider(),
          Expanded(
            child: StatCell(
              value: readout.totalBlocks?.toString() ?? '—',
              unit: 'CEN',
              label: l10n.mineTotalLabel,
            ),
          ),
          const StatDivider(),
          Expanded(
            child: StatCell(
              value: readout.shares?.toString() ?? '—',
              unit: l10n.mineSharesUnit,
              label: l10n.mineAcceptedLabel,
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
