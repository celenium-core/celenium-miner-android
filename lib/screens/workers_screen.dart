import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../services/mining_readout.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/cen_ui.dart';

/// Worker list.
///
/// One card per worker. The fields shown are the ones that decide whether a
/// worker is healthy: hashrate, shares, and the two rejection counters. A
/// worker with rising stale or invalid counts is the one to look at, so those
/// are never hidden.
class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key, required this.snapshot});

  final MinerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final workers = snapshot.stats?.workers ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workersTitle)),
      body: workers.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(Palette.lg),
              child: CenEmpty(reason: l10n.workersEmpty),
            )
          : CenContent(
              child: ListView.separated(
                padding: const EdgeInsets.all(Palette.lg),
                itemCount: workers.length,
                separatorBuilder: (_, _) => const SizedBox(height: Palette.md),
                itemBuilder: (context, index) =>
                    _WorkerCard(worker: workers[index]),
              ),
            ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker});

  final WorkerInfo worker;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final active =
        worker.status?.toLowerCase().contains('active') ?? worker.hashrate > 0;

    return CenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Palette.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.memory_outlined,
                  size: 17,
                  color: Palette.goldLight,
                ),
              ),
              const SizedBox(width: Palette.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.worker.isEmpty ? worker.instance : worker.worker,
                      style: TypeScale.title(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      worker.instance,
                      style: TypeScale.monoMuted(context, size: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              LiveStatus(
                label: active ? l10n.statusActive : l10n.statusIdle,
                active: active,
                tint: Palette.greenDim,
              ),
            ],
          ),
          const SizedBox(height: Palette.lg),
          Row(
            children: [
              Expanded(
                child: StatCell(
                  value: formatHashrate(worker.hashrate),
                  color: Palette.goldLight,
                  label: l10n.workersHashRate,
                ),
              ),
              const StatDivider(),
              Expanded(
                child: StatCell(value: '${worker.shares}', label: l10n.profileShares),
              ),
              const StatDivider(),
              Expanded(
                child: StatCell(value: '${worker.blocks}', label: l10n.workersBlocks),
              ),
            ],
          ),
          if (worker.stale > 0 || worker.invalid > 0) ...[
            const SizedBox(height: Palette.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Palette.md,
                vertical: Palette.sm,
              ),
              decoration: BoxDecoration(
                color: Palette.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Palette.rowRadius),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    size: 15,
                    color: Palette.red,
                  ),
                  const SizedBox(width: Palette.sm),
                  Expanded(
                    child: Text(
                      l10n.workersStaleInvalid(worker.stale, worker.invalid),
                      style: TypeScale.caption(context)
                          .copyWith(color: Palette.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (worker.sessionUptime != null) ...[
            const SizedBox(height: Palette.md),
            Text(
              l10n.workersSession(_duration(worker.sessionUptime!)),
              style: TypeScale.monoMuted(context, size: 10),
            ),
          ],
        ],
      ),
    );
  }
}

String _duration(int seconds) {
  final d = Duration(seconds: seconds);
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}
