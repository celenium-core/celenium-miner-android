import 'package:celenium_miner/services/cen_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';

/// Vectors copied from crypto/addresses/src/lib.rs in celenium-build. If Dart
/// and Rust ever disagree on an address, funds go to the wrong place, so these
/// are the contract.
void main() {
  group('bech32 encoding matches the Rust implementation', () {
    test('zero payload, PubKey version, testnet prefix', () {
      final data5 = conv8to5([versionPubKey, ...List.filled(32, 0)]);
      expect(
        bech32Encode('cen69test', data5),
        'cen69test:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqz0ef0nda',
      );
    });

    test('zero payload, PubKeyECDSA version, testnet prefix', () {
      final data5 = conv8to5([1, ...List.filled(33, 0)]);
      expect(
        bech32Encode('cen69test', data5),
        'cen69test:qyqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqg52hclvv',
      );
    });

    test('known payload, PubKey version, mainnet prefix', () {
      // The payload from the Rust test, byte for byte.
      final payload = [
        0x5f, 0xff, 0x3c, 0x4d, 0xa1, 0x8f, 0x45, 0xad, //
        0xcd, 0xd4, 0x99, 0xe4, 0x46, 0x11, 0xe9, 0xff, //
        0xf1, 0x48, 0xba, 0x69, 0xdb, 0x3c, 0x4e, 0xa2, //
        0xdd, 0xd9, 0x55, 0xfc, 0x46, 0xa5, 0x95, 0x22, //
      ];
      final data5 = conv8to5([versionPubKey, ...payload]);
      expect(
        bech32Encode('cen69', data5),
        'cen69:qp0l70zd5x85ttwd6jv7g3s3a8llzj96d8dncn4zmhv4tlzx5k2jy02uakv06',
      );
    });

    test('conv8to5 output length for a 33-byte input', () {
      // 33 bytes is not a multiple of 5, so the Rust version pads to 53 groups.
      expect(conv8to5(List.filled(33, 0)).length, 53);
      // 35 bytes is a multiple of 5, so no padding.
      expect(conv8to5(List.filled(35, 0)).length, 56);
    });
  });

  group('key generation', () {
    test('a generated wallet produces a valid-looking address', () {
      final wallet = generateWallet(CenNetwork.simnet);
      expect(wallet.address.startsWith('cen69sim:'), isTrue);
      // 53 payload groups + 8 checksum groups, so a fixed length per prefix.
      expect(wallet.address.length, 'cen69sim:'.length + 61);
    });

    test('the same key always derives the same address', () {
      final wallet = generateWallet(CenNetwork.simnet);
      final restored = CenWallet.fromHex(wallet.privateKeyHex, CenNetwork.simnet);
      expect(restored.address, wallet.address);
      expect(restored.privateKeyHex, wallet.privateKeyHex);
    });

    test('private key stays inside the valid curve range', () {
      for (var i = 0; i < 20; i++) {
        final wallet = generateWallet(CenNetwork.simnet);
        expect(wallet.privateKey > BigInt.zero, isTrue);
        expect(wallet.privateKey < ECCurve_secp256k1().n, isTrue);
      }
    });

    test('different keys produce different addresses', () {
      final a = generateWallet(CenNetwork.simnet);
      final b = generateWallet(CenNetwork.simnet);
      expect(a.address, isNot(b.address));
    });

    test('an out-of-range key is rejected rather than silently used', () {
      expect(
        () => CenWallet.fromHex('0' * 64, CenNetwork.simnet),
        throwsA(isA<FormatException>()),
      );
    });

    test('a hex key with 0x prefix is accepted', () {
      final wallet = generateWallet(CenNetwork.simnet);
      final restored = CenWallet.fromHex(
        '0x${wallet.privateKeyHex}',
        CenNetwork.simnet,
      );
      expect(restored.address, wallet.address);
    });
  });

  group('address format', () {
    test('x-only public key is 32 bytes', () {
      final wallet = generateWallet(CenNetwork.simnet);
      expect(wallet.xOnlyPublicKey.length, 32);
    });

    test('each network uses its own prefix', () {
      for (final network in CenNetwork.values) {
        final wallet = generateWallet(network);
        expect(wallet.address.startsWith('${network.prefix}:'), isTrue);
      }
    });
  });
}
