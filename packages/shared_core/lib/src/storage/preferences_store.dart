/// Storage for non-sensitive settings: language, UI preferences, small
/// cached configuration. Values are not encrypted, so credentials and
/// personal data must never be stored here — use `SecureStore` for those.
abstract interface class PreferencesStore {
  String? getString(String key);

  bool? getBool(String key);

  int? getInt(String key);

  Future<void> setString(String key, String value);

  Future<void> setBool(String key, {required bool value});

  Future<void> setInt(String key, int value);

  Future<void> remove(String key);
}
