// Cycle B of the field-report reproduction, run AFTER cycle A and an
// out-of-band corruption of the plugin's EncryptedSharedPreferences file
// (the host strips the androidx keyset entries, keeping the value blobs —
// the exact state a reinstall-with-restored-backup leaves behind: data
// present, key gone).
//
// In a FRESH process (this run relaunches the app), the real plugin must
// surface its decryption failure, the Keystore fix must swallow it into
// absence — never a crash, never "SET WALLET FIRST" without a path — and
// the recovery screen must self-heal into a NEW twelve-word wallet.
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

  // The old phrase is only known to this cycle through the file cycle A
  // stashed before the corruption — the storage itself must read as gone.
  final oldPhrase = await File('$_pkgRoot/cache/old_phrase.txt').readAsString();
  expect(oldPhrase, isNotEmpty);

  // Core assertion of the Keystore fix in the REAL restart path: the corrupt
  // blob reads as absence instead of rethrowing PlatformException.
  String? read;
  Object? err;
  try {
    read = await keystore.readPhrase();
  } catch (e) {
    err = e;
  }
  // ignore: avoid_print
  print('CORRUPT_READ value="$read" error=$err');
  expect(err, isNull, reason: 'fix must swallow the platform error');
  expect(read, isNull, reason: 'corrupt blob must read as absent');

  testWidgets('corrupt storage self-heals into a new wallet', (tester) async {
    await tester.pumpWidget(_host(keystore, wordlist));
    await _pumpUntil(tester, find.text('Create recovery words'));

    await tester.tap(find.text('Create recovery words'));
    await _pumpUntil(tester, find.text('Continue'));

    final phrase = await keystore.readPhrase();
    expect(phrase, isNotNull);
    final words = Mnemonic.fromPhrase(phrase!).words;
    expect(words, hasLength(12));
    expect(phrase, isNot(oldPhrase), reason: 'wallet must be regenerated');
    for (final w in words) {
      expect(wordlist.contains(w), isTrue, reason: 'not BIP39: $w');
      expect(find.text(w), findsWidgets, reason: 'not rendered: $w');
    }
    // ignore: avoid_print
    print('CYCLE_B_OK regenerated ${words.length} words');
  });
}
