import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'models/bridge.dart';
import 'l10n/l10n.dart';
import 'screens/backup_screen.dart';
import 'screens/bridge_screen.dart';
import 'screens/log_screen.dart';
import 'screens/mining_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/workers_screen.dart';
import 'services/ad_units.dart';
import 'services/bridge_api.dart';
import 'services/cen_wallet.dart';
import 'services/crash_log.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';
import 'theme/layout.dart';
import 'theme/palette.dart';
import 'theme/typography.dart';
import 'widgets/ad_banner.dart';
import 'widgets/hacker_fx.dart';
import 'widgets/brand_mark.dart';
import 'widgets/cen_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // No ad SDK call happens before the first frame: its init talks to Play
  // Services, and an unhandled failure there kills the process on launch.
  // The banner warms the SDK lazily, where every failure is contained.
  installCrashHandlers();
  runApp(const CeleniumMinerApp());
}

class CeleniumMinerApp extends StatefulWidget {
  const CeleniumMinerApp({super.key});

  @override
  State<CeleniumMinerApp> createState() => _CeleniumMinerAppState();
}

class _CeleniumMinerAppState extends State<CeleniumMinerApp> {
  final SettingsStore _settings = SettingsStore();

  /// The language the app is currently drawing in. A notifier rather than a
  /// field because the picker lives deep in the profile screen: changing it
  /// there has to rebuild the whole [MaterialApp], and only the root owns the
  /// locale.
  final ValueNotifier<AppLanguage> _language = ValueNotifier(
    // Start on the system language so the first frame after the splash is not
    // briefly wrong while the stored value loads.
    AppLanguage.system,
  );

  @override
  void initState() {
    super.initState();
    _settings.language().then((stored) {
      if (mounted) _language.value = stored;
    });
  }

  @override
  void dispose() {
    _language.dispose();
    super.dispose();
  }

  Future<void> _setLanguage(AppLanguage language) async {
    _language.value = language;
    await _settings.setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    // Desktop only: CEN_TAB opens a specific tab, so a screen can be launched
    // straight into for review without clicking through the shell. Ignored on
    // Android, where there is no environment to read.
    var initialTab = _Tab.mine;
    if (!kIsWeb) {
      final tab = Platform.environment['CEN_TAB'] ?? '';
      if (tab == 'wallet') initialTab = _Tab.wallet;
      if (tab == 'profile') initialTab = _Tab.profile;
    }

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: _language,
      builder: (context, language, _) => MaterialApp(
        title: 'Celenium Miner',
        debugShowCheckedModeBanner: false,
        theme: buildCenTheme(),
        // Null locale means "let the platform decide", which is what the
        // system option is for.
        locale: language.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MinerHome(
          initialTab: initialTab,
          language: language,
          onLanguageChanged: _setLanguage,
        ),
      ),
    );
  }
}

/// The three primary destinations.
enum _Tab { mine, wallet, profile }

/// The tab strip's labels, in the language currently selected.
String _tabLabel(AppLocalizations l10n, _Tab tab) => switch (tab) {
  _Tab.mine => l10n.navMine,
  _Tab.wallet => l10n.navWallet,
  _Tab.profile => l10n.navProfile,
};

/// Secondary screens, reached from the profile settings list.
enum _Route { bridge, workers, activity, backup, about }

class MinerHome extends StatefulWidget {
  const MinerHome({
    super.key,
    this.initialTab = _Tab.mine,
    this.language = AppLanguage.system,
    this.onLanguageChanged,
  });

  /// Which tab opens first. Set from the `--tab` argument so a screenshot run
  /// can land directly on a screen instead of driving the bottom nav.
  final _Tab initialTab;

  /// Current interface language, shown in the profile settings.
  final AppLanguage language;

