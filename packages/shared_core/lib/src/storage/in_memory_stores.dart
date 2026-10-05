import 'preferences_store.dart';
import 'secure_store.dart';

/// [SecureStore] that keeps values in memory only. For tests and for
/// platforms without a keystore (values are lost when the process ends).
final class InMemorySecureStore implements SecureStore {
  InMemorySecureStore([Map<String, String> initial = const <String, String>{}])
    : _values = <String, String>{...initial};

  final Map<String, String> _values;

  /// Keys currently stored, for assertions in tests.
  Set<String> get keys => _values.keys.toSet();

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();
}

/// [PreferencesStore] that keeps values in memory only. For tests.
final class InMemoryPreferencesStore implements PreferencesStore {
  InMemoryPreferencesStore([
    Map<String, Object> initial = const <String, Object>{},
  ]) : _values = <String, Object>{...initial};

  final Map<String, Object> _values;

  T? _typed<T>(String key) {
    final value = _values[key];
    return value is T ? value : null;
  }

  @override
  String? getString(String key) => _typed<String>(key);

  @override
  bool? getBool(String key) => _typed<bool>(key);

  @override
  int? getInt(String key) => _typed<int>(key);

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
