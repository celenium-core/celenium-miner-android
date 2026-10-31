import 'package:flutter/material.dart';

import '../models/bridge.dart';
import '../services/mining_readout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/cen_ui.dart';

/// Profile.
///
/// The concept version carried a rank, a referral count, a verified badge and
/// a days-active figure. None of those exist in this build: there is no
/// account system to rank, no referral tracking, and nothing to verify. The
/// three stats shown here are the three the bridge actually reports.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.snapshot,
    required this.networkLabel,
    required this.onOpenBridge,
    required this.onOpenWorkers,
    required this.onOpenActivity,
    required this.onOpenBackup,
    required this.onOpenAbout,
  });

  final MinerSnapshot snapshot;
  final String networkLabel;
  final VoidCallback onOpenBridge;
  final VoidCallback onOpenWorkers;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenBackup;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final readout = MiningReadout.from(snapshot);
    final stats = snapshot.stats;
    final workers = stats?.workers.length ?? 0;
    final address = stats?.internalCpu?.wallet;
    final nodeAddress = snapshot.status?.celeniumdAddress;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Palette.lg, Palette.sm, Palette.lg, Palette.xxl),
      children: [
        // Network label left, live status right, serif title beneath: the
        // same top bar the concept uses on both Profile and Wallet.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    networkLabel.toUpperCase(),
                    style: TypeScale.monoMuted(context, size: 10).copyWith(letterSpacing: 1.4),
                  ),
                ),
                LiveStatus(
                  label: readout.active ? 'ACTIVE' : 'IDLE',
                  active: readout.active,
                  tint: Palette.greenDim,
                ),
              ],
            ),
            const SizedBox(height: Palette.sm),
            Text('Profile', style: TypeScale.screenTitle(context)),
          ],
        ),
        const SizedBox(height: Palette.lg),
        _IdentityCard(
          workerName: readout.workerName,
          address: address,
          active: readout.active,
        ),
        const SizedBox(height: Palette.md),
        // Four cells, matching the concept's strip. All four come from the
        // bridge: the concept's referrals, days, and rank have no source here,
        // so they are replaced by counts that do.
        CenCard.glass(
          glow: Palette.gold,
          child: Row(
            children: [
              Expanded(
                child: StatCell(
                  value: readout.sessionBlocks?.toString() ?? '—',
                  label: 'blocks',
                  color: Palette.goldLight,
                ),
              ),
              const StatDivider(),
              Expanded(child: StatCell(value: readout.shares?.toString() ?? '—', label: 'shares')),
              const StatDivider(),
              Expanded(child: StatCell(value: workers > 0 ? workers.toString() : '—', label: 'workers')),
              const StatDivider(),
              Expanded(
                child: StatCell(
                  value: readout.hashrateGhs == null
                      ? '—'
                      : formatHashrate(readout.hashrateGhs!).split(' ').first,
                  unit: 'GH/s',
                  label: 'hashrate',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        Eyebrow('Settings'),
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
                label: 'Bridge',
                trailing: Text(
                  nodeAddress == null ? 'not set' : _shortNode(nodeAddress),
                  style: TypeScale.monoMuted(context, size: 10),
                ),
                onTap: onOpenBridge,
              ),
              SettingRow(
                flat: true,
                icon: Icons.dns_outlined,
                label: 'Workers',
                trailing: workers > 0 ? Pill(label: '$workers', dense: true) : null,
                onTap: onOpenWorkers,
              ),
              SettingRow(
                flat: true,
                icon: Icons.receipt_long_outlined,
                label: 'Activity log',
                onTap: onOpenActivity,
              ),
              SettingRow(
                flat: true,
                icon: Icons.shield_outlined,
                label: 'Recovery words',
                tint: Palette.goldLight,
                onTap: onOpenBackup,
              ),
              SettingRow(
                flat: true,
                last: true,
                icon: Icons.info_outline,
                label: 'About',
                tint: Palette.slate,
                onTap: onOpenAbout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.workerName, required this.address, required this.active});

  final String? workerName;
  final String? address;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // The cream card, as in the concept: the one large light mass on an
    // otherwise dark screen, which is what makes the white accent read.
    return CenCard.light(
      glow: Palette.gold,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: Palette.ink, shape: BoxShape.circle),
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
                        workerName ?? 'No worker',
                        style: TypeScale.headline(context).copyWith(color: Palette.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Palette.sm),
                    // Green verified pill with a tick, as in the concept. It
                    // marks a real state: the bridge reports this worker
                    // hashing, which is the only thing there is to verify.
                    if (active)
                      const Pill(
                        label: 'ACTIVE',
                        background: Palette.green,
                        foreground: Palette.ink,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address == null ? 'no address reported' : 'mining to ${_shortAddress(address!)}',
                  style: TypeScale.mono(context, size: 10).copyWith(color: Palette.slate),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _shortAddress(String address) {
  if (address.length <= 22) return address;
  return '${address.substring(0, 12)}…${address.substring(address.length - 8)}';
}

/// Node addresses are host:port, so the port is the part worth keeping.
String _shortNode(String address) {
  final separator = address.lastIndexOf(':');
  if (separator <= 0) return address;
  return '…${address.substring(separator)}';
}
