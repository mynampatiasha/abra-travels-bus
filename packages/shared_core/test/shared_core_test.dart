import 'package:shared_core/shared_core.dart';
import 'package:test/test.dart';

void main() {
  group('AppConfig', () {
    AppConfig config(String url, AppEnvironment environment) => AppConfig(
      environment: environment,
      appKind: AppKind.customer,
      apiBaseUrl: Uri.parse(url),
    );

    test('builds the versioned API base URL', () {
      final dev = config('http://localhost:4000', AppEnvironment.development);
      expect(dev.apiV1Url.toString(), 'http://localhost:4000/api/v1/');
      expect(dev.isProduction, isFalse);
      expect(dev.clientType, ClientType.mobile);
      expect(dev.defaultLocaleTag, 'en');
    });

    test('requires https in staging and production', () {
      for (final environment in [
        AppEnvironment.staging,
        AppEnvironment.production,
      ]) {
        expect(
          () => config('http://api.example.com', environment),
          throwsArgumentError,
        );
        expect(
          config('https://api.example.com', environment).apiV1Url.scheme,
          'https',
        );
      }
    });

    test('rejects relative and non-http URLs', () {
      expect(
        () => config('/api', AppEnvironment.development),
        throwsArgumentError,
      );
      expect(
        () => config('ftp://host', AppEnvironment.development),
        throwsArgumentError,
      );
    });

    test('client types carry the values the API expects', () {
      expect(ClientType.mobile.wireValue, 'MOBILE');
      expect(ClientType.web.wireValue, 'WEB');
    });
  });

  group('Result', () {
    test('success exposes its value', () {
      const result = Result<int>.success(7);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 7);
      expect(result.failureOrNull, isNull);
      expect(result.getOrThrow(), 7);
      expect(
        result.fold(onSuccess: (v) => 'ok $v', onFailure: (_) => 'no'),
        'ok 7',
      );
      expect(result.map((v) => v * 2).valueOrNull, 14);
    });

    test('failure exposes its failure and never a value', () {
      const result = Result<int>.failure(NetworkFailure());
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(result.map((v) => v * 2).failureOrNull, isA<NetworkFailure>());
      expect(
        result.getOrThrow,
        throwsA(
          isA<AppException>().having(
            (e) => e.failure,
            'failure',
            isA<NetworkFailure>(),
          ),
        ),
      );
    });

    test('guard turns AppException into a failure', () async {
      final result = await Result.guard<int>(
        () async => throw const AppException(TimeoutFailure()),
      );
      expect(result.failureOrNull, isA<TimeoutFailure>());
    });

    test(
      'guard turns any other error into UnexpectedFailure without its message',
      () async {
        final result = await Result.guard<int>(
          () async => throw StateError('token=abc123'),
        );
        final failure = result.failureOrNull;
        expect(failure, isA<UnexpectedFailure>());
        expect(failure!.debugMessage, isNot(contains('abc123')));
      },
    );

    test('guard returns the value on success', () async {
      expect((await Result.guard(() async => 'done')).valueOrNull, 'done');
    });
  });

  group('ApiFailure', () {
    ApiFailure failure(
      String code,
      int status, [
      Map<String, Object?> details = const {},
    ]) => ApiFailure(
      code: code,
      message: 'm',
      statusCode: status,
      requestId: 'req-1',
      details: details,
    );

    test('classifies authentication and authorization failures', () {
      expect(
        failure(ApiErrorCodes.unauthenticated, 401).isUnauthenticated,
        isTrue,
      );
      expect(
        failure(ApiErrorCodes.unauthenticated, 401).isRefreshable,
        isFalse,
      );
      expect(failure(ApiErrorCodes.tokenExpired, 401).isRefreshable, isTrue);
      expect(
        failure(ApiErrorCodes.permissionsChanged, 401).isRefreshable,
        isTrue,
      );
      expect(failure(ApiErrorCodes.permissionDenied, 403).isForbidden, isTrue);
      expect(failure(ApiErrorCodes.resourceNotFound, 404).isNotFound, isTrue);
      expect(failure(ApiErrorCodes.validationFailed, 400).isValidation, isTrue);
    });

    test('reads retryAfterSeconds only when it is a number', () {
      expect(
        failure(ApiErrorCodes.rateLimited, 429, {
          'retryAfterSeconds': 30,
        }).retryAfterSeconds,
        30,
      );
      expect(
        failure(ApiErrorCodes.rateLimited, 429, {
          'retryAfterSeconds': 'soon',
        }).retryAfterSeconds,
        isNull,
      );
      expect(failure(ApiErrorCodes.rateLimited, 429).retryAfterSeconds, isNull);
    });

    test(
      'debug text has code, status and request id but not the server message',
      () {
        const withMessage = ApiFailure(
          code: 'X',
          message: 'secret detail',
          statusCode: 400,
          requestId: 'r',
        );
        expect(
          withMessage.toString(),
          allOf(contains('X'), contains('400'), contains('r')),
        );
        expect(withMessage.toString(), isNot(contains('secret detail')));
      },
    );
  });

  group('LogRedactor', () {
    test('redacts credentials at any depth and keeps the rest', () {
      final redacted = LogRedactor.redact(<String, Object?>{
        'phone': '+919876543210',
        'password': 'hunter2-long',
        'Authorization': 'Bearer abc',
        'body': <String, Object?>{
          'refreshToken': 'r.secret',
          'code': '123456',
          'device': <String, Object?>{'accessToken': 'jwt', 'name': 'Pixel'},
        },
        'list': <Object?>[
          <String, Object?>{'otp': '999999', 'ok': true},
        ],
      });
      final text = redacted.toString();
      for (final secret in [
        'hunter2-long',
        'Bearer abc',
        'r.secret',
        '123456',
        'jwt',
        '999999',
      ]) {
        expect(text, isNot(contains(secret)));
      }
      expect(text, contains('Pixel'));
      expect(text, contains(LogRedactor.redacted));
    });

    test('matches keys case-insensitively', () {
      for (final key in [
        'PASSWORD',
        'RefreshToken',
        'x-api-key',
        'Cookie',
        'mfaToken',
        'recoveryCodes',
      ]) {
        expect(LogRedactor.isSensitiveKey(key), isTrue, reason: key);
      }
      expect(LogRedactor.isSensitiveKey('requestId'), isFalse);
    });

    test('safePath drops the query string', () {
      expect(
        LogRedactor.safePath(
          Uri.parse('https://h/api/v1/tickets/lookup?pnr=AB12&phone=98765'),
        ),
        '/api/v1/tickets/lookup',
      );
    });
  });

  group('AppLogger', () {
    test('redacts context before it reaches the sink', () {
      final logger = MemoryLogger()
        ..info(
          'signed in',
          context: <String, Object?>{
            'userId': 'u1',
            'accessToken': 'jwt-value',
          },
        )
        ..error('failed');
      expect(logger.entries, hasLength(2));
      expect(logger.entries.first.level, LogLevel.info);
      expect(logger.entries.first.context, {
        'userId': 'u1',
        'accessToken': LogRedactor.redacted,
      });
      expect(logger.entries.last.context, isEmpty);
    });

    test('SilentLogger and DeveloperLogger accept every level', () {
      for (final logger in <AppLogger>[
        const SilentLogger(),
        const DeveloperLogger(),
      ]) {
        logger
          ..debug('d')
          ..info('i')
          ..warning('w')
          ..error('e', context: <String, Object?>{'password': 'x'});
      }
    });
  });

  group('in-memory stores', () {
    test('secure store reads, writes, deletes and clears', () async {
      final store = InMemorySecureStore({'a': '1'});
      expect(await store.read('a'), '1');
      expect(await store.read('missing'), isNull);
      await store.write('b', '2');
      expect(store.keys, {'a', 'b'});
      await store.delete('a');
      expect(await store.read('a'), isNull);
      await store.deleteAll();
      expect(store.keys, isEmpty);
    });

    test(
      'preferences store is typed: a value of another type reads as absent',
      () async {
        final store = InMemoryPreferencesStore();
        await store.setString('lang', 'hi');
        await store.setBool('seen', value: true);
        await store.setInt('count', 3);
        expect(store.getString('lang'), 'hi');
        expect(store.getBool('seen'), isTrue);
        expect(store.getInt('count'), 3);
        expect(store.getInt('lang'), isNull);
        expect(store.getString('count'), isNull);
        await store.remove('lang');
        expect(store.getString('lang'), isNull);
      },
    );
  });
}
