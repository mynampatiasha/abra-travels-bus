import 'dart:async';

import 'package:customer_app/app/providers.dart';
import 'package:customer_app/features/authentication/field_error.dart';
import 'package:customer_app/features/authentication/gate/sign_in_flow.dart';
import 'package:customer_app/features/authentication/login_screen.dart';
import 'package:customer_app/features/authentication/otp_sign_in_controller.dart';
import 'package:customer_app/features/authentication/sign_in_problem.dart';
import 'package:customer_app/features/my_trips/booking_details_screen.dart';
import 'package:customer_app/features/unavailable/feature_unavailable_screen.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:customer_app/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_app.dart';

const phoneE164 = '+919876543210';
const maskedPhone = '+91******3210';
const code = '482915';

const incorrect = 'That code is incorrect. Please try again.';
const expired = 'That code has expired. Please request a new one.';
const tooMany = 'Too many attempts. Please try again later.';
const guestProfileMessage =
    'Book faster, find your tickets and manage your trips.';

/// A backend that answers the authentication endpoints like the real one.
/// Individual tests replace single answers.
class FakeAuthBackend {
  FakeResponse Function() send = otpSentResponse;
  FakeResponse Function(RecordedRequest request) verify = (_) => signInResponse;
  FakeResponse Function() logout = () => FakeResponse.ok(null);
  bool isOnline = true;

  Future<FakeResponse> call(RecordedRequest request) async {
    if (!isOnline) throw connectionError(request);
    return switch (request.path) {
      'auth/otp/send' => send(),
      'auth/otp/verify' => verify(request),
      'auth/logout' => logout(),
      'me' => currentUserResponse,
      _ => FakeResponse.error(404, 'RESOURCE_NOT_FOUND'),
    };
  }
}

String locationOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(customerRouterProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();

Future<void> open(WidgetTester tester, String location) async {
  ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).go(location);
  await tester.pumpAndSettle();
}

/// Lets a request that is in flight finish, then the UI settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

Finder get phoneField => find.descendant(
  of: find.byType(PhoneStep),
  matching: find.byType(TextField),
);
Finder get codeField => find.descendant(
  of: find.byType(CodeStep),
  matching: find.byType(TextField),
);

/// The code step is a step of the sign-in flow, not a location of its own.
Finder get codeStep => find.byType(CodeStep);

Future<void> requestCode(
  WidgetTester tester, [
  String number = '98765 43210',
]) async {
  await tester.enterText(phoneField, number);
  final button = find.widgetWithText(AbraButton, 'Continue');
  // Typing brings the field into view; let that finish before scrolling to
  // the button, or the two scrolls fight on a small screen.
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await settle(tester);
}

Future<void> enterCode(WidgetTester tester, String value) async {
  await tester.enterText(codeField, value);
  await settle(tester);
}

List<RecordedRequest> requestsTo(TestApp app, String path) =>
    app.adapter.requests.where((request) => request.path == path).toList();

String? errorOf(WidgetTester tester, Finder field) {
  final error = find.descendant(of: field, matching: find.byType(FieldError));
  return error.evaluate().isEmpty
      ? null
      : tester.widget<FieldError>(error).message;
}

bool isEnabled(WidgetTester tester, String label) =>
    tester
        .widget<AbraButton>(find.widgetWithText(AbraButton, label))
        .onPressed !=
    null;

