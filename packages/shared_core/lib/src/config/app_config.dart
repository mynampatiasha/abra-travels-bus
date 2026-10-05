import 'package:meta/meta.dart';

/// Where the app is running. Mirrors the backend environments.
enum AppEnvironment { development, test, staging, production }

/// Which Abra Travels application this is.
enum AppKind { customer, operator, driver, admin, partner }

/// How the client keeps its refresh token (documentation/authentication.md §2).
///
/// [mobile] receives the refresh token in the response body and keeps it in
/// the platform keystore. [web] receives it as an HttpOnly cookie that the
/// app never sees.
enum ClientType {
  mobile('MOBILE'),
  web('WEB');

  const ClientType(this.wireValue);

  /// Value sent to the API as `device.clientType`.
  final String wireValue;
}

/// Immutable configuration of one app instance. Created once at start-up
/// (from `--dart-define` values) and passed to the shared packages.
@immutable
class AppConfig {
  /// Creates a configuration and validates it. Throws [ArgumentError] when
  /// the values are unsafe, for example plain HTTP in production.
  AppConfig({
    required this.environment,
    required this.appKind,
    required this.apiBaseUrl,
    this.clientType = ClientType.mobile,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.defaultLocaleTag = 'en',
  }) {
    if (!apiBaseUrl.hasScheme || apiBaseUrl.host.isEmpty) {
      throw ArgumentError.value(apiBaseUrl, 'apiBaseUrl', 'must be absolute');
    }
    final isSecure = apiBaseUrl.scheme == 'https';
    if (!isSecure && apiBaseUrl.scheme != 'http') {
      throw ArgumentError.value(apiBaseUrl, 'apiBaseUrl', 'must be http(s)');
    }
    final requiresHttps =
        environment == AppEnvironment.staging ||
        environment == AppEnvironment.production;
    if (requiresHttps && !isSecure) {
      throw ArgumentError.value(
        apiBaseUrl,
        'apiBaseUrl',
        'must use https in ${environment.name}',
      );
    }
  }

  final AppEnvironment environment;
  final AppKind appKind;

  /// Origin of the backend, without the `/api/v1` prefix.
  final Uri apiBaseUrl;
  final ClientType clientType;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// BCP-47 tag used when neither the user nor the device selects a
  /// supported language.
  final String defaultLocaleTag;

  bool get isProduction => environment == AppEnvironment.production;

  /// Base URL of the versioned REST API.
  Uri get apiV1Url => apiBaseUrl.resolve('/api/v1/');
}
