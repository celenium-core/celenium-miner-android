import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/bridge.dart';
import 'screens/backup_screen.dart';
import 'screens/bridge_screen.dart';
import 'screens/log_screen.dart';
import 'screens/mining_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/workers_screen.dart';
import 'services/bridge_api.dart';
import 'services/cen_wallet.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';
import 'theme/palette.dart';
import 'theme/typography.dart';
import 'widgets/ad_banner.dart';
import 'widgets/hacker_fx.dart';
import 'widgets/brand_mark.dart';
import 'widgets/cen_ui.dart';

void main() {
  runApp(const CeleniumMinerApp());
}

class CeleniumMinerApp extends StatelessWidget {
  const CeleniumMinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celenium Miner',
      debugShowCheckedModeBanner: false,
      theme: buildCenTheme(),
      home: const _Boot(),
    );
  }
}

/// Holds the splash until the first poll has had a chance to answer, so the
/// boot readout can show real values instead of an empty block.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  MinerSnapshot? _snapshot;

  /// Which tab to open once the splash clears. Read from the `--tab`
  /// argument; defaults to the mining screen.
  _Tab _initialTab = _Tab.mine;

  @override
  void initState() {
    super.initState();
    final args = Platform.environment['CEN_TAB'] ?? '';
    if (args == 'wallet') _initialTab = _Tab.wallet;
    if (args == 'profile') _initialTab = _Tab.profile;
    _probe();
  }

  Future<void> _probe() async {
    final settings = SettingsStore();
    final url = await settings.baseUrl();
    final snapshot = await BridgeApi(baseUrl: url).fetchSnapshot();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      network: 'simnet',
      nodeVersion: _snapshot?.status?.celeniumdVersion,
      blockCount: _snapshot?.stats?.totalBlocks,
      hashrateGhs: _snapshot?.stats?.internalCpu?.hashrateGhs,
      workerCount: _snapshot?.stats?.workers.length,
      onDone: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MinerHome(initialTab: _initialTab),
        ),
      ),
    );
  }
}

/// The three primary destinations.
enum _Tab { mine, wallet, profile }

const _tabLabels = {
  _Tab.mine: 'Mine',
  _Tab.wallet: 'Wallet',
  _Tab.profile: 'Profile',
};

/// Secondary screens, reached from the profile settings list.
enum _Route { bridge, workers, activity, backup, about }

class MinerHome extends StatefulWidget {
  const MinerHome({super.key, this.initialTab = _Tab.mine});

  /// Which tab opens first. Set from the `--tab` argument so a screenshot run
  /// can land directly on a screen instead of driving the bottom nav.
  final _Tab initialTab;

  @override
  State<MinerHome> createState() => _MinerHomeState();
}

/// What a back press should do, given the shell's current state.
enum BackAction {
  /// A settings screen is open: close it and stay in the app.
  closeRoute,

  /// Another tab is showing: return to the Mine tab.
  goToMineTab,

  /// Nothing left to unwind: the app may close.
  exitApp,
}

/// Decides what the hardware back button does.
///
/// Unwinds one level at a time so a back press never throws away the session:
/// an open settings screen closes first, then another tab returns to Mine,
/// and only at the root does the app close.
BackAction decideBackAction({required bool hasOpenRoute, required bool isOnMineTab}) {
  if (hasOpenRoute) return BackAction.closeRoute;
  if (!isOnMineTab) return BackAction.goToMineTab;
  return BackAction.exitApp;
}

class _MinerHomeState extends State<MinerHome> {
  final SettingsStore _settings = SettingsStore();
  final List<LogEntry> _log = [];

  Timer? _pollTimer;
  BridgeApi? _api;
  int _intervalMs = SettingsStore.defaultIntervalMs;

  MinerSnapshot? _snapshot;
  bool _connected = false;
  bool _polling = false;
  late _Tab _tab = widget.initialTab;
  _Route? _route;
  String? _adUnitId;
  bool _adDismissed = false;

