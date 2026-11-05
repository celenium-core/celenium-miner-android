/// Translations, and the one place screens look them up.
///
/// Two locales ship: English and Indonesian. The generated class is
/// `AppLocalizations`, built by `flutter gen-l10n` from `lib/l10n/app_*.arb`
/// on every build, so it is never edited by hand.
library;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The strings for the locale in context.
///
/// The app always installs the delegates, so in the running app this is just a
/// lookup. The English fallback covers the two cases where no delegate is
/// installed: widget tests that wrap a screen in a bare `MaterialApp`, and the
/// golden screenshot harness. Neither should have to know about locales, and
/// neither should crash because of them.
AppLocalizations l10nOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

/// Selectable language. `system` follows the phone's own setting.
enum AppLanguage {
  system(null, 'System'),
  english(Locale('en'), 'English'),
  indonesian(Locale('id'), 'Bahasa Indonesia');

  const AppLanguage(this.locale, this.label);

  /// Null for [system]: no locale is forced and the platform decides.
  final Locale? locale;

  /// The language's name in its own language, which is what a picker should
  /// show: someone looking for Indonesian reads "Bahasa Indonesia", not
  /// "Indonesian".
  final String label;

  /// Parses the persisted value. Unknown values fall back to [system] rather
  /// than throwing, so a settings file from a newer build cannot break startup.
  static AppLanguage fromCode(String? code) {
    for (final language in AppLanguage.values) {
      if (language.name == code) return language;
    }
    return AppLanguage.system;
  }

  String get code => name;
}