void main() {
  late FakeAuthBackend backend;
  late TestApp app;

  Future<void> start(
    WidgetTester tester, {
    Map<String, String> stored = const {},
    Size size = const Size(400, 800),
  }) async {
    backend = FakeAuthBackend();
    app = TestApp(handler: (request) => backend(request), stored: stored);
    await app.pump(tester, size: size);
    tester.takeException();
    // Guests start on the home screen; these tests are about signing in.
    if (stored.isEmpty) await open(tester, '/login');
  }

  group('mobile number', () {
    testWidgets('an invalid number is rejected on the device, without a '
        'request', (tester) async {
      await start(tester);
      for (final number in [
        '',
        '12345',
        '98765 4321',
        '1234567890',
        '+1 202 555 0143',
        '987654321012',
      ]) {
        await requestCode(tester, number);
        expect(
          errorOf(tester, phoneField),
          'Enter a valid mobile number.',
          reason: number,
        );
        expect(locationOf(tester), '/login');
      }
      expect(requestsTo(app, 'auth/otp/send'), isEmpty);
    });

    testWidgets('the error disappears when the number is edited', (
      tester,
    ) async {
      await start(tester);
      await requestCode(tester, '123');
      expect(errorOf(tester, phoneField), isNotNull);
      await tester.enterText(phoneField, '9876');
      await tester.pump();
      expect(errorOf(tester, phoneField), isNull);
    });

    testWidgets('is sent in international form, with or without the country '
        'code typed', (tester) async {
      for (final typed in ['9876543210', '98765 43210', '+91 98765-43210']) {
        await start(tester);
        await requestCode(tester, typed);
        final request = requestsTo(app, 'auth/otp/send').single;
        expect((request.body! as Map)['phone'], phoneE164, reason: typed);
        expect((request.body! as Map)['purpose'], 'SIGN_IN');
        expect(request.header('Authorization'), isNull);
        expect(codeStep, findsOneWidget);
      }
    });

    testWidgets('repeated taps send one request and show progress', (
      tester,
    ) async {
      await start(tester);
      final answer = Completer<FakeResponse>();
      app.adapter.handler = (request) =>
          request.path == 'auth/otp/send' ? answer.future : backend(request);

      await tester.enterText(phoneField, '9876543210');
      await tester.tap(find.widgetWithText(AbraButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));

      answer.complete(otpSentResponse());
      await settle(tester);
      expect(requestsTo(app, 'auth/otp/send'), hasLength(1));
      expect(codeStep, findsOneWidget);
    });

    testWidgets('no connection: says so, and the same button retries', (
      tester,
    ) async {
      await start(tester);
      backend.isOnline = false;
      await requestCode(tester);
      expect(
        errorOf(tester, phoneField),
        'Check your connection and try again.',
      );
      expect(locationOf(tester), '/login');

      backend.isOnline = true;
      await tester.tap(find.widgetWithText(AbraButton, 'Continue'));
      await settle(tester);
      expect(codeStep, findsOneWidget);
    });

    testWidgets('rate limited: explains, shows the wait and blocks the button '
        'until it is over', (tester) async {
      await start(tester);
      backend.send = () => FakeResponse.error(
        429,
        'RATE_LIMITED',
        message: 'internal: bucket otp:send:phone exhausted',
        details: {'retryAfterSeconds': 45},
      );
      await requestCode(tester);

      expect(errorOf(tester, phoneField), tooMany);
      expect(find.text('Try again in 45 seconds'), findsOneWidget);
      expect(find.textContaining('bucket'), findsNothing);
      expect(isEnabled(tester, 'Continue'), isFalse);

      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Try again in 30 seconds'), findsOneWidget);
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await settle(tester);
      expect(requestsTo(app, 'auth/otp/send'), hasLength(1));

      backend.send = otpSentResponse;
      await tester.pump(const Duration(seconds: 31));
      expect(isEnabled(tester, 'Continue'), isTrue);
      await tester.tap(find.widgetWithText(AbraButton, 'Continue'));
      await settle(tester);
      expect(codeStep, findsOneWidget);
    });

    testWidgets('the code could not be sent on any channel', (tester) async {
      await start(tester);
      backend.send = () => FakeResponse.error(503, 'SERVICE_UNAVAILABLE');
      await requestCode(tester);
      expect(
        errorOf(tester, phoneField),
        'We could not send the code. Please try again shortly.',
      );
    });

    testWidgets('a server failure is reported without technical detail', (
      tester,
    ) async {
      await start(tester);
      backend.send = () => FakeResponse.error(
        500,
        'INTERNAL_ERROR',
        message: 'MongoServerError at OtpChallengeRepository',
      );
      await requestCode(tester);
      expect(
        errorOf(tester, phoneField),
        contains('Our service is having a problem'),
      );
      expect(find.textContaining('Mongo'), findsNothing);
    });
  });

  group('verification code', () {
    testWidgets('signing in: the code is verified by the backend, the session '
        'is stored securely and the app opens', (tester) async {
      await start(tester);
      await requestCode(tester);

      expect(
        find.text('We sent a 6-digit code on WhatsApp to $maskedPhone.'),
        findsOneWidget,
      );
      expect(find.textContaining('9876543210'), findsNothing);

      await enterCode(tester, code);

      final request = requestsTo(app, 'auth/otp/verify').single;
      expect(request.body, {
        'phone': phoneE164,
        'code': code,
        'device': {'clientType': 'MOBILE'},
      });
      expect(locationOf(tester), '/home');
      expect(find.byType(AppShell), findsOneWidget);
      expect(app.sessionManager.state, isA<AuthSignedIn>());

      // Tokens are in secure storage only.
      expect(
        await app.secureStore.read(AuthTokenStore.accessTokenKey),
        'access-1',
      );
      expect(
        await app.secureStore.read(AuthTokenStore.refreshTokenKey),
        'session-1.refresh-1',
      );
      expect(app.preferences.getString(AuthTokenStore.accessTokenKey), isNull);
      expect(app.preferences.getString(AuthTokenStore.refreshTokenKey), isNull);

      // Neither the code, the number nor the tokens reach the log.
      final log = app.logger.entries.toString();
      for (final secret in [code, '9876543210', 'access-1', 'refresh-1']) {
        expect(log, isNot(contains(secret)), reason: secret);
      }
    });

    testWidgets('says SMS when the backend fell back to SMS', (tester) async {
      await start(tester);
      backend.send = () => otpSentResponse(channel: 'SMS');
      await requestCode(tester);
      expect(
        find.text('We sent a 6-digit code by SMS to $maskedPhone.'),
        findsOneWidget,
      );
    });

    testWidgets('a pasted code with spaces is accepted', (tester) async {
      await start(tester);
      await requestCode(tester);
      await enterCode(tester, '482 915');
      expect(
        (requestsTo(app, 'auth/otp/verify').single.body! as Map)['code'],
        code,
      );
      expect(locationOf(tester), '/home');
    });

    testWidgets('an incomplete code is not sent', (tester) async {
      await start(tester);
      await requestCode(tester);
      await enterCode(tester, '4829');
      expect(isEnabled(tester, 'Verify'), isFalse);
      expect(requestsTo(app, 'auth/otp/verify'), isEmpty);
    });

    testWidgets('wrong code: says so, empties the field and lets the user '
        'try again', (tester) async {
      await start(tester);
      backend.verify = (request) => (request.body! as Map)['code'] == code
          ? signInResponse
          : FakeResponse.error(
              401,
              'OTP_INVALID',
              message: 'challenge 66f0 mismatch',
            );
      await requestCode(tester);

      await enterCode(tester, '000000');
      expect(errorOf(tester, codeField), incorrect);
      expect(tester.widget<TextField>(codeField).controller!.text, isEmpty);
      expect(find.textContaining('66f0'), findsNothing);
      expect(codeStep, findsOneWidget);
      expect(app.sessionManager.state, const AuthSignedOut());
      expect(await app.secureStore.read(AuthTokenStore.accessTokenKey), isNull);

      await enterCode(tester, code);
      expect(locationOf(tester), '/home');
    });

    testWidgets('expired code: says so before any request and offers a new '
        'one', (tester) async {
      await start(tester);
      await requestCode(tester);
      await tester.pump(const Duration(seconds: 301));

      expect(errorOf(tester, codeField), expired);
      await enterCode(tester, code);
      expect(requestsTo(app, 'auth/otp/verify'), isEmpty);
      expect(isEnabled(tester, 'Verify'), isFalse);

      await tester.tap(find.widgetWithText(AbraButton, 'Resend code'));
      await settle(tester);
      expect(requestsTo(app, 'auth/otp/send'), hasLength(2));
      expect(find.text('A new code has been sent.'), findsOneWidget);
      expect(errorOf(tester, codeField), isNull);

      await enterCode(tester, code);
      expect(locationOf(tester), '/home');
    });

    testWidgets('a code that ran out while being typed is reported as '
        'expired, not as incorrect', (tester) async {
      await start(tester);
      backend.send = () => otpSentResponse(expiresInSeconds: 60);
      backend.verify = (_) => FakeResponse.error(401, 'OTP_INVALID');
      await requestCode(tester);
      await tester.pump(const Duration(seconds: 59));
      // Sent with one second left; the answer arrives after the expiry.
      final answer = Completer<FakeResponse>();
      app.adapter.handler = (request) =>
          request.path == 'auth/otp/verify' ? answer.future : backend(request);
      await tester.enterText(codeField, code);
      await tester.pump(const Duration(seconds: 2));
      answer.complete(FakeResponse.error(401, 'OTP_INVALID'));
      await settle(tester);

      expect(errorOf(tester, codeField), expired);
    });

    testWidgets('resend is offered only after the interval the backend set', (
      tester,
    ) async {
      await start(tester);
      await requestCode(tester);

      expect(find.text('Resend code in 30 seconds'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Resend code'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Resend code in 20 seconds'), findsOneWidget);
      await tester.pump(const Duration(seconds: 19));
      expect(find.text('Resend code in 1 second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(AbraButton, 'Resend code'));
      await settle(tester);
      expect(requestsTo(app, 'auth/otp/send'), hasLength(2));
      expect(find.text('A new code has been sent.'), findsOneWidget);
      // The interval starts again.
      expect(find.text('Resend code in 30 seconds'), findsOneWidget);
    });

    testWidgets('resend refused by the backend: explains and waits as long as '
        'the backend says', (tester) async {
      await start(tester);
      await requestCode(tester);
      await tester.pump(const Duration(seconds: 30));
      backend.send = () => FakeResponse.error(
        429,
        'RATE_LIMITED',
        details: {'retryAfterSeconds': 600},
      );

      await tester.tap(find.widgetWithText(AbraButton, 'Resend code'));
      await settle(tester);
      expect(errorOf(tester, codeField), tooMany);
      expect(find.text('Resend code in 600 seconds'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Resend code'), findsNothing);
    });

    testWidgets('resend without a connection keeps the screen usable', (
      tester,
    ) async {
      await start(tester);
      await requestCode(tester);
      await tester.pump(const Duration(seconds: 30));
      backend.isOnline = false;
      await tester.tap(find.widgetWithText(AbraButton, 'Resend code'));
      await settle(tester);

      expect(
        errorOf(tester, codeField),
        'Check your connection and try again.',
      );
      backend.isOnline = true;
      await enterCode(tester, code);
      expect(locationOf(tester), '/home');
    });

    for (final (name, response, message) in [
      (
        'account locked',
        FakeResponse.error(
          423,
          'ACCOUNT_LOCKED',
          details: {'retryAfterSeconds': 900},
        ),
        tooMany,
      ),
      (
        'not a customer account',
        FakeResponse.error(403, 'PERMISSION_DENIED'),
        'This number belongs to an account that cannot sign in to this app.',
      ),
      (
        'disabled account',
        FakeResponse.error(403, 'ACCOUNT_DISABLED'),
        'This account has been disabled. Please contact support.',
      ),
      (
        'server failure',
        FakeResponse.error(
          500,
          'INTERNAL_ERROR',
          message: 'stack: at verify()',
        ),
        'Our service is having a problem. Please try again in a little while.',
      ),
    ]) {
      testWidgets('$name: a safe message, and no session', (tester) async {
        await start(tester);
        backend.verify = (_) => response;
        await requestCode(tester);
        await enterCode(tester, code);

        expect(errorOf(tester, codeField), message);
        expect(find.textContaining('stack'), findsNothing);
        expect(codeStep, findsOneWidget);
        expect(app.sessionManager.state, const AuthSignedOut());
      });
    }

    testWidgets('no connection while verifying: says so; the code can be '
        'entered again', (tester) async {
      await start(tester);
      await requestCode(tester);
      backend.isOnline = false;
      await enterCode(tester, code);
      expect(
        errorOf(tester, codeField),
        'Check your connection and try again.',
      );

      backend.isOnline = true;
      await enterCode(tester, code);
      expect(locationOf(tester), '/home');
    });

    testWidgets('"Change number" returns to the number step, with the '
        'number kept', (tester) async {
      await start(tester);
      await requestCode(tester);
      await tester.tap(find.text('Change number'));
      await settle(tester);
      expect(locationOf(tester), '/login');
      expect(find.byType(PhoneStep), findsOneWidget);
      expect(codeStep, findsNothing);
      expect(
        tester.widget<TextField>(phoneField).controller!.text,
        '9876543210',
      );
    });

    testWidgets('Back on the code step returns to the number step', (
      tester,
    ) async {
      await start(tester);
      await requestCode(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(PhoneStep), findsOneWidget);
      expect(locationOf(tester), '/login');
    });

    testWidgets('opened without a pending code, it goes to the number step', (
      tester,
    ) async {
      await start(tester);
      await open(tester, '/otp');
      expect(locationOf(tester), '/login');
    });
  });

  group('returning to where the user was heading', () {
    testWidgets('a protected link: the sheet opens over it; after the code '
        'the screen itself appears', (tester) async {
      await start(tester);
      await open(tester, '/my-trips/bk-1');
      expect(find.text('Log in or sign up'), findsOneWidget);

      await requestCode(tester);
      expect(codeStep, findsOneWidget);
      await enterCode(tester, code);
      expect(find.text('Log in or sign up'), findsNothing);
      expect(locationOf(tester), '/my-trips/bk-1');
      expect(find.byType(BookingDetailsScreen), findsOneWidget);
    });

    testWidgets('the sign-in page opens the destination in its link, also '
        'after "Change number"', (tester) async {
      await start(tester);
      await open(tester, '/login?from=%2Fticket%2Ftkt-1');
      await requestCode(tester);
      await tester.tap(find.text('Change number'));
      await settle(tester);
      expect(locationOf(tester), '/login?from=%2Fticket%2Ftkt-1');
      await requestCode(tester);
      await enterCode(tester, code);
      expect(locationOf(tester), '/ticket/tkt-1');
    });
  });

  group('session', () {
    testWidgets('a session ended by the server is explained on the sign-in '
        'screen', (tester) async {
      await start(tester, stored: storedSession);
      await open(tester, '/profile');
      await app.run(tester, app.sessionManager.onSessionRejected());

      expect(find.text('Session ended'), findsOneWidget);
      await tester.tap(find.widgetWithText(AbraButton, 'Log in / Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneStep), findsOneWidget);
      expect(
        find.text('Your session has ended. Please sign in again.'),
        findsOneWidget,
      );
      expect(locationOf(tester), '/profile');
    });

    testWidgets('the notice is not shown after an ordinary sign-out', (
      tester,
    ) async {
      await start(tester);
      expect(find.textContaining('session has ended'), findsNothing);
    });

    testWidgets('an expired access token is renewed without the user '
        'noticing', (tester) async {
      await start(tester, stored: storedSession);
      var meCalls = 0;
      app.adapter.handler = (request) async => switch (request.path) {
        'me' when meCalls++ == 0 => FakeResponse.error(401, 'TOKEN_EXPIRED'),
        'auth/refresh' => FakeResponse.ok(<String, Object?>{
          ...(signInResponse.body! as Map)['data'] as Map<String, Object?>,
          'accessToken': 'access-2',
          'refreshToken': 'session-1.refresh-2',
        }),
        _ => currentUserResponse,
      };
      await app.run(tester, app.sessionManager.reloadUser());

      expect(locationOf(tester), '/home');
      expect(
        await app.secureStore.read(AuthTokenStore.accessTokenKey),
        'access-2',
      );
      expect(
        await app.secureStore.read(AuthTokenStore.refreshTokenKey),
        'session-1.refresh-2',
      );
    });

    testWidgets('when the refresh is refused the user is signed out', (
      tester,
    ) async {
      await start(tester, stored: storedSession);
      app.adapter.handler = (request) async => switch (request.path) {
        'auth/refresh' => FakeResponse.error(401, 'UNAUTHENTICATED'),
        _ => FakeResponse.error(401, 'TOKEN_EXPIRED'),
      };
      await open(tester, '/profile');
      final reload = app.sessionManager.reloadUser().then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      await settle(tester);

      expect(await reload, isA<AppException>());
      expect(find.text('Session ended'), findsOneWidget);
      expect(locationOf(tester), '/profile');
      expect(
        await app.secureStore.read(AuthTokenStore.refreshTokenKey),
        isNull,
      );
    });
  });

  group('sign-out', () {
    Future<void> openProfile(WidgetTester tester) async {
      await start(tester, stored: storedSession);
      await open(tester, '/profile');
      expect(find.text('Signed in as'), findsOneWidget);
      expect(find.text('Asha'), findsOneWidget);
      expect(find.text(maskedPhone), findsOneWidget);
    }

    Future<void> confirmSignOut(WidgetTester tester) async {
      // At the end of the Profile list.
      await tester.scrollUntilVisible(
        find.widgetWithText(AbraButton, 'Sign out'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.widgetWithText(AbraButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await settle(tester);
    }

    testWidgets('ends the session on the server and on the device', (
      tester,
    ) async {
      await openProfile(tester);
      await confirmSignOut(tester);

      final request = requestsTo(app, 'auth/logout').single;
      expect((request.body! as Map)['refreshToken'], 'session-1.refresh-1');
      // Still on Profile, now as a guest.
      expect(locationOf(tester), '/profile');
      expect(find.text(guestProfileMessage), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      expect(app.sessionManager.state, const AuthSignedOut());
      expect(await app.secureStore.read(AuthTokenStore.accessTokenKey), isNull);
      expect(
        await app.secureStore.read(AuthTokenStore.refreshTokenKey),
        isNull,
      );
      expect(find.textContaining('session has ended'), findsNothing);
    });

    testWidgets('cancelling keeps the user signed in', (tester) async {
      await openProfile(tester);
      // At the end of the Profile list.
      await tester.scrollUntilVisible(
        find.widgetWithText(AbraButton, 'Sign out'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.widgetWithText(AbraButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(requestsTo(app, 'auth/logout'), isEmpty);
      expect(locationOf(tester), '/profile');
      expect(app.sessionManager.state, isA<AuthSignedIn>());
    });

    for (final (name, configure) in <(String, void Function(FakeAuthBackend))>[
      ('without a connection', (backend) => backend.isOnline = false),
      (
        'when the session is already invalid on the server',
        (backend) =>
            backend.logout = () => FakeResponse.error(401, 'UNAUTHENTICATED'),
      ),
      (
        'when the server fails',
        (backend) =>
            backend.logout = () => FakeResponse.error(500, 'INTERNAL_ERROR'),
      ),
    ]) {
      testWidgets('$name the device is still signed out', (tester) async {
        await openProfile(tester);
        configure(backend);
        await confirmSignOut(tester);

        expect(find.text(guestProfileMessage), findsOneWidget);
        expect(
          await app.secureStore.read(AuthTokenStore.accessTokenKey),
          isNull,
        );
        expect(
          await app.secureStore.read(AuthTokenStore.refreshTokenKey),
          isNull,
        );
      });
    }

    testWidgets('after sign-out the personal screens show the guest card', (
      tester,
    ) async {
      await openProfile(tester);
      await confirmSignOut(tester);
      await open(tester, '/profile/edit');
      expect(find.text('Log in to continue'), findsOneWidget);
      expect(find.byType(FeatureUnavailableBody), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('sign-in screens meet the tap-target, labelling and contrast '
        'guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      for (final step in ['number', 'code']) {
        if (step == 'code') await requestCode(tester);
        await expectLater(
          tester,
          meetsGuideline(androidTapTargetGuideline),
          reason: step,
        );
        await expectLater(
          tester,
          meetsGuideline(iOSTapTargetGuideline),
          reason: step,
        );
        await expectLater(
          tester,
          meetsGuideline(labeledTapTargetGuideline),
          reason: step,
        );
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: step,
        );
      }
      handle.dispose();
    });

    testWidgets('fields are labelled and an error is announced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      expect(find.bySemanticsLabel(RegExp('Mobile number')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(r'Country code \+91')), findsWidgets);

      await requestCode(tester, '123');
      final error = tester.getSemantics(
        find.text('Enter a valid mobile number.'),
      );
      expect(error.flagsCollection.isLiveRegion, isTrue);

      await requestCode(tester);
      expect(find.bySemanticsLabel(RegExp('Verification code')), findsWidgets);
      handle.dispose();
    });

    testWidgets('both steps fit a small phone with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await start(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      await requestCode(tester);
      expect(codeStep, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OtpSignInController', () {
    late DateTime now;
    late ProviderContainer container;

    void setUpContainer({Map<String, String> stored = const {}}) {
      backend = FakeAuthBackend();
      app = TestApp(handler: (request) => backend(request), stored: stored);
      now = DateTime.utc(2026, 10, 5, 12);
      container = ProviderContainer(
        overrides: [
          appDependenciesProvider.overrideWithValue(app.dependencies),
          signInClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
    }

    OtpSignInController controller() =>
        container.read(otpSignInControllerProvider.notifier);
    OtpSignInState state() => container.read(otpSignInControllerProvider);

    test('asking again for the same number inside the resend interval sends '
        'nothing new', () async {
      setUpContainer();
      expect(
        await controller().requestCode('9876543210'),
        SendCodeOutcome.codeSent,
      );
      now = now.add(const Duration(seconds: 10));
      expect(
        await controller().requestCode('98765 43210'),
        SendCodeOutcome.codeSent,
      );
      expect(requestsTo(app, 'auth/otp/send'), hasLength(1));

      // A different number is a new request.
      expect(
        await controller().requestCode('9876543211'),
        SendCodeOutcome.codeSent,
      );
      expect(requestsTo(app, 'auth/otp/send'), hasLength(2));
      expect(state().phone, '+919876543211');
    });

    test(
      'resend is refused before the interval ends and allowed after',
      () async {
        setUpContainer();
        await controller().requestCode('9876543210');
        expect(await controller().resend(), isFalse);
        now = now.add(const Duration(seconds: 30));
        expect(await controller().resend(), isTrue);
        expect(state().resentNotice, isTrue);
        expect(requestsTo(app, 'auth/otp/send'), hasLength(2));
      },
    );

    test('while the backend asked to wait, no request is sent', () async {
      setUpContainer();
      backend.send = () => FakeResponse.error(
        429,
        'RATE_LIMITED',
        details: {'retryAfterSeconds': 120},
      );
      expect(
        await controller().requestCode('9876543210'),
        SendCodeOutcome.rejected,
      );
      expect(state().problem, SignInProblem.tooManyAttempts);
      expect(state().retryAfterSeconds, 120);

      now = now.add(const Duration(seconds: 119));
      await controller().requestCode('9876543210');
      expect(requestsTo(app, 'auth/otp/send'), hasLength(1));
      now = now.add(const Duration(seconds: 2));
      backend.send = otpSentResponse;
      expect(
        await controller().requestCode('9876543210'),
        SendCodeOutcome.codeSent,
      );
    });

    test('a code of the wrong length or with letters never reaches the '
        'backend', () async {
      setUpContainer();
      await controller().requestCode('9876543210');
      for (final bad in ['', '12345', '1234567', '12a456']) {
        expect(await controller().verify(bad), isFalse, reason: bad);
        expect(state().problem, SignInProblem.codeIncorrect);
      }
      expect(requestsTo(app, 'auth/otp/verify'), isEmpty);
    });

    test('verifying without a requested code does nothing', () async {
      setUpContainer();
      expect(await controller().verify(code), isFalse);
      expect(app.adapter.requests, isEmpty);
    });

    test('the state never holds the code', () async {
      setUpContainer();
      backend.verify = (_) => FakeResponse.error(401, 'OTP_INVALID');
      await controller().requestCode('9876543210');
      await controller().verify(code);
      final s = state();
      expect(
        [
          s.phone,
          s.dispatch?.codeLength,
          s.problem,
          s.retryAfterSeconds,
        ].join(' '),
        isNot(contains(code)),
      );
    });

    test('an account with two-step verification is told it is not supported, '
        'and no session starts', () async {
      setUpContainer();
      backend.verify = (_) => FakeResponse.ok(<String, Object?>{
        'mfaRequired': true,
        'mfaToken': 'mfa-token-1',
        'mfaTokenExpiresInSeconds': 300,
      });
      await controller().requestCode('9876543210');
      expect(await controller().verify(code), isFalse);
      expect(state().problem, SignInProblem.twoStepNotSupported);
      expect(app.sessionManager.state, isNot(isA<AuthSignedIn>()));
      expect(await app.secureStore.read(AuthTokenStore.accessTokenKey), isNull);
    });
  });

  group('failures → messages', () {
    SignInProblem problem(
      AppFailure failure, {
      SignInStep step = SignInStep.verifyCode,
      bool codeExpired = false,
    }) => signInProblemFor(failure, step: step, codeExpired: codeExpired);

    ApiFailure api(String code, int status) => ApiFailure(
      code: code,
      message: 'server text',
      statusCode: status,
      requestId: 'req-1',
    );

    test('every failure has a problem the user can act on', () {
      expect(problem(const NetworkFailure()), SignInProblem.network);
      expect(problem(const TimeoutFailure()), SignInProblem.timeout);
      expect(
        problem(const ServerFailure(statusCode: 502)),
        SignInProblem.server,
      );
      expect(problem(const UnexpectedFailure('x')), SignInProblem.unexpected);
      expect(problem(api('OTP_INVALID', 401)), SignInProblem.codeIncorrect);
      expect(
        problem(api('OTP_INVALID', 401), codeExpired: true),
        SignInProblem.codeExpired,
      );
      expect(problem(api('RATE_LIMITED', 429)), SignInProblem.tooManyAttempts);
      expect(
        problem(api('ACCOUNT_LOCKED', 423)),
        SignInProblem.tooManyAttempts,
      );
      expect(
        problem(api('PERMISSION_DENIED', 403)),
        SignInProblem.notCustomerAccount,
      );
      expect(
        problem(api('ACCOUNT_DISABLED', 403)),
        SignInProblem.accountDisabled,
      );
      expect(
        problem(api('VALIDATION_FAILED', 400), step: SignInStep.sendCode),
        SignInProblem.invalidPhone,
      );
      expect(
        problem(api('VALIDATION_FAILED', 400)),
        SignInProblem.codeIncorrect,
      );
      expect(
        problem(api('SERVICE_UNAVAILABLE', 503), step: SignInStep.sendCode),
        SignInProblem.deliveryFailed,
      );
      expect(problem(api('SERVICE_UNAVAILABLE', 503)), SignInProblem.server);
      expect(problem(api('INTERNAL_ERROR', 500)), SignInProblem.server);
      expect(problem(api('SOMETHING_NEW', 418)), SignInProblem.unexpected);
    });

    testWidgets('every problem has a translated message', (tester) async {
      final messages = (await englishTranslations.load(const Locale('en')))!;
      await start(tester);
      final texts = <String>{};
      for (final value in SignInProblem.values) {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(LoginScreen)),
        );
        container.read(otpSignInControllerProvider.notifier).state =
            OtpSignInState(problem: value);
        await tester.pump();
        final text = errorOf(tester, phoneField);
        expect(text, isNotNull, reason: value.name);
        expect(messages.containsValue(text), isTrue, reason: value.name);
        texts.add(text!);
      }
      expect(texts.length, greaterThan(8));
    });
  });
}