  /// Called when the user picks a different language. Null in tests that do
  /// not exercise the picker.
  final ValueChanged<AppLanguage>? onLanguageChanged;

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
BackAction decideBackAction({
  required bool hasOpenRoute,
  required bool isOnMineTab,
}) {
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

  /// The banner actually on screen. Null until AdMob hands one over, which is
  /// exactly why the slot stays invisible instead of reserving space for an
  /// ad that never arrived.
  BannerAd? _banner;

  /// True once a request came back empty. The slot then collapses for the
  /// rest of the session instead of re-asking AdMob on every rebuild.
  bool _adFailed = false;

  /// One-shot guard: a rebuild must never re-request the banner.
  bool _adRequested = false;

  /// True until the entry button on the splash is pressed.
  ///
  /// The splash is the first thing the shell shows, and it stays until the
  /// user asks to enter. It used to be a separate route that waited on a
  /// bridge poll, but the splash no longer reports anything, so there is
  /// nothing to wait for.
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  void _finishBoot() {
    if (mounted) setState(() => _booting = false);
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
      // An id typed into Node settings wins; otherwise the live unit takes
      // over in release and Google's test unit in debug, so the slot works
      // out of the box instead of sitting unconfigured forever.
      _adUnitId = resolveBannerUnitId(adUnitId);
      _adDismissed = adDismissed;
      _wordlist = wordlist;
    });
    await _loadAd();
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
    _banner?.dispose();
    if (!mounted) return;
    setState(() {
      _banner = null;
      _adDismissed = true;
    });
  }

  /// Asks AdMob for one banner, sized to the slot that will hold it.
  ///
  /// A fixed 320x50 unit does not fit a phone: the slot also carries the "Ad"
  /// badge and the close button. The adaptive size is requested at the exact
  /// leftover width, so the ad is drawn whole instead of clipped.
  /// Asks AdMob for one banner, sized to the slot that will hold it.
  ///
  /// A fixed 320x50 unit does not fit a phone: the slot also carries the "Ad"
  /// badge and the close button. The adaptive size is requested at the exact
  /// leftover width, so the ad is drawn whole instead of clipped.
  ///
  /// Best-effort by design: every failure - the SDK refusing to start, a bad
  /// size, a rejected request - collapses the slot instead of surfacing as an
  /// unhandled error that takes the whole app down.
  Future<void> _loadAd() async {
    if (_adRequested) return;
    _adRequested = true;
    final unitId = _adUnitId;
    if (unitId == null || !adsSupported) return;

    await ensureAdsReady();
    if (!mounted) return;

    try {
      final media = MediaQuery.maybeOf(context);
      if (media == null) return;
      // The replacement (the ...Large... variant) allows ads up to 15% of the
      // screen height, which is taller than this slot; the classic adaptive
      // size stays at 50dp across phone widths.
      // ignore: deprecated_member_use
      final AdSize? adaptive = await AdSize.getAnchoredAdaptiveBannerAdSize(
        media.orientation,
        bannerAdWidth(media.size.width).round(),
      );
      if (!mounted) return;

      final banner = BannerAd(
        adUnitId: unitId,
        size: adaptive ?? AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            // A taller-than-slot ad would be clipped, and a clipped ad may not
            // be shown: drop it and collapse the slot instead.
            if (ad is! BannerAd || ad.size.height > AdBanner.height) {
              ad.dispose();
              if (mounted) setState(() => _adFailed = true);
              return;
            }
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() => _banner = ad);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _adFailed = true;
              _pushLog([
                LogEntry(
                  time: _clock,
                  message: l10nOf(context).logAdRequestFailed,
                  isError: true,
                ),
              ]);
            });
          },
        ),
      );
      await banner.load();
    } catch (error, stack) {
      recordCaughtError(error, stack: stack);
      if (!mounted) return;
      setState(() {
        _adFailed = true;
        _pushLog([
          LogEntry(
            time: _clock,
            message: l10nOf(context).logAdRequestFailed,
            isError: true,
          ),
        ]);
      });
    }
  }

  AdSlotState get _adSlotState {
    if (_adDismissed) return AdSlotState.dismissed;
    if (_adUnitId == null) return AdSlotState.unconfigured;
    if (_banner != null) return AdSlotState.loaded;
    if (_adFailed) return AdSlotState.noFill;
    return AdSlotState.awaitingSdk;
  }

  /// The banner wrapped in the exact box AdMob filled, so the ad is drawn at
  /// its own size and is never stretched or cropped by the row around it.
  Widget? get _adWidget {
    final ad = _banner;
    if (ad == null) return null;
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
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
        _pushLog(
          diffSnapshots(
            l10n: l10nOf(context),
            previous: previous,
            current: snapshot,
            wasConnected: wasConnected,
            isConnected: connected,
            clock: _clock,
          ),
        );
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _pushLog([
          LogEntry(
            time: _clock,
            message: l10nOf(context).logPollFailed,
            isError: true,
          ),
        ]);
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
    switch (decideBackAction(
      hasOpenRoute: _route != null,
      isOnMineTab: _tab == _Tab.mine,
    )) {
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
    // The splash owns the shell until the user asks to enter, so the tabs,
    // the ad banner and the polling all stay dormant behind it.
    if (_booting) {
      return SplashScreen(onDone: _finishBoot);
    }

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

    final layout = CenLayout.of(context);

    // Keyboard shortcuts only earn their keep on a desktop, where a keyboard
    // is guaranteed. On a phone they would fight the soft keyboard.
    final shell = _buildPhoneShell(snapshot, showBanner);

    if (layout.isCompact) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) => _handleBack(),
        child: shell,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _handleBack(),
      child: CallbackShortcuts(
        bindings: _shellShortcuts(),
        child: Focus(autofocus: true, child: shell),
      ),
    );
  }

  /// Ctrl+1/2/3 jump between tabs, Escape unwinds one level. The same
  /// unwinding the hardware back button does, so the two never disagree.
  Map<ShortcutActivator, VoidCallback> _shellShortcuts() => {
    const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
        setState(() => _tab = _Tab.mine),
    const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
        setState(() => _tab = _Tab.wallet),
    const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
        setState(() => _tab = _Tab.profile),
    const SingleActivator(LogicalKeyboardKey.escape): _handleBack,
  };

  /// Phone shell: the cream pill floats above the content, as designed.
  Widget _buildPhoneShell(MinerSnapshot snapshot, bool showBanner) {
    return Stack(
      children: [
        // One continuous console canvas (field + rain + CRT texture) painted
        // edge to edge behind BOTH the content and the floating tab bar. The
        // Scaffold is transparent, so the canvas behind the pill is the same
        // dark field the content sits on — no seam where the tab bar begins.
        _canvas(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    bottom: showBanner ? AdBanner.footprint : 0,
                  ),
                  child: _buildTab(snapshot),
                ),
                _adLayer(),
              ],
            ),
          ),
          bottomNavigationBar: _BottomTabs(
            current: _tab,
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
      ],
    );
  }

  /// Full-screen console backdrop: the dark field, the always-on binary rain,
  /// and the CRT scanline/sweep texture. Drawn once behind the whole shell so
  /// the three layers read as one continuous plane instead of stopping at the
  /// bottom-indicator line where the content and the tab bar meet.
  Widget _canvas() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: const [
              ColoredBox(color: Palette.field),
              Opacity(
                opacity: 0.13,
                child: BinaryRain(
                  expand: true,
                  columns: 5,
                  color: Palette.greenDim,
                ),
              ),
              ScanlineOverlay(opacity: 0.06, spacing: 3),
              ScanSweep(),
            ],
          ),
        ),
      ),
    );
  }

  /// Floating overlay, not an inline row: it never pushes the content, so the
  /// layout does not move when the ad loads or fails.
  Widget _adLayer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AdBanner(
        state: _adSlotState,
        onDismiss: _dismissAd,
        child: _adWidget,
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
          api: _api,
          onBackup: () => _open(_Route.backup),
          onOpenActivity: () => _open(_Route.activity),
        );
      case _Tab.profile:
        return ProfileScreen(
          snapshot: snapshot,
          networkLabel: 'simnet',
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
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
        // Caught errors ride on top of the poll log, so a failure the user
        // felt shows up where they look for what the app has been doing.
        return LogScreen(
          entries: [
            ...crashJournal.map(
              (error) => LogEntry(
                time: error.time,
                message: error.message,
                isError: true,
              ),
            ),
            ..._log,
          ],
        );
      case _Route.backup:
        return BackupScreen(onDone: _closeRoute, wordlist: _wordlist);
      case _Route.about:
        return const _AboutScreen();
    }
  }
}

