import 'package:flutter/material.dart';

import '../models/bridge.dart';
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
  });

  final MinerSnapshot snapshot;
  final String? nodeAddress;
  final VoidCallback onOpenWorkers;
  final VoidCallback onOpenActivity;
  final VoidCallback onConnectNode;

  @override
  Widget build(BuildContext context) {
    final readout = MiningReadout.from(snapshot);
    final layout = CenLayout.of(context);

    final summary = _SummaryCard(
      readout: readout,
      nodeAddress: nodeAddress,
      onConnectNode: onConnectNode,
    );
    final dial = _DialBlock(readout: readout, onTap: onOpenWorkers);
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

/// Light card: identity, hashrate, difficulty, live status.
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
    final connected = readout.hashrateGhs != null || readout.workerName != null;

    return Container(
      padding: const EdgeInsets.all(Palette.lg),
      decoration: BoxDecoration(
        color: Palette.surfaceLight,
        borderRadius: BorderRadius.circular(Palette.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: identity on the left, hashrate on the right, exactly as
          // the concept lays it out.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Palette.ink,
                  shape: BoxShape.circle,
                ),
                child: Center(child: BrandMark(size: 24, onDark: true)),
              ),
              const SizedBox(width: Palette.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      readout.workerName ?? 'No worker',
                      style: TypeScale.title(context).copyWith(
                        color: Palette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nodeAddress ?? 'node not set',
                      style: TypeScale.monoInk(
                        context,
                        size: 10,
                      ).copyWith(color: Palette.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Palette.sm),
              // Hash rate block sits on the right, with the level badge
              // beside the value.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Eyebrow('Hash rate', color: Palette.slate),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        readout.hashrateGhs == null
                            ? '—'
                            : formatHashrate(readout.hashrateGhs!),
                        style: TypeScale.hero(context)
                            .copyWith(color: Palette.ink, fontSize: 30),
                      ),
                      // Gold level badge, as in the concept. The level is
                      // derived from the hashrate so the number means
                      // something rather than being decoration.
                      if (readout.hashrateGhs != null) ...[
                        const SizedBox(width: Palette.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Palette.md,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Palette.gold,
                            borderRadius: BorderRadius.circular(Palette.pill),
                          ),
                          child: Text(
                            'LV.${readout.hashrateGhs!.floor().clamp(1, 99)}',
                            style: TypeScale.caption(context).copyWith(
                              color: Palette.ink,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Palette.lg),
          // Lower row: worker and difficulty on the left, live status on the
          // right, as in the concept.
          Row(
            children: [
              Expanded(
                child: Text(
                  '${readout.workerName ?? 'WORKER-00'} · DIFF ${readout.difficulty == null ? '—' : readout.difficulty!.toStringAsFixed(2)}',
                  style: TypeScale.monoInk(
                    context,
                    size: 10,
                  ).copyWith(color: Palette.slate),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Palette.sm),
              LiveStatus(
                label: readout.active ? 'MINING ACTIVE' : 'IDLE',
                active: readout.active,
                tint: readout.active ? Palette.greenDim : Palette.slate,
              ),
            ],
          ),
          if (!connected) ...[
            const SizedBox(height: Palette.lg),
            Text(
              'The bridge has not answered. Set its address to start reading live figures.',
              style: TypeScale.caption(context).copyWith(color: Palette.slate),
            ),
            const SizedBox(height: Palette.sm),
            TextButton(
              onPressed: onConnectNode,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Set bridge address'),
            ),
          ],
        ],
      ),
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
    return Column(
      children: [
        // The app reads the bridge; it does not start or stop hashing, so the
        // control here opens the worker list rather than claiming to pause.
        Text(
          '[ TAP FOR WORKERS ]',
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
          readout.latestBlockHash == null
              ? '> waiting for first share'
              : '> share accepted ${shortHash(readout.latestBlockHash!, head: 8, tail: 6)}'
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
  const _DialBlock({required this.readout, required this.onTap});

  final MiningReadout readout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = readout.acceptanceRate;

    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Share acceptance. Open workers.',
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: MiningDial(rate: rate, active: readout.active, size: 232),
          ),
        ),
        const SizedBox(height: Palette.lg),
        // Acceptance is what the dial shows, so it is stated once here rather
        // than repeated in the stats strip below.
        Text(
          rate == null
              ? 'ACCEPTANCE\nno shares yet'
              : 'ACCEPTANCE\n${(rate * 100).toStringAsFixed(0)}%',
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

/// Three real counts, each with its unit on its own line as in the concept.
///
/// No price: CEN is not listed anywhere, so a price here would be invented.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.readout});

  final MiningReadout readout;

  @override
  Widget build(BuildContext context) {
    return CenCard(
      child: Row(
        children: [
          Expanded(
            child: StatCell(
              value: readout.sessionBlocks?.toString() ?? '—',
              unit: 'CEN',
              label: 'session',
              color: Palette.goldLight,
            ),
          ),
          const StatDivider(),
          Expanded(
            child: StatCell(
              value: readout.totalBlocks?.toString() ?? '—',
              unit: 'CEN',
              label: 'total',
            ),
          ),
          const StatDivider(),
          Expanded(
            child: StatCell(
              value: readout.shares?.toString() ?? '—',
              unit: 'shares',
              label: 'accepted',
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
    final hash = readout.latestBlockHash;

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
                      ? 'no block accepted yet'
                      : 'block accepted ${shortHash(hash)}${readout.latestBlockTime == null ? '' : ' · ${readout.latestBlockTime}'}',
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
