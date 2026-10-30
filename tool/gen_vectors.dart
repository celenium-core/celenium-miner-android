import 'package:cenium_miner/services/cen_wallet.dart';

/// Prints the address strings the Rust test vectors should expect after the
/// prefix rename. The checksum depends on the prefix, so the expected values
/// cannot be edited by hand; they are computed here and then pasted into
/// crypto/addresses/src/lib.rs.
void main() {
  final known = [
    0x5f, 0xff, 0x3c, 0x4d, 0xa1, 0x8f, 0x45, 0xad, //
    0xcd, 0xd4, 0x99, 0xe4, 0x46, 0x11, 0xe9, 0xff, //
    0xf1, 0x48, 0xba, 0x69, 0xdb, 0x3c, 0x4e, 0xa2, //
    0xdd, 0xd9, 0x55, 0xfc, 0x46, 0xa5, 0x95, 0x22, //
  ];
  final ecdsaKnown = [
    0xba, 0x01, 0xfc, 0x5f, 0x4e, 0x9d, 0x98, 0x79, //
    0x59, 0x9c, 0x69, 0xa3, 0xda, 0xfd, 0xb8, 0x35, //
    0xa7, 0x25, 0x5e, 0x5f, 0x2e, 0x93, 0x4e, 0x93, //
    0x22, 0xec, 0xd3, 0xaf, 0x19, 0x0a, 0xb0, 0xf6, //
    0x0e, //
  ];

  String enc(String prefix, int version, List<int> payload) =>
      bech32Encode(prefix, conv8to5([version, ...payload]));

  print('testnet  PubKey      zeros : ${enc('cen69test', 0, List.filled(32, 0))}');
  print('testnet  PubKeyECDSA zeros : ${enc('cen69test', 1, List.filled(33, 0))}');
  print('testnet  PubKeyECDSA known : ${enc('cen69test', 1, ecdsaKnown)}');
  print('mainnet  PubKey      zeros : ${enc('cen69', 0, List.filled(32, 0))}');
  print('mainnet  PubKey      known : ${enc('cen69', 0, known)}');
}
