import 'package:flutter/foundation.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_storage/shared_storage.dart';

/// The long-lived objects of the management app, created once at start-up.
/// Tests build this with in-memory stores and a fake HTTP adapter.
class AppDependencies {
  AppDependencies({
    required this.config,
    required this.logger,
    required this.preferences,
    required this.localeController,
    required this.translations,
    required this.apiClient,
    required this.sessionManager,
    required this.permissions,
    required this.notifications,
  });

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
      // In a browser the access token is kept in memory only; the refresh
      // token is an HttpOnly cookie. Elsewhere tokens go to the keystore.
      tokenStore: AuthTokenStore(
        kIsWeb ? InMemorySecureStore() : KeystoreSecureStore(),
      ),
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
      permissions: PermissionsController(PermissionsRepository(apiClient)),
      notifications: NotificationCenter(
        repository: NotificationsRepository(apiClient),
        live: SocketLiveNotificationSource(config.apiBaseUrl.origin),
        // Push when the page is closed needs a browser; the admin app is a web app
        push: kIsWeb ? FirebaseDevicePush() : null,
      ),
    );
  }

  static const TranslationSource bundledTranslations =
      MergedTranslationSource(<TranslationSource>[
        AssetTranslationSource(package: null, filePrefix: 'admin_'),
        AssetTranslationSource(),
      ]);

  final AppConfig config;
  final AppLogger logger;
  final PreferencesStore preferences;
  final LocaleController localeController;
  final TranslationSource translations;
  final ApiClient apiClient;
  final AuthSessionManager sessionManager;

  /// What the signed-in user may see. For showing and hiding only: the
  /// backend authorizes every request itself.
  final PermissionsController permissions;

  /// The person's notifications: the list, the live socket for an open app and push for a
  /// closed one.
  final NotificationCenter notifications;
}
