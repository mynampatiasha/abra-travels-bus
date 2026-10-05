import 'package:dio/dio.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';
import 'package:test/test.dart';

class FakeTokenSource implements AuthTokenSource {
  FakeTokenSource({this.token = 'access-1', this.refreshResult = true});

  String? token;
  bool refreshResult;
  AppFailure? refreshFailure;
  int refreshCalls = 0;
  int rejectedCalls = 0;

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<bool> refreshAccessToken() async {
    refreshCalls++;
    if (refreshFailure != null) throw AppException(refreshFailure!);
    if (refreshResult) token = 'access-2';
    return refreshResult;
  }

  @override
  Future<void> onSessionRejected() async => rejectedCalls++;
}

typedef Harness = ({
  ApiClient client,
  FakeHttpAdapter adapter,
  MemoryLogger logger,
});

Harness harness(
  Future<FakeResponse> Function(RecordedRequest request) handler, {
  AuthTokenSource? tokens,
  ClientType clientType = ClientType.mobile,
  String Function()? languageTag,
}) {
  final adapter = FakeHttpAdapter(handler);
  final logger = MemoryLogger();
  final client = ApiClient(
    config: AppConfig(
      environment: AppEnvironment.test,
      appKind: AppKind.customer,
      apiBaseUrl: Uri.parse('http://localhost:4000'),
      clientType: clientType,
    ),
    dio: Dio()..httpClientAdapter = adapter,
    logger: logger,
    languageTag: languageTag,
    requestIdFactory: () => 'client-request-id',
  );
  if (tokens != null) client.attachTokenSource(tokens);
  return (client: client, adapter: adapter, logger: logger);
}

Future<AppFailure> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on AppException catch (exception) {
    return exception.failure;
  }
  fail('expected an AppException');
}

