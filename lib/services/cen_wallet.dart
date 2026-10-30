/// CEN address generation, matching the Rust implementation exactly.
///
/// The address is `bech32(prefix, conv8to5([version] + payload))` where the
/// payload for a PubKey address is the 32-byte x-only secp256k1 public key.
/// That is the whole derivation: no hashing step, the key is the payload.
///
/// Every routine here is verified against the Rust test vectors in
/// crypto/addresses/src/lib.rs, so a Dart address and a Rust address for the
/// same key are guaranteed to agree.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/ecc/curves/secp256k1.dart';

/// Network prefixes. Simnet is the default because that is the only network
/// with a running node today.
enum CenNetwork {
  simnet('cen69sim'),
  testnet10('cen69test'),
  mainnet('cen69');

  const CenNetwork(this.prefix);
  final String prefix;
}

/// bech32 charset, SIPA's original, not the bech32m variant.
const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

/// secp256k1 group order. A private key must be in [1, n-1].
final BigInt _curveOrder = ECCurve_secp256k1().n;

/// Port of `conv8to5` in crypto/addresses/src/bech32.rs.
///
/// Packs 8-bit bytes into 5-bit groups, big-endian within each byte. The Rust
/// version pads the final group with zero bits when the input length is not a
/// multiple of 5, which is what makes a 33-byte input produce 53 groups.
List<int> conv8to5(List<int> data) {
  final padding = data.length % 5 == 0 ? 0 : 1;
  final out = List<int>.filled(data.length * 8 ~/ 5 + padding, 0);
  var idx = 0;
  var buff = 0;
  var bits = 0;
  for (final byte in data) {
    buff = (buff << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out[idx++] = (buff >> bits) & 0x1f;
      buff &= (1 << bits) - 1;
    }
  }
  if (bits > 0 && idx < out.length) {
    out[idx] = (buff << (5 - bits)) & 0x1f;
  }
  return out;
}

/// The 40-bit polymod from crypto/addresses/src/bech32.rs.
///
/// This is NOT the standard bech32 polymod. CEN uses the 40-bit bech32m-style
/// variant with these five generator constants, and the function itself ends
/// with `c ^ 1`.
const List<int> _generators = [
  0x98f2bc8e61,
  0x79b76d99e2,
  0xf33e5fb3c4,
  0xae2eabe2a8,
  0x1e4f43e470,
];

int _polymod(List<int> values) {
  var c = 1;
  for (final d in values) {
    final c0 = c >> 35;
    c = ((c & 0x07ffffffff) << 5) ^ d;
    for (var i = 0; i < 5; i++) {
      if (((c0 >> i) & 1) != 0) c ^= _generators[i];
    }
  }
  return c ^ 1;
}

/// The 8 five-bit checksum groups.
///
/// Rust: `polymod(prefix.chain([0]).chain(payload).chain([0u8; 8]))`, then the
/// low 5 bytes of that u64 big-endian go through conv8to5, which yields 8
/// groups. Standard bech32 uses 6 groups and no trailing 8 zeros, so a stock
/// bech32 library produces the wrong checksum here.
List<int> _checksumGroups(List<int> payload5, String prefix) {
  final prefix5 = prefix.codeUnits.map((c) => c & 0x1f).toList();
  final values = [...prefix5, 0, ...payload5, 0, 0, 0, 0, 0, 0, 0, 0];
  final checksum = _polymod(values);

  final bytes = List<int>.filled(8, 0);
  var v = checksum;
  for (var i = 7; i >= 0; i--) {
    bytes[i] = v & 0xff;
    v >>= 8;
  }
  return conv8to5(bytes.sublist(3));
}

/// Encodes `prefix:data` in CEN's bech32 variant.
String bech32Encode(String prefix, List<int> data5) {
  final combined = [...data5, ..._checksumGroups(data5, prefix)];
  return '$prefix:${combined.map((v) => _charset[v]).join()}';
}

/// Version byte for a PayToPubKey address. Always 0 in CEN.
const int versionPubKey = 0;

/// A generated wallet: the key and the address derived from it.
class CenWallet {
  const CenWallet({
    required this.privateKey,
    required this.network,
  });

  final BigInt privateKey;
  final CenNetwork network;

  /// 32-byte big-endian private key.
  Uint8List get privateKeyBytes {
    final hex = privateKey.toRadixString(16).padLeft(64, '0');
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  String get privateKeyHex => privateKey.toRadixString(16).padLeft(64, '0');

  /// The x-only public key, which is the address payload.
  ///
  /// secp256k1 point multiplication then the x coordinate only, dropping the
  /// parity byte. That is what Kaspa-style addresses carry.
  Uint8List get xOnlyPublicKey {
    final domain = ECCurve_secp256k1();
    final point = domain.G * privateKey;
    if (point == null) {
      throw StateError('public key derivation failed for this private key');
    }
    final x = point.x!.toBigInteger()!;
    return _bigIntToBytes32(x);
  }

  String get address {
    final payload = xOnlyPublicKey;
    final data5 = conv8to5([versionPubKey, ...payload]);
    return bech32Encode(network.prefix, data5);
  }

  /// Restores a wallet from a hex private key.
  factory CenWallet.fromHex(String hex, CenNetwork network) {
    final trimmed = hex.trim().toLowerCase().replaceFirst('0x', '');
    final key = BigInt.parse(trimmed, radix: 16);
    if (key <= BigInt.zero || key >= _curveOrder) {
      throw FormatException('private key is outside the valid curve range');
    }
    return CenWallet(privateKey: key, network: network);
  }
}

Uint8List _bigIntToBytes32(BigInt value) {
  final hex = value.toRadixString(16).padLeft(64, '0');
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Generates a fresh wallet using a cryptographically secure random source.
CenWallet generateWallet(CenNetwork network, {Random? random}) {
  final rng = random ?? Random.secure();
  while (true) {
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final key = _bytesToBigInt(bytes);
    if (key > BigInt.zero && key < _curveOrder) {
      return CenWallet(privateKey: key, network: network);
    }
  }
}

BigInt _bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}
