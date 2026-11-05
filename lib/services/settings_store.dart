import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// Persisted app settings.
///
/// Only the bridge address, the polling interval, the ad slot, and the chosen
/// language are stored. No secrets: the app never holds a private key, and it
/// has nothing to sign.
class SettingsStore {
  static const String _keyBaseUrl = 'bridge_base_url';
  static const String _keyInterval = 'poll_interval_ms';
  static const String _keyAdUnitId = 'ad_unit_id';
  static const String _keyAdDismissed = 'ad_dismissed';

  /// Public so tests can seed the stored language instead of hard-coding the
  /// key, which would silently stop testing anything if the key were renamed.
  static const String languageKey = 'language_code';

  static const String defaultBaseUrl = 'http://127.0.0.1:3030';
  static const int defaultIntervalMs = 2000;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String> baseUrl() async {
    final prefs = await _prefs;
    return prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_keyBaseUrl, value);
  }

  Future<int> intervalMs() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyInterval) ?? defaultIntervalMs;
  }

  Future<void> setIntervalMs(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyInterval, value);
  }

  /// The banner ad unit id, or null when none is configured.
  ///
  /// Empty and whitespace-only values are normalised to null so an accidental
  /// blank save cannot leave a slot that reserves space and shows nothing.
  Future<String?> adUnitId() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyAdUnitId)?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<void> setAdUnitId(String? value) async {
    final prefs = await _prefs;
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_keyAdUnitId);
      return;
    }
    await prefs.setString(_keyAdUnitId, trimmed);
  }

  /// Whether the user closed the banner. Persisted, because a close button
  /// that forgets is a dead control (R-26).
  Future<bool> adDismissed() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyAdDismissed) ?? false;
  }

  Future<void> setAdDismissed(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyAdDismissed, value);
  }

  /// The chosen interface language. Unknown stored values fall back to
  /// [AppLanguage.system], so a value written by a newer build cannot break
  /// startup on an older one.
  Future<AppLanguage> language() async {
    final prefs = await _prefs;
    return AppLanguage.fromCode(prefs.getString(languageKey));
  }

  Future<void> setLanguage(AppLanguage value) async {
    final prefs = await _prefs;
    await prefs.setString(languageKey, value.code);
  }
}
