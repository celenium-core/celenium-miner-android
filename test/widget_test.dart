import 'dart:math';

import 'package:cenium_miner/models/bridge.dart';
import 'package:cenium_miner/screens/backup_screen.dart';
import 'package:cenium_miner/screens/mining_screen.dart';
import 'package:cenium_miner/screens/wallet_screen.dart';
import 'package:cenium_miner/services/bridge_api.dart';
import 'package:cenium_miner/services/cen_wallet.dart';
import 'package:cenium_miner/services/keystore.dart';
import 'package:cenium_miner/services/mining_readout.dart';
import 'package:cenium_miner/services/settings_store.dart';
import 'package:cenium_miner/theme/app_theme.dart';
import 'package:cenium_miner/theme/palette.dart';
import 'package:cenium_miner/widgets/ad_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
        }
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
              }
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
          return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) * ((s + 0.055) / 1.055);
        }

        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
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
      expect(ratio(Palette.slateLight, Palette.surface), greaterThanOrEqualTo(4.5));
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

    testWidgets('a configured slot with no ad reserves nothing', (tester) async {
      // The rule the user asked for: the banner appears only once an ad has
      // actually arrived. A saved unit id on its own is not an ad.
      await tester.pumpWidget(host(AdSlotState.awaitingSdk, () {}));

      expect(tester.getSize(find.byType(AdBanner)), Size.zero);
      expect(find.text('Ad'), findsNothing);
    });

    testWidgets('a real ad reserves a fixed height and labels itself', (tester) async {
      await tester.pumpWidget(
        host(AdSlotState.loaded, () {}, ad: const Text('REAL AD UNIT')),
      );

      final size = tester.getSize(find.byType(AdBanner));
      expect(size.height, AdBanner.footprint);
      expect(AdBanner.footprint, AdBanner.height + Palette.sm);
      expect(find.text('Ad'), findsOneWidget);
      expect(find.text('REAL AD UNIT'), findsOneWidget);
    });

    testWidgets('the close button dismisses and meets the touch target', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        host(AdSlotState.loaded, () => dismissed++, ad: const Text('REAL AD UNIT')),
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
      expect(AdBanner.willShow(AdSlotState.awaitingSdk, const Text('ad')), isFalse);
      expect(AdBanner.willShow(AdSlotState.unconfigured, const Text('ad')), isFalse);
      expect(AdBanner.willShow(AdSlotState.noFill, const Text('ad')), isFalse);
      expect(AdBanner.willShow(AdSlotState.dismissed, const Text('ad')), isFalse);
    });
  });

  group('ad settings persistence', () {
    test('a blank ad unit id round-trips to null, not to an empty slot', () async {
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

    testWidgets('shows the real hashrate and worker from the bridge', (tester) async {
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

    testWidgets('shows real block and share counts, not a price', (tester) async {
      await tester.pumpWidget(host(snapshotWith()));

      // The concept mock carried a $ price. CEN is not listed anywhere, so a
      // price here would be invented: the third cell is shares instead.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1204'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('the level badge is derived from the hashrate, not invented',
        (tester) async {
      await tester.pumpWidget(host(snapshotWith()));

      // 1.42 GH/s floors to 1, so the badge reads LV.1. The badge only
      // appears once there is a hashrate to derive it from.
      expect(find.text('LV.1'), findsOneWidget);
    });

    testWidgets('no level badge when the bridge has not answered', (tester) async {
      await tester.pumpWidget(host(const MinerSnapshot()));

      expect(find.textContaining('LV.'), findsNothing);
    });
  });

  group('wallet screen', () {
    Widget host(MinerSnapshot snapshot) {
      return MediaQuery(
        data: const MediaQueryData(size: Size(400, 2600)),
        child: MaterialApp(
          theme: buildCenTheme(),
          home: Scaffold(
            body: WalletScreen(
              snapshot: snapshot,
              networkLabel: 'simnet',
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
      expect(find.text('CEL'), findsWidgets);
    });

    testWidgets('does not invent a balance', (tester) async {
      // The bridge reports mining results, not balances. Showing 0.00 here
      // would tell the user their coins are gone.
      await tester.pumpWidget(host(snapshotWith()));

      expect(find.textContaining('The bridge reports mining results'), findsOneWidget);
      expect(find.text('0,00'), findsNothing);
      expect(find.text('0.00'), findsNothing);
    });

    testWidgets('send is disabled with an honest reason', (tester) async {
      await tester.pumpWidget(host(snapshotWith()));

      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Sending is not available yet'), findsOneWidget);
    });

    testWidgets('an empty block list explains what fills it', (tester) async {
      await tester.pumpWidget(host(snapshotWith(withWorker: false)
          .copyWithNullBlocks()));

      expect(
        find.textContaining('No transactions yet'),
        findsOneWidget,
      );
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
          home: BackupScreen(onDone: () {}, keystore: keystore, wordlist: _testWordlist),
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

    testWidgets('a generated phrase is shown once, behind a confirmation', (tester) async {
      final keystore = _FakeKeystore();
      await tester.pumpWidget(host(keystore));
      await pumpUntil(tester, find.text('Create recovery words'));

      await tester.tap(find.text('Create recovery words'));
      await pumpUntil(tester, find.text('Continue'));

      // Twelve numbered words are on screen.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.textContaining('Anyone who reads these twelve words'), findsOneWidget);

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
