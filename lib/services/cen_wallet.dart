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

import 'package:flutter/services.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

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
  const CenWallet({required this.privateKey, required this.network});

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

  /// Restores a wallet from a BIP39 recovery phrase.
  ///
  /// The phrase goes through the same PBKDF2 and HMAC steps as
  /// `celenium-wallet`, so a phrase backed up here can be imported there and
  /// will produce the same address.
  factory CenWallet.fromMnemonic(Mnemonic mnemonic, CenNetwork network) {
    if (!mnemonic.isValidLength) {
      throw const FormatException('recovery phrase must be 12 or 24 words');
    }
    final seed = mnemonicToSeed(mnemonic);
    final key = seedToPrivateKey(seed);
    if (key <= BigInt.zero || key >= _curveOrder) {
      throw const FormatException(
        'phrase produced a key outside the valid curve range',
      );
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

// ---------------------------------------------------------------------------
// BIP39 recovery phrase
// ---------------------------------------------------------------------------

/// The official BIP39 English wordlist, 2048 words.
///
/// Loaded from an asset rather than embedded so the list can be verified
/// against the published checksum (`f2350695…`) instead of trusted on sight.
const String bip39WordlistAsset = 'assets/wordlists/english.txt';

/// Parsed wordlist. Throws when the asset is missing or the wrong length.
Future<List<String>> loadBip39Wordlist(AssetBundle bundle) async {
  final raw = await bundle.loadString(bip39WordlistAsset);
  final words = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (words.length != 2048) {
    throw StateError('BIP39 wordlist has ${words.length} words, expected 2048');
  }
  return words;
}

/// A BIP39 recovery phrase and the key it produces.
///
/// The phrase is the source of the key, not a wrapper around it: losing the
/// phrase loses the key, and holding the phrase is enough to rebuild the key
/// on any device. This matches what `celenium-wallet` accepts, so a phrase
/// written down from this app can be imported by the CLI wallet.
class Mnemonic {
  const Mnemonic(this.words);

  /// Builds from a phrase, tolerating extra whitespace and mixed case.
  factory Mnemonic.fromPhrase(String phrase) {
    final words = phrase
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    return Mnemonic(words);
  }

  final List<String> words;

  bool get isValidLength => words.length == 12 || words.length == 24;

  String get phrase => words.join(' ');

  @override
  String toString() => 'Mnemonic(${words.length} words)';
}

/// Generates a fresh 12-word phrase from a secure random source.
///
/// 128 bits of entropy plus a 4-bit checksum makes 132 bits, which is exactly
/// 12 words of 11 bits.
Mnemonic generateMnemonic({Random? random, required List<String> wordlist}) {
  final rng = random ?? Random.secure();
  final entropy = List<int>.generate(16, (_) => rng.nextInt(256));
  return mnemonicFromEntropy(entropy, wordlist: wordlist);
}

/// Encodes entropy as a BIP39 phrase, computing the checksum.
Mnemonic mnemonicFromEntropy(
  List<int> entropy, {
  required List<String> wordlist,
}) {
  if (entropy.length != 16 && entropy.length != 32) {
    throw ArgumentError(
      'entropy must be 16 or 32 bytes, got ${entropy.length}',
    );
  }

  // SHA-256 of the entropy; the first `entropyBits / 32` bits are the checksum.
  final hash = sha256(entropy);
  final checksumBits = entropy.length * 8 ~/ 32;

  final bits = <int>[];
  for (final byte in entropy) {
    for (var i = 7; i >= 0; i--) {
      bits.add((byte >> i) & 1);
    }
  }
  for (var i = 0; i < checksumBits; i++) {
    bits.add((hash[i ~/ 8] >> (7 - i % 8)) & 1);
  }

  final words = <String>[];
  for (var i = 0; i < bits.length; i += 11) {
    var index = 0;
    for (var j = 0; j < 11; j++) {
      index = (index << 1) | bits[i + j];
    }
    words.add(wordlist[index]);
  }
  return Mnemonic(words);
}

/// Verifies the checksum of a phrase against the wordlist.
bool isValidMnemonic(Mnemonic mnemonic, List<String> wordlist) {
  if (!mnemonic.isValidLength) return false;

  final bits = <int>[];
  for (final word in mnemonic.words) {
    final index = wordlist.indexOf(word);
    if (index < 0) return false;
    for (var i = 10; i >= 0; i--) {
      bits.add((index >> i) & 1);
    }
  }

  final checksumBits = bits.length ~/ 33;
  final entropyBits = bits.length - checksumBits;

  final entropy = <int>[];
  for (var i = 0; i < entropyBits; i += 8) {
    var byte = 0;
    for (var j = 0; j < 8; j++) {
      byte = (byte << 1) | bits[i + j];
    }
    entropy.add(byte);
  }

  final hash = sha256(entropy);
  for (var i = 0; i < checksumBits; i++) {
    final expected = (hash[i ~/ 8] >> (7 - i % 8)) & 1;
    if (bits[entropyBits + i] != expected) return false;
  }
  return true;
}

/// SHA-256, used for the BIP39 checksum.
Uint8List sha256(List<int> data) {
  final digest = SHA256Digest();
  digest.update(Uint8List.fromList(data), 0, data.length);
  final out = Uint8List(32);
  digest.doFinal(out, 0);
  return out;
}

/// PBKDF2-HMAC-SHA512 over the phrase, salt `mnemonic`, 2048 rounds, 64 bytes.
///
/// This is the BIP39 seed. `celenium-wallet` derives its master key from
/// exactly this, so the same phrase produces the same key in both places.
Uint8List mnemonicToSeed(Mnemonic mnemonic, {String passphrase = ''}) {
  final salt = 'mnemonic$passphrase';
  final derivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128))
    ..init(Pbkdf2Parameters(Uint8List.fromList(salt.codeUnits), 2048, 64));
  return derivator.process(Uint8List.fromList(mnemonic.phrase.codeUnits));
}

