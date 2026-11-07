// The fonts the app ships, loaded into the test renderer so screenshots and
// goldens show the real typefaces instead of the fallback box font.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads every weight in [paths] under one family, so the engine can match the
/// theme's regular/bold styles. All weights must ride in a single [FontLoader]:
/// separate `load()` calls for the same family overwrite each other.
Future<void> _loadFonts(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Loads the five fonts the app uses, including the Material icon font.
///
/// Goldens do not get the icon font from the engine, so every `Icons.*` glyph
/// renders as an empty rectangle without the last load below. The path is the
/// copy bundled with the Flutter SDK this project builds against.
///
/// Cinzel and JetBrains Mono ship as *variable* fonts (`[wght]` axis) for the
/// device. The flutter_test software renderer shows variable fonts as tofu, so
/// tests load static instances (weights 400/700) generated from those files
/// instead — produced by `scripts/make_static_fonts.py`.
Future<void> loadCenFonts() async {
  await _loadFonts('Cinzel', [
    'test/support/fonts/Cinzel-Regular.ttf',
    'test/support/fonts/Cinzel-Bold.ttf',
  ]);
  await _loadFonts('Manrope', ['assets/fonts/Manrope.ttf']);
  await _loadFonts('JetBrains Mono', [
    'test/support/fonts/JetBrainsMono-Regular.ttf',
    'test/support/fonts/JetBrainsMono-Bold.ttf',
  ]);
  await _loadFonts('Press Start 2P', ['assets/fonts/PressStart2P-Regular.ttf']);
  await _loadFonts('MaterialIcons', [
    '/home/dx401/flutter-install/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}


/// The logo mark ships as PNG assets, and the test asset bundle resolves them
/// asynchronously — inside `testWidgets`' FakeAsync zone that decode never
/// completes, so a golden would show a blank circle where the logo sits. Prime
/// the image cache after the host is pumped but before the golden is captured.
Future<void> precacheMarkImages(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in const [
      'assets/logo/cen_mark_for_dark.png',
      'assets/logo/cen_mark_for_light.png',
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
}
