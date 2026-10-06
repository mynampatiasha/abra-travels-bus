import 'package:flutter/foundation.dart';
import 'package:shared_core/shared_core.dart';

/// The build configuration is missing or unsafe. The message is for
/// developers and build logs; it is never shown to customers.
class ConfigurationException implements Exception {
  const ConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}

/// Build-time settings of the management app, passed with `--dart-define`:
///
/// ```text
/// flutter run --dart-define=ABRA_ENV=development \
///             --dart-define=ABRA_API_BASE_URL=http://10.0.2.2:4000
/// ```
///
/// - `ABRA_ENV`: development (default), test, staging or production.
/// - `ABRA_API_BASE_URL`: origin of the backend. Required outside
///   development. Must be HTTPS in staging, in production and in every
///   release build.
///
/// Only public values belong here. Secrets are never compiled into the app.
@immutable
class AdminEnvironment {
  const AdminEnvironment({
    required this.environmentName,
    required this.apiBaseUrl,
  });

  /// Reads the values compiled into this build.
  const AdminEnvironment.fromDartDefines()
    : environmentName = const String.fromEnvironment(
        'ABRA_ENV',
        defaultValue: 'development',
      ),
      apiBaseUrl = const String.fromEnvironment('ABRA_API_BASE_URL');

  final String environmentName;
  final String apiBaseUrl;

  /// Port of the backend on a developer machine (`backend/.env.example`).
  static const developmentPort = 4000;

  /// Validates the values and builds the configuration used by the shared
  /// packages. Throws [ConfigurationException] when they are unusable.
  AppConfig toAppConfig({
    TargetPlatform? platform,
    bool isReleaseBuild = kReleaseMode,
    bool isWeb = kIsWeb,
  }) {
    final environment = AppEnvironment.values
        .where((value) => value.name == environmentName.trim().toLowerCase())
        .firstOrNull;
    if (environment == null) {
      throw ConfigurationException(
        'ABRA_ENV "$environmentName" is not one of '
        '${AppEnvironment.values.map((value) => value.name).join(', ')}',
      );
    }

    final Uri baseUrl;
    final configured = apiBaseUrl.trim();
    if (configured.isEmpty) {
      if (environment != AppEnvironment.development) {
        throw ConfigurationException(
          'ABRA_API_BASE_URL is required in ${environment.name}',
        );
      }
      baseUrl = isWeb
          ? Uri(scheme: 'http', host: 'localhost', port: developmentPort)
          : _developmentUrl(platform ?? defaultTargetPlatform);
    } else {
      final parsed = Uri.tryParse(configured);
      if (parsed == null) {
        throw const ConfigurationException(
          'ABRA_API_BASE_URL is not a valid URL',
        );
      }
      baseUrl = parsed;
    }

    if (isReleaseBuild && baseUrl.scheme != 'https') {
      throw const ConfigurationException(
        'Release builds must use an https ABRA_API_BASE_URL',
      );
    }

    try {
      return AppConfig(
        environment: environment,
        appKind: AppKind.admin,
        apiBaseUrl: baseUrl,
        // In a browser the refresh token lives in an HttpOnly cookie the app
        // never sees (documentation/authentication.md §2).
        clientType: isWeb ? ClientType.web : ClientType.mobile,
      );
    } on ArgumentError catch (error) {
      throw ConfigurationException('ABRA_API_BASE_URL ${error.message}');
    }
  }

  /// The Android emulator reaches the developer machine at 10.0.2.2; the
  /// iOS simulator shares the machine's localhost.
  static Uri _developmentUrl(TargetPlatform platform) => Uri(
    scheme: 'http',
    host: platform == TargetPlatform.android ? '10.0.2.2' : 'localhost',
    port: developmentPort,
  );
}
