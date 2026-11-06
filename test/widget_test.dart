import 'dart:math';

import 'package:celenium_miner/main.dart';
import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/models/bridge.dart';
import 'package:celenium_miner/screens/backup_screen.dart';
import 'package:celenium_miner/screens/mining_screen.dart';
import 'package:celenium_miner/screens/profile_screen.dart';
import 'package:celenium_miner/screens/wallet_screen.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:celenium_miner/services/cen_wallet.dart';
import 'package:celenium_miner/services/keystore.dart';
import 'package:celenium_miner/services/mining_readout.dart';
import 'package:celenium_miner/services/settings_store.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:celenium_miner/theme/palette.dart';
import 'package:celenium_miner/widgets/ad_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A snapshot shaped like a real bridge response: one worker hashing, two
/// blocks accepted, one stale share, a mined block in the list.
MinerSnapshot snapshotWith({
  String wallet = 'cen69sim:qabc',
  int instances = 1,
  bool withWorker = true,
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
      'blocks': [
        {
          'instance': 'default',
          'worker': 'asic-1',
          'wallet': wallet,
          'timestamp': '2026-10-29T10:00:00Z',
          'hash': 'abc123def456',
        },
      ],
      'workers': withWorker
          ? [
              {
                'instance': 'default',
                'worker': 'asic-1',
                'wallet': wallet,
                'hashrate': 1.42,
                'shares': 1204,
                'stale': 1,
                'invalid': 0,
                'blocks': 2,
                'lastSeen': 1793244445,
                'status': 'online',
                'currentDifficulty': 8.0,
                'sessionUptime': 3600,
              },
            ]
          : <Object?>[],
      'bridgeUptime': 7200,
    }),
  );
}

/// A synthetic 2048-word list.
///
/// The real BIP39 wordlist ships as an asset, and loading it from a plain
/// `test()` poisons the asset bundle for the widget tests that follow in the
/// same file. The pure-logic tests only need 2048 distinct indexable words,
/// so they use this; the real wordlist is exercised by the app and verified
/// by its own checksum test.
List<String> get _testWordlist =>
    List<String>.generate(2048, (i) => 'word${i.toString().padLeft(4, '0')}');

