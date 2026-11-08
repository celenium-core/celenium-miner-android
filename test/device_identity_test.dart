import 'package:celenium_miner/services/cen_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const seedA = 'android-id:9774d56d682e549c';
  const seedB = 'ip:192.168.1.50';

  test('device identity derivation is deterministic', () {
    final k1 = deviceIdentityToPrivateKey(seedA);
    final k2 = deviceIdentityToPrivateKey(seedA);
    expect(k1, equals(k2));
    expect(
      deviceIdentityToPrivateKey(seedA),
      isNot(equals(deviceIdentityToPrivateKey(seedB))),
    );
  });

  test('deriveDeviceWallet yields a stable valid mainnet address', () {
    final w1 = deriveDeviceWallet(seedA, CenNetwork.mainnet);
    final w2 = deriveDeviceWallet(seedA, CenNetwork.mainnet);
    expect(w1.address, equals(w2.address));
    expect(w1.address, startsWith('cen69:'));
    expect(w1.address.length, greaterThan('cen69:'.length));
  });

  test('different seeds yield different addresses', () {
    final a = deriveDeviceWallet(seedA, CenNetwork.mainnet).address;
    final b = deriveDeviceWallet(seedB, CenNetwork.mainnet).address;
    expect(a, isNot(equals(b)));
  });
}