/// Bottom navigation: a cream pill floating above the content, as in the
/// concept. Instead of a fixed disc on every tab, a single navy "lens" rides
/// behind the active tab and morphs — it slides and stretches — as the selected
/// tab changes, so the indicator reads as liquid rather than swapping discs.
class _BottomTabs extends StatefulWidget {
  const _BottomTabs({required this.current, required this.onSelect});

  final _Tab current;
  final ValueChanged<_Tab> onSelect;

  @override
  State<_BottomTabs> createState() => _BottomTabsState();
}

class _BottomTabsState extends State<_BottomTabs>
    with SingleTickerProviderStateMixin {
  /// Width of one tab slot. Fixed so the lens has a known home on each tab.
  static const double _slotW = 68;

  /// Height of the tab strip, which the lens bulges within.
  static const double _barH = 58;

  /// Drives the lens between the tabs. Its value is the floating tab index, so
  /// a mid-flight value sits between two homes and the painter can stretch the
  /// lens toward the nearer one.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
      value: widget.current.index.toDouble(),
      // The lens is driven by the raw tab index (0..2), so the controller
      // must be allowed to animate past its default upperBound of 1.0.
      upperBound: (_Tab.values.length - 1).toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant _BottomTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _controller.animateTo(
        widget.current.index.toDouble(),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// How strongly a slot reads as selected, 0..1. Slides smoothly with the
  /// lens so the label and mark crossfade in step with the moving bulge.
  double _selectiveness(int slot) {
    return (1 - (_controller.value - slot).abs()).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final count = _Tab.values.length;
    final width = _slotW * _Tab.values.length;

    return SafeArea(
      top: false,
      child: Padding(
        // Cream pill that hugs its three items and is centred on a fully
        // transparent bar: the dark canvas shows through on both sides of
        // the pill, so the menu reads as floating cream tabs rather than a
        // full-width bar.
        padding: const EdgeInsets.fromLTRB(
          Palette.lg,
          0,
          Palette.lg,
          Palette.md,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          // Without a height factor, Align expands to fill the body and the
          // Scaffold gives the whole screen to the bottom bar, collapsing the
          // body (and every tab inside it) to zero height.
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Palette.sm,
              vertical: Palette.sm,
            ),
            decoration: BoxDecoration(
              color: Palette.cream,
              borderRadius: BorderRadius.circular(Palette.pill),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: width,
              height: _barH,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => Stack(
                  // The lens is taller than the tab slot, so it is allowed to
                  // paint a few pixels past the strip's rect while the pill
                  // above never clips it.
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(width, _barH),
                      painter: _LiquidBulgePainter(
                        t: _controller.value,
                        slotW: _slotW,
                        barH: _barH,
                        color: Palette.field,
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          _LiquidTab(
                            tab: _Tab.values[i],
                            label: _tabLabel(l10nOf(context), _Tab.values[i]),
                            width: _slotW,
                            sel: _selectiveness(i),
                            selected: _Tab.values[i] == widget.current,
                            onTap: () => widget.onSelect(_Tab.values[i]),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The liquid ride itself: a superellipse "lens" that bulges behind the active
/// tab and stretches horizontally while it travels, then settles back to its
/// rest shape. A superellipse (not a disc or a stadium) is what gives the
/// liquid-glass look — a fuller centre that tapers to soft, rounded tips.
class _LiquidBulgePainter extends CustomPainter {
  _LiquidBulgePainter({
    required this.t,
    required this.slotW,
    required this.barH,
    required this.color,
  });

  /// Floating tab index (0..2), fractional while in flight.
  final double t;

  final double slotW;
  final double barH;
  final Color color;

  /// Rest semi-axes. Wide-but-short reads as a lens, taller than an icon glyph.
  static const double _a0 = 26;
  static const double _b0 = 19;

  /// Superellipse exponent. 3.4 is full in the middle with softly tapered tips;
  /// neither a hard rectangle nor a plain ellipse.
  static const double _n = 3.4;

  /// Extra horizontal reach the lens gains at the peak of a jump.
  static const double _stretch = 14;

  @override
  void paint(Canvas canvas, Size size) {
    // Distance from the nearest integer home, 0..0.5, so the stretch is zero at
    // rest and greatest midway between two tabs — the classic liquid squash.
    final frac = (t - t.roundToDouble()).abs();
    final envelope = math.sin(math.pi * frac);

    final cx = t * slotW + slotW / 2;
    final cy = barH / 2 - 6.5; // centres on the icon row, not the label
    final a = _a0 + _stretch * envelope;
    final b = _b0 * (1 - 0.22 * envelope);

    final path = Path();
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final angle = 2 * math.pi * i / steps;
      final x = cx + a * _superCoord(math.cos(angle));
      final y = cy + b * _superCoord(math.sin(angle));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawShadow(path, Colors.black54, 6, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Superellipse coordinate: keeps the curve full in the middle and tapers
  /// the tips, which is what distinguishes the lens from a plain oval.
  double _superCoord(double value) {
    final magnitude = value.abs();
    return value.sign * math.pow(magnitude, 2 / _n).toDouble();
  }

  @override
  bool shouldRepaint(covariant _LiquidBulgePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.slotW != slotW ||
        oldDelegate.barH != barH ||
        oldDelegate.color != color;
  }
}

class _LiquidTab extends StatelessWidget {
  const _LiquidTab({
    required this.tab,
    required this.label,
    required this.width,
    required this.sel,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final String label;
  final double width;

  /// Smooth 0..1 selection, crossfades the mark and label in step with the lens.
  final double sel;

  /// Discrete selection, only for the accessibility flag.
  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // On the cream pill the ink is navy. The cream mark fades in against the
    // navy lens as it arrives; idle tabs keep the dim navy glyph.
    final labelColor = Color.lerp(Palette.creamInkDim, Palette.creamInk, sel)!;
    final weight = sel >= 0.5 ? FontWeight.w700 : FontWeight.w500;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Palette.pill),
        child: SizedBox(
          width: width,
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                // 44px minimum touch target (R-03) comes from the slot, which
                // is far wider than 44 and as tall as the whole strip.
                width: 34,
                height: 34,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 1 - sel,
                      child: Icon(
                        _iconFor(tab),
                        size: 19,
                        color: Palette.creamInkDim,
                      ),
                    ),
                    if (sel > 0)
                      Opacity(
                        opacity: sel,
                        child: BrandMark(size: 20, onDark: true),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label.toUpperCase(),
                style: TypeScale.monoMuted(context, size: 8).copyWith(
                  color: labelColor,
                  letterSpacing: 1.3,
                  fontWeight: weight,
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
    final l10n = l10nOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.aboutTitle),
      ),
      body: CenContent(
        child: ListView(
          padding: const EdgeInsets.all(Palette.lg),
          children: [
            Center(
              child: Column(
                children: [
                  const SizedBox(height: Palette.lg),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: Palette.surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: BrandMark(size: 50, onDark: true)),
                  ),
                  const SizedBox(height: Palette.lg),
                  Text('CELENIUM', style: TypeScale.wordmark(context)),
                  const SizedBox(height: Palette.xs),
                  Text(
                    'C E N   C O R E',
                    style: TypeScale.monoMuted(
                      context,
                      size: 9,
                    ).copyWith(letterSpacing: 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Palette.xxl),
            CenCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(l10n.aboutWhatTitle),
                  const SizedBox(height: Palette.sm),
                  Text(
                    l10n.aboutWhatBody,
                    style: const TextStyle(
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
            CenCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(l10n.aboutVersion),
                  const SizedBox(height: Palette.sm),
                  const Text(
                    '1.0.2',
                    style: TextStyle(
                      fontFamily: TypeScale.monoFamily,
                      fontSize: 12,
                      color: Palette.creamDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Palette.md),
            CenCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(l10n.aboutCreatedBy),
                  const SizedBox(height: Palette.sm),
                  const Text(
                    'Dimas A. Pradana',
                    style: TextStyle(
                      fontFamily: TypeScale.monoFamily,
                      fontSize: 12,
                      color: Palette.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
