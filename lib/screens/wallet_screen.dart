import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
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
    required this.networkLabel,
    required this.onBackup,
    required this.onOpenActivity,
    this.api,
    this.keystore,
    this.network = CenNetwork.simnet,
  });

  final MinerSnapshot snapshot;
  final String networkLabel;

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
            networkLabel: widget.networkLabel,
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
          Text(
            balance?.formattedCen ?? '—',
            style: TypeScale.hero(context).copyWith(color: Palette.creamInk),
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
        // Three capsules, send first and in gold: moving coins is the reason
        // the screen exists, so it takes the primary slot.
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: l10n.walletSend,
                icon: Icons.north_east,
                primary: true,
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

  InputDecoration _field(BuildContext context, {required String hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      filled: true,
      fillColor: Palette.field,
      hintStyle: TypeScale.monoMuted(context, size: 12),
      suffixStyle: TypeScale.monoMuted(context, size: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: const BorderSide(color: Palette.surfaceHigh),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: const BorderSide(color: Palette.goldLight),
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
          const SizedBox(height: Palette.sm),
          Text(
            widget.from,
            style: TypeScale.monoMuted(context, size: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Palette.lg),
          Eyebrow(l10n.walletSendRecipient),
          const SizedBox(height: Palette.sm),
          TextField(
            controller: _toController,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            style: TypeScale.mono(context, size: 13).copyWith(
              color: Palette.cream,
            ),
            decoration: _field(context, hint: '${widget.network.prefix}:…'),
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
