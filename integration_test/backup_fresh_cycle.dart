// Cycle A of the field-report reproduction, run by `flutter drive` with
// --keep-app-running so the app (and its data) survives into cycle B.
//
// Fresh install: opening the recovery screen must offer creation, and a
// created wallet must render its twelve BIP39 words. The phrase is stashed
// at cache/old_phrase.txt so cycle B can prove the self-heal generates a
// different wallet.
import 'dart:io';

import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/screens/backup_screen.dart';
import 'package:celenium_miner/services/cen_wallet.dart';
import 'package:celenium_miner/services/keystore.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _pkgRoot = '/data/data/com.celenium.celenium_miner';

Widget _host(Keystore keystore, List<String> wordlist, {Key? key}) {
  return MediaQuery(
    key: key,
    data: const MediaQueryData(size: Size(400, 2400)),
    child: MaterialApp(
      theme: buildCenTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BackupScreen(onDone: () {}, keystore: keystore, wordlist: wordlist),
    ),
  );
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.trim().isNotEmpty)
      .toSet();
  // ignore: avoid_print
  print('PUMP_TIMEOUT visible texts: ${texts.take(24)}');
  fail('never appeared: $finder');
}

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final keystore = Keystore();
  final wordlist = await loadBip39Wordlist(rootBundle);
  await keystore.deletePhrase();

  testWidgets('fresh install: recovery screen offers creation, words render', (
    tester,
  ) async {
    await tester.pumpWidget(_host(keystore, wordlist));
    await _pumpUntil(tester, find.text('Create recovery words'));
    expect(find.text('I already have words'), findsOneWidget);

    await tester.tap(find.text('Create recovery words'));
    await _pumpUntil(tester, find.text('Continue'));

    final phrase = await keystore.readPhrase();
    expect(phrase, isNotNull);
    final words = Mnemonic.fromPhrase(phrase!).words;
    expect(words, hasLength(12));
    for (final w in words) {
      expect(wordlist.contains(w), isTrue, reason: 'not BIP39: $w');
      expect(find.text(w), findsWidgets, reason: 'not rendered: $w');
    }
    expect(find.text('1'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    // Stash the phrase for cycle B's "wallet changed" proof.
    await File('$_pkgRoot/cache/old_phrase.txt').writeAsString(phrase);
    // ignore: avoid_print
    print('CYCLE_A_OK saved ${words.length} words');
  });
}
