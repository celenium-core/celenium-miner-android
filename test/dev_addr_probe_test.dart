// Temporary probe — derives fixed test keys and the premine address so the
// live send/receive test can be driven headlessly against the bridge HTTP API.
// Uses the app's own verified derivation (crypto/addresses test vectors), so
// the addresses are guaranteed to match what the node/bridge expect.
import 'package:celenium_miner/services/cen_wallet.dart';

void main() {
  // Fixed throwaway simnet keys — never use key 1/2 anywhere but a local test.
  const keyAHex = '0000000000000000000000000000000000000000000000000000000000000001';
  const keyBHex = '0000000000000000000000000000000000000000000000000000000000000002';

  final a = CenWallet.fromHex(keyAHex, CenNetwork.simnet);
  final b = CenWallet.fromHex(keyBHex, CenNetwork.simnet);

  // DEV premine pubkey from consensus/core/src/config/genesis.rs.
  const premineDevPubkey = <int>[
    0x63, 0xa2, 0xcd, 0x0e, 0x5f, 0xc8, 0x32, 0x0e, 0x93, 0x99, 0xfd, 0x25,
    0x08, 0xa9, 0xf3, 0xda, 0x45, 0xdb, 0x94, 0x01, 0x9f, 0x61, 0xa8, 0x90,
    0xd3, 0xea, 0x42, 0xef, 0x32, 0x3c, 0xf9, 0xe6,
  ];
  final premineDevAddr = bech32Encode(
    CenNetwork.simnet.prefix,
    conv8to5([versionPubKey, ...premineDevPubkey]),
  );

  print('A_PRIVHEX=${a.privateKeyHex}');
  print('A_ADDR=${a.address}');
  print('B_PRIVHEX=${b.privateKeyHex}');
  print('B_ADDR=${b.address}');
  print('PREMINE_DEV_ADDR=$premineDevAddr');
}