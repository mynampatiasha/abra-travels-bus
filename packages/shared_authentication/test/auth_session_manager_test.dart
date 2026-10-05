import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:test/test.dart';

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

JsonMap tokens(
  int generation, {
  bool web = false,
  bool mfaEnrollment = false,
}) => <String, Object?>{
  'tokenType': 'Bearer',
  'accessToken': 'access-$generation',
  'accessTokenExpiresInSeconds': 900,
  'refreshToken': web ? '' : 'session-1.refresh-$generation',
  'refreshTokenExpiresAt': '2026-11-01T00:00:00.000Z',
  'sessionId': 'session-1',
  'mfaEnrollmentRequired': mfaEnrollment,
  'user': userJson,
};

final FakeResponse meResponse = FakeResponse.ok(<String, Object?>{
  'user': userJson,
  'session': <String, Object?>{
    'id': 'session-1',
    'mfaEnrollmentRequired': false,
  },
});

class Harness {
  Harness(
    Future<FakeResponse> Function(RecordedRequest request) handler, {
    ClientType clientType = ClientType.mobile,
    Map<String, String> stored = const <String, String>{},
  }) : adapter = FakeHttpAdapter(handler),
       secureStore = InMemorySecureStore(stored) {
    final client = ApiClient(
      config: AppConfig(
        environment: AppEnvironment.test,
        appKind: AppKind.customer,
        apiBaseUrl: Uri.parse('http://localhost:4000'),
        clientType: clientType,
      ),
      dio: Dio()..httpClientAdapter = adapter,
    );
    api = AuthApi(client, clientType: clientType, deviceName: 'Pixel 9');
    manager = AuthSessionManager(
      api: api,
      client: client,
      tokenStore: AuthTokenStore(secureStore),
      clientType: clientType,
      logger: logger,
    );
    this.client = client;
    manager.states.listen(states.add);
  }

  final FakeHttpAdapter adapter;
  final InMemorySecureStore secureStore;
  final MemoryLogger logger = MemoryLogger();
  final List<AuthState> states = <AuthState>[];
  late final ApiClient client;
  late final AuthApi api;
  late final AuthSessionManager manager;

  List<String> get paths => adapter.requests.map((r) => r.path).toList();
}

