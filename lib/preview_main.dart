// Preview entrypoint: renders the mining screen with a hard-coded fixture so
// the visual result can be captured in a real browser (correct variable-font
// rendering) without a live bridge. Build with:
//   flutter build web -t lib/preview_main.dart --release
import 'package:celenium_miner/models/bridge.dart';
import 'package:celenium_miner/screens/mining_screen.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:flutter/material.dart';

MinerSnapshot _fixture() {
  const wallet = 'cen69sim:qabc';
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

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildCenTheme(),
      home: Scaffold(
        body: MiningScreen(
          snapshot: _fixture(),
          nodeAddress: '127.0.0.1:26510',
          onOpenWorkers: () {},
          onOpenActivity: () {},
          onConnectNode: () {},
        ),
      ),
    ),
  );
}