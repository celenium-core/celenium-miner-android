// The fonts the app ships, loaded into the test renderer so screenshots and
// goldens show the real typefaces instead of the fallback box font.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

/// Loads the four fonts the app uses, including the Material icon font.
///
/// Goldens do not get the icon font from the engine, so every `Icons.*` glyph
/// renders as an empty rectangle without the last load below. The path is the
/// copy bundled with the Flutter SDK this project builds against.
Future<void> loadCenFonts() async {
  await _loadFont('Cinzel', 'assets/fonts/Cinzel[wght].ttf');
  await _loadFont('Manrope', 'assets/fonts/Manrope.ttf');
  await _loadFont('JetBrains Mono', 'assets/fonts/JetBrainsMono[wght].ttf');
  await _loadFont(
    'MaterialIcons',
    '/home/dx401/flutter-install/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}
