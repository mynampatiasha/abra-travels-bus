import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_storage/shared_storage.dart';

/// The long-lived objects of the app, created once at start-up and handed
/// to the widget tree through `appDependenciesProvider`. Tests build this
/// with in-memory stores and a fake HTTP adapter.
class AppDependencies {
  AppDependencies({
    required this.config,
    required this.logger,
    required this.preferences,
    required this.localeController,
    required this.translations,
    required this.apiClient,
    required this.sessionManager,
    this.notifications,
  });

  /// Creates the production object graph on the device.
  static Future<AppDependencies> create({
    required AppConfig config,
    required AppLogger logger,
  }) async {
    final preferences = await DevicePreferencesStore.open();
    final localeController = LocaleController(
      config: AbraLocaleConfig(),
      preferences: preferences,
    );
    final apiClient = ApiClient(
      config: config,
      logger: logger,
      languageTag: () => localeController.languageTag,
    );
    final sessionManager = AuthSessionManager(
      api: AuthApi(apiClient, clientType: config.clientType),
      client: apiClient,
      // Tokens live in the platform keystore only.
      tokenStore: AuthTokenStore(KeystoreSecureStore()),
      clientType: config.clientType,
      logger: logger,
    );
    return AppDependencies(
      config: config,
      logger: logger,
      preferences: preferences,
      localeController: localeController,
      translations: bundledTranslations,
      apiClient: apiClient,
      sessionManager: sessionManager,
      notifications: NotificationCenter(
        repository: NotificationsRepository(apiClient),
        live: SocketLiveNotificationSource(config.apiBaseUrl.origin),
        // Push for a closed app: Android and iOS read the Firebase file added
        // at build time. Without it push stays off and the app still works.
        push: FirebaseDevicePush(),
      ),
    );
  }

  /// The app's own messages on top of the messages shared by all apps.
  static const TranslationSource bundledTranslations =
      MergedTranslationSource(<TranslationSource>[
        AssetTranslationSource(package: null, filePrefix: 'customer_'),
        AssetTranslationSource(),
      ]);

  final AppConfig config;
  final AppLogger logger;

  /// Ordinary settings (language, onboarding). Never credentials.
  final PreferencesStore preferences;
  final LocaleController localeController;
  final TranslationSource translations;
  final ApiClient apiClient;
  final AuthSessionManager sessionManager;

  /// The person's notifications (list, live socket, push). Null in tests.
  final NotificationCenter? notifications;
}
