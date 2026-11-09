// Corrupt-secure-storage resilience (the 04:15 BadPaddingException report).
//
// Android's Auto Backup hands this app its EncryptedSharedPreferences blob
// back after a reinstall, but the Keystore master key never travels with it,
// so every read dies with PlatformException(BAD_DECRYPT). Before the fix the
// engine's wallet resolution kept throwing and the app looked dead on boot.
// The real [Keystore] must degrade that ciphertext to absence — and clear the
// dead entry so the next regeneration (or a user re-import) starts clean.
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celenium_miner/services/keystore.dart';

/// Storage whose ciphertext no longer matches the platform key: read always
/// throws the exact platform error from the field report, delete is recorded.
class _CorruptStorage extends FlutterSecureStorage {
  final List<String> deletedKeys = [];

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: 'bad_decrypt',
      message: 'error:1e000065:OPENSSL_internal:BAD_DECRYPT',
    );
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletedKeys.add(key);
  }
}

/// In-memory storage for the happy path: values land in a map, read reports
/// them back, so the wrapper's ordinary round-trip stays covered as well.
class _MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

Future<void> main() async {
  test('undecryptable phrase degrades to null, not a crash', () async {
    final storage = _CorruptStorage();
    final keystore = Keystore(storage);

    // Before the fix: this rethrew PlatformException and the engine's wallet
    // resolution pushed the boot into a permanent error state.
    expect(await keystore.readPhrase(), isNull);

    // The dead ciphertext must be dropped or the failure repeats forever.
    expect(storage.deletedKeys, contains('cen_recovery_phrase'));
  });

  test('undecryptable backup flag degrades to false', () async {
    final storage = _CorruptStorage();
    final keystore = Keystore(storage);

    expect(await keystore.hasBackedUp(), isFalse);
    expect(storage.deletedKeys, contains('cen_recovery_backed_up'));
  });

  test('healthy storage keeps the ordinary round-trip', () async {
    final keystore = Keystore(_MemoryStorage());

    await keystore.savePhrase('word eleven words twelve thirteen');
    expect(await keystore.readPhrase(), 'word eleven words twelve thirteen');

    expect(await keystore.hasBackedUp(), isFalse);
    await keystore.setBackedUp(true);
    expect(await keystore.hasBackedUp(), isTrue);
  });
}
