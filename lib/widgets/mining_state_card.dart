import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_panel.dart';
import '../models/bridge.dart';
import '../theme/tokens.dart';

/// The app's single focal element: whether mining is live, and how fast.
///
/// The accent colour appears here and nowhere else on this screen, so "live"
/// has one consistent meaning across the whole app.
class MiningStateCard extends StatelessWidget {
  const MiningStateCard({
    required this.snapshot,
    required this.connected,
    super.key,
  });

  final MinerSnapshot snapshot;
  final bool connected;

  /// The command that starts the bridge with the internal CPU miner. Shown
  /// verbatim because the bridge has no runtime start/stop endpoint: the
  /// miner is enabled by this launch flag, not toggled over HTTP.
  static const String launchCommand =
      'stratum-bridge --internal-cpu-miner-address <your-cenium-address>';

  @override
  Widget build(BuildContext context) {
    final mining = snapshot.isMining;
    final cpu = snapshot.stats?.internalCpu;

    return GlassPanel(
      accentBorder: mining,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StateDot(live: mining),
              const SizedBox(width: Space.sm),
              // The state is the answer this card exists to give, so it keeps
              // its full width. The bridge address is metadata: it yields
              // first and ellipsises rather than pushing the layout apart.
              Text(
                connected ? (mining ? 'Mining' : 'Idle') : 'Disconnected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: mining ? Palette.accent : Palette.textSecondary,
                    ),
              ),
              if (connected) ...[
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'bridge ${snapshot.status?.webBind ?? ""}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.xl),
          if (!connected)
            const _DisconnectedBody()
          else if (mining)
            _LiveBody(cpu: cpu!)
          else
            const _IdleBody(),
        ],
      ),
    );
  }
}

/// The live-state indicator. This is the only glowing element in the app.
class _StateDot extends StatelessWidget {
  const _StateDot({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: live ? Palette.accent : Palette.textSecondary,
        shape: BoxShape.circle,
        boxShadow: live
            ? [
                BoxShadow(
                  color: Palette.accent.withValues(alpha: 0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }
}

class _LiveBody extends StatelessWidget {
  const _LiveBody({required this.cpu});

  final InternalCpuStats cpu;

  String _formatHashrate(double ghs) {
    if (ghs >= 1000) return '${(ghs / 1000).toStringAsFixed(2)} TH/s';
    if (ghs >= 1) return '${ghs.toStringAsFixed(2)} GH/s';
    return '${(ghs * 1000).toStringAsFixed(0)} MH/s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatHashrate(cpu.hashrateGhs),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFeatures: Type.tabular,
                color: Palette.accent,
              ),
        ),
        const SizedBox(height: Space.xs),
        Text('local hashrate', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Space.xl),
        // A Wrap, not a Row: three figures plus their gaps fit a desktop card,
        // but a phone card is narrower. Wrapping keeps every figure readable
        // instead of clipping the last one off the edge.
        Wrap(
          spacing: Space.xxl,
          runSpacing: Space.lg,
          children: [
            _Figure(
              label: 'accepted',
              value: cpu.blocksAccepted.toString(),
            ),
            _Figure(
              label: 'submitted',
              value: cpu.blocksSubmitted.toString(),
            ),
            _Figure(label: 'shares', value: _compact(cpu.shares)),
          ],
        ),
        if (cpu.stale > 0 || cpu.invalid > 0) ...[
          const SizedBox(height: Space.lg),
          Text(
            '${cpu.stale} stale, ${cpu.invalid} invalid shares',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Palette.warn),
          ),
        ],
      ],
    );
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No miner running',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: Space.sm),
        Text(
          'The bridge is reachable but no internal CPU miner is attached to it. '
          'Start the bridge with the miner flag to begin.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Space.lg),
        _CommandLine(command: MiningStateCard.launchCommand),
      ],
    );
  }
}

class _DisconnectedBody extends StatelessWidget {
  const _DisconnectedBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bridge unreachable',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: Space.sm),
        Text(
          'The app could not read /api/status or /api/stats from the configured '
          'address. Check that the stratum bridge is running and that its web '
          'dashboard port matches the address in Node settings.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: Type.tabular,
                fontSize: 18,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// A copyable command line. Real, not decorative: it is the exact launch
/// command the bridge accepts.
class _CommandLine extends StatelessWidget {
  const _CommandLine({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm + 2,
      ),
      decoration: BoxDecoration(
        color: Palette.field,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: Palette.surfaceHigh),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              command,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Palette.textPrimary,
                    fontFeatures: Type.tabular,
                  ),
            ),
          ),
          const SizedBox(width: Space.sm),
          _CopyButton(command: command),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: 44,
      child: IconButton(
        tooltip: 'Copy command',
        icon: const Icon(Icons.copy_rounded, size: 18),
        color: Palette.textSecondary,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: command));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Command copied to clipboard')),
          );
        },
      ),
    );
  }
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toString();
}
