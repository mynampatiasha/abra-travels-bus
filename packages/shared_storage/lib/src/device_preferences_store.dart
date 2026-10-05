import 'package:shared_core/shared_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [PreferencesStore] backed by the platform preferences (SharedPreferences
/// on Android, NSUserDefaults on iOS, localStorage on web). Not encrypted:
/// for settings only. Credentials go to a `SecureStore`.
final class DevicePreferencesStore implements PreferencesStore {
  DevicePreferencesStore(this._preferences);

  /// Opens the platform preferences. Call once at start-up.
  static Future<DevicePreferencesStore> open() async =>
      DevicePreferencesStore(await SharedPreferences.getInstance());

  final SharedPreferences _preferences;

  // A value of another type under the same key is treated as absent.
  T? _typed<T>(String key) {
    final value = _preferences.get(key);
    return value is T ? value : null;
  }

  @override
  String? getString(String key) => _typed<String>(key);

  @override
  bool? getBool(String key) => _typed<bool>(key);

  @override
  int? getInt(String key) => _typed<int>(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> setBool(String key, {required bool value}) =>
      _preferences.setBool(key, value);

  @override
  Future<void> setInt(String key, int value) => _preferences.setInt(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
