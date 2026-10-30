import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bridge.dart';
import '../theme/tokens.dart';
import '../widgets/mining_state_card.dart';

/// The app's home screen.
///
/// Composition follows the screen's job: the one decision a miner makes here
/// is "is it running, and is it earning", so the live state owns the top and
/// everything else supports it. The network readout is deliberately a list of
/// label/value rows rather than a row of equal stat cards, because it is
/// secondary information.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.snapshot, required this.connected, super.key});

  final MinerSnapshot snapshot;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final network = _NetworkPanel(snapshot: snapshot, connected: connected);
        final blocks = _RecentBlocks(blocks: snapshot.stats?.blocks ?? const []);

        return ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            MiningStateCard(snapshot: snapshot, connected: connected),
            const SizedBox(height: Space.lg),
            _PayoutPanel(
              wallet: snapshot.stats?.internalCpu?.wallet ?? '',
            ),
            const SizedBox(height: Space.lg),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: network),
                  const SizedBox(width: Space.lg),
                  Expanded(child: blocks),
                ],
              )
            else ...[
              network,
              const SizedBox(height: Space.lg),
              blocks,
            ],
          ],
        );
      },
    );
  }
}

class _NetworkPanel extends StatelessWidget {
  const _NetworkPanel({required this.snapshot, required this.connected});

  final MinerSnapshot snapshot;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final stats = snapshot.stats;
    final instances = snapshot.status?.instances ?? 0;
    return _Panel(
      title: 'Network',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            label: 'Status',
            value: connected ? 'reachable' : 'unreachable',
            valueColor: connected ? Palette.accent : Palette.danger,
          ),
          _Row(label: 'Node', value: snapshot.status?.celeniumdAddress ?? '-'),
          _Row(
            label: 'Node version',
            value: snapshot.status?.celeniumdVersion ?? '-',
          ),
          _Row(
            label: 'Network hashrate',
            value: _hashrate(stats?.networkHashrate ?? 0),
          ),
          _Row(
            label: 'Difficulty',
            value: stats == null ? '-' : _difficulty(stats.networkDifficulty),
          ),
          _Row(
            label: 'Block count',
            value: stats == null ? '-' : _compact(stats.networkBlockCount),
          ),
          _Row(
            label: 'Bridge uptime',
            value: stats?.bridgeUptime == null ? '-' : _duration(stats!.bridgeUptime!),
          ),
          _Row(
            label: 'Mining instances',
            value: '$instances of 1',
            valueColor: instances > 1 ? Palette.danger : null,
          ),
          if (instances > 1) _LimitNote(count: instances),
        ],
      ),
    );
  }
}

/// Where mined CEN goes.
///
/// There is no withdrawal button because the app holds no keys: rewards are
/// paid by the network straight to the wallet the bridge is configured with.
/// What the user actually needs here is that address, so it is selectable and
/// copyable rather than retyped (R-26).
class _PayoutPanel extends StatelessWidget {
  const _PayoutPanel({required this.wallet});

  final String wallet;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasWallet = wallet.isNotEmpty;

    return _Panel(
      title: 'Payout',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasWallet)
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    wallet,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Palette.textPrimary,
                      fontFeatures: Type.tabular,
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                _CopyButton(value: wallet),
              ],
            )
          else
            _EmptyNote(
              message: 'No payout address yet. Set the wallet in the bridge '
                  'config and it appears here.',
            ),
          const SizedBox(height: Space.sm),
          Text(
            hasWallet
                ? 'Rewards are paid straight to this address by the network. '
                    'The app holds no keys, so there is nothing to withdraw '
                    'from inside it - copy the address into your wallet.'
                : 'Mined CEN is sent straight to the wallet address the '
                    'bridge is configured with.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address copied')),
        );
      },
      icon: const Icon(Icons.copy, size: 16),
      label: const Text('Copy'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
      ),
    );
  }
}

/// One device, one miner. The bridge is what enforces it; this note is what
/// tells the user the rule was broken, instead of letting hashrate silently
/// split across instances (R-38).
class _LimitNote extends StatelessWidget {
  const _LimitNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs, bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Palette.danger,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              'This device is running $count mining instances. The limit is 1 '
              'per device - stop the extras so the hashrate is not split.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Palette.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentBlocks extends StatelessWidget {
  const _RecentBlocks({required this.blocks});

  final List<BlockInfo> blocks;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Blocks mined',
      trailing: blocks.isEmpty ? null : '${blocks.length}',
      child: blocks.isEmpty
          ? _EmptyNote(
              message: 'No blocks yet. Mined blocks appear here with their hash '
                  'and the worker that found them.',
            )
          : Column(
              children: [
                for (final block in blocks.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: Palette.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                _shortHash(block.hash),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Palette.textPrimary,
                                      fontFeatures: Type.tabular,
                                    ),
                              ),
                              Text(
                                '${block.worker} - ${block.timestamp}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Palette.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: Type.tabular,
                      ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? Palette.textPrimary,
                    fontFeatures: Type.tabular,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: Theme.of(context).textTheme.bodySmall);
  }
}

String _hashrate(int hps) {
  if (hps <= 0) return '-';
  if (hps >= 1e18) return '${(hps / 1e18).toStringAsFixed(2)} EH/s';
  if (hps >= 1e15) return '${(hps / 1e15).toStringAsFixed(2)} PH/s';
  if (hps >= 1e12) return '${(hps / 1e12).toStringAsFixed(2)} TH/s';
  if (hps >= 1e9) return '${(hps / 1e9).toStringAsFixed(2)} GH/s';
  if (hps >= 1e6) return '${(hps / 1e6).toStringAsFixed(2)} MH/s';
  return '${(hps / 1e3).toStringAsFixed(2)} kH/s';
}

String _difficulty(double difficulty) {
  if (difficulty <= 0) return '-';
  if (difficulty >= 1e12) return '${(difficulty / 1e12).toStringAsFixed(2)} T';
  if (difficulty >= 1e9) return '${(difficulty / 1e9).toStringAsFixed(2)} G';
  if (difficulty >= 1e6) return '${(difficulty / 1e6).toStringAsFixed(2)} M';
  return difficulty.toStringAsFixed(2);
}

String _compact(int value) {
  if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}k';
  return value.toString();
}

String _duration(int seconds) {
  final d = Duration(seconds: seconds);
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

String _shortHash(String hash) {
  if (hash.length <= 20) return hash;
  return '${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}';
}
