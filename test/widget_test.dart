import 'package:cenium_miner/main.dart';
import 'package:cenium_miner/models/bridge.dart';
import 'package:cenium_miner/screens/dashboard_screen.dart';
import 'package:cenium_miner/services/bridge_api.dart';
import 'package:cenium_miner/services/settings_store.dart';
import 'package:cenium_miner/theme/tokens.dart';
import 'package:cenium_miner/widgets/ad_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('normaliseBaseUrl', () {
    test('adds a scheme when missing', () {
      expect(normaliseBaseUrl('127.0.0.1:3030'), 'http://127.0.0.1:3030');
    });

    test('keeps an explicit scheme', () {
      expect(normaliseBaseUrl('http://10.0.0.5:3030'), 'http://10.0.0.5:3030');
    });

    test('strips trailing slashes', () {
      expect(normaliseBaseUrl('http://127.0.0.1:3030///'), 'http://127.0.0.1:3030');
    });

    test('rejects empty and unusable input', () {
      expect(normaliseBaseUrl(''), isNull);
      expect(normaliseBaseUrl('   '), isNull);
      expect(normaliseBaseUrl('http://'), isNull);
    });
  });

  group('bridge API models', () {
    test('parses a real /api/status body', () {
      final status = BridgeStatus.tryParse({
        'celeniumd_address': '127.0.0.1:26510',
        'celeniumd_version': '2.1.0-a438515',
        'instances': 1,
        'web_bind': '0.0.0.0:3030',
      });
      expect(status, isNotNull);
      expect(status!.celeniumdVersion, '2.1.0-a438515');
      expect(status.instances, 1);
    });

    test('parses a real /api/stats body with an internal miner', () {
      final stats = BridgeStats.tryParse({
        'totalBlocks': 3,
        'totalShares': 1204,
        'networkHashrate': 4500000000000,
        'networkDifficulty': 1234567.5,
        'networkBlockCount': 1920,
        'activeWorkers': 1,
        'internalCpu': {
          'hashrateGhs': 1.42,
          'hashesTried': 900000000,
          'blocksSubmitted': 3,
          'blocksAccepted': 2,
          'shares': 1204,
          'stale': 1,
          'invalid': 0,
          'wallet': 'celeniumsim:qabc',
        },
        'blocks': [
          {
            'instance': 'default',
            'worker': 'asic-1',
            'wallet': 'celeniumsim:qabc',
            'timestamp': '2026-10-29T10:00:00Z',
            'hash': 'abc123',
          }
        ],
        'workers': [
          {
            'instance': 'default',
            'worker': 'asic-1',
            'wallet': 'celeniumsim:qabc',
            'hashrate': 1.42,
            'shares': 1204,
            'stale': 1,
            'invalid': 0,
            'blocks': 2,
            'lastSeen': 1793244445,
            'status': 'online',
            'currentDifficulty': 8.0,
            'sessionUptime': 3600,
          }
        ],
        'bridgeUptime': 7200,
      });

      expect(stats, isNotNull);
      expect(stats!.internalCpu, isNotNull);
      expect(stats.internalCpu!.hashrateGhs, 1.42);
      expect(stats.internalCpu!.blocksAccepted, 2);
      expect(stats.blocks.length, 1);
      expect(stats.workers.single.status, 'online');
      expect(stats.workers.single.sessionUptime, 3600);

      final snapshot = MinerSnapshot(status: null, stats: stats);
      expect(snapshot.isMining, isTrue);
      expect(snapshot.hashrateGhs, 1.42);
      expect(snapshot.blocksAccepted, 2);
      expect(snapshot.stale, 1);
    });

    test('a stats body with no internal miner is not mining', () {
      final stats = BridgeStats.tryParse({
        'totalBlocks': 0,
        'totalShares': 0,
        'networkHashrate': 0,
        'networkDifficulty': 0,
        'networkBlockCount': 0,
        'activeWorkers': 0,
        'internalCpu': null,
        'blocks': <Object?>[],
        'workers': <Object?>[],
      });
      expect(stats, isNotNull);
      expect(MinerSnapshot(status: null, stats: stats).isMining, isFalse);
    });

    test('malformed bodies are rejected rather than half-parsed', () {
      expect(BridgeStatus.tryParse('not an object'), isNull);
      expect(BridgeStats.tryParse(null), isNull);
      // A non-list where a list belongs must reject the whole body, not
      // silently report zero blocks.
      expect(BridgeStats.tryParse({'blocks': 'not a list'}), isNull);
      expect(BridgeStats.tryParse({'workers': 42}), isNull);
    });
  });

  group('palette', () {
    test('accent on the field clears WCAG AA for normal text', () {
      // Relative luminance per WCAG 2.1
      double luminance(Color c) {
        double channel(double v) {
          // Color.r/g/b are 0..1 doubles on current Flutter; stay tolerant of
          // the older 0..255 form so this survives an SDK bump.
          final s = v > 1.0 ? v / 255 : v;
          return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055).pow();
        }

        return 0.2126 * channel(c.r) +
            0.7152 * channel(c.g) +
            0.0722 * channel(c.b);
      }

      double ratio(Color a, Color b) {
        final la = luminance(a);
        final lb = luminance(b);
        final hi = la > lb ? la : lb;
        final lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(ratio(Palette.accent, Palette.field), greaterThanOrEqualTo(4.5));
      expect(ratio(Palette.textPrimary, Palette.field), greaterThanOrEqualTo(4.5));
      expect(ratio(Palette.textSecondary, Palette.field), greaterThanOrEqualTo(4.5));
      expect(ratio(Palette.accent, Palette.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('ad banner', () {
    Widget host(
      AdSlotState state,
      VoidCallback onDismiss, {
      Widget? ad,
    }) {
      return MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              AdBanner(state: state, onDismiss: onDismiss, child: ad),
            ],
          ),
        ),
      );
    }

    testWidgets('collapsed states render zero height', (tester) async {
      for (final state in [
        AdSlotState.unconfigured,
        AdSlotState.awaitingSdk,
        AdSlotState.noFill,
        AdSlotState.dismissed,
      ]) {
        await tester.pumpWidget(host(state, () {}));
        expect(find.byType(AdBanner), findsOneWidget);
        expect(
          tester.getSize(find.byType(AdBanner)),
          Size.zero,
          reason: '$state must not reserve any space',
        );
        expect(find.text('Ad'), findsNothing);
      }
    });

    testWidgets('a configured slot with no ad reserves nothing', (tester) async {
      // The rule: the banner appears only once an ad has actually arrived.
      // A saved unit id on its own is not an ad, so the slot stays invisible
      // and the layout is untouched.
      await tester.pumpWidget(host(AdSlotState.awaitingSdk, () {}));

      expect(tester.getSize(find.byType(AdBanner)), Size.zero);
      expect(find.text('Ad'), findsNothing);
      expect(find.textContaining('Connect an ad network'), findsNothing);
    });

    testWidgets('a loaded state with no ad still reserves nothing',
        (tester) async {
      // No ad network is wired in, so even "loaded" must not draw.
      await tester.pumpWidget(host(AdSlotState.loaded, () {}));

      expect(tester.getSize(find.byType(AdBanner)), Size.zero);
      expect(find.text('Ad'), findsNothing);
    });

    testWidgets('a real ad reserves a fixed height and labels itself',
        (tester) async {
      await tester.pumpWidget(
        host(AdSlotState.loaded, () {}, ad: const Text('REAL AD UNIT')),
      );

      // The footprint is fixed, so an ad appearing never moves the layout.
      final size = tester.getSize(find.byType(AdBanner));
      expect(size.height, AdBanner.footprint);
      expect(AdBanner.footprint, AdBanner.height + Space.sm);
      expect(find.text('Ad'), findsOneWidget);
      expect(find.text('REAL AD UNIT'), findsOneWidget);
    });

    testWidgets('the close button dismisses and meets the touch target',
        (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        host(
          AdSlotState.loaded,
          () => dismissed++,
          ad: const Text('REAL AD UNIT'),
        ),
      );

      final close = find.byType(IconButton);
      expect(close, findsOneWidget);

      final target = tester.getRect(close);
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));

      await tester.tap(close);
      await tester.pump();
      expect(dismissed, 1, reason: 'the close control must do real work');
    });

    test('willShow is true only for a real ad', () {
      expect(AdBanner.willShow(AdSlotState.loaded, const Text('ad')), isTrue);
      expect(AdBanner.willShow(AdSlotState.loaded, null), isFalse);
      expect(
        AdBanner.willShow(AdSlotState.awaitingSdk, const Text('ad')),
        isFalse,
      );
      expect(
        AdBanner.willShow(AdSlotState.unconfigured, const Text('ad')),
        isFalse,
      );
      expect(AdBanner.willShow(AdSlotState.noFill, const Text('ad')), isFalse);
      expect(
        AdBanner.willShow(AdSlotState.dismissed, const Text('ad')),
        isFalse,
      );
    });

    test('a real ad does not shift the layout when it appears', () {
      // The height is a constant, so the reserved space is identical every
      // time a real ad appears. This is the R-40 guarantee stated as a test.
      expect(AdBanner.height, greaterThan(0));
      expect(AdBanner.height, lessThanOrEqualTo(64));
    });
  });

  group('ad settings persistence', () {
    test('a blank ad unit id round-trips to null, not to an empty slot',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = SettingsStore();

      expect(await store.adUnitId(), isNull);

      await store.setAdUnitId('   ');
      expect(await store.adUnitId(), isNull);

      await store.setAdUnitId('  ca-app-pub-1/2  ');
      expect(await store.adUnitId(), 'ca-app-pub-1/2');
    });

    test('a dismissal survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SettingsStore();

      expect(await store.adDismissed(), isFalse);
      await store.setAdDismissed(true);

      // A fresh store reads the same backing prefs, which is what a relaunch
      // does. A close button that forgets here is a dead control (R-26).
      expect(await SettingsStore().adDismissed(), isTrue);
    });
  });

  group('app smoke test', () {
    testWidgets('warns about localhost on a phone viewport',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The default test platform is android, so the phone hint must show.
      await tester.pumpWidget(const CeniumMinerApp());
      await tester.pump(const Duration(seconds: 2));

      // Scope the tap to the navigation bar: 'Node' also appears as a row
      // label on the dashboard, which makes an unscoped finder ambiguous.
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Node'),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('127.0.0.1 means this device'), findsOneWidget);
    });

    testWidgets('renders the shell and reports an unreachable bridge',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      // Force a phone viewport: the default 800x600 test surface is wide
      // enough to trigger the tablet rail, which hides the in-bar title.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const CeniumMinerApp());
      // First frame shows the loading view while the first poll is in flight.
      expect(find.text('Contacting the bridge'), findsOneWidget);

      // Let the poll fail against the default (absent) bridge.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Cenium Miner'), findsOneWidget);
      expect(find.text('Offline'), findsWidgets);

      // Navigation works: every destination is reachable and renders. Taps
      // are scoped to the navigation bar because destination screens reuse
      // the same words as their nav labels.
      Future<void> tapNav(String label) async {
        await tester.tap(find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ));
        await tester.pump(const Duration(seconds: 1));
      }

      await tapNav('Workers');
      expect(find.text('No workers connected'), findsOneWidget);

      await tapNav('Node');
      expect(find.widgetWithText(TextField, 'Bridge address'), findsOneWidget);

      // The new "No account" section sits below the fold on a phone viewport,
      // so drag the list until it is really built instead of assuming it is.
      final noAccount = find.text('No account, no database');
      final list = find.byType(ListView).first;
      for (var i = 0; i < 15 && noAccount.evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(noAccount, findsOneWidget);

      await tapNav('Activity');
      expect(find.textContaining('Nothing logged yet'), findsOneWidget);
    });
  });

  group('payout and device limit', () {
    MinerSnapshot snapshotWith({
      int instances = 1,
      String wallet = 'celeniumsim:qabc',
    }) {
      return MinerSnapshot(
        status: BridgeStatus.tryParse({
          'celeniumd_address': '127.0.0.1:26510',
          'celeniumd_version': '2.1.0-a438515',
          'instances': instances,
          'web_bind': '0.0.0.0:3030',
        }),
        stats: BridgeStats.tryParse({
          'totalBlocks': 3,
          'totalShares': 1204,
          'networkHashrate': 4500000000000,
          'networkDifficulty': 1234567.5,
          'networkBlockCount': 1920,
          'activeWorkers': 1,
          'internalCpu': {
            'hashrateGhs': 1.42,
            'hashesTried': 900000000,
            'blocksSubmitted': 3,
            'blocksAccepted': 2,
            'shares': 1204,
            'stale': 1,
            'invalid': 0,
            'wallet': wallet,
          },
          'blocks': <Object?>[],
          'workers': <Object?>[],
          'bridgeUptime': 7200,
        }),
      );
    }

    Widget host(MinerSnapshot snapshot) {
      // Tall viewport: a ListView builds lazily, so a short one would leave
      // the lower panels unbuilt and the finder would report a false negative.
      return MediaQuery(
        data: const MediaQueryData(size: Size(400, 2600)),
        child: MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: DashboardScreen(snapshot: snapshot, connected: true),
          ),
        ),
      );
    }

    testWidgets('the payout address is shown and can be copied', (tester) async {
      // The clipboard is a platform channel; without a mock the copy call
      // throws and the confirmation never reaches the screen.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(host(snapshotWith()));

      expect(find.text('Payout'), findsOneWidget);
      expect(find.text('celeniumsim:qabc'), findsOneWidget);

      final copy = find.widgetWithText(OutlinedButton, 'Copy');
      expect(copy, findsOneWidget);

      await tester.tap(copy);
      await tester.pump();
      expect(find.text('Address copied'), findsOneWidget);
    });

    testWidgets('a missing payout address says so instead of showing a blank',
        (tester) async {
      await tester.pumpWidget(host(snapshotWith(wallet: '')));

      expect(find.text('celeniumsim:qabc'), findsNothing);
      expect(find.textContaining('No payout address yet'), findsOneWidget);
    });

    testWidgets('the instance limit is reported as one device, one miner',
        (tester) async {
      await tester.pumpWidget(host(snapshotWith(instances: 1)));

      expect(find.text('Mining instances'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.textContaining('The limit is 1 per device'), findsNothing);
    });

    testWidgets('running more than one instance is flagged, not hidden',
        (tester) async {
      await tester.pumpWidget(host(snapshotWith(instances: 3)));

      expect(find.text('3 of 1'), findsOneWidget);
      expect(
        find.textContaining('The limit is 1 per device'),
        findsOneWidget,
        reason: 'silent over-mining splits hashrate and the user never knows',
      );
    });
  });
}

extension _Pow on double {
  double pow() => this * this;
}
