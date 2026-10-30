import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/bridge.dart';
import 'screens/dashboard_screen.dart';
import 'screens/log_screen.dart';
import 'screens/node_screen.dart';
import 'screens/workers_screen.dart';
import 'services/bridge_api.dart';
import 'services/settings_store.dart';
import 'theme/tokens.dart';
import 'widgets/ad_banner.dart';
import 'widgets/glass_panel.dart';

void main() {
  runApp(const CeniumMinerApp());
}

class CeniumMinerApp extends StatelessWidget {
  const CeniumMinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cenium Miner',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const MinerHome(),
    );
  }
}

enum _Destination { dashboard, workers, node, activity }

const _labels = {
  _Destination.dashboard: 'Mining',
  _Destination.workers: 'Workers',
  _Destination.node: 'Node',
  _Destination.activity: 'Activity',
};

const _icons = {
  _Destination.dashboard: Icons.bolt_outlined,
  _Destination.workers: Icons.dns_outlined,
  _Destination.node: Icons.settings_ethernet_outlined,
  _Destination.activity: Icons.receipt_long_outlined,
};

const _selectedIcons = {
  _Destination.dashboard: Icons.bolt,
  _Destination.workers: Icons.dns,
  _Destination.node: Icons.settings_ethernet,
  _Destination.activity: Icons.receipt_long,
};

class MinerHome extends StatefulWidget {
  const MinerHome({super.key});

  @override
  State<MinerHome> createState() => _MinerHomeState();
}

class _MinerHomeState extends State<MinerHome> {
  final SettingsStore _settings = SettingsStore();
  final List<LogEntry> _log = [];

  Timer? _pollTimer;
  BridgeApi? _api;
  String _baseUrl = SettingsStore.defaultBaseUrl;
  int _intervalMs = SettingsStore.defaultIntervalMs;

  MinerSnapshot? _snapshot;
  bool _connected = false;
  bool _firstLoad = true;
  bool _polling = false;
  _Destination _destination = _Destination.dashboard;

  String? _adUnitId;
  bool _adDismissed = false;

