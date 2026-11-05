import 'package:celenium_miner/services/ad_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('banner ad sizing', () {
    test('asks for the width the slot actually leaves free', () {
      // A 360dp phone keeps badge and close button in the row, so the ad is
      // narrower than a fixed 320x50 unit would need.
      expect(bannerAdWidth(360), closeTo(224, 0.01));
      expect(bannerAdWidth(411), closeTo(275, 0.01));
    });

    test('never asks for more than a banner needs', () {
      // On a wide window the ad stops growing instead of stretching across.
      expect(bannerAdWidth(1200), 400);
    });

    test('never asks for a width AdMob would refuse', () {
      expect(bannerAdWidth(200), 120);
      expect(bannerAdWidth(0), 120);
    });
  });

  group('unit id resolution', () {
    test('a typed id always wins', () {
      expect(resolveBannerUnitId('ca-app-pub-1/2'), 'ca-app-pub-1/2');
    });

    test('without an override the build decides the unit', () {
      // Tests run in debug, where serving live ads gets an account limited.
      expect(resolveBannerUnitId(null), kTestBannerUnitId);
      expect(kLiveBannerUnitId, startsWith('ca-app-pub-'));
      expect(kTestBannerUnitId, startsWith('ca-app-pub-'));
    });
  });
}