  /// The BIP39 wordlist, loaded once at startup and handed to the recovery
  /// screen. Loading it in the screen itself made every open re-read the
  /// asset and left the widget untestable without a bundle.
  List<String>? _wordlist;

  /// The ad itself, supplied by an ad network once it actually returns one.
  /// Null until then, which is exactly why the banner stays invisible instead
  /// of reserving space for an ad that never arrived.
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
    List<String>? wordlist;
    try {
      wordlist = await loadBip39Wordlist(rootBundle);
    } on Object {
      // A missing wordlist only costs the recovery screen; mining must still
      // work. The screen falls back to loading it itself.
      wordlist = null;
    }
    if (!mounted) return;
    setState(() {
      _intervalMs = interval;
      _api = BridgeApi(baseUrl: url);
      _adUnitId = adUnitId;
      _adDismissed = adDismissed;
      _wordlist = wordlist;
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

  /// Closes the banner for good. The write is awaited before the state flips
  /// so a kill right after the tap cannot bring the banner back.
  Future<void> _dismissAd() async {
    await _settings.setAdDismissed(true);
    if (!mounted) return;
    setState(() => _adDismissed = true);
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

  void _open(_Route route) => setState(() => _route = route);
  void _closeRoute() => setState(() => _route = null);

  /// What the hardware back button does.
  ///
  /// The shell holds two levels: the three tabs, and the settings screens
  /// opened from Profile. Back unwinds one level at a time instead of closing
  /// the app, which is what a phone user expects from a back gesture.
  ///
  /// The decision itself lives in [decideBackAction] so it can be tested
  /// without driving a real back gesture.
  void _handleBack() {
    switch (decideBackAction(hasOpenRoute: _route != null, isOnMineTab: _tab == _Tab.mine)) {
      case BackAction.closeRoute:
        _closeRoute();
      case BackAction.goToMineTab:
        setState(() => _tab = _Tab.mine);
      case BackAction.exitApp:
        // Already at the root: let the system handle it, which closes the app.
        SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    if (route != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) => _handleBack(),
        child: _buildSubScreen(route),
      );
    }

    // Space is reserved only when a real ad is on screen. A configured but
    // empty slot is invisible and reserves nothing, so the banner appears
    // when an ad actually arrives.
    final showBanner = AdBanner.willShow(_adSlotState, _adWidget);
    final snapshot = _snapshot ?? const MinerSnapshot();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _handleBack(),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Ambient binary rain behind every tab. It sits under the
              // content at low opacity so the console feel is present on
              // Mining, Profile and Wallet alike without competing with the
              // readings, and it is the one effect that never stops.
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 0.13,
                      child: BinaryRain(
                        expand: true,
                        columns: 5,
                        color: Palette.greenDim,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: showBanner ? AdBanner.footprint : 0),
                child: _buildTab(snapshot),
              ),
              // CRT scanlines over the whole app: the console look with no
              // motion, so it never competes with the readings. Stronger than
              // a whisper, because the effect is meant to be felt here.
              Positioned.fill(
                child: IgnorePointer(
                  child: ScanlineOverlay(opacity: 0.06, spacing: 3),
                ),
              ),
              // A slow sweep of light down the screen, the CRT refresh the
              // scanlines imply. Bounded to one pass so it never loops into
              // a distraction.
              const Positioned.fill(
                child: IgnorePointer(child: ExcludeSemantics(child: ScanSweep())),
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
        bottomNavigationBar: _BottomTabs(
          current: _tab,
          onSelect: (tab) => setState(() => _tab = tab),
        ),
      ),
    );
  }