void main() {
  group('requests', () {
    test(
      'calls /api/v1 with JSON, request id, language and bearer token',
      () async {
        final h = harness(
          (_) async => FakeResponse.ok(<String, Object?>{'ok': true}),
          tokens: FakeTokenSource(),
          languageTag: () => 'kn',
        );
        final response = await h.client.post(
          '/bookings',
          body: <String, Object?>{'seat': 'A1'},
          idempotencyKey: 'idem-1',
        );

        expect(response.data, {'ok': true});
        final request = h.adapter.requests.single;
        expect(
          request.options.uri.toString(),
          'http://localhost:4000/api/v1/bookings',
        );
        expect(request.method, 'POST');
        expect(request.body, {'seat': 'A1'});
        expect(request.header('Authorization'), 'Bearer access-1');
        expect(request.header('X-Request-Id'), 'client-request-id');
        expect(request.header('Accept-Language'), 'kn');
        expect(request.header('Idempotency-Key'), 'idem-1');
        expect(request.header('X-Abra-Client'), isNull);
      },
    );

    test('public requests carry no token', () async {
      final h = harness(
        (_) async => FakeResponse.ok(null),
        tokens: FakeTokenSource(),
      );
      await h.client.post(
        'auth/login',
        body: <String, Object?>{},
        authenticated: false,
      );
      expect(h.adapter.requests.single.header('Authorization'), isNull);
    });

    test('drops null query values and sends the rest', () async {
      final h = harness(
        (_) async => FakeResponse.ok(<Object?>[]),
        tokens: FakeTokenSource(),
      );
      await h.client.get(
        'users',
        query: <String, Object?>{'page': 2, 'operatorId': null},
      );
      expect(h.adapter.requests.single.options.uri.queryParameters, {
        'page': '2',
      });
    });

    test(
      'web clients identify themselves and allow credentials (refresh cookie)',
      () async {
        final h = harness(
          (_) async => FakeResponse.ok(null),
          clientType: ClientType.web,
        );
        await h.client.post('auth/refresh', authenticated: false);
        final request = h.adapter.requests.single;
        expect(request.header('X-Abra-Client'), 'web');
        expect(request.options.extra['withCredentials'], isTrue);
      },
    );

    test(
      'an authenticated request without a session fails before any network call',
      () async {
        final h = harness(
          (_) async => FakeResponse.ok(null),
          tokens: FakeTokenSource(token: null),
        );
        expect(
          await failureOf(h.client.get('me')),
          isA<SessionExpiredFailure>(),
        );
        expect(h.adapter.requests, isEmpty);
      },
    );

    test('reads paging from the envelope', () async {
      final h = harness(
        (_) async => FakeResponse.ok(
          <Object?>[],
          meta: <String, Object?>{'page': 1, 'pageSize': 20, 'total': 41},
        ),
        tokens: FakeTokenSource(),
      );
      final response = await h.client.get('users');
      expect(response.page!.total, 41);
      expect(response.page!.hasMore, isTrue);
    });
  });

  group('failures', () {
    test(
      'maps the error envelope to ApiFailure with code, status, request id and details',
      () async {
        final h = harness(
          (_) async => FakeResponse.error(
            423,
            ApiErrorCodes.accountLocked,
            message: 'Too many failed attempts.',
            details: <String, Object?>{'retryAfterSeconds': 900},
          ),
        );
        final failure = await failureOf(
          h.client.post('auth/login', authenticated: false),
        );
        expect(failure, isA<ApiFailure>());
        final api = failure as ApiFailure;
        expect(api.code, ApiErrorCodes.accountLocked);
        expect(api.statusCode, 423);
        expect(api.requestId, 'test-request');
        expect(api.retryAfterSeconds, 900);
      },
    );

    test('a non-envelope error body is a ServerFailure', () async {
      final h = harness(
        (_) async => const FakeResponse(502, '<html>Bad Gateway</html>'),
      );
      final failure = await failureOf(
        h.client.get('trips/search', authenticated: false),
      );
      expect(
        failure,
        isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 502),
      );
    });

    test('a 2xx body that is not the envelope is a ServerFailure', () async {
      final h = harness(
        (_) async =>
            const FakeResponse(200, <String, Object?>{'unexpected': true}),
      );
      expect(
        await failureOf(h.client.get('x', authenticated: false)),
        isA<ServerFailure>(),
      );
    });

    test('maps transport errors', () async {
      Future<AppFailure> transport(DioExceptionType type, {Object? error}) {
        final h = harness(
          (request) async => throw DioException(
            requestOptions: request.options,
            type: type,
            error: error,
          ),
        );
        return failureOf(h.client.get('x', authenticated: false));
      }

      expect(
        await transport(DioExceptionType.connectionTimeout),
        isA<TimeoutFailure>(),
      );
      expect(
        await transport(DioExceptionType.receiveTimeout),
        isA<TimeoutFailure>(),
      );
      expect(
        await transport(DioExceptionType.connectionError),
        isA<NetworkFailure>(),
      );
      expect(
        await transport(DioExceptionType.badCertificate),
        isA<NetworkFailure>(),
      );
      expect(await transport(DioExceptionType.cancel), isA<CancelledFailure>());
      expect(
        await transport(DioExceptionType.unknown, error: StateError('x')),
        isA<UnexpectedFailure>(),
      );
    });

    test(
      '403 and 404 are passed through without touching the session',
      () async {
        final tokens = FakeTokenSource();
        final h = harness(
          (_) async => FakeResponse.error(403, ApiErrorCodes.permissionDenied),
          tokens: tokens,
        );
        final failure = await failureOf(h.client.get('users'));
        expect((failure as ApiFailure).isForbidden, isTrue);
        expect(tokens.refreshCalls, 0);
        expect(tokens.rejectedCalls, 0);
      },
    );
  });

  group('token refresh', () {
    for (final code in [
      ApiErrorCodes.tokenExpired,
      ApiErrorCodes.permissionsChanged,
    ]) {
      test(
        '$code → refresh once and repeat the request with the new token',
        () async {
          final tokens = FakeTokenSource();
          final h = harness((request) async {
            return request.header('Authorization') == 'Bearer access-1'
                ? FakeResponse.error(401, code)
                : FakeResponse.ok(<String, Object?>{'id': 'me'});
          }, tokens: tokens);

          final response = await h.client.get('me');
          expect(response.data, {'id': 'me'});
          expect(tokens.refreshCalls, 1);
          expect(h.adapter.requests.map((r) => r.header('Authorization')), [
            'Bearer access-1',
            'Bearer access-2',
          ]);
        },
      );
    }

    test(
      'refresh says the session ended → SessionExpiredFailure, no retry',
      () async {
        final tokens = FakeTokenSource(refreshResult: false);
        final h = harness(
          (_) async => FakeResponse.error(401, ApiErrorCodes.tokenExpired),
          tokens: tokens,
        );
        expect(
          await failureOf(h.client.get('me')),
          isA<SessionExpiredFailure>(),
        );
        expect(h.adapter.requests, hasLength(1));
      },
    );

    test(
      'still expired after one refresh → session ends, no refresh loop',
      () async {
        final tokens = FakeTokenSource();
        final h = harness(
          (_) async => FakeResponse.error(401, ApiErrorCodes.tokenExpired),
          tokens: tokens,
        );
        expect(
          await failureOf(h.client.get('me')),
          isA<SessionExpiredFailure>(),
        );
        expect(tokens.refreshCalls, 1);
        expect(tokens.rejectedCalls, 1);
        expect(h.adapter.requests, hasLength(2));
      },
    );

    test(
      'offline during refresh keeps the session and reports the network failure',
      () async {
        final tokens = FakeTokenSource()
          ..refreshFailure = const NetworkFailure();
        final h = harness(
          (_) async => FakeResponse.error(401, ApiErrorCodes.tokenExpired),
          tokens: tokens,
        );
        expect(await failureOf(h.client.get('me')), isA<NetworkFailure>());
        expect(tokens.rejectedCalls, 0);
      },
    );

    test(
      'UNAUTHENTICATED (revoked session) is not refreshed; the session is rejected',
      () async {
        final tokens = FakeTokenSource();
        final h = harness(
          (_) async => FakeResponse.error(401, ApiErrorCodes.unauthenticated),
          tokens: tokens,
        );
        expect(
          await failureOf(h.client.get('me')),
          isA<SessionExpiredFailure>(),
        );
        expect(tokens.refreshCalls, 0);
        expect(tokens.rejectedCalls, 1);
      },
    );

    test(
      'a 401 on a public request (wrong password) is returned as it is',
      () async {
        final tokens = FakeTokenSource();
        final h = harness(
          (_) async =>
              FakeResponse.error(401, ApiErrorCodes.invalidCredentials),
          tokens: tokens,
        );
        final failure = await failureOf(
          h.client.post('auth/login', authenticated: false),
        );
        expect((failure as ApiFailure).code, ApiErrorCodes.invalidCredentials);
        expect(tokens.refreshCalls + tokens.rejectedCalls, 0);
      },
    );
  });

  group('logging', () {
    test(
      'logs method, path, status and request id — never tokens, bodies or queries',
      () async {
        final h = harness(
          (_) async => FakeResponse.ok(null),
          tokens: FakeTokenSource(token: 'super-secret-jwt'),
        );
        await h.client.post(
          'auth/login',
          body: <String, Object?>{
            'identifier': 'asha@example.com',
            'password': 'violet-river-lantern',
          },
        );
        await h.client.get(
          'tickets/lookup',
          query: <String, Object?>{'pnr': 'AB12CD34'},
        );

        final logged = h.logger.entries
            .map((e) => '${e.message} ${e.context}')
            .join('\n');
        expect(logged, contains('auth/login'));
        expect(logged, contains('200'));
        for (final secret in [
          'super-secret-jwt',
          'violet-river-lantern',
          'asha@example.com',
          'AB12CD34',
        ]) {
          expect(logged, isNot(contains(secret)));
        }
      },
    );

    test(
      'a transport failure is logged as a warning without the error text',
      () async {
        final h = harness(
          (request) async => throw DioException(
            requestOptions: request.options,
            type: DioExceptionType.connectionError,
            error: 'connect ECONNREFUSED 10.0.0.5:4000',
          ),
        );
        await failureOf(h.client.get('x', authenticated: false));
        final entry = h.logger.entries.single;
        expect(entry.level, LogLevel.warning);
        expect('${entry.context}', isNot(contains('10.0.0.5')));
      },
    );
  });
}