/// The shell mounted the way main() mounts it, with the real localisation
/// delegates. Screen tests pump a bare MaterialApp and so fall back to English;
/// a test that is meant to catch a missing translation has to name its locale
/// here, or it would pass in either language.
Widget shellApp(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: buildCenTheme(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

/// Pumps frames by hand. The ambient binary rain never stops, so
/// pumpAndSettle would spin until it timed out.
Future<void> pumpFrames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('normaliseBaseUrl', () {
    test('adds a scheme when missing', () {
      expect(normaliseBaseUrl('127.0.0.1:3030'), 'http://127.0.0.1:3030');
    });

    test('keeps an explicit scheme', () {
      expect(normaliseBaseUrl('http://10.0.0.5:3030'), 'http://10.0.0.5:3030');
    });

    test('strips trailing slashes', () {
      expect(
        normaliseBaseUrl('http://127.0.0.1:3030///'),
        'http://127.0.0.1:3030',
      );
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
          'wallet': 'cen69sim:qabc',
        },
        'blocks': <Object?>[],
        'workers': <Object?>[],
      });

      expect(stats, isNotNull);
      expect(stats!.internalCpu, isNotNull);
      expect(stats.internalCpu!.hashrateGhs, 1.42);
      expect(stats.internalCpu!.blocksAccepted, 2);
    });

    test('malformed bodies are rejected rather than half-parsed', () {
      expect(BridgeStatus.tryParse('not an object'), isNull);
      expect(BridgeStats.tryParse(null), isNull);
      expect(BridgeStats.tryParse({'blocks': 'not a list'}), isNull);
      expect(BridgeStats.tryParse({'workers': 42}), isNull);
    });
  });

  group('mining readout', () {
    test('derives figures from the bridge, never invents them', () {
      final readout = MiningReadout.from(snapshotWith());

      expect(readout.hashrateGhs, 1.42);
      expect(readout.difficulty, 8.0);
      expect(readout.workerName, 'asic-1');
      expect(readout.sessionBlocks, 2);
      expect(readout.totalBlocks, 3);
      expect(readout.shares, 1204);
      expect(readout.stale, 1);
      expect(readout.active, isTrue);
    });

    test('acceptance rate is null until shares exist', () {
      // A dial with nothing to measure must not show a decorative fill.
      final empty = MinerSnapshot(
        status: BridgeStatus.tryParse({
          'celeniumd_address': '127.0.0.1:26510',
          'celeniumd_version': '2.1.0',
          'instances': 1,
          'web_bind': '0.0.0.0:3030',
        }),
        stats: BridgeStats.tryParse({
          'totalBlocks': 0,
          'totalShares': 0,
          'networkHashrate': 0,
          'networkDifficulty': 0,
          'networkBlockCount': 0,
          'activeWorkers': 0,
          'internalCpu': null,
          'blocks': <Object?>[],
          'workers': <Object?>[],
        }),
      );

      expect(MiningReadout.from(empty).acceptanceRate, isNull);
      expect(MiningReadout.from(empty).active, isFalse);
    });

    test('hashrate is formatted in the unit that keeps it readable', () {
      expect(formatHashrate(0.0042), '4.2 MH/s');
      expect(formatHashrate(1.42), '1.42 GH/s');
      expect(formatHashrate(1500), '1.50 TH/s');
    });

    test('a long hash is shortened but stays recognisable', () {
      final hash = List.filled(64, 'a').join();
      final short = shortHash(hash);
      expect(short.length < hash.length, isTrue);
      expect(short, contains('aaaaaaa'));
      expect(short, endsWith('a'));
    });
  });

  group('palette contrast', () {
    test('text and accent clear WCAG AA on the dark canvas', () {
      double luminance(Color c) {
        double channel(double v) {
          final s = v > 1.0 ? v / 255 : v;
          return s <= 0.03928
              ? s / 12.92
              : ((s + 0.055) / 1.055) * ((s + 0.055) / 1.055);
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

      expect(ratio(Palette.cream, Palette.field), greaterThanOrEqualTo(4.5));
      expect(ratio(Palette.gold, Palette.field), greaterThanOrEqualTo(4.5));
      expect(ratio(Palette.cream, Palette.surface), greaterThanOrEqualTo(4.5));
      expect(
        ratio(Palette.slateLight, Palette.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('ad banner', () {
    Widget host(AdSlotState state, VoidCallback onDismiss, {Widget? ad}) {
      return MaterialApp(
        theme: buildCenTheme(),
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
        expect(
          tester.getSize(find.byType(AdBanner)),
          Size.zero,
          reason: '$state must not reserve any space',
        );
        expect(find.text('Ad'), findsNothing);
      }
    });

    testWidgets('a configured slot with no ad reserves nothing', (
      tester,
    ) async {
      // The rule the user asked for: the banner appears only once an ad has
      // actually arrived. A saved unit id on its own is not an ad.
      await tester.pumpWidget(host(AdSlotState.awaitingSdk, () {}));

      expect(tester.getSize(find.byType(AdBanner)), Size.zero);
      expect(find.text('Ad'), findsNothing);
    });

    testWidgets('a real ad reserves a fixed height and labels itself', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AdSlotState.loaded, () {}, ad: const Text('REAL AD UNIT')),
      );

      final size = tester.getSize(find.byType(AdBanner));
      expect(size.height, AdBanner.footprint);
      expect(AdBanner.footprint, AdBanner.height + Palette.sm);
      expect(find.text('Ad'), findsOneWidget);
      expect(find.text('REAL AD UNIT'), findsOneWidget);
    });

    testWidgets('the close button dismisses and meets the touch target', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        host(
          AdSlotState.loaded,
          () => dismissed++,
          ad: const Text('REAL AD UNIT'),
        ),
      );

      final close = find.byType(IconButton);
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
  });

  group('ad settings persistence', () {
    test(
      'a blank ad unit id round-trips to null, not to an empty slot',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = SettingsStore();

        expect(await store.adUnitId(), isNull);

        await store.setAdUnitId('   ');
        expect(await store.adUnitId(), isNull);

        await store.setAdUnitId('  ca-app-pub-1/2  ');
        expect(await store.adUnitId(), 'ca-app-pub-1/2');
      },
    );

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

  group('mining screen', () {
    Widget host(MinerSnapshot snapshot) {
      return MediaQuery(
        data: const MediaQueryData(size: Size(400, 2600)),
        child: MaterialApp(
          theme: buildCenTheme(),
          home: Scaffold(
            body: MiningScreen(
              snapshot: snapshot,
              nodeAddress: '127.0.0.1:26510',
              onOpenWorkers: () {},
              onOpenActivity: () {},
              onConnectNode: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows the real hashrate and worker from the bridge', (
      tester,
    ) async {
      await tester.pumpWidget(host(snapshotWith()));

      expect(find.text('1.42 GH/s'), findsOneWidget);
      expect(find.text('asic-1'), findsOneWidget);
      expect(find.text('MINING ACTIVE'), findsOneWidget);
    });

    testWidgets('says so when the bridge has not answered', (tester) async {
      await tester.pumpWidget(host(const MinerSnapshot()));

      expect(find.text('—'), findsWidgets);
      expect(find.text('IDLE'), findsOneWidget);
      expect(
        find.textContaining('The bridge has not answered'),
        findsOneWidget,
      );
    });

    testWidgets('shows real block and share counts, not a price', (
      tester,
    ) async {
      await tester.pumpWidget(host(snapshotWith()));

      // The concept mock carried a $ price. CEN is not listed anywhere, so a
      // price here would be invented: the third cell is shares instead.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1204'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('the level badge is derived from the hashrate, not invented', (
      tester,
    ) async {
      await tester.pumpWidget(host(snapshotWith()));

      // 1.42 GH/s floors to 1, so the badge reads LV.1. The badge only
      // appears once there is a hashrate to derive it from.
      expect(find.text('LV.1'), findsOneWidget);
    });

    testWidgets('no level badge when the bridge has not answered', (
      tester,
    ) async {
      await tester.pumpWidget(host(const MinerSnapshot()));

      expect(find.textContaining('LV.'), findsNothing);
    });
  });

  group('hardware back button', () {
    // The back press must unwind one level at a time. Closing the app from
    // any tab is the behaviour this replaces, so each level is asserted.
    test('an open settings screen closes first', () {
      expect(
        decideBackAction(hasOpenRoute: true, isOnMineTab: false),
        BackAction.closeRoute,
      );
      expect(
        decideBackAction(hasOpenRoute: true, isOnMineTab: true),
        BackAction.closeRoute,
      );
    });

    test('another tab returns to Mine rather than closing', () {
      expect(
        decideBackAction(hasOpenRoute: false, isOnMineTab: false),
        BackAction.goToMineTab,
      );
    });

    test('only the root closes the app', () {
      expect(
        decideBackAction(hasOpenRoute: false, isOnMineTab: true),
        BackAction.exitApp,
      );
    });

    test('unwinding reaches the exit only after two presses', () {
      // From Wallet with settings open: press one closes settings, press two
      // returns to Mine, press three exits. Three presses, not one.
      var route = true;
      var onMine = false;

      route = false; // press one closed the settings screen
      expect(
        decideBackAction(hasOpenRoute: route, isOnMineTab: onMine),
        BackAction.goToMineTab,
      );

      onMine = true; // press two returned to Mine
      expect(
        decideBackAction(hasOpenRoute: route, isOnMineTab: onMine),
        BackAction.exitApp,
      );
    });
  });

  group('brand naming', () {
    testWidgets('the ticker reads CEN everywhere it appears', (tester) async {
      // The coin is CEN. An earlier pass shipped "CEL" in a few spots, which
      // reads as a different asset, so the ticker is asserted directly.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCenTheme(),
          home: Scaffold(
            body: WalletScreen(
              snapshot: snapshotWith(),
              networkLabel: 'simnet',
              onBackup: () {},
              onOpenActivity: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CEN'), findsWidgets);
      expect(find.text('CEL'), findsNothing);
    });

    testWidgets('the mining screen states CEN as the unit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCenTheme(),
          home: Scaffold(
            body: MiningScreen(
              snapshot: snapshotWith(),
              nodeAddress: '127.0.0.1:26510',
              onOpenWorkers: () {},
              onOpenActivity: () {},
              onConnectNode: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CEN'), findsWidgets);
      expect(find.text('CEL'), findsNothing);
    });
  });

  group('wallet screen', () {
    Widget host(MinerSnapshot snapshot, {BridgeApi? api}) {
      return MediaQuery(
        data: const MediaQueryData(size: Size(400, 2600)),
        child: MaterialApp(
          theme: buildCenTheme(),
          home: Scaffold(
            body: WalletScreen(
              snapshot: snapshot,
              networkLabel: 'simnet',
              api: api,
              onBackup: () {},
              onOpenActivity: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows the mining address and mined blocks', (tester) async {
      await tester.pumpWidget(host(snapshotWith()));

      expect(find.text('cen69sim:qabc'), findsWidgets);
      // The row reads as a transaction, as in the concept.
      expect(find.text('Mining reward'), findsOneWidget);
      expect(find.text('+50.00'), findsOneWidget);
      expect(find.text('CEN'), findsWidgets);
    });

    testWidgets('does not invent a balance', (tester) async {
      // With no bridge to answer it, the card shows "unknown" (an em-dash) and
      // never a hardcoded 0.00 that would tell the user their coins are gone.
      await tester.pumpWidget(host(snapshotWith()));

      expect(find.text('—'), findsWidgets);
      expect(find.text('0,00'), findsNothing);
      expect(find.text('0.00'), findsNothing);
    });

    testWidgets('shows the balance returned by the bridge', (tester) async {
      final api = BridgeApi(
        baseUrl: 'http://127.0.0.1:3030',
        client: MockClient((request) async {
          expect(request.url.path, '/api/balance');
          expect(request.url.queryParameters['address'], 'cen69sim:qabc');
          return http.Response(
            '{"address": "cen69sim:qabc", "balancePradha": 123456789}',
            200,
          );
        }),
      );

      await tester.pumpWidget(host(snapshotWith(), api: api));
      await tester.pumpAndSettle();

      expect(find.text('1.23456789'), findsOneWidget);
    });

    testWidgets('send explains why it is unavailable without a node', (
      tester,
    ) async {
      await tester.pumpWidget(host(snapshotWith()));

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.text("The node isn't reachable"), findsOneWidget);
    });

    testWidgets('send explains why it is unavailable before the first block', (
      tester,
    ) async {
      await tester.pumpWidget(host(snapshotWith(wallet: '')));

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.text('No wallet address yet'), findsOneWidget);
    });

    testWidgets('an empty block list explains what fills it', (tester) async {
      await tester.pumpWidget(
        host(snapshotWith(withWorker: false).copyWithNullBlocks()),
      );

      expect(find.textContaining('No transactions yet'), findsOneWidget);
    });
  });

  group('recovery words', () {
    test('a generated phrase is 12 valid BIP39 words', () async {
      final wordlist = _testWordlist;
      final mnemonic = generateMnemonic(wordlist: wordlist, random: Random(42));

      expect(mnemonic.words.length, 12);
      expect(isValidMnemonic(mnemonic, wordlist), isTrue);
      for (final word in mnemonic.words) {
        expect(wordlist, contains(word));
      }
    });

    test('the same entropy always produces the same phrase', () async {
      final wordlist = _testWordlist;
      final a = mnemonicFromEntropy(List.filled(16, 7), wordlist: wordlist);
      final b = mnemonicFromEntropy(List.filled(16, 7), wordlist: wordlist);

      expect(a.phrase, b.phrase);
    });

    test('a mangled phrase fails its checksum', () async {
      final wordlist = _testWordlist;
      final mnemonic = generateMnemonic(wordlist: wordlist, random: Random(1));

      final broken = Mnemonic([
        ...mnemonic.words.sublist(0, 11),
        wordlist.first == mnemonic.words[11] ? wordlist[1] : wordlist.first,
      ]);

      expect(isValidMnemonic(broken, wordlist), isFalse);
    });

    test('a phrase restores the same address as its key', () async {
      final wordlist = _testWordlist;
      final mnemonic = generateMnemonic(wordlist: wordlist, random: Random(9));

      final fromPhrase = CenWallet.fromMnemonic(mnemonic, CenNetwork.simnet);

      // The phrase is the source of the key: deriving the key from the seed
      // must land on the same address.
      final seed = mnemonicToSeed(mnemonic);
      final key = seedToPrivateKey(seed);
      final fromKey = CenWallet(privateKey: key, network: CenNetwork.simnet);

      expect(fromPhrase.address, fromKey.address);
      expect(fromPhrase.address, startsWith('cen69sim:'));
    });
  });

  group('backup screen', () {
    // A tall viewport: the intro is a scrolling list, so a short surface
    // leaves the lower buttons unbuilt and the finder reports a false miss.
    Widget host(Keystore keystore) {
      return MediaQuery(
        data: const MediaQueryData(size: Size(400, 2400)),
        child: MaterialApp(
          theme: buildCenTheme(),
          home: BackupScreen(
            onDone: () {},
            keystore: keystore,
            wordlist: _testWordlist,
          ),
        ),
      );
    }

    // The intro waits on the wordlist asset, which resolves on a microtask
    // after the first frame. Pump a bounded number of frames rather than
    // assuming one is enough, and never pumpAndSettle: the loading state
    // holds a progress indicator that spins forever.
    Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 20; i++) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('offers to create words and explains why', (tester) async {
      await tester.pumpWidget(host(_FakeKeystore()));
      await pumpUntil(tester, find.text('Create recovery words'));

      expect(find.text('Recovery words'), findsOneWidget);
      expect(find.text('Create recovery words'), findsOneWidget);

      // The import button sits at the end of a scrolling list, so bring it
      // into view before asserting rather than assuming it is already built.
      final import = find.text('I already have words');
      final list = find.byType(ListView).first;
      for (var i = 0; i < 10 && import.evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -300));
        await tester.pump();
      }
      expect(import, findsOneWidget);
    });

    testWidgets('a generated phrase is shown once, behind a confirmation', (
      tester,
    ) async {
      final keystore = _FakeKeystore();
      await tester.pumpWidget(host(keystore));
      await pumpUntil(tester, find.text('Create recovery words'));

      await tester.tap(find.text('Create recovery words'));
      await pumpUntil(tester, find.text('Continue'));

      // Twelve numbered words are on screen.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(
        find.textContaining('Anyone who reads these twelve words'),
        findsOneWidget,
      );

      // The phrase is persisted, and the backup flag is still false.
      expect(await keystore.readPhrase(), isNotNull);
      expect(await keystore.hasBackedUp(), isFalse);

      // Continue is gated on the checkbox, not available on a bare tap.
      final cont = find.widgetWithText(FilledButton, 'Continue');
      expect(cont, findsOneWidget);
      expect(tester.widget<FilledButton>(cont).enabled, isFalse);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<FilledButton>(cont).enabled, isTrue);
    });
  });

  // The desktop shell binds Ctrl+1/2/3 and Escape. Driving the real MinerHome
  // at a desktop window size proves the bindings against the widget that owns
  // them, rather than against a re-implementation of the map.
  group('desktop shell shortcuts', () {
    testWidgets('Ctrl+2 moves the shell to the wallet tab', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Wide enough for the expanded layout, which is the only layout that
      // installs the shortcut bindings.
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(shellApp(const MinerHome()));
      // Long enough for the emblem sweep to finish and the entry button to
      // fade in behind its delay.
      await pumpFrames(tester, 30);

      // The splash owns the shell until the entry button is pressed.
      expect(find.text('ENTER'), findsOneWidget);
      await tester.tap(find.text('ENTER'));
      await pumpFrames(tester, 10);

      // Mine opens first; both its dial caption and the node feed name
      // ACCEPTANCE, so it appears more than once. It exists nowhere else, so
      // any match proves the Mine tab is on screen.
      expect(find.textContaining('ACCEPTANCE'), findsWidgets);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await pumpFrames(tester, 10);

      // The wallet screen is the only one that names a balance. Eyebrow
      // uppercases its label, so the rendered text is all caps.
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.textContaining('ACCEPTANCE'), findsNothing);
    });
  });

  // Regression: the phone shell once collapsed to zero body height. The bottom
  // tab bar's Align (no height factor) expanded to fill the whole screen, so
  // the Scaffold handed the content body zero height and every tab rendered
  // empty even though its widgets were all still in the tree. Widget presence
  // checks cannot see this — the render height must be asserted directly.
  group('phone shell height', () {
    testWidgets('the content body takes vertical space after entry', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      // Phone viewport: the compact layout with the bottom tab bar.
      tester.view.physicalSize = const Size(800, 1720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(shellApp(const MinerHome()));
      await pumpFrames(tester, 30);
      await tester.tap(find.text('ENTER'));
      await pumpFrames(tester, 10);

      // Before the fix this was Size(400, 0): the whole tab body was zero
      // pixels tall. A healthy phone body is most of the viewport height.
      final bodyHeight = tester.getSize(find.byType(MiningScreen)).height;
      expect(
        bodyHeight,
        greaterThan(100),
        reason: 'the tab body must take vertical space, not collapse to zero',
      );
    });
  });

  // Regression: tapping PROFILE once left the active lens parked on WALLET.
  // The lens is driven by the raw tab index (0..2), but the AnimationController
  // defaulted to upperBound 1.0, so animateTo(2.0) was clamped and the lens
  // could never reach the profile slot. The controller now declares
  // upperBound = tabCount - 1; this asserts the lens actually settles on 2.0.
  group('phone shell tab lens', () {
    testWidgets('tapping PROFILE drives the lens to the profile slot', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(shellApp(const MinerHome()));
      await pumpFrames(tester, 30);
      await tester.tap(find.text('ENTER'));
      await pumpFrames(tester, 10);

      await tester.tap(find.text('PROFILE'));
      // The lens ride is 430ms; a handful of frames carries it to rest.
      await pumpFrames(tester, 10);

      // The liquid lens is the one CustomPaint whose painter carries the
      // floating tab index. `t` is a public field on a library-private class,
      // read here via `dynamic` rather than a golden.
      double lensPosition() {
        final paint = tester.widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter?.runtimeType.toString() == '_LiquidBulgePainter',
          ),
        );
        return (paint.painter! as dynamic).t as double;
      }

      expect(
        lensPosition(),
        closeTo(2.0, 0.01),
        reason:
            'the lens must settle on the profile slot (index 2), not clamp '
            'to 1.0 on the wallet slot',
      );
    });
  });

  // The app ships in English and Indonesian. These tests mount the shell under
  // a named locale, which the screen tests above deliberately do not do: they
  // read the English fallback, so a missing translation could never fail them.
  group('localisation', () {
    testWidgets('the shell reads Indonesian under the Indonesian locale', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        shellApp(const MinerHome(), locale: const Locale('id')),
      );
      await pumpFrames(tester, 30);

      expect(find.text('MASUK'), findsOneWidget);
      expect(find.text('ENTER'), findsNothing);

      await tester.tap(find.text('MASUK'));
      await pumpFrames(tester, 10);

      // The tab strip uppercases its captions, so the Indonesian names arrive
      // as TAMBANG / DOMPET / PROFIL. The English set has to be gone.
      expect(find.text('TAMBANG'), findsWidgets);
      expect(find.text('MINE'), findsNothing);
      expect(find.text('WALLET'), findsNothing);
    });

    testWidgets('a stored language is applied at startup', (tester) async {
      // The choice has to survive a restart: the root reads it back from the
      // settings store and rebuilds the MaterialApp with that locale.
      SharedPreferences.setMockInitialValues({
        SettingsStore.languageKey: AppLanguage.indonesian.code,
      });

      await tester.pumpWidget(const CeleniumMinerApp());
      await pumpFrames(tester, 30);

      expect(find.text('MASUK'), findsOneWidget);
    });

    testWidgets('the profile picker offers both languages and reports the '
        'choice', (tester) async {
      AppLanguage? picked;
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        shellApp(
          Scaffold(
            body: ProfileScreen(
              snapshot: snapshotWith(),
              networkLabel: 'simnet',
              onLanguageChanged: (choice) => picked = choice,
              onOpenBridge: () {},
              onOpenWorkers: () {},
              onOpenActivity: () {},
              onOpenBackup: () {},
              onOpenAbout: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final languageRow = find.text('Language');
      await tester.ensureVisible(languageRow);
      await tester.pump();

      // The row states the current choice before the sheet is opened.
      expect(find.text('System default'), findsOneWidget);

      await tester.tap(languageRow);
      await tester.pumpAndSettle();

      // Each language is named in its own language: someone looking for
      // Indonesian reads "Bahasa Indonesia", not "Indonesian". The system
      // option now appears twice, once as the row's current value and once as
      // an option in the sheet.
      expect(find.text('Bahasa Indonesia'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('System default'), findsNWidgets(2));

      await tester.tap(find.text('Bahasa Indonesia'));
      await tester.pumpAndSettle();

      expect(picked, AppLanguage.indonesian);
      expect(find.text('Language saved'), findsOneWidget);
    });
  });
}

extension on MinerSnapshot {
  MinerSnapshot copyWithNullBlocks() {
    return MinerSnapshot(
      status: status,
      stats: stats == null
          ? null
          : BridgeStats(
              totalBlocks: stats!.totalBlocks,
              totalShares: stats!.totalShares,
              networkHashrate: stats!.networkHashrate,
              networkDifficulty: stats!.networkDifficulty,
              networkBlockCount: stats!.networkBlockCount,
              activeWorkers: stats!.activeWorkers,
              internalCpu: stats!.internalCpu,
              blocks: const [],
              workers: stats!.workers,
              bridgeUptime: stats!.bridgeUptime,
            ),
    );
  }
}

/// Stands in for the platform keystore, which is not available in a widget
/// test. Records the same two values the real one does.
class _FakeKeystore implements Keystore {
  String? _phrase;
  bool _backedUp = false;

  @override
  Future<String?> readPhrase() async => _phrase;

  @override
  Future<void> savePhrase(String phrase) async => _phrase = phrase.trim();

  @override
  Future<void> deletePhrase() async {
    _phrase = null;
    _backedUp = false;
  }

  @override
  Future<bool> hasBackedUp() async => _backedUp;

  @override
  Future<void> setBackedUp(bool value) async => _backedUp = value;
}
