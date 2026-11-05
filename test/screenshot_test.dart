// Renders the desktop mining layout to PNG so the visual result can be
// inspected. This is not an assertion suite: the golden files are regenerated
// on demand with --update-goldens and read back via vision_analyze.
import 'package:celenium_miner/models/bridge.dart';
import 'package:celenium_miner/screens/mining_screen.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:celenium_miner/theme/palette.dart';
import 'package:celenium_miner/theme/typography.dart';
import 'package:celenium_miner/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fonts.dart';

MinerSnapshot snapshotWith({String wallet = 'cen69sim:qabc'}) {
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
      'workers': [
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
      ],
      'bridgeUptime': 7200,
    }),
  );
}

Widget _host(MinerSnapshot snapshot) {
  return MaterialApp(
    theme: buildCenTheme(),
    debugShowCheckedModeBanner: false,
    home: _Shell(snapshot: snapshot),
  );
}

/// The real desktop shell: a nav rail carrying the brand and the three tabs,
/// wrapped around the mining screen. Rendered here so the screenshot proves
/// the navigation menu is present, not just the screen body.
class _Shell extends StatelessWidget {
  const _Shell({required this.snapshot});

  final MinerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            backgroundColor: Palette.field,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            leading: Padding(
              padding: const EdgeInsets.only(top: Palette.lg, bottom: Palette.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Palette.cream,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: BrandMark(size: 28)),
                  ),
                  const SizedBox(height: Palette.sm),
                  Text(
                    'CELENIUM',
                    style: TextStyle(
                      fontFamily: TypeScale.displayFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: Palette.cream,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: Palette.lg),
              child: Text(
                'v1.0.0',
                style: TypeScale.monoMuted(context, size: 10),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.bolt_outlined),
                label: Text('Mine'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: Text('Wallet'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                label: Text('Profile'),
              ),
            ],
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: Palette.slateLight,
          ),
          Expanded(
            child: SafeArea(
              child: MiningScreen(
                snapshot: snapshot,
                nodeAddress: '127.0.0.1:26510',
                onOpenWorkers: () {},
                onOpenActivity: () {},
                onConnectNode: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpDesktop(WidgetTester tester, MinerSnapshot snapshot) async {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(snapshot));
  // A handful of frames lets entrance transitions settle; repeating live
  // indicators mean pumpAndSettle never returns.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('capture desktop connected mining layout', (tester) async {
    await loadCenFonts();
    await _pumpDesktop(tester, snapshotWith());
    await expectLater(
      find.byType(_Shell),
      matchesGoldenFile('goldens/mining_desktop_connected.png'),
    );
  });

  testWidgets('capture desktop empty mining layout', (tester) async {
    await loadCenFonts();
    await _pumpDesktop(tester, const MinerSnapshot());
    await expectLater(
      find.byType(_Shell),
      matchesGoldenFile('goldens/mining_desktop_empty.png'),
    );
  });
}