  /// The ad itself, supplied by an ad network once it actually returns one.
  /// Null until then - which is exactly why the banner stays invisible
  /// instead of reserving space for an ad that never arrived.
  Widget? _adWidget;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final url = await _settings.baseUrl();
    final interval = await _settings.intervalMs();
    final adUnitId = await _settings.adUnitId();
    final adDismissed = await _settings.adDismissed();
    if (!mounted) return;
    setState(() {
      _baseUrl = url;
      _intervalMs = interval;
      _api = BridgeApi(baseUrl: url);
      _adUnitId = adUnitId;
      _adDismissed = adDismissed;
    });
    await _poll();
    // Without this guard, disposing the screen while the first poll is still
    // in flight still starts the periodic timer, and nothing ever cancels it.
    if (!mounted) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(milliseconds: _intervalMs),
      (_) => _poll(),
    );
  }

  Future<void> _saveBaseUrl(String url) async {
    await _settings.setBaseUrl(url);
    if (!mounted) return;
    setState(() {
      _baseUrl = url;
      _api = BridgeApi(baseUrl: url);
      _firstLoad = true;
      _snapshot = null;
      _connected = false;
      _log.clear();
    });
    await _poll();
  }

  /// Closes the banner for good. The write is awaited before the state flips
  /// so a kill right after the tap cannot bring the banner back.
  Future<void> _dismissAd() async {
    await _settings.setAdDismissed(true);
    if (!mounted) return;
    setState(() => _adDismissed = true);
  }

  Future<void> _saveAdUnitId(String? value) async {
    await _settings.setAdUnitId(value);
    if (!mounted) return;
    setState(() => _adUnitId = value?.trim());
  }

  AdSlotState get _adSlotState {
    if (_adDismissed) return AdSlotState.dismissed;
    if (_adUnitId == null) return AdSlotState.unconfigured;
    return AdSlotState.awaitingSdk;
  }

  String get _clock {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _poll() async {
    final api = _api;
    if (api == null || _polling) return;
    _polling = true;

    final wasConnected = _connected;
    final previous = _snapshot;

    try {
      final snapshot = await api.fetchSnapshot();
      final connected = snapshot.status != null || snapshot.stats != null;
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _connected = connected;
        _firstLoad = false;
        _pushLog(diffSnapshots(
          previous: previous,
          current: snapshot,
          wasConnected: wasConnected,
          isConnected: connected,
          clock: _clock,
        ));
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _firstLoad = false;
        _pushLog([LogEntry(time: _clock, message: 'Poll failed', isError: true)]);
      });
    } finally {
      _polling = false;
    }
  }

  void _pushLog(List<LogEntry> entries) {
    if (entries.isEmpty) return;
    _log.insertAll(0, entries);
    if (_log.length > 60) _log.removeRange(60, _log.length);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;

    // Space is reserved only when a real ad is on screen. A configured but
    // empty slot is invisible and reserves nothing, so the banner appears
    // when an ad actually arrives.
    final showBanner = AdBanner.willShow(_adSlotState, _adWidget);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: showBanner ? AdBanner.footprint : 0,
              ),
              child: Row(
                children: [
                  if (wide) _buildRail(),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(
                          connected: _connected,
                          mining: _snapshot?.isMining ?? false,
                          onRefresh: _poll,
                          showTitle: !wide,
                        ),
                        Expanded(child: _buildBody()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Floating overlay, not an inline row: it never pushes the
            // content, so the layout does not move when the ad loads or fails.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AdBanner(
                state: _adSlotState,
                onDismiss: _dismissAd,
                child: _adWidget,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide ? null : _buildBottomBar(),
    );
  }

  Widget _buildRail() {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: Palette.surface,
        border: Border(right: BorderSide(color: Palette.surfaceHigh)),
      ),
      child: SafeArea(
        child: NavigationRail(
          backgroundColor: Palette.surface,
          selectedIndex: _Destination.values.indexOf(_destination),
          onDestinationSelected: (index) =>
              setState(() => _destination = _Destination.values[index]),
          indicatorColor: Palette.accent.withValues(alpha: 0.14),
          selectedIconTheme: const IconThemeData(color: Palette.accent),
          unselectedIconTheme: const IconThemeData(color: Palette.textSecondary),
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final d in _Destination.values)
              NavigationRailDestination(
                icon: Icon(_icons[d]),
                selectedIcon: Icon(_selectedIcons[d]),
                label: Text(
                  _labels[d]!,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return NavigationBar(
      backgroundColor: Palette.surface,
      indicatorColor: Palette.accent.withValues(alpha: 0.14),
      selectedIndex: _Destination.values.indexOf(_destination),
      onDestinationSelected: (index) =>
          setState(() => _destination = _Destination.values[index]),
      destinations: [
        for (final d in _Destination.values)
          NavigationDestination(
            icon: Icon(_icons[d]),
            selectedIcon: Icon(_selectedIcons[d]),
            label: _labels[d]!,
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_firstLoad) {
      return const _LoadingView();
    }
    switch (_destination) {
      case _Destination.dashboard:
        return DashboardScreen(
          snapshot: _snapshot ?? const MinerSnapshot(),
          connected: _connected,
        );
      case _Destination.workers:
        return WorkersScreen(workers: _snapshot?.stats?.workers ?? const []);
      case _Destination.node:
        return NodeScreen(
          baseUrl: _baseUrl,
          onSave: _saveBaseUrl,
          adUnitId: _adUnitId,
          onSaveAdUnitId: _saveAdUnitId,
        );
      case _Destination.activity:
        return LogScreen(entries: _log);
    }
  }
}

/// The app bar. One of only two glass surfaces in the app: it floats above
/// the field as chrome, not content.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.connected,
    required this.mining,
    required this.onRefresh,
    required this.showTitle,
  });

  final bool connected;
  final bool mining;
  final Future<void> Function() onRefresh;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          if (showTitle) ...[
            Text('Cenium Miner', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: Space.md),
          ],
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: mining
                  ? Palette.accent
                  : (connected ? Palette.textSecondary : Palette.danger),
              shape: BoxShape.circle,
              boxShadow: mining
                  ? [
                      BoxShadow(
                        color: Palette.accent.withValues(alpha: 0.5),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            mining ? 'Mining' : (connected ? 'Idle' : 'Offline'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh now',
            icon: const Icon(Icons.refresh, size: 20),
            color: Palette.textSecondary,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Palette.accent,
            ),
          ),
          const SizedBox(height: Space.lg),
          Text('Contacting the bridge', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
            child: Text(
              'Reading /api/status and /api/stats from the address in Node '
              'settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a hash rate in H/s on a binary scale.
String formatHashrateHps(int hps) {
  const units = ['H/s', 'kH/s', 'MH/s', 'GH/s', 'TH/s', 'PH/s'];
  var value = math.max(hps, 0).toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${value.toStringAsFixed(2)} ${units[unit]}';
}