const storedSession = <String, String>{
  AuthTokenStore.accessTokenKey: 'access-1',
  AuthTokenStore.refreshTokenKey: 'session-1.refresh-1',
  AuthTokenStore.sessionIdKey: 'session-1',
};

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('sign-in', () {
    test(
      'password sign-in stores the tokens in secure storage and publishes the user',
      () async {
        final h = Harness((_) async => FakeResponse.ok(tokens(1)));
        expect(h.manager.state, isA<AuthUnknown>());

        final result = await h.manager.signInWithPassword(
          identifier: 'asha@example.com',
          password: 'violet-river-lantern',
        );
        await settle();

        expect(result, isA<AuthenticatedSession>());
        final request = h.adapter.requests.single;
        expect(request.path, 'auth/login');
        expect(request.header('Authorization'), isNull);
        expect(request.body, {
          'identifier': 'asha@example.com',
          'password': 'violet-river-lantern',
          'device': {'clientType': 'MOBILE', 'deviceName': 'Pixel 9'},
        });
        expect(
          await h.secureStore.read(AuthTokenStore.accessTokenKey),
          'access-1',
        );
        expect(
          await h.secureStore.read(AuthTokenStore.refreshTokenKey),
          'session-1.refresh-1',
        );
        final state = h.manager.state as AuthSignedIn;
        expect(state.user.id, 'user-1');
        expect(state.sessionId, 'session-1');
        expect(h.states.single, isA<AuthSignedIn>());
      },
    );

    test('OTP flow: send, then verify', () async {
      final h = Harness((request) async {
        return request.path == 'auth/otp/send'
            ? FakeResponse.ok(<String, Object?>{
                'expiresInSeconds': 300,
                'resendAfterSeconds': 30,
              })
            : FakeResponse.ok(tokens(1));
      });
      final dispatch = await h.manager.sendOtp('+919876543210');
      expect(dispatch.resendAfterSeconds, 30);
      expect(h.adapter.requests.first.body, {
        'phone': '+919876543210',
        'purpose': 'SIGN_IN',
      });

      await h.manager.signInWithOtp(phone: '+919876543210', code: '123456');
      expect(h.adapter.requests.last.path, 'auth/otp/verify');
      expect(h.manager.state, isA<AuthSignedIn>());
    });

    test(
      'an account with MFA yields a challenge; nothing is stored until it is completed',
      () async {
        final h = Harness((request) async {
          return request.path == 'auth/login'
              ? FakeResponse.ok(<String, Object?>{
                  'mfaRequired': true,
                  'mfaToken': 'mfa-token',
                  'mfaTokenExpiresInSeconds': 300,
                })
              : FakeResponse.ok(tokens(1));
        });
        final result = await h.manager.signInWithPassword(
          identifier: 'a@b.co',
          password: 'p',
        );
        expect(result, isA<MfaChallenge>());
        expect(h.manager.state, isA<AuthUnknown>());
        expect(h.secureStore.keys, isEmpty);

        await h.manager.completeMfa(result as MfaChallenge, code: '654321');
        expect(h.adapter.requests.last.body, {
          'mfaToken': 'mfa-token',
          'code': '654321',
          'device': {'clientType': 'MOBILE', 'deviceName': 'Pixel 9'},
        });
        expect(h.manager.state, isA<AuthSignedIn>());
      },
    );

    test('registration sends the profile and terms acceptance', () async {
      final h = Harness((_) async => FakeResponse.ok(tokens(1)));
      await h.manager.register(
        const RegistrationRequest(
          phone: '+919876543210',
          code: '123456',
          name: 'Asha',
          acceptTerms: true,
          preferredLanguage: 'kn',
        ),
      );
      final body = h.adapter.requests.single.body! as Map;
      expect(body['acceptTerms'], isTrue);
      expect(body['marketingConsent'], isFalse);
      expect(body['preferredLanguage'], 'kn');
      expect(body.containsKey('email'), isFalse);
      expect(body.containsKey('password'), isFalse);
    });

    test('a failed sign-in changes nothing', () async {
      final h = Harness(
        (_) async => FakeResponse.error(401, ApiErrorCodes.invalidCredentials),
      );
      await expectLater(
        h.manager.signInWithPassword(identifier: 'a@b.co', password: 'wrong'),
        throwsA(isA<AppException>()),
      );
      expect(h.manager.state, isA<AuthUnknown>());
      expect(h.secureStore.keys, isEmpty);
    });

    test(
      'a malformed sign-in response is a server failure, not a session',
      () async {
        final h = Harness(
          (_) async =>
              FakeResponse.ok(<String, Object?>{'accessToken': 'only-this'}),
        );
        await expectLater(
          h.manager.signInWithPassword(identifier: 'a@b.co', password: 'p'),
          throwsA(
            isA<AppException>().having(
              (e) => e.failure,
              'failure',
              isA<ServerFailure>(),
            ),
          ),
        );
        expect(h.manager.state, isA<AuthUnknown>());
        expect(h.secureStore.keys, isEmpty);
      },
    );

    test('a session that must enrol MFA is flagged', () async {
      final h = Harness(
        (_) async => FakeResponse.ok(tokens(1, mfaEnrollment: true)),
      );
      await h.manager.signInWithPassword(
        identifier: 'staff@abra.test',
        password: 'p',
      );
      expect((h.manager.state as AuthSignedIn).mfaEnrollmentRequired, isTrue);
    });
  });

  group('restore at start-up', () {
    test('no stored session → signed out, no network call', () async {
      final h = Harness((_) async => FakeResponse.ok(null));
      final result = await h.manager.restore();
      expect(result.valueOrNull, const AuthSignedOut());
      expect(h.adapter.requests, isEmpty);
    });

    test('stored session → loads the profile', () async {
      final h = Harness((_) async => meResponse, stored: storedSession);
      await h.manager.restore();
      expect(h.manager.state, isA<AuthSignedIn>());
      expect(
        h.adapter.requests.single.header('Authorization'),
        'Bearer access-1',
      );
    });

    test(
      'expired access token → refreshes with rotation, then loads the profile',
      () async {
        final h = Harness((request) async {
          if (request.path == 'auth/refresh') return FakeResponse.ok(tokens(2));
          return request.header('Authorization') == 'Bearer access-1'
              ? FakeResponse.error(401, ApiErrorCodes.tokenExpired)
              : meResponse;
        }, stored: storedSession);

        await h.manager.restore();
        expect(h.paths, ['me', 'auth/refresh', 'me']);
        expect(h.adapter.requests[1].body, {
          'refreshToken': 'session-1.refresh-1',
        });
        // Rotation: the replaced refresh token is gone from storage
        expect(
          await h.secureStore.read(AuthTokenStore.refreshTokenKey),
          'session-1.refresh-2',
        );
        expect(
          await h.secureStore.read(AuthTokenStore.accessTokenKey),
          'access-2',
        );
        expect(h.manager.state, isA<AuthSignedIn>());
      },
    );

    test(
      'refresh token rejected → session expired and credentials erased',
      () async {
        final h = Harness((request) async {
          return request.path == 'auth/refresh'
              ? FakeResponse.error(401, ApiErrorCodes.unauthenticated)
              : FakeResponse.error(401, ApiErrorCodes.tokenExpired);
        }, stored: storedSession);

        final result = await h.manager.restore();
        expect(
          result.valueOrNull,
          const AuthSignedOut(SignedOutReason.sessionExpired),
        );
        expect(h.secureStore.keys, isEmpty);
      },
    );

    test(
      'offline → the session is kept and the failure is returned for a retry',
      () async {
        final h = Harness(
          (request) async => throw DioException(
            requestOptions: request.options,
            type: DioExceptionType.connectionError,
          ),
          stored: storedSession,
        );
        final result = await h.manager.restore();
        expect(result.failureOrNull, isA<NetworkFailure>());
        expect(h.manager.state, isA<AuthUnknown>());
        expect(h.secureStore.keys, hasLength(3));
      },
    );

    test(
      'web: no stored token, the HttpOnly cookie renews the session',
      () async {
        final h = Harness((request) async {
          return request.path == 'auth/refresh'
              ? FakeResponse.ok(tokens(1, web: true))
              : meResponse;
        }, clientType: ClientType.web);

        await h.manager.restore();
        final refresh = h.adapter.requests.first;
        expect(refresh.path, 'auth/refresh');
        expect(refresh.body, <String, Object?>{});
        expect(refresh.header('X-Abra-Client'), 'web');
        expect(h.manager.state, isA<AuthSignedIn>());
        // The refresh token never reaches app storage on web
        expect(
          await h.secureStore.read(AuthTokenStore.refreshTokenKey),
          isNull,
        );
      },
    );

    test('web: no valid cookie → signed out', () async {
      final h = Harness(
        (_) async => FakeResponse.error(401, ApiErrorCodes.unauthenticated),
        clientType: ClientType.web,
      );
      await h.manager.restore();
      expect(h.manager.state, isA<AuthSignedOut>());
    });
  });

  group('refresh', () {
    test(
      'concurrent refreshes share one request (rotation allows only one)',
      () async {
        final gate = Completer<void>();
        final h = Harness((request) async {
          await gate.future;
          return FakeResponse.ok(tokens(2));
        }, stored: storedSession);

        final first = h.manager.refreshAccessToken();
        final second = h.manager.refreshAccessToken();
        final third = h.manager.refreshAccessToken();
        gate.complete();

        expect(await Future.wait([first, second, third]), [true, true, true]);
        expect(h.paths, ['auth/refresh']);
      },
    );

    test(
      'a later refresh starts a new request with the rotated token',
      () async {
        var generation = 1;
        final h = Harness(
          (_) async => FakeResponse.ok(tokens(++generation)),
          stored: storedSession,
        );
        await h.manager.refreshAccessToken();
        await h.manager.refreshAccessToken();
        expect(
          h.adapter.requests.map((r) => (r.body! as Map)['refreshToken']),
          ['session-1.refresh-1', 'session-1.refresh-2'],
        );
      },
    );

    test(
      'server error or timeout during refresh does not sign the user out',
      () async {
        for (final response in [
          FakeResponse.error(503, ApiErrorCodes.serviceUnavailable),
          const FakeResponse(502, '<html>Bad Gateway</html>'),
        ]) {
          final h = Harness((_) async => response, stored: storedSession);
          await expectLater(
            h.manager.refreshAccessToken(),
            throwsA(isA<AppException>()),
          );
          expect(h.secureStore.keys, hasLength(3));
          expect(h.manager.state, isNot(isA<AuthSignedOut>()));
        }
      },
    );

    test('reuse detected by the server (401) ends the session', () async {
      final h = Harness(
        (_) async => FakeResponse.error(401, ApiErrorCodes.unauthenticated),
        stored: storedSession,
      );
      expect(await h.manager.refreshAccessToken(), isFalse);
      expect(
        h.manager.state,
        const AuthSignedOut(SignedOutReason.sessionExpired),
      );
      expect(h.secureStore.keys, isEmpty);
    });

    test('mobile without a refresh token cannot refresh', () async {
      final h = Harness((_) async => FakeResponse.ok(tokens(2)));
      expect(await h.manager.refreshAccessToken(), isFalse);
      expect(h.adapter.requests, isEmpty);
    });
  });

  group('sign-out and expiry', () {
    test(
      'sign-out revokes on the server with the refresh token and clears storage',
      () async {
        final h = Harness(
          (_) async => FakeResponse.ok(<String, Object?>{'signedOut': true}),
          stored: storedSession,
        );
        await h.manager.signOut();
        expect(h.adapter.requests.single.path, 'auth/logout');
        expect(h.adapter.requests.single.body, {
          'refreshToken': 'session-1.refresh-1',
        });
        expect(h.secureStore.keys, isEmpty);
        expect(h.manager.state, const AuthSignedOut());
      },
    );

    test(
      'sign-out still clears the device when the server is unreachable',
      () async {
        final h = Harness(
          (request) async => throw DioException(
            requestOptions: request.options,
            type: DioExceptionType.connectionError,
          ),
          stored: storedSession,
        );
        await h.manager.signOut();
        expect(h.secureStore.keys, isEmpty);
        expect(h.manager.state, const AuthSignedOut());
        expect(h.logger.entries.single.level, LogLevel.warning);
      },
    );

    test(
      'sign-out everywhere calls logout-all with the access token',
      () async {
        final h = Harness(
          (_) async =>
              FakeResponse.ok(<String, Object?>{'sessionsSignedOut': 3}),
          stored: storedSession,
        );
        await h.manager.signOutEverywhere();
        expect(h.adapter.requests.single.path, 'auth/logout-all');
        expect(
          h.adapter.requests.single.header('Authorization'),
          'Bearer access-1',
        );
        expect(h.manager.state, const AuthSignedOut());
      },
    );

    test(
      'a request rejected because the session was revoked expires the session',
      () async {
        final h = Harness(
          (_) async => FakeResponse.error(401, ApiErrorCodes.unauthenticated),
          stored: storedSession,
        );
        await expectLater(h.api.sessions(), throwsA(isA<AppException>()));
        await settle();
        expect(
          h.manager.state,
          const AuthSignedOut(SignedOutReason.sessionExpired),
        );
        expect(h.secureStore.keys, isEmpty);
      },
    );
  });

  group('credential handling', () {
    test('tokens are only ever written to the secure store', () async {
      final h = Harness((_) async => FakeResponse.ok(tokens(1)));
      await h.manager.signInWithPassword(identifier: 'a@b.co', password: 'p');
      expect(h.secureStore.keys, {
        AuthTokenStore.accessTokenKey,
        AuthTokenStore.refreshTokenKey,
        AuthTokenStore.sessionIdKey,
      });
      final logged = h.logger.entries
          .map((e) => '${e.message}${e.context}')
          .join();
      expect(logged, isNot(contains('access-1')));
      expect(logged, isNot(contains('refresh-1')));
    });

    test('AuthTokenStore round-trips and clears', () async {
      final store = AuthTokenStore(InMemorySecureStore());
      expect(await store.read(), isNull);
      await store.save(accessToken: 'a', refreshToken: 'r', sessionId: 's');
      expect(await store.read(), (
        accessToken: 'a',
        refreshToken: 'r',
        sessionId: 's',
      ));
      await store.save(accessToken: 'a2', refreshToken: '', sessionId: 's');
      expect((await store.read())!.refreshToken, isNull);
      await store.clear();
      expect(await store.read(), isNull);
    });
  });

  test('other endpoints: sessions, revoke, password reset', () async {
    final h = Harness((request) async {
      return switch (request.path) {
        'me/sessions' when request.method == 'GET' => FakeResponse.ok(<Object?>[
          <String, Object?>{
            'id': 'session-1',
            'current': true,
            'clientType': 'MOBILE',
            'deviceName': 'Pixel 9',
            'ip': null,
            'userAgent': null,
            'createdAt': null,
            'lastUsedAt': '2026-10-01T05:15:00.000Z',
            'expiresAt': '2026-10-31T05:15:00.000Z',
          },
        ]),
        'auth/otp/send' => FakeResponse.ok(<String, Object?>{
          'expiresInSeconds': 300,
          'resendAfterSeconds': 30,
        }),
        _ => FakeResponse.ok(<String, Object?>{}),
      };
    }, stored: storedSession);

    expect((await h.api.sessions()).single.current, isTrue);
    await h.api.revokeSession('session-2');
    await h.api.resetPassword(
      phone: '+919876543210',
      code: '123456',
      newPassword: 'violet-river-lantern',
    );
    await h.manager.sendOtp('+919876543210', purpose: OtpPurpose.passwordReset);

    expect(h.adapter.requests[1].method, 'DELETE');
    expect(h.adapter.requests[1].path, 'me/sessions/session-2');
    expect(h.adapter.requests[2].path, 'auth/password/reset');
    expect(h.adapter.requests[2].header('Authorization'), isNull);
    expect((h.adapter.requests[3].body! as Map)['purpose'], 'PASSWORD_RESET');
  });
}