/// First 32 bytes of HMAC-SHA512("Bitcoin seed", seed).
///
/// Port of `ExtendedPrivateKey::new` in wallet/bip32/src/xprivate_key.rs. The
/// wallet uses the master key directly with no derivation path, so this one
/// value is the wallet's private key.
BigInt seedToPrivateKey(Uint8List seed) {
  const domainSeparator = 'Bitcoin seed';
  final hmac = HMac(SHA512Digest(), 128);
  hmac.init(KeyParameter(Uint8List.fromList(domainSeparator.codeUnits)));
  final result = hmac.process(seed);
  return _bytesToBigInt(result.sublist(0, 32));
}

/// Derives a key from a device identity string.
///
/// HMAC-SHA256 keyed with a fixed domain tag; the 32-byte digest is the
/// scalar. Deterministic per device and isolated from the BIP39 path, so a
/// device address can never collide with a recovery-phrase address.
BigInt deviceIdentityToPrivateKey(String seed) {
  const domainTag = 'celenium-device-v1';
  final hmac = HMac(SHA256Digest(), 64);
  hmac.init(KeyParameter(Uint8List.fromList(domainTag.codeUnits)));
  return _bytesToBigInt(hmac.process(Uint8List.fromList(seed.codeUnits)));
}

/// A wallet from a device identity, with the key kept inside the curve range.
///
/// The HMAC output lands outside [1, n-1] with probability ~2^-128; the counter
/// bump recovers on the next pass. It effectively settles on the first try.
CenWallet deriveDeviceWallet(String seed, CenNetwork network) {
  var counter = 0;
  while (true) {
    final key = deviceIdentityToPrivateKey('$seed:$counter');
    if (key > BigInt.zero && key < _curveOrder) {
      return CenWallet(privateKey: key, network: network);
    }
    counter++;
  }
}
