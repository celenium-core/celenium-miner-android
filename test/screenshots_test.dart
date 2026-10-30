import 'package:cenium_miner/models/bridge.dart';
import 'package:cenium_miner/screens/dashboard_screen.dart';
import 'package:cenium_miner/screens/log_screen.dart';
import 'package:cenium_miner/screens/node_screen.dart';
import 'package:cenium_miner/screens/workers_screen.dart';
import 'package:cenium_miner/theme/tokens.dart';
import 'package:cenium_miner/widgets/ad_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the real screens headlessly and writes PNGs, so the app can be
/// reviewed as an image without a display server.
///
/// Generate with:
///   flutter test --update-goldens test/screenshots_test.dart
///
/// Files land next to this test in screenshots/. Golden comparison is exact,
/// so these are regenerated rather than asserted; the tests here only guard
/// that each screen builds and that the banner really takes no space when no
/// ad has arrived.

MinerSnapshot get _snapshot {
  return MinerSnapshot(
    status: BridgeStatus.tryParse({
      'celeniumd_address': '127.0.0.1:26510',
      'celeniumd_version': '2.1.0-a438515',
      'instances': 1,
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
        'wallet': 'celeniumsim:qabc',
      },
      'blocks': <Object?>[],
      'workers': <Object?>[],
      'bridgeUptime': 7200,
    }),
  );
}

const List<WorkerInfo> _workers = [
  WorkerInfo(
    instance: 'default',
    worker: 'asic-1',
    wallet: 'celeniumsim:qabc',
    hashrate: 1.42,
    shares: 1204,
    stale: 1,
    invalid: 0,
    blocks: 2,
    lastSeen: 1793244445,
    status: 'online',
    currentDifficulty: 8.0,
    sessionUptime: 3600,
  ),
];

const List<LogEntry> _log = [
  LogEntry(time: '10:04:12', message: 'Bridge reachable at 0.0.0.0:3030'),
  LogEntry(time: '10:14:55', message: 'Block accepted (1 new, 2 total)'),
  LogEntry(time: '10:31:03', message: 'Internal CPU miner started'),
  LogEntry(time: '10:47:40', message: 'Stale share (1 new, 1 total)'),
  LogEntry(time: '11:02:18', message: 'Block accepted (1 new, 3 total)'),
  LogEntry(time: '11:15:09', message: 'Bridge unreachable', isError: true),
];

/// Mirrors the app shell: the screen plus the floating ad slot, so the
/// screenshot proves the banner takes no room until a real ad arrives.
Widget _shell(Widget screen, {bool wide = true}) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final banner = AdBanner(state: AdSlotState.awaitingSdk, onDismiss: () {});
            return Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: AdBanner.willShow(AdSlotState.awaitingSdk, null)
                          ? AdBanner.footprint
                          : 0,
                    ),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(child: screen),
                              const SizedBox(width: 0),
                            ],
                          )
                        : screen,
                  ),
                ),
                const Positioned(left: 0, right: 0, bottom: 0, child: SizedBox()),
                Positioned(left: 0, right: 0, bottom: 0, child: banner),
              ],
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  const desktop = Size(1280, 800);
  const phone = Size(411, 914);

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget body,
    Size size,
  ) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(body);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(name));
  }

  testWidgets('desktop dashboard', (tester) async {
    await capture(
      tester,
      'screenshots/desktop-dashboard.png',
      _shell(DashboardScreen(snapshot: _snapshot, connected: true)),
      desktop,
    );
  });

  testWidgets('phone dashboard with an empty ad slot', (tester) async {
    await capture(
      tester,
      'screenshots/phone-dashboard.png',
      _shell(
        DashboardScreen(snapshot: _snapshot, connected: true),
        wide: false,
      ),
      phone,
    );
  });

  testWidgets('desktop node screen', (tester) async {
    await capture(
      tester,
      'screenshots/desktop-node.png',
      _shell(
        NodeScreen(
          baseUrl: 'http://127.0.0.1:3030',
          onSave: (_) async {},
          adUnitId: 'ca-app-pub-0000000000000000/0000000000',
          onSaveAdUnitId: (_) async {},
        ),
      ),
      desktop,
    );
  });

  testWidgets('desktop workers screen', (tester) async {
    await capture(
      tester,
      'screenshots/desktop-workers.png',
      _shell(const WorkersScreen(workers: _workers)),
      desktop,
    );
  });

  testWidgets('desktop activity screen', (tester) async {
    await capture(
      tester,
      'screenshots/desktop-activity.png',
      _shell(const LogScreen(entries: _log)),
      desktop,
    );
  });

  testWidgets('an empty ad slot really occupies no space', (tester) async {
    await tester.binding.setSurfaceSize(phone);
    await tester.pumpWidget(
      _shell(
        DashboardScreen(snapshot: _snapshot, connected: true),
        wide: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdBanner), findsOneWidget);
    // The shell stretches the slot to the full width, so only the height is
    // meaningful: zero height is zero space taken.
    expect(tester.getSize(find.byType(AdBanner)).height, 0);
    expect(find.text('Ad'), findsNothing);
    expect(find.textContaining('Connect an ad network'), findsNothing);
  });
}
