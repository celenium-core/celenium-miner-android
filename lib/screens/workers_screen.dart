import 'package:flutter/material.dart';

import '../models/bridge.dart';
import '../theme/tokens.dart';

/// Connected workers, straight from the bridge.
///
/// Every row is real data. When nothing is connected the screen says why it
/// is empty and what fills it, rather than showing filler rows.
class WorkersScreen extends StatelessWidget {
  const WorkersScreen({required this.workers, super.key});

  final List<WorkerInfo> workers;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text('Workers', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Space.xs),
        Text(
          'Stratum workers currently connected to the bridge.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        if (workers.isEmpty)
          Container(
            padding: const EdgeInsets.all(Space.xl),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: Palette.surfaceHigh),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No workers connected', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Space.sm),
                Text(
                  'Point a miner at the bridge stratum port with your Celenium '
                  'address as the worker name. Connected workers show up here '
                  'with their hashrate and share counts.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          for (final worker in workers) _WorkerCard(worker: worker),
      ],
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker});

  final WorkerInfo worker;

  @override
  Widget build(BuildContext context) {
    final online = worker.status == 'online';
    return Container(
      margin: const EdgeInsets.only(bottom: Space.md),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: online ? Palette.accentDim : Palette.surfaceHigh,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: online ? Palette.accent : Palette.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  worker.worker.isEmpty ? worker.instance : worker.worker,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _hashrate(worker.hashrate),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFeatures: Type.tabular,
                      color: online ? Palette.accent : Palette.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xl,
            runSpacing: Space.sm,
            children: [
              _Figure(label: 'shares', value: _compact(worker.shares)),
              _Figure(label: 'blocks', value: worker.blocks.toString()),
              if (worker.stale > 0)
                _Figure(
                  label: 'stale',
                  value: worker.stale.toString(),
                  color: Palette.warn,
                ),
              if (worker.invalid > 0)
                _Figure(
                  label: 'invalid',
                  value: worker.invalid.toString(),
                  color: Palette.danger,
                ),
              if (worker.sessionUptime != null)
                _Figure(
                  label: 'session',
                  value: _duration(worker.sessionUptime!),
                ),
            ],
          ),
          if (worker.wallet.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            SelectableText(
              worker.wallet,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFeatures: Type.tabular,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFeatures: Type.tabular,
                color: color ?? Palette.textPrimary,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _hashrate(double ghs) {
  if (ghs <= 0) return '-';
  if (ghs >= 1000) return '${(ghs / 1000).toStringAsFixed(2)} TH/s';
  return '${ghs.toStringAsFixed(2)} GH/s';
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toString();
}

String _duration(int seconds) {
  final d = Duration(seconds: seconds);
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}
