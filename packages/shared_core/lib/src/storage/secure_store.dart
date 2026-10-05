/// Storage for credentials: access token, refresh token, session data.
///
/// Implementations must keep values in the platform keystore (Android
/// Keystore, iOS Keychain). Shared packages depend on this contract only;
/// the platform implementation lives in `shared_storage`. Never use a
/// [PreferencesStore] for anything stored here.
abstract interface class SecureStore {
  /// The value for [key], or null when nothing is stored.
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Removes every value this store owns (sign-out, account removal).
  Future<void> deleteAll();
}
