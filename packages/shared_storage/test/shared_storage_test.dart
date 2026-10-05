import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/shared_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeystoreSecureStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

    test(
      'reads, writes, deletes and clears through the platform keystore',
      () async {
        final SecureStore store = KeystoreSecureStore();
        expect(await store.read('abra.auth.refresh_token'), isNull);

        await store.write('abra.auth.refresh_token', 'session.secret');
        await store.write('abra.auth.access_token', 'jwt');
        expect(await store.read('abra.auth.refresh_token'), 'session.secret');

        await store.delete('abra.auth.refresh_token');
        expect(await store.read('abra.auth.refresh_token'), isNull);
        expect(await store.read('abra.auth.access_token'), 'jwt');

        await store.deleteAll();
        expect(await store.read('abra.auth.access_token'), isNull);
      },
    );

    test('secure values never appear in ordinary preferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await KeystoreSecureStore().write(
        'abra.auth.refresh_token',
        'session.secret',
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
    });
  });

  group('DevicePreferencesStore', () {
    test('stores typed settings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final PreferencesStore store = await DevicePreferencesStore.open();

      expect(store.getString(PreferenceKeys.localeTag), isNull);
      await store.setString(PreferenceKeys.localeTag, 'kn');
      await store.setBool('abra.preferences.onboarding_seen', value: true);
      await store.setInt('abra.preferences.launch_count', 3);

      expect(store.getString(PreferenceKeys.localeTag), 'kn');
      expect(store.getBool('abra.preferences.onboarding_seen'), isTrue);
      expect(store.getInt('abra.preferences.launch_count'), 3);
    });

    test(
      'a value of another type reads as absent instead of throwing',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{'key': 42});
        final store = await DevicePreferencesStore.open();
        expect(store.getString('key'), isNull);
        expect(store.getBool('key'), isNull);
        expect(store.getInt('key'), 42);
      },
    );

    test('remove deletes one key and survives a reopen', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferenceKeys.localeTag: 'hi',
        'other': 'x',
      });
      final store = await DevicePreferencesStore.open();
      await store.remove(PreferenceKeys.localeTag);
      final reopened = await DevicePreferencesStore.open();
      expect(reopened.getString(PreferenceKeys.localeTag), isNull);
      expect(reopened.getString('other'), 'x');
    });
  });

  test(
    'the in-memory stores are available for tests through this package',
    () async {
      final SecureStore secure = InMemorySecureStore();
      final PreferencesStore preferences = InMemoryPreferencesStore();
      await secure.write('k', 'v');
      await preferences.setString('k', 'v');
      expect(await secure.read('k'), 'v');
      expect(preferences.getString('k'), 'v');
    },
  );
}
