import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_core/shared_core.dart';

/// [SecureStore] backed by the platform keystore: Android Keystore
/// (EncryptedSharedPreferences) and iOS Keychain.
///
/// iOS items are readable after the first unlock and never leave the device
/// (not included in backups or iCloud Keychain), so a session cannot be
/// restored onto another device.
///
/// On web there is no keystore; web apps keep the refresh token in an
/// HttpOnly cookie managed by the browser and should hold the access token
/// in an `InMemorySecureStore`.
final class KeystoreSecureStore implements SecureStore {
  KeystoreSecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
