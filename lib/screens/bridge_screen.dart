import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bridge.dart';
import '../services/settings_store.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/cen_ui.dart';

/// Bridge and app settings.
///
/// This is the screen that makes the rest of the app work: it holds the one
/// address the app needs, and how often it polls. Everything is plain text
/// input; nothing here is a secret.
class BridgeScreen extends StatefulWidget {
  const BridgeScreen({
    super.key,
    required this.settings,
    required this.snapshot,
  });

  final SettingsStore settings;
  final MinerSnapshot snapshot;

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  final _urlController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  int _intervalMs = SettingsStore.defaultIntervalMs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await widget.settings.baseUrl();
    final interval = await widget.settings.intervalMs();
    if (!mounted) return;
    _urlController.text = url;
    _intervalMs = interval;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.settings.setBaseUrl(_urlController.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10nOf(context).bridgeSaved)),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final status = widget.snapshot.status;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bridgeTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CenContent(
              child: ListView(
                padding: const EdgeInsets.all(Palette.lg),
                children: [
                  _NodeCard(
                    online: status != null,
                    address: status?.celeniumdAddress,
                    version: status?.celeniumdVersion,
                    instances: status?.instances,
                  ),
                  const SizedBox(height: Palette.lg),
                  CenCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(l10n.bridgeAddress),
                        const SizedBox(height: Palette.sm),
                        TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          style: TypeScale.mono(
                            context,
                            size: 13,
                          ).copyWith(color: Palette.cream),
                          decoration: const InputDecoration(
                            hintText: 'http://5.178.98.100:3031',
                          ),
                        ),
                        const SizedBox(height: Palette.sm),
                        Text(
                          l10n.bridgeAddressNote,
                          style: TypeScale.caption(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Palette.md),
                  CenCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(l10n.bridgePollInterval),
                        const SizedBox(height: Palette.sm),
                        _IntervalPicker(
                          value: _intervalMs,
                          onChanged: (ms) async {
                            setState(() => _intervalMs = ms);
                            await widget.settings.setIntervalMs(ms);
                          },
                        ),
                        const SizedBox(height: Palette.sm),
                        Text(
                          l10n.bridgePollNote,
                          style: TypeScale.caption(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Palette.xl),
                  GoldButton(
                    label: _saving ? l10n.commonSaving : l10n.commonSave,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.online,
    this.address,
    this.version,
    this.instances,
  });

  final bool online;
  final String? address;
  final String? version;
  final int? instances;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return CenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(l10n.bridgeNode)),
              LiveStatus(
                label: online ? l10n.statusOnline : l10n.statusOffline,
                active: online,
                tint: Palette.greenDim,
              ),
            ],
          ),
          const SizedBox(height: Palette.md),
          _InfoRow(label: l10n.bridgeInfoAddress, value: address ?? '—'),
          _InfoRow(label: l10n.bridgeInfoVersion, value: version ?? '—'),
          _InfoRow(
            label: l10n.bridgeInfoInstances,
            value: instances?.toString() ?? '—',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Palette.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: TypeScale.caption(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: TypeScale.mono(
                context,
                size: 11,
              ).copyWith(color: Palette.creamDim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preset poll intervals. A slider would imply any value is useful; these four
/// cover the range that actually matters on a phone.
class _IntervalPicker extends StatelessWidget {
  const _IntervalPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const List<int> _presets = [1000, 2000, 5000, 10000];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Palette.sm,
      runSpacing: Palette.sm,
      children: [
        for (final ms in _presets)
          _IntervalChip(
            ms: ms,
            selected: value == ms,
            onTap: () => onChanged(ms),
          ),
      ],
    );
  }
}

class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    required this.ms,
    required this.selected,
    required this.onTap,
  });

  final int ms;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Palette.lg,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? Palette.gold : Palette.surfaceHigh,
          borderRadius: BorderRadius.circular(Palette.pill),
        ),
        child: Text(
          '${ms ~/ 1000}s',
          style: TypeScale.caption(context).copyWith(
            color: selected ? Palette.ink : Palette.creamDim,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
