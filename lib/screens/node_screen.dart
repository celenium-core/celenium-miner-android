import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/bridge_api.dart';
import '../theme/tokens.dart';

/// True on a phone or tablet, where 127.0.0.1 resolves to the device itself
/// rather than the desktop running the bridge.
bool get _onPhone {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}

/// Connection settings for the bridge.
///
/// The address field is validated and the Test connection button performs a
/// real request, so the control either works or reports what failed.
class NodeScreen extends StatelessWidget {
  const NodeScreen({
    required this.baseUrl,
    required this.onSave,
    required this.adUnitId,
    required this.onSaveAdUnitId,
    super.key,
  });

  final String baseUrl;
  final Future<void> Function(String url) onSave;
  final String? adUnitId;
  final Future<void> Function(String? value) onSaveAdUnitId;

  @override
  Widget build(BuildContext context) {
    return _NodeScreenBody(
      baseUrl: baseUrl,
      onSave: onSave,
      adUnitId: adUnitId,
      onSaveAdUnitId: onSaveAdUnitId,
    );
  }
}

class _NodeScreenBody extends StatefulWidget {
  const _NodeScreenBody({
    required this.baseUrl,
    required this.onSave,
    required this.adUnitId,
    required this.onSaveAdUnitId,
  });

  final String baseUrl;
  final Future<void> Function(String url) onSave;
  final String? adUnitId;
  final Future<void> Function(String? value) onSaveAdUnitId;

  @override
  State<_NodeScreenBody> createState() => _NodeScreenBodyState();
}

class _NodeScreenBodyState extends State<_NodeScreenBody> {
  late final TextEditingController _controller;
  late final TextEditingController _adController;
  String? _error;
  String? _result;
  String? _adResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.baseUrl);
    _adController = TextEditingController(text: widget.adUnitId ?? '');
  }

  @override
  void didUpdateWidget(_NodeScreenBody old) {
    super.didUpdateWidget(old);
    if (widget.baseUrl != old.baseUrl && widget.baseUrl != _controller.text) {
      _controller.text = widget.baseUrl;
    }
    if (widget.adUnitId != old.adUnitId &&
        widget.adUnitId != _adController.text) {
      _adController.text = widget.adUnitId ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _adController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = normaliseBaseUrl(_controller.text);
    if (url == null) {
      setState(() => _error = 'Enter a host and port, for example 127.0.0.1:3030');
      return;
    }
    setState(() {
      _error = null;
      _result = null;
    });
    await widget.onSave(url);
    if (!mounted) return;
    setState(() => _result = 'Saved. The dashboard now reads from $url');
  }

  Future<void> _saveAdUnitId() async {
    final value = _adController.text.trim();
    await widget.onSaveAdUnitId(value.isEmpty ? null : value);
    if (!mounted) return;
    setState(() => _adResult = value.isEmpty
        ? 'Removed. The banner slot is hidden again.'
        : 'Saved. The banner slot is now visible at the bottom of the screen.');
  }

  Future<void> _clearAdUnitId() async {
    _adController.clear();
    await widget.onSaveAdUnitId(null);
    if (!mounted) return;
    setState(() => _adResult = 'Removed. The banner slot is hidden again.');
  }

  Future<void> _test() async {
    final url = normaliseBaseUrl(_controller.text);
    if (url == null) {
      setState(() => _error = 'Enter a host and port, for example 127.0.0.1:3030');
      return;
    }
    setState(() {
      _error = null;
      _result = null;
      _testing = true;
    });
    try {
      final status = await BridgeApi(baseUrl: url).fetchStatus();
      if (!mounted) return;
      setState(() => _result =
          'Reachable. Node ${status.celeniumdAddress} running ceniumd '
          '${status.celeniumdVersion}, ${status.instances} instance(s).');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach $url: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text('Node', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Space.xs),
        Text(
          'Address of the stratum bridge web dashboard.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFeatures: Type.tabular,
              ),
          decoration: InputDecoration(
            labelText: 'Bridge address',
            hintText: '127.0.0.1:3030',
            helperText: 'The bridge serves /api/status and /api/stats on its '
                'web dashboard port.',
            filled: true,
            fillColor: Palette.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              borderSide: const BorderSide(color: Palette.surfaceHigh),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              borderSide: const BorderSide(color: Palette.surfaceHigh),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              borderSide: const BorderSide(color: Palette.accent),
            ),
          ),
          onSubmitted: (_) => _save(),
        ),
        // On a phone, 127.0.0.1 is the phone itself, so the default address
        // can never reach a bridge running on a desktop. Say so rather than
        // leaving the user to guess why every poll fails.
        if (_onPhone) ...[
          const SizedBox(height: Space.sm),
          Text(
            'On a phone, 127.0.0.1 means this device. Use the LAN address of '
            'the machine running the bridge.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Palette.accent,
                ),
          ),
        ],
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              ),
              child: const Text('Save address'),
            ),
            OutlinedButton(
              onPressed: _testing ? null : _test,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                side: const BorderSide(color: Palette.surfaceHigh),
                foregroundColor: Palette.textPrimary,
              ),
              child: Text(_testing ? 'Testing...' : 'Test connection'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.lg),
          _Notice(message: _error!, isError: true),
        ],
        if (_result != null) ...[
          const SizedBox(height: Space.lg),
          _Notice(message: _result!, isError: false),
        ],
        const SizedBox(height: Space.xxl),
        Text(
          'No account, no database',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Space.sm),
        Text(
          'There is no sign-up, no login and no server holding your data. The '
          'app opens straight into the dashboard. The only things it remembers '
          'on this device are the bridge address and whether you closed the ad '
          'banner - both are local preferences, not an account, and clearing '
          'them costs you nothing.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Space.xxl),
        Text('How the app reads data', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        Text(
          'The app polls the bridge over HTTP. It holds no private key and '
          'signs nothing, so it cannot move funds. Mining itself is started by '
          'launching the bridge with the internal miner flag; the bridge '
          'exposes no runtime start or stop endpoint, so the app reports the '
          'state it finds rather than pretending to change it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Space.xxl),
        Text('Advertising', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        Text(
          'The banner only appears once a real ad is actually served. A '
          'configured slot with no ad stays completely invisible and reserves '
          'no space. It floats over the bottom of the screen so it never '
          'pushes your content, and the user can close it for good at any '
          'time.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _adController,
          keyboardType: TextInputType.text,
          autocorrect: false,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFeatures: Type.tabular,
              ),
          decoration: InputDecoration(
            labelText: 'Banner ad unit id',
            hintText: 'ca-app-pub-0000000000000000/0000000000',
            helperText:
                'Leave empty to keep the slot hidden. No ad network is wired '
                'in yet, so saving an id shows the slot but earns nothing.',
            filled: true,
            fillColor: Palette.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              borderSide: const BorderSide(color: Palette.surfaceHigh),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              borderSide: const BorderSide(color: Palette.surfaceHigh),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              borderSide: const BorderSide(color: Palette.accent),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            FilledButton(
              onPressed: _saveAdUnitId,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              ),
              child: const Text('Save ad unit id'),
            ),
            OutlinedButton(
              onPressed: _clearAdUnitId,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                side: const BorderSide(color: Palette.surfaceHigh),
                foregroundColor: Palette.textPrimary,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
        if (_adResult != null) ...[
          const SizedBox(height: Space.lg),
          _Notice(message: _adResult!, isError: false),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Palette.danger : Palette.accent;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18, color: color),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
