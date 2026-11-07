import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../services/block_time.dart';
import '../services/bridge_api.dart';
import '../services/cen_wallet.dart';
import '../services/keystore.dart';
import '../services/mining_readout.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/cen_ui.dart';

/// Wallet.
///
/// Shows the address the bridge mines to, the balance the bridge reports for
/// it, and the blocks the bridge has accepted. Sending is available on
/// Android, Windows, and Linux: the app derives the key from the locally
/// stored recovery words and hands it to the bridge for one signed transfer,
/// which the bridge broadcasts to the node.
class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.snapshot,
    required this.onBackup,
    required this.onOpenActivity,
    this.api,
    this.keystore,
    this.network = CenNetwork.simnet,
  });

  final MinerSnapshot snapshot;

  /// Client used to query the account balance and send transactions. Null
  /// while settings are still loading or the bridge is unreachable, in which
  /// case the balance card keeps showing "unknown" and sending is disabled.
  final BridgeApi? api;

  /// Locally stored wallet. Null when none is configured yet.
  final Keystore? keystore;

  /// Which network the local key belongs to (the UI reads it from settings).
  final CenNetwork network;

  /// Opens the backup flow for the locally generated key.
  final VoidCallback onBackup;
  final VoidCallback onOpenActivity;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// Bumped after a successful send so the balance card re-fetches. A new key
  /// recreates the card's state and re-runs its initial balance query.
  int _balanceEpoch = 0;

  /// The address the bridge is mining to, or null when none exists yet. An
  /// empty string is treated as "no address": the bridge reports an empty
  /// wallet slot until its first accepted block.
  String? get _address {
    final wallet = widget.snapshot.stats?.internalCpu?.wallet;
    return (wallet == null || wallet.isEmpty) ? null : wallet;
  }

  List<BlockInfo> get _blocks => widget.snapshot.stats?.blocks ?? const [];

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
            connected: widget.snapshot.stats != null,
          ),
          const SizedBox(height: Palette.lg),
          _BalanceCard(
            key: ValueKey('balance-$_balanceEpoch'),
            address: address,
            api: widget.api,
          ),
          const SizedBox(height: Palette.lg),
          if (address != null) ...[
            _AddressCard(address: address),
            const SizedBox(height: Palette.lg),
          ],
          _Actions(
            address: address,
            api: widget.api,
            keystore: widget.keystore,
            network: widget.network,
            onBackup: widget.onBackup,
            onSent: () => setState(() => _balanceEpoch++),
          ),
          const SizedBox(height: Palette.xl),
          Row(
            children: [
              Eyebrow(l10n.walletTransactions),
              const Spacer(),
              if (blocks.isNotEmpty)
                TextButton(
                  onPressed: widget.onOpenActivity,
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
  const _Header({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    // One compact top bar: the page name left, the live status right. The
    // network label is gone — it only ever said SIMNET, and on mainnet that
    // is no longer true — so the page name carries its slot at the same size
    // as the status beside it.
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.walletTitle.toUpperCase(),
            style: TypeScale.caption(context).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        LiveStatus(
          label: connected ? l10n.statusOnline : l10n.statusOffline,
          active: connected,
          tint: Palette.greenDim,
        ),
      ],
    );
  }
}

/// Fetches the account balance from the bridge and shows it. A real zero is
/// shown as `0`; the em-dash only appears when there is no address or the node
/// can't be reached, so "unknown" is never rendered as a false zero.
class _BalanceCard extends StatefulWidget {
  const _BalanceCard({super.key, required this.address, required this.api});

  final String? address;
  final BridgeApi? api;

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  AccountBalance? _balance;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _BalanceCard old) {
    super.didUpdateWidget(old);
    if (old.address != widget.address || old.api != widget.api) {
      _balance = null;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final address = widget.address;
    final api = widget.api;
    if (address == null || address.isEmpty || api == null) return;
    AccountBalance? result;
    try {
      result = await api.fetchBalance(address);
    } on Object {
      result = null;
    }
    if (!mounted) return;
    setState(() => _balance = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final balance = _balance;
    final needsNote = balance == null;

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
          // The page's one big number, in an arcade pixel face. Press Start
          // 2P has no em-dash glyph, so the "unknown" dash keeps the display
          // face; the pixel face takes over only for a real figure. A
          // FittedBox lets a long balance scale instead of overflowing the
          // cream card.
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                balance?.formattedCen ?? '—',
                maxLines: 1,
                style: (balance == null
                        ? TypeScale.hero(context)
                        : TypeScale.pixel(context, size: 28))
                    .copyWith(color: Palette.creamInk),
              ),
            ),
          ),
          if (needsNote) ...[
            const SizedBox(height: Palette.sm),
            Text(
              l10n.walletNoBalanceNote,
              style: TypeScale.caption(
                context,
              ).copyWith(color: Palette.creamInkDim),
            ),
          ],
        ],
      ),
    );
  }
}

