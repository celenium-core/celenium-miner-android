import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../services/mining_readout.dart';
import '../theme/layout.dart';
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
    final l10n = l10nOf(context);
    final address = _address;
    final blocks = _blocks;

    return CenContent(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Palette.sm),
          _Header(
            networkLabel: networkLabel,
            connected: snapshot.stats != null,
          ),
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
              Eyebrow(l10n.walletTransactions),
              const Spacer(),
              if (blocks.isNotEmpty)
                TextButton(
                  onPressed: onOpenActivity,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.walletSeeAll),
                ),
            ],
          ),
          const SizedBox(height: Palette.sm),
          if (blocks.isEmpty)
            CenEmpty(reason: l10n.walletNoTxReason)
          else
            for (final block in blocks.take(6)) _BlockRow(block: block),
          const SizedBox(height: Palette.xxl),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.networkLabel, required this.connected});

  final String networkLabel;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    // The concept puts the network label left, a live status right, and the
    // screen title beneath in the serif. Same order here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                networkLabel.toUpperCase(),
                style: TypeScale.monoMuted(
                  context,
                  size: 10,
                ).copyWith(letterSpacing: 1.4),
              ),
            ),
            LiveStatus(
              label: connected ? l10n.statusOnline : l10n.statusOffline,
              active: connected,
              tint: Palette.greenDim,
            ),
          ],
        ),
        const SizedBox(height: Palette.sm),
        Text(l10n.walletTitle, style: TypeScale.screenTitle(context)),
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
    final l10n = l10nOf(context);
    // The cream balance card from the concept: the light mass carries the
    // dark figure, which is the opposite of every other panel here and is
    // what makes the balance the first thing the eye lands on.
    return CenCard.light(
      glow: Palette.gold,
      padding: const EdgeInsets.all(Palette.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow(l10n.walletTotalBalance, color: Palette.creamInkDim),
              const Spacer(),
              const Pill(
                label: 'CEN',
                background: Palette.gold,
                foreground: Palette.white,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Palette.sm),
          Text(
            '—',
            style: TypeScale.hero(context).copyWith(color: Palette.creamInk),
          ),
          const SizedBox(height: Palette.sm),
          Text(
            l10n.walletNoBalanceNote,
            style: TypeScale.caption(context).copyWith(color: Palette.creamInkDim),
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
    final l10n = l10nOf(context);
    return CenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(l10n.walletMiningAddress),
          const SizedBox(height: Palette.sm),
          SelectableText(
            address,
            style: TypeScale.mono(
              context,
              size: 11,
            ).copyWith(color: Palette.goldLight),
          ),
          const SizedBox(height: Palette.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.walletAddressCopied)),
                );
              },
              icon: const Icon(Icons.copy, size: 14),
              label: Text(l10n.commonCopy),
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
    final l10n = l10nOf(context);
    return Column(
      children: [
        // Three capsules, send first and in gold: moving coins is the reason
        // the screen exists, so it takes the primary slot.
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: l10n.walletSend,
                icon: Icons.north_east,
                primary: true,
                onTap: () => _showSendUnavailable(context),
              ),
            ),
            const SizedBox(width: Palette.sm),
            Expanded(
              child: _ActionButton(
                label: l10n.walletReceive,
                icon: Icons.south_west,
                primary: false,
                onTap: address == null
                    ? null
                    : () => _showReceiveSheet(context, address!),
              ),
            ),
            const SizedBox(width: Palette.sm),
            Expanded(
              child: _ActionButton(
                label: l10n.walletSwap,
                icon: Icons.swap_horiz,
                primary: false,
                onTap: () => _showSwapUnavailable(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: Palette.md),
        GhostButton(
          label: l10n.walletBackupWords,
          icon: Icons.shield_outlined,
          onPressed: onBackup,
        ),
      ],
    );
  }
}

