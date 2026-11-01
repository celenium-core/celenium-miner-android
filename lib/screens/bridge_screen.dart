import 'package:flutter/material.dart';

import '../models/bridge.dart';
import '../services/settings_store.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/cen_ui.dart';

/// Bridge and app settings.
///
/// This is the screen that makes the rest of the app work: it holds the one
/// address the app needs, how often it polls, and the ad slot. Everything is
/// plain text input; nothing here is a secret.
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
  final _adController = TextEditingController();
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
    final ad = await widget.settings.adUnitId();
    final interval = await widget.settings.intervalMs();
    if (!mounted) return;
    _urlController.text = url;
    _adController.text = ad ?? '';
    _intervalMs = interval;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.settings.setBaseUrl(_urlController.text.trim());
    await widget.settings.setAdUnitId(_adController.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Bridge address saved')));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _adController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.snapshot.status;

    return Scaffold(
      appBar: AppBar(title: const Text('BRIDGE')),
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
                        Eyebrow('Bridge address'),
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
                            hintText: 'http://127.0.0.1:3030',
                          ),
                        ),
                        const SizedBox(height: Palette.sm),
                        Text(
                          'The bridge serves mining results over HTTP. No account and no '
                          'credentials are sent with the request.',
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
                        Eyebrow('Poll interval'),
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
                          'How often the app asks the bridge for fresh figures. A shorter '
                          'interval updates faster and uses more battery.',
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
                        Eyebrow('Ad unit id'),
                        const SizedBox(height: Palette.sm),
                        TextField(
                          controller: _adController,
                          autocorrect: false,
                          style: TypeScale.mono(
                            context,
                            size: 13,
                          ).copyWith(color: Palette.cream),
                          decoration: const InputDecoration(
                            hintText: 'ca-app-pub-…/…',
                          ),
                        ),
                        const SizedBox(height: Palette.sm),
                        Text(
                          'Leave this empty and no banner is requested. The banner only '
                          'appears once a real ad is served: an empty slot reserves no '
                          'space and shows nothing.',
                          style: TypeScale.caption(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Palette.xl),
                  GoldButton(
                    label: _saving ? 'Saving…' : 'Save',
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
    return CenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow('Node')),
              LiveStatus(
                label: online ? 'ONLINE' : 'OFFLINE',
                active: online,
                tint: Palette.greenDim,
              ),
            ],
          ),
          const SizedBox(height: Palette.md),
          _InfoRow(label: 'Address', value: address ?? '—'),
          _InfoRow(label: 'Version', value: version ?? '—'),
          _InfoRow(label: 'Instances', value: instances?.toString() ?? '—'),
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