/// The address the bridge is mining to. This is the number the user copies
/// into the bridge, so it is shown in full rather than truncated. An eye
/// toggle blurs the eyebrow, the address and the copy button for privacy; the
/// eye itself stays sharp and tappable, so hiding is always reversible.
class _AddressCard extends StatefulWidget {
  const _AddressCard({required this.address});

  final String address;

  @override
  State<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<_AddressCard> {
  bool _revealed = true;

  /// Blurs and deactivates [child] while hidden, so the address cannot be
  /// read or long-pressed into the clipboard off the screen.
  Widget _veil(Widget child) {
    if (_revealed) return child;
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: child,
      ),
    );
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10nOf(context).walletAddressCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return CenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _veil(Eyebrow(l10n.walletMiningAddress)),
          const SizedBox(height: Palette.sm),
          _veil(
            SelectableText(
              widget.address,
              style: TypeScale.mono(
                context,
                size: 11,
              ).copyWith(color: Palette.goldLight),
            ),
          ),
          const SizedBox(height: Palette.md),
          Row(
            children: [
              _veil(
                TextButton.icon(
                  onPressed: _revealed ? _copy : null,
                  icon: const Icon(Icons.copy, size: 14),
                  label: Text(l10n.commonCopy),
                ),
              ),
              const Spacer(),
              _RevealButton(
                revealed: _revealed,
                onTap: () => setState(() => _revealed = !_revealed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The eye that toggles address privacy: a soft gold disc when the address is
/// readable, a flat one when it is blurred, with the classic eye / eye-off
/// glyph. It is deliberately outside the veil, so hiding never locks the user
/// out. 44px keeps the touch target above the accessibility minimum.
class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.revealed, required this.onTap});

  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final label = revealed ? l10n.walletHideAddress : l10n.walletShowAddress;
    return Semantics(
      button: true,
      toggled: revealed,
      child: Tooltip(
        message: label,
        child: Material(
          color: revealed
              ? Palette.gold.withValues(alpha: 0.12)
              : Palette.surfaceHigh,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                revealed
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: revealed ? Palette.goldLight : Palette.slate,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.address,
    required this.api,
    required this.keystore,
    required this.network,
    required this.onBackup,
    required this.onSent,
  });

  final String? address;
  final BridgeApi? api;
  final Keystore? keystore;
  final CenNetwork network;
  final VoidCallback onBackup;
  final VoidCallback onSent;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Column(
      children: [
        // Three capsules with one accent each: send (blue, primary), receive
        // (green = incoming), swap (slate = not available yet). Swap still
        // opens a note on tap, so it reads "off" without hiding the release
        // plan behind it.
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: l10n.walletSend,
                icon: Icons.north_east,
                kind: _ActionKind.primary,
                onTap: () => _showSendOrReason(
                  context,
                  address: address,
                  api: api,
                  keystore: keystore,
                  network: network,
                  onSent: onSent,
                ),
              ),
            ),
            const SizedBox(width: Palette.sm),
            Expanded(
              child: _ActionButton(
                label: l10n.walletReceive,
                icon: Icons.south_west,
                kind: _ActionKind.secondary,
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
                kind: _ActionKind.soon,
                onTap: () => _showSwapUnavailable(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: Palette.md),
        NeonButton(
          label: l10n.walletBackupWords,
          icon: Icons.shield_outlined,
          onPressed: onBackup,
        ),
      ],
    );
  }
}

/// Swap is a planned feature, not a bug: CEN has no exchange listing yet, so
/// there is nothing to swap against. The button is deliberately de-emphasised
/// and this card spells out, in one line, why it doesn't work and that it
/// will later.
void _showSwapUnavailable(BuildContext context) {
  final l10n = l10nOf(context);
  showDialog<void>(
    context: context,
    builder: (_) => _SwapSoonDialog(
      eyebrow: l10n.walletSwapSoon,
      title: l10n.walletSwapUnavailable,
      body: l10n.walletSwapBody,
      actionLabel: l10n.commonGotIt,
    ),
  );
}

/// A small amber notice: a tinted swap glyph over a pill that reads "coming
/// soon", a one-line reason, and a single positive close. Amber, not blue, so
/// it reads as information rather than a call to action.
class _SwapSoonDialog extends StatelessWidget {
  const _SwapSoonDialog({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Palette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: Palette.xl),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(Palette.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.amber.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 64,
                height: 64,
                child: Center(
                  child: Icon(Icons.swap_horiz, size: 28, color: Palette.amber),
                ),
              ),
            ),
            const SizedBox(height: Palette.lg),
            Pill(
              label: eyebrow,
              background: Palette.amber.withValues(alpha: 0.16),
              foreground: Palette.amber,
              dense: true,
            ),
            const SizedBox(height: Palette.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TypeScale.headline(context),
            ),
            const SizedBox(height: Palette.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypeScale.label(context),
            ),
            const SizedBox(height: Palette.xl),
            GoldButton(
              label: actionLabel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ActionKind { primary, secondary, soon }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.kind,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final _ActionKind kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // primary (send) is solid blue with a soft glow; secondary (receive) is a
    // translucent pill with a green "incoming" glyph; soon (swap) is the same
    // pill drained to slate so it reads as not-yet-available without hiding
    // the release note behind it.
    final l10n = l10nOf(context);
    final filled = kind == _ActionKind.primary;
    final soon = kind == _ActionKind.soon;
    final disabled = onTap == null;

    final Color background = filled
        ? Palette.gold
        : (soon || disabled)
            ? Palette.field
            : Palette.surfaceHigh;
    final Color foreground = filled
        ? Palette.white
        : (soon || disabled)
            ? Palette.slate
            : Palette.cream;
    final Color iconColor = filled
        ? Palette.white
        : (soon || disabled)
            ? Palette.slate
            : Palette.green;

    final Widget pill = Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        // Material takes either a shape or a borderRadius, never both, so the
        // pill shape carries the radius and the outline lives inside it.
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Palette.pill),
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: Palette.slate.withValues(alpha: soon ? 0.28 : 0.35),
                ),
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
                Icon(icon, size: 17, color: iconColor),
                const SizedBox(width: Palette.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeScale.title(context).copyWith(
                      color: foreground,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: onTap != null,
      hint: soon ? l10n.walletSwapUnavailable : null,
      child: filled
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Palette.pill),
                boxShadow: [
                  BoxShadow(
                    color: Palette.gold.withValues(alpha: 0.22),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: pill,
            )
          : pill,
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

void _showSendOrReason(
  BuildContext context, {
  required String? address,
  required BridgeApi? api,
  required Keystore? keystore,
  required CenNetwork network,
  required VoidCallback onSent,
}) {
  final l10n = l10nOf(context);
  final String? reasonTitle;
  final String? reasonBody;
  if (address == null) {
    reasonTitle = l10n.walletSendNoAddress;
    reasonBody = l10n.walletSendNoAddressBody;
  } else if (api == null) {
    reasonTitle = l10n.walletSendNodeDown;
    reasonBody = l10n.walletSendNodeDownBody;
  } else {
    reasonTitle = null;
    reasonBody = null;
  }

  if (reasonTitle != null) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(reasonTitle!, style: TypeScale.headline(context)),
        content: Text(reasonBody ?? '', style: TypeScale.label(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
    return;
  }

  _showSendSheet(
    context,
    from: address!,
    api: api!,
    keystore: keystore,
    network: network,
    onSent: onSent,
  );
}

void _showSendSheet(
  BuildContext context, {
  required String from,
  required BridgeApi api,
  required Keystore? keystore,
  required CenNetwork network,
  required VoidCallback onSent,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SendSheet(
      from: from,
      api: api,
      keystore: keystore,
      network: network,
      onSent: onSent,
    ),
  );
}

/// The send form: recipient, amount, and the fixed network fee.
///
/// Signing happens inside the bridge. The app reads the locally stored
/// recovery words, derives the key, and hands it over per-request, so the key
/// exists on the device only in the form of those words and is never logged.
class _SendSheet extends StatefulWidget {
  const _SendSheet({
    required this.from,
    required this.api,
    required this.keystore,
    required this.network,
    required this.onSent,
  });

  final String from;
  final BridgeApi api;
  final Keystore? keystore;
  final CenNetwork network;
  final VoidCallback onSent;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  static const int _pradhaPerCen = 100000000;

  /// Fixed fee, matching the proven `--fee` default in `tx_e2e`: 0.01 CEN.
  static const int feePradha = 1000000;
  static const String _feeDisplay = '0.01 CEN';

  /// Highest spendable value (i64 max). The chain's u64 range is wider, but a
  /// real amount cannot approach either bound: total supply is 34.5M CEN.
  static final BigInt _maxPradha = BigInt.from(0x7FFFFFFFFFFFFFFF);

  late final Keystore _keystore = widget.keystore ?? Keystore();

  final _toController = TextEditingController();
  final _amountController = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _txid;

  @override
  void dispose() {
    _toController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Parses a decimal CEN amount into pradha with integer math, so values stay
  /// exact past 2^53. Null when the input is not a positive decimal with at
  /// most eight fractional digits (a fraction of a pradha cannot be sent).
  int? _amountToPradha() {
    final trimmed = _amountController.text.trim();
    final match = RegExp(r'^(\d+)(?:\.(\d{0,8}))?$').firstMatch(trimmed);
    if (match == null) return null;
    final whole = BigInt.parse(match.group(1)!);
    final fracDigits = match.group(2) ?? '';
    final frac = fracDigits.isEmpty
        ? BigInt.zero
        : BigInt.parse(fracDigits.padRight(8, '0'));
    final total = whole * BigInt.from(_pradhaPerCen) + frac;
    if (total <= BigInt.zero || total > _maxPradha) return null;
    return total.toInt();
  }

  Future<void> _submit() async {
    final l10n = l10nOf(context);
    final to = _toController.text.trim();
    final amountPradha = _amountToPradha();

    if (to.isEmpty) {
      setState(() => _error = l10n.walletSendNeedRecipient);
      return;
    }
    if (amountPradha == null) {
      setState(() => _error = l10n.walletSendInvalidAmount);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final phrase = await _keystore.readPhrase();
      if (phrase == null) {
        if (mounted) setState(() => _error = l10n.walletSendNoKey);
        return;
      }
      final wallet = CenWallet.fromMnemonic(
        Mnemonic.fromPhrase(phrase),
        widget.network,
      );
      if (wallet.address != widget.from) {
        if (mounted) setState(() => _error = l10n.walletSendKeyMismatch);
        return;
      }
      final result = await widget.api.sendCoins(
        from: widget.from,
        to: to,
        amountPradha: amountPradha,
        feePradha: feePradha,
        privateKeyHex: wallet.privateKeyHex,
      );
      if (!mounted) return;
      if (result.ok) {
        setState(() => _txid = result.txid);
        widget.onSent();
      } else {
        setState(() => _error = result.error ?? l10n.walletSendFailed);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(
    BuildContext context, {
    required String hint,
    String? suffix,
    bool green = false,
  }) {
    final enabled = green
        ? Palette.green.withValues(alpha: 0.35)
        : Palette.surfaceHigh;
    final focused = green ? Palette.green : Palette.goldLight;
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      filled: true,
      fillColor: green
          ? Palette.green.withValues(alpha: 0.06)
          : Palette.field,
      hintStyle: TypeScale.monoMuted(context, size: 12),
      suffixStyle: TypeScale.monoMuted(context, size: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: BorderSide(color: enabled),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: BorderSide(color: focused),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Palette.xl,
          right: Palette.xl,
          top: Palette.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + Palette.xl,
        ),
        child: _txid == null ? _buildForm(l10n) : _buildSuccess(l10n),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.walletSendTitle, style: TypeScale.screenTitle(context)),
          const SizedBox(height: Palette.lg),
          CenCard(
            padding: const EdgeInsets.all(Palette.lg),
            color: Palette.green.withValues(alpha: 0.08),
            border: BorderSide(color: Palette.green.withValues(alpha: 0.30)),
            radius: Palette.rowRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(l10n.walletMiningAddress, color: Palette.green),
                const SizedBox(height: Palette.sm),
                SelectableText(
                  widget.from,
                  style: TypeScale.mono(
                    context,
                    size: 12,
                  ).copyWith(color: Palette.cream),
                ),
              ],
            ),
          ),
          const SizedBox(height: Palette.lg),
          Eyebrow(l10n.walletSendRecipient, color: Palette.green),
          const SizedBox(height: Palette.sm),
          TextField(
            controller: _toController,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            style: TypeScale.mono(context, size: 13).copyWith(
              color: Palette.cream,
            ),
            decoration: _field(
              context,
              hint: '${widget.network.prefix}:…',
              green: true,
            ),
          ),
          const SizedBox(height: Palette.lg),
          Eyebrow(l10n.walletSendAmount),
          const SizedBox(height: Palette.sm),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TypeScale.hero(context).copyWith(color: Palette.cream),
            decoration: _field(context, hint: '0.00', suffix: 'CEN'),
          ),
          const SizedBox(height: Palette.lg),
          Row(
            children: [
              Text(l10n.walletSendFee, style: TypeScale.label(context)),
              const Spacer(),
              Text(
                _feeDisplay,
                style: TypeScale.mono(
                  context,
                  size: 12,
                ).copyWith(color: Palette.goldLight),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: Palette.md),
            Text(
              _error!,
              style: TypeScale.caption(context).copyWith(color: Palette.red),
            ),
          ],
          const SizedBox(height: Palette.xl),
          GoldButton(
            label: _busy ? l10n.walletSendSending : l10n.walletSendConfirm,
            icon: Icons.north_east,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Palette.green.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 30,
                    color: Palette.greenDim,
                  ),
                ),
                const SizedBox(height: Palette.md),
                Text(l10n.walletSendSuccess, style: TypeScale.screenTitle(context)),
                const SizedBox(height: Palette.sm),
                Text(
                  l10n.walletSendSuccessBody,
                  textAlign: TextAlign.center,
                  style: TypeScale.label(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: Palette.xl),
          Eyebrow(l10n.walletSendTxId),
          const SizedBox(height: Palette.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Palette.md),
            decoration: BoxDecoration(
              color: Palette.surfaceHigh,
              borderRadius: BorderRadius.circular(Palette.rowRadius),
            ),
            child: SelectableText(
              _txid!,
              style: TypeScale.mono(
                context,
                size: 10,
              ).copyWith(color: Palette.goldLight),
            ),
          ),
          const SizedBox(height: Palette.xl),
          GoldButton(
            label: l10n.commonDone,
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
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
                color: Palette.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Palette.rowRadius),
                border: Border.all(
                  color: Palette.green.withValues(alpha: 0.30),
                ),
              ),
              child: SelectableText(
                address,
                style: TypeScale.mono(
                  context,
                  size: 12,
                ).copyWith(color: Palette.cream),
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
/// `pre_deflationary_phase_base_subsidy() = 50000000000 / BPS` pradha, with
/// BPS = 10, and 1 CEN = 100000000 pradha. That gives 50 CEN per block.
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

/// Turns a block timestamp into the concept's short form: TODAY, YESTERDAY, or
/// a date. Falls back to the raw string when it cannot be parsed.
///
/// The bridge reports Unix seconds (see [friendlyBlockTime]), so the value is
/// routed through the shared parser rather than `DateTime.tryParse` here —
/// a raw epoch parses to nothing and would otherwise leak through verbatim.
String _friendlyTime(AppLocalizations l10n, String raw) => friendlyBlockTime(
      raw,
      todayLabel: l10n.commonToday,
      yesterdayLabel: l10n.commonYesterday,
    );