void _showSwapUnavailable(BuildContext context) {
  final l10n = l10nOf(context);
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.walletSwapUnavailable, style: TypeScale.headline(context)),
      content: Text(
        l10n.walletSwapBody,
        style: TypeScale.label(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
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
    // Send is the solid gold capsule. Receive and Swap are the translucent
    // pills with a white outline the concept uses, so the three read as one
    // primary action and two secondary ones without a second solid block
    // competing for attention.
    final background = primary
        ? Palette.gold
        : Palette.surfaceHigh;
    final foreground = primary ? Palette.white : Palette.cream;
    final disabledBg = primary
        ? Palette.goldDim.withValues(alpha: 0.35)
        : Palette.field;
    final disabledFg = Palette.slate;

    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        // Material takes either a shape or a borderRadius, never both, so the
        // pill shape carries the radius and the outline lives inside it.
        child: Material(
          color: onTap == null ? disabledBg : background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Palette.pill),
            side: primary
                ? BorderSide.none
                : BorderSide(color: Palette.slate.withValues(alpha: 0.35)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Palette.pill),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: onTap == null ? disabledFg : foreground,
                  ),
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
  final l10n = l10nOf(context);
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(
        l10n.walletSendUnavailable,
        style: TypeScale.headline(context),
      ),
      content: Text(
        l10n.walletSendBody,
        style: TypeScale.label(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
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
    final l10n = l10nOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Palette.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.walletReceive, style: TypeScale.screenTitle(context)),
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
                style: TypeScale.mono(
                  context,
                  size: 12,
                ).copyWith(color: Palette.goldLight),
              ),
            ),
            const SizedBox(height: Palette.lg),
            GoldButton(
              label: l10n.walletCopyAddress,
              icon: Icons.copy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.walletAddressCopied)),
                );
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: Palette.sm),
            Text(
              l10n.walletReceiveNote,
              style: TypeScale.caption(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The block subsidy in CEN.
///
/// Taken from consensus/core/src/config/bps.rs:
/// `pre_deflationary_phase_base_subsidy() = 50000000000 / BPS` sompi, with
/// BPS = 10, and 1 CEN = 100000000 sompi. That gives 50 CEN per block.
///
/// This is the pre-deflationary value. The subsidy halves every six months,
/// so once the network passes its first halving this figure is stale. It is
/// shown because a mined block genuinely pays the subsidy, not because the
/// app needs a number to fill the row with.
const double blockRewardCen = 50;

/// One accepted block, laid out like the concept's transaction row: circular
/// icon on the left, description and timestamp stacked, amount right-aligned.
///
/// The amount is the block subsidy, which is the one number the consensus
/// rules fix rather than something the app chooses. See [blockRewardCen].
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block});

  final BlockInfo block;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Palette.sm),
      child: CenCard.glass(
        padding: const EdgeInsets.symmetric(
          horizontal: Palette.lg,
          vertical: 14,
        ),
        radius: Palette.rowRadius,
        child: Row(
          children: [
            // Circular, not square: the concept uses a round badge for the
            // direction of the transaction.
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Palette.green.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward,
                size: 16,
                color: Palette.greenDim,
              ),
            ),
            const SizedBox(width: Palette.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.walletMiningReward, style: TypeScale.title(context)),
                  const SizedBox(height: 2),
                  Text(
                    '${_friendlyTime(l10n, block.timestamp)} · ${shortHash(block.hash, head: 8, tail: 6)}',
                    style: TypeScale.monoMuted(context, size: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Palette.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${blockRewardCen.toStringAsFixed(2)}',
                  style: TypeScale.mono(context, size: 13).copyWith(
                    color: Palette.greenDim,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text('CEN', style: TypeScale.monoMuted(context, size: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Turns an ISO timestamp into the concept's short form: TODAY, YESTERDAY, or
/// a date. Falls back to the raw string when it cannot be parsed.
String _friendlyTime(AppLocalizations l10n, String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final then = DateTime(parsed.year, parsed.month, parsed.day);
  final days = today.difference(then).inDays;

  if (days == 0) return l10n.commonToday;
  if (days == 1) return l10n.commonYesterday;

  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}';
}
