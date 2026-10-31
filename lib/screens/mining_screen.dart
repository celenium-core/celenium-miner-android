import 'package:flutter/material.dart';

import '../models/bridge.dart';
import '../services/mining_readout.dart';
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(Palette.lg, Palette.sm, Palette.lg, Palette.xxl),
      children: [
        _SummaryCard(readout: readout, nodeAddress: nodeAddress, onConnectNode: onConnectNode),
        const SizedBox(height: Palette.xl),
        _DialBlock(readout: readout, onTap: onOpenWorkers),
        const SizedBox(height: Palette.xl),
        _StatsStrip(readout: readout),
        const SizedBox(height: Palette.lg),
        // A hex stream that runs only while the bridge reports hashing: the
        // motion is the app saying data is arriving right now.
        HexTicker(active: readout.active),
        const SizedBox(height: Palette.lg),
        _LatestLine(readout: readout, onTap: onOpenActivity),
      ],
    );
  }
}

/// Light card: identity, hashrate, difficulty, live status.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.readout, required this.nodeAddress, required this.onConnectNode});

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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: Palette.ink, shape: BoxShape.circle),
                child: Center(child: BrandMark(size: 24, petal: Palette.gold, core: Palette.ink)),
              ),
              const SizedBox(width: Palette.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      readout.workerName ?? 'No worker',
                      style: TypeScale.title(context).copyWith(color: Palette.ink, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nodeAddress ?? 'node not set',
                      style: TypeScale.monoInk(context, size: 10).copyWith(color: Palette.slate),
                    ),
                  ],
                ),
              ),
              LiveStatus(
                label: readout.active ? 'MINING ACTIVE' : 'IDLE',
                active: readout.active,
                tint: readout.active ? Palette.greenDim : Palette.slate,
              ),
            ],
          ),
          const SizedBox(height: Palette.lg),
          Eyebrow('Hash rate', color: Palette.slate),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                readout.hashrateGhs == null ? '—' : formatHashrate(readout.hashrateGhs!),
                style: TypeScale.hero(context).copyWith(color: Palette.ink, fontSize: 34),
              ),
              const Spacer(),
              // Gold level badge, as in the concept. The level is derived from
              // the hashrate so the number means something rather than being
              // decoration: every 1 GH/s is one level.
              if (readout.hashrateGhs != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Palette.md, vertical: 5),
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
          ),
          const SizedBox(height: Palette.md),
          // Only the fields that add something the identity row does not
          // already say. The worker name is the identity, so repeating it
          // here would be a second label for the same fact.
          _MetaChip(
            'DIFFICULTY',
            readout.difficulty == null ? '—' : readout.difficulty!.toStringAsFixed(2),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Palette.md, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Palette.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TypeScale.monoInk(context, size: 9).copyWith(color: Palette.slate, letterSpacing: 1.2),
          ),
          const SizedBox(width: Palette.sm),
          Text(value, style: TypeScale.monoInk(context, size: 11).copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
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
        Text(
          rate == null
              ? 'ACCEPTANCE\nno shares yet'
              : 'ACCEPTANCE\n${(rate * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.center,
          style: TypeScale.mono(context, size: 12).copyWith(color: Palette.goldLight, letterSpacing: 1.4),
        ),
        const SizedBox(height: Palette.md),
        // A real destination, not a control the app cannot honour: it does not
        // start or stop hashing, it shows who is hashing.
        Text(
          '[ TAP FOR WORKERS ]',
          style: TypeScale.monoMuted(context, size: 10).copyWith(letterSpacing: 1.6),
        ),
      ],
    );
  }
}

/// Three real counts. No price: CEN is not listed anywhere, so a price here
/// would be invented.
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
              label: 'session',
              color: Palette.goldLight,
            ),
          ),
          const StatDivider(),
          Expanded(child: StatCell(value: readout.totalBlocks?.toString() ?? '—', label: 'total')),
          const StatDivider(),
          Expanded(child: StatCell(value: readout.shares?.toString() ?? '—', label: 'shares')),
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
          padding: const EdgeInsets.symmetric(horizontal: Palette.lg, vertical: 14),
          child: Row(
            children: [
              Text('>', style: TypeScale.monoGold(context, size: 13)),
              const SizedBox(width: Palette.sm),
              Expanded(
                child: Text(
                  hash == null
                      ? 'no block accepted yet'
                      : 'block accepted ${shortHash(hash)}${readout.latestBlockTime == null ? '' : ' · ${readout.latestBlockTime}'}',
                  style: TypeScale.mono(context, size: 11).copyWith(color: Palette.slateLight),
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
