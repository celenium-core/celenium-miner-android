// Standalone address derivation — pure Dart + pointycastle, NO Flutter import,
// so it runs under `dart run`. Mirrors cen_wallet.dart's CenWallet.fromHex path
// exactly (secp256k1 G*k -> x-only pubkey -> CEN bech32 with version 0).
import 'package:pointycastle/ecc/curves/secp256k1.dart';

const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

List<int> conv8to5(List<int> data) {
  final padding = data.length % 5 == 0 ? 0 : 1;
  final out = List<int>.filled(data.length * 8 ~/ 5 + padding, 0);
  var idx = 0, buff = 0, bits = 0;
  for (final byte in data) {
    buff = (buff << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out[idx++] = (buff >> bits) & 0x1f;
      buff &= (1 << bits) - 1;
    }
  }
  if (bits > 0 && idx < out.length) out[idx] = (buff << (5 - bits)) & 0x1f;
  return out;
}

const List<int> _generators = [0x98f2bc8e61, 0x79b76d99e2, 0xf33e5fb3c4, 0xae2eabe2a8, 0x1e4f43e470];

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

String bech32Encode(String prefix, List<int> data5) {
  final combined = [...data5, ..._checksumGroups(data5, prefix)];
  return '$prefix:${combined.map((v) => _charset[v]).join()}';
}

List<int> bigIntToBytes32(BigInt value) {
  final hex = value.toRadixString(16).padLeft(64, '0');
  return List<int>.generate(32, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}

String deriveFromPriv(String privHex, String prefix) {
  final key = BigInt.parse(privHex, radix: 16);
  final domain = ECCurve_secp256k1();
  final point = domain.G * key;
  final x = point!.x!.toBigInteger()!;
  return bech32Encode(prefix, conv8to5([0, ...bigIntToBytes32(x)]));
}

String deriveFromXonly(String xHex, String prefix) {
  final x = BigInt.parse(xHex, radix: 16);
  return bech32Encode(prefix, conv8to5([0, ...bigIntToBytes32(x)]));
}

void main() {
  final a = deriveFromPriv('0000000000000000000000000000000000000000000000000000000000000001', 'cen69sim');
  final b = deriveFromPriv('0000000000000000000000000000000000000000000000000000000000000002', 'cen69sim');
  final premine = deriveFromXonly('63a2cd0e5fc8320e9399fd2508a9f3da45db94019f61a890d3ea42ef323cf9e6', 'cen69sim');
  print('A_PRIVHEX=0000000000000000000000000000000000000000000000000000000000000001');
  print('A_ADDR=$a');
  print('B_PRIVHEX=0000000000000000000000000000000000000000000000000000000000000002');
  print('B_ADDR=$b');
  print('PREMINE_DEV_ADDR=$premine');
}