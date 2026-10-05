/// Platform storage for the Abra Travels apps, behind the contracts of
/// `shared_core`: [KeystoreSecureStore] for credentials and
/// [DevicePreferencesStore] for ordinary settings. App code depends on the
/// contracts (`SecureStore`, `PreferencesStore`), never on the plugins.
library;

export 'package:shared_core/shared_core.dart'
    show
        InMemoryPreferencesStore,
        InMemorySecureStore,
        PreferencesStore,
        SecureStore;

export 'src/device_preferences_store.dart';
export 'src/keystore_secure_store.dart';
export 'src/preference_keys.dart';
