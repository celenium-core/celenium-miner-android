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
    final value = await _safeRead(_keyPhrase);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// Reads one entry, treating an undecryptable one as absent.
  ///
  /// Android's Auto Backup restores this app's encrypted blob after a
  /// reinstall while the Keystore master key stays behind, so every read
  /// then dies with BadPaddingException (BAD_DECRYPT) forever — the miner
  /// can never start and the wallet can never unlock. Instead of crashing,
  /// drop the dead ciphertext and report absence: the engine regenerates a
  /// fresh wallet, and a user who still has the words re-imports them on
  /// the backup screen.
  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception {
      // The unreadable entry must go, or writes land next to it and the
      // screen keeps failing on every future boot. Best effort: absence is
      // the honest answer even when the delete itself is refused.
      try {
        await _storage.delete(key: key);
      } on Exception {
        // Fall through: a stuck entry degrades to "prompt re-import".
      }
      return null;
    }
  }

  Future<void> savePhrase(String phrase) async {
    await _storage.write(key: _keyPhrase, value: phrase.trim());
  }

  Future<void> deletePhrase() async {
    await _storage.delete(key: _keyPhrase);
    await _storage.delete(key: _keyBackedUp);
  }

  Future<bool> hasBackedUp() async {
    return await _safeRead(_keyBackedUp) == 'true';
  }

  Future<void> setBackedUp(bool value) async {
    await _storage.write(key: _keyBackedUp, value: value ? 'true' : 'false');
  }
}
