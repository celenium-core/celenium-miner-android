import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for the recovery phrase.
///
/// The phrase is the key. It goes in the platform keystore (Android Keystore,
/// iOS Keychain, libsecret on Linux) and never in SharedPreferences, which is
/// world-readable on a rooted device.
///
/// Two separate values are kept: the phrase itself, and whether the user has
/// confirmed writing it down. They are separate so the "you have not backed
/// up yet" warning can clear without the app having to reveal the phrase
/// again.
class Keystore {
  Keystore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyPhrase = 'cen_recovery_phrase';
  static const _keyBackedUp = 'cen_recovery_backed_up';

  Future<String?> readPhrase() async {
    final value = await _storage.read(key: _keyPhrase);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> savePhrase(String phrase) async {
    await _storage.write(key: _keyPhrase, value: phrase.trim());
  }

  Future<void> deletePhrase() async {
    await _storage.delete(key: _keyPhrase);
    await _storage.delete(key: _keyBackedUp);
  }

  Future<bool> hasBackedUp() async {
    return await _storage.read(key: _keyBackedUp) == 'true';
  }

  Future<void> setBackedUp(bool value) async {
    await _storage.write(key: _keyBackedUp, value: value ? 'true' : 'false');
  }
}
