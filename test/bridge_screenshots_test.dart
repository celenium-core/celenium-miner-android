// Renders the full phone shell — the bottom nav included — in two bridge
// states so the mining card can be reviewed in context: connected to a mock
// bridge, and before any bridge is reachable. Plain goldens regenerated with
// --update-goldens and read back as images; not an assertion suite.
//
// The connected state feeds MinerHome an injected http.Client (the `client`
// parameter), because a real HTTP request cannot be made inside testWidgets'
// FakeAsync zone — flutter_test stubs every outgoing call to HTTP 400. This is
// the same seam BridgeApi already exposes for its own tests.
//
// Order matters: the connected test runs first. MinerHome boots through a real
// async poll on first instantiation, and within a single test isolate only the
// first boot reaches the mock; a later test would silently stay on the empty
// readout. Keeping connected first is what keeps both goldens honest.
import 'dart:convert';

import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/main.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fonts.dart';

/// Phone-sized viewport at 3x so the PNG is 1080 wide and readable.
void _phoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host({http.Client? client}) {
  return MaterialApp(
    title: 'Celenium Miner',
    debugShowCheckedModeBanner: false,
    theme: buildCenTheme(),
    locale: const Locale('id'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MinerHome(client: client, onLanguageChanged: (_) {}),
  );
}

/// The whole visible app, not just MinerHome, so the bottom nav is captured.
final Finder _screen = find.byType(Overlay).first;

/// Live counters keep repainting, so pumpAndSettle would time out.
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _enterShell(WidgetTester tester) async {
  await _settle(tester, frames: 32);
  await tester.tap(find.text('MASUK'));
  await _settle(tester);
}

/// A mock bridge: one active worker "asic-1" mining on the internal CPU miner.
http.Client _connectedBridge() {
  return MockClient((request) async {
    const json = {'content-type': 'application/json'};
    switch (request.url.path) {
      case '/api/status':
        return http.Response(
          jsonEncode(const {
            'celeniumd_address': '127.0.0.1:26510',
            'celeniumd_version': '0.1.0-alpha',
            'instances': 1,
            'web_bind': '0.0.0.0:3030',
          }),
          200,
          headers: json,
        );
      case '/api/stats':
        return http.Response(
          jsonEncode(const {
            'totalBlocks': 4,
            'totalShares': 128,
            'networkHashrate': 1420000000,
            'networkDifficulty': 8.00,
            'networkBlockCount': 4,
            'activeWorkers': 1,
            'miningEnabled': true,
            'internalCpu': {
              'hashrateGhs': 1.42,
              'hashesTried': 12983210,
              'blocksSubmitted': 1,
              'blocksAccepted': 1,
              'shares': 128,
              'stale': 2,
              'invalid': 0,
              'wallet': 'cen69qpzv8x3k2m...',
            },
            'blocks': [
              {
                'instance': 'asic-1',
                'worker': 'asic-1',
                'wallet': 'cen69qpzv8x3k2m...',
                'timestamp': '02:00:00',
                'hash': '0x9f3a1c7b...c2d1',
              }
            ],
            'workers': [
              {
                'instance': 'asic-1',
                'worker': 'asic-1',
                'wallet': 'cen69qpzv8x3k2m...',
                'hashrate': 1.42,
                'shares': 128,
                'stale': 2,
                'invalid': 0,
                'blocks': 1,
                'currentDifficulty': 8.00,
                'sessionUptime': 7200,
                'status': 'active',
              }
            ],
            'bridgeUptime': 7200,
          }),
          200,
          headers: json,
        );
      default:
        return http.Response('not found', 404);
    }
  });
}

void main() {
  testWidgets('capture connected mine tab with nav', (tester) async {
    await loadCenFonts();
    SharedPreferences.setMockInitialValues({});
    _phoneViewport(tester);

    await tester.pumpWidget(_host(client: _connectedBridge()));
    await precacheMarkImages(tester);
    await _enterShell(tester);

    await expectLater(
      _screen,
      matchesGoldenFile('goldens/bridge_connected_nav.png'),
    );
  });

  testWidgets('capture empty mine tab with nav', (tester) async {
    await loadCenFonts();
    SharedPreferences.setMockInitialValues({});
    _phoneViewport(tester);

    await tester.pumpWidget(_host());
    await precacheMarkImages(tester);
    await _enterShell(tester);

    await expectLater(
      _screen,
      matchesGoldenFile('goldens/bridge_empty_nav.png'),
    );
  });
}