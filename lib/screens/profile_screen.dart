import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../services/device_identity.dart';
import '../services/mining_readout.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/cen_ui.dart';

/// Profile.
///
/// The concept version carried a rank, a referral count, a verified badge and
/// a days-active figure. None of those exist in this build: there is no
/// account system to rank, no referral tracking, and nothing to verify. What
/// remains is the one card the bridge can actually fill: which device is
/// mining — its IP and Android ID — and whether it is hashing right now.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.snapshot,
    this.language = AppLanguage.system,
    this.onLanguageChanged,
    required this.onOpenBridge,
    required this.onOpenActivity,
    required this.onOpenBackup,
    required this.onOpenAbout,
    this.deviceIpOverride,
  });

  final MinerSnapshot snapshot;

  /// Pinned device label for the profile card. Production resolves it from
  /// [deviceIdentityLabel]; screenshot tests pin it so the goldens stay
  /// byte-stable regardless of the machine that runs them.
  final String? deviceIpOverride;

  /// The interface language in force, and the way to change it. The root owns
  /// the locale, so the picker reports back rather than switching directly.
  final AppLanguage language;
  final ValueChanged<AppLanguage>? onLanguageChanged;

  final VoidCallback onOpenBridge;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenBackup;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final readout = MiningReadout.from(snapshot);
    final deviceLabel = deviceIpOverride != null
        ? Future<String?>.value(deviceIpOverride)
        : deviceIdentityLabel();
    final nodeAddress = snapshot.status?.celeniumdAddress;

    return CenContent(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Palette.sm),
          // Page name left, live status right: the same compact top bar Wallet
          // uses. The network label is gone — it only ever said SIMNET, which
          // is no longer true past mainnet — so the page name carries its slot.
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.profileTitle.toUpperCase(),
                  style: TypeScale.caption(context).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              LiveStatus(
                label: readout.active ? l10n.statusActive : l10n.statusIdle,
                active: readout.active,
                tint: Palette.greenDim,
              ),
            ],
          ),
          const SizedBox(height: Palette.lg),
          _IdentityCard(deviceLabel: deviceLabel, active: readout.active),
          const SizedBox(height: Palette.xl),
          Eyebrow(l10n.profileSettings),
          const SizedBox(height: Palette.sm),
          // One card holding the whole group, rows separated by hairlines.
          // Five floating tiles read as five unrelated things; one card with
          // internal dividers reads as the settings section it is.
          CenCard.glass(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SettingRow(
                  flat: true,
                  icon: Icons.hub_outlined,
                  label: l10n.profileBridgeRow,
                  trailing: Text(
                    nodeAddress == null
                        ? l10n.profileNotSet
                        : _shortNode(nodeAddress),
                    style: TypeScale.monoMuted(context, size: 10),
                  ),
                  onTap: onOpenBridge,
                ),
                SettingRow(
                  flat: true,
                  icon: Icons.receipt_long_outlined,
                  label: l10n.profileActivityRow,
                  onTap: onOpenActivity,
                ),
                SettingRow(
                  flat: true,
                  icon: Icons.shield_outlined,
                  label: l10n.profileRecoveryRow,
                  tint: Palette.goldLight,
                  onTap: onOpenBackup,
                ),
                SettingRow(
                  flat: true,
                  icon: Icons.translate_outlined,
                  label: l10n.profileLanguage,
                  trailing: Text(
                    _languageLabel(l10n, language),
                    style: TypeScale.monoMuted(context, size: 10),
                  ),
                  onTap: () => _showLanguageSheet(
                    context,
                    current: language,
                    onChanged: onLanguageChanged,
                  ),
                ),
                SettingRow(
                  flat: true,
                  last: true,
                  icon: Icons.info_outline,
                  label: l10n.profileAboutRow,
                  tint: Palette.slate,
                  onTap: onOpenAbout,
                ),
              ],
            ),
          ),
          const SizedBox(height: Palette.xxl),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.deviceLabel, required this.active});

  /// Resolves to the device's IP and Android ID line; null while unknown.
  final Future<String?> deviceLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    // The cream card, as in the concept: the one large light mass on an
    // otherwise dark screen, which is what makes the white accent read.
    return CenCard.light(
      glow: Palette.gold,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Palette.field,
              shape: BoxShape.circle,
            ),
            child: Center(child: BrandMark(size: 30, onDark: true)),
          ),
          const SizedBox(width: Palette.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Celenium Miner',
                        style: TypeScale.headline(context)
                            .copyWith(color: Palette.creamInk),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Palette.sm),
                    // Green verified pill with a tick, as in the concept. It
                    // marks a real state: the bridge reports this worker
                    // hashing, which is the only thing there is to verify.
                    if (active)
                      Pill(
                        label: l10n.statusActive,
                        background: Palette.green,
                        foreground: Palette.ink,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // The device itself, not the wallet: the address is already on
                // the Wallet tab, and what identifies this worker is the phone
                // — its LAN address and the Android ID the key hangs off.
                FutureBuilder<String?>(
                  future: deviceLabel,
                  builder: (context, snapshot) => Text(
                    snapshot.data ?? l10n.profileDeviceUnknown,
                    style: TypeScale.mono(
                      context,
                      size: 10,
                    ).copyWith(color: Palette.creamInkDim),
                    overflow: TextOverflow.ellipsis,
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

/// Node addresses are host:port, so the port is the part worth keeping.
String _shortNode(String address) {
  final separator = address.lastIndexOf(':');
  if (separator <= 0) return address;
  return '…${address.substring(separator)}';
}

/// The name of a language in the settings row. The system option is spelled
/// out in the current interface language, because it means "follow the phone",
/// not a language called System.
String _languageLabel(AppLocalizations l10n, AppLanguage language) =>
    language == AppLanguage.system
    ? l10n.profileLanguageSystem
    : language.label;

/// Sheet for picking the interface language. Reports the choice back to the
/// root rather than switching here: only the [MaterialApp] can change locales.
Future<void> _showLanguageSheet(
  BuildContext context, {
  required AppLanguage current,
  required ValueChanged<AppLanguage>? onChanged,
}) async {
  final l10n = l10nOf(context);
  final selected = await showModalBottomSheet<AppLanguage>(
    context: context,
    backgroundColor: Palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Palette.xl)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Palette.lg,
              Palette.lg,
              Palette.lg,
              Palette.sm,
            ),
            child: Text(
              l10n.profileLanguage,
              style: TypeScale.title(sheetContext),
            ),
          ),
          for (final option in AppLanguage.values)
            _LanguageOption(
              label: option == AppLanguage.system
                  ? l10n.profileLanguageSystem
                  : option.label,
              selected: option == current,
              onTap: () => Navigator.of(sheetContext).pop(option),
            ),
          const SizedBox(height: Palette.sm),
        ],
      ),
    ),
  );

  if (selected == null || selected == current) return;
  onChanged?.call(selected);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l10n.profileLanguageDone)));
}

/// One row of the language sheet. Full-width and 52 high so it clears the
/// 44-pixel touch target with room to spare.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Palette.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TypeScale.label(
                    context,
                  ).copyWith(color: selected ? Palette.gold : Palette.creamDim),
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 18, color: Palette.gold),
            ],
          ),
        ),
      ),
    );
  }
}
