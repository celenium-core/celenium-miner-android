// Functional (assertion-only) coverage for the wallet tab: the mining address,
// the session estimate, the balance fetch, and the send/unavailable-decision.
//
// These pin down the two regressions the user reported —
//   1. the mining address and earned-coins estimate were missing on the wallet
//      tab (the tab read the bridge's `internalCpu.wallet`, which is always
//      null on Android),
//   2. the "Kirim" action dead-ended on a "no address" dialog because the
//      default network was `simnet` while mining runs on `mainnet` —
// and prove the functions run headlessly (no device, no golden files, no fonts).
library;

import 'dart:convert';

import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/models/bridge.dart';
import 'package:celenium_miner/screens/wallet_screen.dart';
import 'package:celenium_miner/services/bridge_api.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A real-looking mainnet address the test treats as "the phone's own key".
const _local = 'cen69:qz0p8x7m2v5n3w9r4t6y8u1i5o7p9a2s3d4f6g8h7j6k5l9';

/// The bridge is NOT the miner on Android, so `internalCpu.wallet` is null and
/// the address MUST come from `localAddress` — exactly the bug under test.
MinerSnapshot _snapshot() {
  return MinerSnapshot(
    status: BridgeStatus.tryParse(const {
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
}

http.Client _bridge() {
  return MockClient((request) async {
    const json = {'content-type': 'application/json'};
    if (request.url.path == '/api/balance') {
      return http.Response(
        jsonEncode({'address': request.url.queryParameters['address'] ?? _local, 'balancePradha': 123456789}),
        200,
        headers: json,
      );
    }
    return http.Response('not found', 404);
  });
}

Widget _host({String? localAddress, double? estimatedCen}) {
  final api = BridgeApi(baseUrl: 'http://127.0.0.1:3030', client: _bridge());
  return MaterialApp(
    theme: buildCenTheme(),
    locale: const Locale('id'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: WalletScreen(
        snapshot: _snapshot(),
        onBackup: () {},
        onOpenActivity: () {},
        api: api,
        localAddress: localAddress,
        estimatedCen: estimatedCen,
      ),
    ),
  );
}

/// Live counters keep repainting, so `pumpAndSettle` would time out.
Future<void> _settle(WidgetTester tester, {int frames = 16}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('wallet tab shows the local mining address and session estimate',
      (tester) async {
    await tester.pumpWidget(_host(localAddress: _local, estimatedCen: 0.123456));
    await _settle(tester);

    // Bug #1 fix: the earned-coins estimate renders.
    expect(find.text('≈ 0.123456 CEN'), findsOneWidget);

    // Bug #1 fix: the phone's own mainnet address is shown (default = revealed),
    // sourced from `localAddress`, not the null `internalCpu.wallet`.
    expect(find.textContaining('cen69:'), findsWidgets);

    // The balance fetch against the mock bridge resolves and renders.
    expect(find.textContaining('1.23456789'), findsWidgets);
  });

  testWidgets('"Kirim" opens the send sheet when address and api exist',
      (tester) async {
    await tester.pumpWidget(_host(localAddress: _local));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.north_east));
    await _settle(tester, frames: 8);

    // Bug #2 fix: with a resolved address the send sheet opens instead of the
    // "no address" dialog dead-end.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('"Kirim" explains itself when there is no address yet',
      (tester) async {
    await tester.pumpWidget(_host(localAddress: null));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.north_east));
    await _settle(tester, frames: 8);

    // Still a graceful, informative dialog — not a crash, not a dead-end sheet.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
}