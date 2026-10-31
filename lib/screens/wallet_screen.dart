import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bridge.dart';
import '../services/mining_readout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/cen_ui.dart';

/// Wallet.
///
/// What this screen can show honestly comes from two places: the address the
/// bridge is mining to, and the blocks the bridge has accepted. It cannot show
/// a balance, because the bridge reports mining results rather than account
/// balances, and it cannot send, because that needs a node connection and the
/// signing key. Both gaps are stated on the screen instead of filled with a
/// number.
class WalletScreen extends StatelessWidget {
  const WalletScreen({
    super.key,
    required this.snapshot,
    required this.networkLabel,
    required this.onBackup,
    required this.onOpenActivity,
  });

  final MinerSnapshot snapshot;
  final String networkLabel;

  /// Opens the backup flow for the locally generated key.
  final VoidCallback onBackup;
  final VoidCallback onOpenActivity;

  String? get _address => snapshot.stats?.internalCpu?.wallet;

  List<BlockInfo> get _blocks => snapshot.stats?.blocks ?? const [];

  @override
  Widget build(BuildContext context) {
    final address = _address;
    final blocks = _blocks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Palette.lg, Palette.sm, Palette.lg, Palette.xxl),
      children: [
        _Header(networkLabel: networkLabel, connected: snapshot.stats != null),
        const SizedBox(height: Palette.lg),
        _BalanceCard(hasAddress: address != null),
        const SizedBox(height: Palette.lg),
        if (address != null) ...[
          _AddressCard(address: address),
          const SizedBox(height: Palette.lg),
        ],
        _Actions(address: address, onBackup: onBackup),
        const SizedBox(height: Palette.xl),
        Row(
          children: [
            Eyebrow('Mined blocks'),
            const Spacer(),
            if (blocks.isNotEmpty)
              TextButton(
                onPressed: onOpenActivity,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('SEE ALL'),
              ),
          ],
        ),
        const SizedBox(height: Palette.sm),
        if (blocks.isEmpty)
          const CenEmpty(
            reason: 'No blocks accepted yet. Mined blocks appear here as they land.',
          )
        else
          for (final block in blocks.take(6)) _BlockRow(block: block),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.networkLabel, required this.connected});

  final String networkLabel;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Wallet', style: TypeScale.screenTitle(context))),
        LiveStatus(label: connected ? 'NODE ONLINE' : 'NODE OFFLINE', active: connected, tint: Palette.greenDim),
      ],
    );
  }
}

/// Balance is unknown, and the card says so rather than showing a zero.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.hasAddress});

  final bool hasAddress;

  @override
  Widget build(BuildContext context) {
    return CenCard(
      padding: const EdgeInsets.all(Palette.xl),
      border: BorderSide(color: Palette.goldDim.withValues(alpha: 0.4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow('Total balance'),
              const Spacer(),
              const Pill(label: 'CEL', background: Palette.gold, foreground: Palette.ink, dense: true),
            ],
          ),
          const SizedBox(height: Palette.sm),
          Text('—', style: TypeScale.hero(context).copyWith(color: Palette.slate)),
          const SizedBox(height: Palette.sm),
          Text(
            'The bridge reports mining results, not account balances. A direct node '
            'connection is needed to read the balance of an address.',
            style: TypeScale.caption(context),
          ),
        ],
      ),
    );
  }
}

/// The address the bridge is mining to. This is the number the user copies
/// into the bridge, so it is shown in full rather than truncated.
class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return CenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('Mining address'),
          const SizedBox(height: Palette.sm),
          SelectableText(
            address,
            style: TypeScale.mono(context, size: 11).copyWith(color: Palette.goldLight),
          ),
          const SizedBox(height: Palette.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied')),
                );
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.address, required this.onBackup});

  final String? address;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Three capsules, send first and in gold: moving coins is the reason
        // the screen exists, so it takes the primary slot.
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Send',
                icon: Icons.north_east,
                primary: true,
                onTap: () => _showSendUnavailable(context),
              ),
            ),
            const SizedBox(width: Palette.sm),
            Expanded(
              child: _ActionButton(
                label: 'Receive',
                icon: Icons.south_west,
                primary: false,
                onTap: address == null ? null : () => _showReceiveSheet(context, address!),
              ),
            ),
            const SizedBox(width: Palette.sm),
            Expanded(
              child: _ActionButton(
                label: 'Swap',
                icon: Icons.swap_horiz,
                primary: false,
                onTap: () => _showSwapUnavailable(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: Palette.md),
        GhostButton(
          label: 'Back up recovery words',
          icon: Icons.shield_outlined,
          onPressed: onBackup,
        ),
      ],
    );
  }
}

void _showSwapUnavailable(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Swap is not available', style: TypeScale.headline(context)),
      content: Text(
        'Swapping CEN for another asset needs a market to swap against. CEN is not '
        'listed on any exchange or decentralised venue yet, so there is nothing to '
        'swap with.',
        style: TypeScale.label(context),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = primary ? Palette.gold : Palette.surfaceHigh;
    final foreground = primary ? Palette.ink : Palette.cream;
    final disabledBg = primary ? Palette.goldDim.withValues(alpha: 0.35) : Palette.surface;
    final disabledFg = Palette.slate;

    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Material(
          color: onTap == null ? disabledBg : background,
          borderRadius: BorderRadius.circular(Palette.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Palette.pill),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: onTap == null ? disabledFg : foreground),
                  const SizedBox(width: Palette.sm),
                  Text(
                    label,
                    style: TypeScale.title(context).copyWith(
                      color: onTap == null ? disabledFg : foreground,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showReceiveSheet(BuildContext context, String address) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReceiveSheet(address: address),
  );
}

void _showSendUnavailable(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Sending is not available yet', style: TypeScale.headline(context)),
      content: Text(
        'Moving coins needs two things this build does not have: a node that can '
        'broadcast a transaction, and the signing key held on this device. Both are '
        'planned. Until then the address can be copied and used from the Celenium '
        'wallet CLI.',
        style: TypeScale.label(context),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}

/// Receive sheet: the address, long enough to be read and copied in full.
class _ReceiveSheet extends StatelessWidget {
  const _ReceiveSheet({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Palette.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receive', style: TypeScale.screenTitle(context)),
            const SizedBox(height: Palette.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Palette.lg),
              decoration: BoxDecoration(
                color: Palette.surfaceHigh,
                borderRadius: BorderRadius.circular(Palette.rowRadius),
              ),
              child: SelectableText(
                address,
                style: TypeScale.mono(context, size: 12).copyWith(color: Palette.goldLight),
              ),
            ),
            const SizedBox(height: Palette.lg),
            GoldButton(
              label: 'Copy address',
              icon: Icons.copy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied')),
                );
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: Palette.sm),
            Text(
              'Anyone with this address can send coins to it. It is safe to share.',
              style: TypeScale.caption(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// One accepted block: real hash, real timestamp, no invented amount.
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block});

  final BlockInfo block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Palette.sm),
      child: CenCard(
        padding: const EdgeInsets.symmetric(horizontal: Palette.lg, vertical: 14),
        radius: Palette.rowRadius,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Palette.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.arrow_downward, size: 16, color: Palette.greenDim),
            ),
            const SizedBox(width: Palette.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Block mined', style: TypeScale.title(context)),
                  const SizedBox(height: 2),
                  Text(
                    '${shortHash(block.hash, head: 10, tail: 8)} · ${block.timestamp}',
                    style: TypeScale.monoMuted(context, size: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(block.worker, style: TypeScale.monoMuted(context, size: 10)),
          ],
        ),
      ),
    );
  }
}
