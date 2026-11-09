// Renders the phone send sheet (and the wallet tab behind it) to PNG so the
// green address cards can be reviewed. Regenerated with --update-goldens and
// read back via vision_analyze; not an assertion suite.
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

import 'support/fonts.dart';

const _wallet =
    'cen69sim:qp82mvgr5t2nw9q3x7c4v6b8m1k5h2j7f9d3s6a0g4l8p1o5i7u9y2e6r4t8w0q';

/// The mock bridge's answer for the balance query, so the sheet has a filled,
/// realistic balance above the actions rather than an "unknown" dash.
http.Client _bridge() {
  return MockClient((request) async {
    const json = {'content-type': 'application/json'};
    if (request.url.path == '/api/balance') {
      return http.Response(
        jsonEncode({'address': _wallet, 'balancePradha': 123456789}),
        200,
        headers: json,
      );
    }
    return http.Response('not found', 404);
  });
}

MinerSnapshot _snapshot() {
  return MinerSnapshot(
    status: BridgeStatus.tryParse(const {
      'celeniumd_address': '127.0.0.1:26510',
      'celeniumd_version': '2.1.0-a438515',
      'instances': 1,
      'web_bind': '0.0.0.0:3030',
    }),
    stats: BridgeStats.tryParse({
      'totalBlocks': 2,
      'totalShares': 1204,
      'networkHashrate': 4500000000000,
      'networkDifficulty': 1234567.5,
      'networkBlockCount': 1920,
      'activeWorkers': 1,
      'miningEnabled': true,
      'internalCpu': {
        'hashrateGhs': 1.42,
        'hashesTried': 900000000,
        'blocksSubmitted': 2,
        'blocksAccepted': 2,
        'shares': 1204,
        'stale': 1,
        'invalid': 0,
        'wallet': _wallet,
      },
      'blocks': [
        {
          'instance': 'default',
          'worker': 'asic-1',
          'wallet': _wallet,
          'timestamp': '2026-10-29T10:00:00Z',
          'hash': 'abc123def456',
        },
      ],
      'workers': [
        {
          'instance': 'default',
          'worker': 'asic-1',
          'wallet': _wallet,
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
      ],
      'bridgeUptime': 7200,
    }),
  );
}

Widget _host() {
  final snapshot = _snapshot();
  final api = BridgeApi(baseUrl: 'http://127.0.0.1:3030', client: _bridge());
  return MaterialApp(
    title: 'Celenium Miner',
    debugShowCheckedModeBanner: false,
    theme: buildCenTheme(),
    locale: const Locale('id'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: WalletScreen(
        snapshot: snapshot,
        api: api,
        onBackup: () {},
        onOpenActivity: () {},
      ),
    ),
  );
}

/// Live counters keep repainting, so pumpAndSettle would time out.
Future<void> _settle(WidgetTester tester, {int frames = 16}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('capture the send sheet with green address cards', (
    tester,
  ) async {
    await loadCenFonts();
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await _settle(tester);

    // Open the send sheet: with an address and an api present it opens
    // directly instead of showing the "unavailable" reason dialog.
    await tester.tap(find.text('Kirim'));
    await _settle(tester);

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/wallet_send_sheet.png'),
    );
  });

  testWidgets('capture the address card revealed and hidden', (tester) async {
    await loadCenFonts();
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await _settle(tester);

    await expectLater(
      find.byType(WalletScreen),
      matchesGoldenFile('goldens/wallet_revealed.png'),
    );

    // Blur the card with the eye, then capture the same frame hidden. The
    // balance card above it now carries its own eye, so tap the address
    // card's — the last eye in traversal order.
    await tester.tap(find.byIcon(Icons.visibility_outlined).last);
    await _settle(tester);

    await expectLater(
      find.byType(WalletScreen),
      matchesGoldenFile('goldens/wallet_hidden.png'),
    );
  });

  testWidgets('capture the swap coming-soon notice', (tester) async {
    await loadCenFonts();
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await _settle(tester);

    await tester.tap(find.text('Tukar'));
    await _settle(tester);

    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/wallet_swap_soon.png'),
    );
  });

  testWidgets('capture the balance card censored by the eye', (tester) async {
    await loadCenFonts();
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await _settle(tester);

    // Tap the balance card's own eye — the first one in traversal order —
    // which blanks the figure into X.XXXX while the address card stays sharp.
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await _settle(tester);

    await expectLater(
      find.byType(WalletScreen),
      matchesGoldenFile('goldens/wallet_balance_censored.png'),
    );
  });
}
