import 'package:customer_app/bootstrap/customer_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

AppConfig config(
  String environment,
  String url, {
  TargetPlatform platform = TargetPlatform.android,
  bool release = false,
}) => CustomerEnvironment(
  environmentName: environment,
  apiBaseUrl: url,
).toAppConfig(platform: platform, isReleaseBuild: release);

Matcher configurationError(String fragment) => throwsA(
  isA<ConfigurationException>().having(
    (error) => error.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  test('this build compiles in the development defaults', () {
    const environment = CustomerEnvironment.fromDartDefines();
    expect(environment.environmentName, 'development');
    expect(environment.apiBaseUrl, isEmpty);
  });

  test('development without a URL targets the backend on the developer '
      'machine', () {
    final android = config('development', '');
    expect(android.environment, AppEnvironment.development);
    expect(android.apiBaseUrl, Uri.parse('http://10.0.2.2:4000'));
    expect(android.apiV1Url, Uri.parse('http://10.0.2.2:4000/api/v1/'));

    final ios = config('development', '', platform: TargetPlatform.iOS);
    expect(ios.apiBaseUrl, Uri.parse('http://localhost:4000'));
  });

  test('always configures the customer app as a mobile client', () {
    final production = config('production', 'https://api.example.com');
    expect(production.appKind, AppKind.customer);
    expect(production.clientType, ClientType.mobile);
    expect(production.isProduction, isTrue);
    expect(production.apiV1Url, Uri.parse('https://api.example.com/api/v1/'));
  });

  test('accepts the environment name in any letter case', () {
    expect(
      config(' Staging ', 'https://staging.example.com').environment,
      AppEnvironment.staging,
    );
  });

  test('rejects an unknown environment', () {
    expect(
      () => config('prod', 'https://x.example'),
      configurationError('"prod"'),
    );
  });

  test('requires a URL outside development', () {
    for (final environment in ['test', 'staging', 'production']) {
      expect(
        () => config(environment, ''),
        configurationError('ABRA_API_BASE_URL is required'),
        reason: environment,
      );
    }
  });

  test('rejects plain HTTP in staging and production', () {
    for (final environment in ['staging', 'production']) {
      expect(
        () => config(environment, 'http://api.example.com'),
        configurationError('https'),
        reason: environment,
      );
    }
  });

  test('a release build never talks plain HTTP, whatever the environment', () {
    expect(
      () => config('development', '', release: true),
      configurationError('Release builds'),
    );
    expect(
      () => config('test', 'http://10.0.0.5:4000', release: true),
      configurationError('Release builds'),
    );
    expect(
      config(
        'development',
        'https://dev.example.com',
        release: true,
      ).apiBaseUrl,
      Uri.parse('https://dev.example.com'),
    );
  });

  test('rejects a URL that is not an absolute http(s) address', () {
    for (final url in ['api.example.com', 'ftp://api.example.com', '/api']) {
      expect(
        () => config('development', url),
        throwsA(isA<ConfigurationException>()),
        reason: url,
      );
    }
  });
}
