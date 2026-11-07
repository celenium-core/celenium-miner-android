import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'crash_log.dart';

/// AdMob identity of this app, mirrored by the `APPLICATION_ID` meta-data in
/// AndroidManifest.xml. The two must agree or every request is rejected.
const String kAdMobAppId = 'ca-app-pub-5168743842779308~5416336913';

/// Live banner unit ("banner_home") from the AdMob console.
const String kLiveBannerUnitId = 'ca-app-pub-5168743842779308/6314485619';

/// Google's fixed banner test unit. Debug builds always use this: tapping a
/// live ad while developing is what gets an AdMob account limited.
const String kTestBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';

/// Whether this build can show AdMob banners at all. The ad SDK is wired for
/// Android only; the desktop targets keep the same shell without ads.
bool get adsSupported => !kIsWeb && Platform.isAndroid;

/// The unit the slot requests. The id is compiled in, never user-editable:
/// release builds serve the live unit, debug builds Google's test unit.
String get bannerUnitId => kDebugMode ? kTestBannerUnitId : kLiveBannerUnitId;

/// Width to ask AdMob for, given the screen width.
///
/// The banner shares its row with the "Ad" badge and the close button, so a
/// fixed 320x50 unit does not fit a phone slot. Asking for the adaptive size
/// at exactly the leftover width is what keeps the ad inside the slot; the
/// figure is a little conservative so rounding never overflows the row.
double bannerAdWidth(double screenWidth) =>
    (screenWidth - 136).clamp(120.0, 400.0);

/// The in-flight SDK start, shared by every caller after the first.
Future<void>? _sdkStart;

/// Starts the AdMob SDK at most once, and never at the app's expense.
///
/// initialize() talks to Play Services; on a device where that fails (no
/// Play Services, a broken install, a revoked app id) an unhandled failure
/// would kill the whole process. Every failure is swallowed here instead:
/// the banner never appears, the rest of the app does not notice.
Future<void> ensureAdsReady() {
  if (!adsSupported) return Future<void>.value();
  final running = _sdkStart;
  if (running != null) return running;
  final started = _startSdk();
  _sdkStart = started;
  return started;
}

Future<void> _startSdk() async {
  try {
    await MobileAds.instance.initialize();
  } catch (error, stack) {
    recordCaughtError(error, stack: stack);
  }
}

