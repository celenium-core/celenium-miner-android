// Renders the Android shell in both shipped languages to PNG, so the two
// language versions can be inspected side by side. Not an assertion suite: the
// goldens are regenerated with --update-goldens and read back as images.
//
// The locale is supplied by the MaterialApp here, exactly as the root app does
// it, so what these pictures show is what the device draws: a phone whose
// language is Indonesian gets Indonesian, a phone set to English gets English.
import 'package:celenium_miner/l10n/l10n.dart';
import 'package:celenium_miner/main.dart';
import 'package:celenium_miner/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fonts.dart';

/// Phone-sized viewport: 360 x 733 logical pixels, the most common Android
/// shape, at 3x so the PNG is 1080 wide and readable without zooming.
void _phoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Locale locale, {AppLanguage language = AppLanguage.system}) {
  return MaterialApp(
    title: 'Celenium Miner',
    debugShowCheckedModeBanner: false,
    theme: buildCenTheme(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MinerHome(language: language, onLanguageChanged: (_) {}),
  );
}

/// Live counters never stop repainting, so pumpAndSettle would time out.
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// The whole visible app: routes, tab bar and any open sheet all live inside
/// the root overlay, which is why this and not MinerHome is captured.
final Finder _screen = find.byType(Overlay).first;

Future<void> _enterShell(WidgetTester tester, String enterLabel) async {
  await _settle(tester, frames: 32);
  await tester.tap(find.text(enterLabel));
  await _settle(tester);
}

Future<void> _openProfile(WidgetTester tester, String profileLabel) async {
  await tester.tap(find.text(profileLabel));
  await _settle(tester);
}

void main() {
  testWidgets('capture splash and mine tab in Indonesian', (tester) async {
    await loadCenFonts();
    SharedPreferences.setMockInitialValues({});
    _phoneViewport(tester);

    await tester.pumpWidget(_host(const Locale('id')));
    await _settle(tester, frames: 32);
    await expectLater(
      _screen,
      matchesGoldenFile('goldens/phone_splash_id.png'),
    );

    await _enterShell(tester, 'MASUK');
    await expectLater(_screen, matchesGoldenFile('goldens/phone_mine_id.png'));
  });

  testWidgets('capture the language sheet in Indonesian', (tester) async {
    await loadCenFonts();
    SharedPreferences.setMockInitialValues({});
    _phoneViewport(tester);

    await tester.pumpWidget(_host(const Locale('id')));
    await _enterShell(tester, 'MASUK');
    await _openProfile(tester, 'PROFIL');

    await expectLater(
      _screen,
      matchesGoldenFile('goldens/phone_profile_id.png'),
    );

    await tester.tap(find.text('Bahasa'));
    await _settle(tester);
    await expectLater(
      _screen,
      matchesGoldenFile('goldens/phone_language_sheet_id.png'),
    );
  });

  testWidgets('capture the language sheet in English', (tester) async {
    await loadCenFonts();
    SharedPreferences.setMockInitialValues({});
    _phoneViewport(tester);

    await tester.pumpWidget(
      _host(const Locale('en'), language: AppLanguage.english),
    );
    await _enterShell(tester, 'ENTER');
    await _openProfile(tester, 'PROFILE');

    await expectLater(
      _screen,
      matchesGoldenFile('goldens/phone_profile_en.png'),
    );

    await tester.tap(find.text('Language'));
    await _settle(tester);
    await expectLater(
      _screen,
      matchesGoldenFile('goldens/phone_language_sheet_en.png'),
    );
  });
}