  Widget _buildTab(MinerSnapshot snapshot) {
    switch (_tab) {
      case _Tab.mine:
        return MiningScreen(
          snapshot: snapshot,
          nodeAddress: snapshot.status?.celeniumdAddress,
          onOpenWorkers: () => _open(_Route.workers),
          onOpenActivity: () => _open(_Route.activity),
          onConnectNode: () => _open(_Route.bridge),
        );
      case _Tab.wallet:
        return WalletScreen(
          snapshot: snapshot,
          networkLabel: 'simnet',
          onBackup: () => _open(_Route.backup),
          onOpenActivity: () => _open(_Route.activity),
        );
      case _Tab.profile:
        return ProfileScreen(
          snapshot: snapshot,
          networkLabel: 'simnet',
          onOpenBridge: () => _open(_Route.bridge),
          onOpenWorkers: () => _open(_Route.workers),
          onOpenActivity: () => _open(_Route.activity),
          onOpenBackup: () => _open(_Route.backup),
          onOpenAbout: () => _open(_Route.about),
        );
    }
  }

  Widget _buildSubScreen(_Route route) {
    final snapshot = _snapshot ?? const MinerSnapshot();
    switch (route) {
      case _Route.bridge:
        return BridgeScreen(settings: _settings, snapshot: snapshot);
      case _Route.workers:
        return WorkersScreen(snapshot: snapshot);
      case _Route.activity:
        return LogScreen(entries: _log);
      case _Route.backup:
        return BackupScreen(
          onDone: _closeRoute,
          wordlist: _wordlist,
        );
      case _Route.about:
        return const _AboutScreen();
    }
  }
}

/// Bottom navigation: a cream pill floating above the content, as in the
/// concept. The active tab carries a gold disc with the brand mark.
class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.current, required this.onSelect});

  final _Tab current;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        // Floating, not docked: the pill hovers over the content with a gap
        // on every side, which is what reads as "floating" rather than "a bar
        // that shifted in".
        padding: const EdgeInsets.fromLTRB(Palette.lg, 0, Palette.lg, Palette.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Palette.sm, vertical: Palette.sm),
          decoration: BoxDecoration(
            color: Palette.surfaceLight,
            borderRadius: BorderRadius.circular(Palette.pill),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final tab in _Tab.values)
                _TabButton(
                  tab: tab,
                  label: _tabLabels[tab]!,
                  selected: tab == current,
                  onTap: () => onSelect(tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // On the cream pill, plain gold text would fail contrast. The active tab
    // is carried by the gold disc; its label uses the deep gold so it stays
    // readable while still reading as the gold family.
    final color = selected ? Palette.goldDim : Palette.slate;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.pill),
        child: Container(
          // 44px minimum touch target (R-03).
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: Palette.md, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? Palette.gold : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: selected
                      ? BrandMark(size: 18)
                      : Icon(_iconFor(tab), size: 19, color: color),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label.toUpperCase(),
                style: TypeScale.monoMuted(context, size: 8).copyWith(
                  color: color,
                  letterSpacing: 1.3,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(_Tab tab) {
    switch (tab) {
      case _Tab.mine:
        return Icons.bolt_outlined;
      case _Tab.wallet:
        return Icons.account_balance_wallet_outlined;
      case _Tab.profile:
        return Icons.person_outline;
    }
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('ABOUT'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Palette.lg),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: Palette.lg),
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(color: Palette.cream, shape: BoxShape.circle),
                  child: Center(child: BrandMark(size: 50)),
                ),
                const SizedBox(height: Palette.lg),
                Text('CELENIUM', style: TypeScale.wordmark(context)),
                const SizedBox(height: Palette.xs),
                Text(
                  'C E N   C O R E',
                  style: TypeScale.monoMuted(context, size: 9).copyWith(letterSpacing: 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: Palette.xxl),
          const CenCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('What this app does'),
                SizedBox(height: Palette.sm),
                Text(
                  'It reads mining results from a Celenium bridge and shows them on '
                  'your phone. It holds no account, no database, and no coins: the '
                  'results live on the blockchain and the bridge, and this app is a '
                  'window onto them.',
                  style: TextStyle(
                    fontFamily: TypeScale.bodyFamily,
                    fontSize: 13,
                    color: Palette.slateLight,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Palette.md),
          const CenCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Version'),
                SizedBox(height: Palette.sm),
                Text(
                  '1.0.0',
                  style: TextStyle(
                    fontFamily: TypeScale.monoFamily,
                    fontSize: 12,
                    color: Palette.creamDim,
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
