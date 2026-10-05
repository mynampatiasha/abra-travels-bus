import 'dart:async';
import 'dart:io';

import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/bootstrap/app_dependencies.dart';
import 'package:customer_app/features/authentication/otp_sign_in_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

/// The real English resources (app + shared), read up front so widget
/// tests need no real-time asset loading.
final MemoryTranslationSource englishTranslations = MemoryTranslationSource({
  'en': <String, String>{
    ...parseArb(
      File(
        '../../packages/shared_localization/l10n/app_en.arb',
      ).readAsStringSync(),
    ),
    ...parseArb(File('l10n/customer_en.arb').readAsStringSync()),
  },
});

const JsonMap userJson = <String, Object?>{
  'id': 'user-1',
  'name': 'Asha',
  'email': null,
  'phone': '+919876543210',
  'emailVerified': false,
  'phoneVerified': true,
  'userType': 'CUSTOMER',
  'status': 'ACTIVE',
  'operatorId': null,
  'partnerId': null,
  'preferredLanguage': 'en',
  'hasPassword': true,
  'mfaEnabled': false,
  'lastLoginAt': null,
  'createdAt': null,
};

/// What the backend answers to a successful sign-in.
final FakeResponse signInResponse = FakeResponse.ok(<String, Object?>{
  'tokenType': 'Bearer',
  'accessToken': 'access-1',
  'accessTokenExpiresInSeconds': 900,
  'refreshToken': 'session-1.refresh-1',
  'refreshTokenExpiresAt': '2026-11-01T00:00:00.000Z',
  'sessionId': 'session-1',
  'mfaEnrollmentRequired': false,
  'user': userJson,
});

/// What the backend answers to `GET /me` for a valid session.
final FakeResponse currentUserResponse = FakeResponse.ok(<String, Object?>{
  'user': userJson,
  'session': <String, Object?>{
    'id': 'session-1',
    'mfaEnrollmentRequired': false,
  },
});

const storedSession = <String, String>{
  AuthTokenStore.accessTokenKey: 'access-1',
  AuthTokenStore.refreshTokenKey: 'session-1.refresh-1',
  AuthTokenStore.sessionIdKey: 'session-1',
};

/// What the backend answers to `POST /auth/otp/send`.
FakeResponse otpSentResponse({
  String channel = 'WHATSAPP',
  int expiresInSeconds = 300,
  int resendAfterSeconds = 30,
}) => FakeResponse.ok(<String, Object?>{
  'expiresInSeconds': expiresInSeconds,
  'resendAfterSeconds': resendAfterSeconds,
  'codeLength': 6,
  'channel': channel,
});

DioException connectionError(RecordedRequest request) => DioException(
  requestOptions: request.options,
  type: DioExceptionType.connectionError,
);

/// The customer app wired exactly as in production, except that storage is
/// in memory and HTTP is answered by [handler]. The shared session manager,
/// API client, router and guards are the real ones.
class TestApp {
  TestApp({
    Future<FakeResponse> Function(RecordedRequest request)? handler,
    Map<String, String> stored = const <String, String>{},
    List<Locale> deviceLocales = const <Locale>[Locale('en')],
    TranslationSource? translations,
  }) : adapter = FakeHttpAdapter(handler ?? (_) async => currentUserResponse),
       secureStore = InMemorySecureStore(stored) {
    final config = AppConfig(
      environment: AppEnvironment.test,
      appKind: AppKind.customer,
      apiBaseUrl: Uri.parse('http://localhost:4000'),
    );
    final localeController = LocaleController(
      config: AbraLocaleConfig(),
      preferences: preferences,
      deviceLocales: deviceLocales,
    );
    final client = ApiClient(
      config: config,
      dio: Dio()..httpClientAdapter = adapter,
      logger: logger,
      languageTag: () => localeController.languageTag,
    );
    dependencies = AppDependencies(
      config: config,
      logger: logger,
      preferences: preferences,
      localeController: localeController,
      translations: translations ?? englishTranslations,
      apiClient: client,
      sessionManager: AuthSessionManager(
        api: AuthApi(client, clientType: config.clientType),
        client: client,
        tokenStore: AuthTokenStore(secureStore),
        clientType: config.clientType,
        logger: logger,
      ),
    );
  }

  final FakeHttpAdapter adapter;
  final InMemorySecureStore secureStore;
  final InMemoryPreferencesStore preferences = InMemoryPreferencesStore();
  final MemoryLogger logger = MemoryLogger();
  late final AppDependencies dependencies;
  final GlobalKey<State<StatefulWidget>> _scopeKey = GlobalKey();

  AuthSessionManager get sessionManager => dependencies.sessionManager;

  List<String> get requestedPaths =>
      adapter.requests.map((request) => request.path).toList();

  /// [clock] replaces the device clock for countdowns (the test clock in
  /// widget tests).
  Widget build({DateTime Function()? clock}) => ProviderScope(
    key: _scopeKey,
    overrides: [
      appDependenciesProvider.overrideWithValue(dependencies),
      if (clock != null) signInClockProvider.overrideWithValue(clock),
    ],
    child: const CustomerApp(),
  );

  /// Starts the app on a screen of [size] and lets start-up finish.
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(build(clock: tester.binding.clock.now));
    await tester.pumpAndSettle();
  }

  /// Signs in through the real session manager (the sign-in screens are
  /// delivered in milestone 10B).
  Future<void> signIn(WidgetTester tester) async {
    final previous = adapter.handler;
    adapter.handler = (_) async => signInResponse;
    await run(
      tester,
      sessionManager.signInWithPassword(
        identifier: 'asha@example.com',
        password: 'violet-river-lantern',
      ),
    );
    adapter.handler = previous;
    await tester.pumpAndSettle();
  }

  /// Completes [operation] (a call that goes through the HTTP client) by
  /// advancing the test clock, then lets the app react to the result.
  Future<void> run(WidgetTester tester, Future<Object?> operation) async {
    var isDone = false;
    Object? failure;
    unawaited(
      operation.then<void>(
        (_) => isDone = true,
        onError: (Object error) {
          failure = error;
          isDone = true;
        },
      ),
    );
    for (var i = 0; i < 100 && !isDone; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(isDone, isTrue, reason: 'operation did not complete');
    expect(failure, isNull);
    await tester.pumpAndSettle();
  }
}
