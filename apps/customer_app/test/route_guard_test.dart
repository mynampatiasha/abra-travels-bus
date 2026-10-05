import 'package:customer_app/routing/app_routes.dart';
import 'package:customer_app/routing/route_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_models/shared_models.dart';

import 'support/test_app.dart';

final AuthState signedIn = AuthSignedIn(
  user: UserProfile.fromJson(userJson),
  sessionId: 'session-1',
  mfaEnrollmentRequired: false,
);
const AuthState signedOut = AuthSignedOut();
const AuthState expired = AuthSignedOut(SignedOutReason.sessionExpired);
const AuthState unknown = AuthUnknown();

String? go(AuthState auth, String location) =>
    RouteGuard.redirect(auth: auth, location: Uri.parse(location));

/// Every location that needs a signed-in user.
const protectedLocations = <String>[
  '/home',
  '/search',
  '/search/results',
  '/bus/bus-7',
  '/trip/trip-7',
  '/seats',
  '/passenger-details',
  '/booking-review',
  '/payment',
  '/booking-success',
  '/ticket/tkt-1',
  '/my-trips',
  '/my-trips/bk-1',
  '/cancel-booking',
  '/live-tracking',
  '/women-safety',
  '/profile',
  '/settings',
  '/support',
  '/account-delete',
];

void main() {
  group('while the stored session is being checked', () {
    test('the splash screen stays', () {
      expect(go(unknown, '/splash'), isNull);
      expect(go(unknown, '/splash?from=%2Fmy-trips'), isNull);
    });

    test('every other location waits on the splash screen and is '
        'remembered', () {
      expect(go(unknown, '/my-trips/bk-1'), '/splash?from=%2Fmy-trips%2Fbk-1');
      expect(go(unknown, '/language'), '/splash?from=%2Flanguage');
      expect(go(unknown, '/home'), '/splash');
      expect(go(unknown, '/login'), '/splash');
    });
  });

  group('signed out', () {
    test('no protected location can be opened', () {
      for (final location in protectedLocations) {
        final redirect = go(signedOut, location);
        expect(redirect, isNotNull, reason: location);
        expect(Uri.parse(redirect!).path, AppRoutes.login, reason: location);
      }
    });

    test('a location nobody defined is protected too', () {
      expect(Uri.parse(go(signedOut, '/admin')!).path, AppRoutes.login);
    });

    test('sign-in remembers where the user was heading', () {
      expect(go(signedOut, '/ticket/tkt-1'), '/login?from=%2Fticket%2Ftkt-1');
      expect(
        go(signedOut, '/search/results?date=2026-10-09'),
        '/login?from=%2Fsearch%2Fresults%3Fdate%3D2026-10-09',
      );
      expect(go(signedOut, '/home'), '/login');
    });

    test('public locations are allowed', () {
      for (final location in ['/login', '/otp', '/onboarding', '/language']) {
        expect(go(signedOut, location), isNull, reason: location);
      }
    });

    test(
      'after start-up the user goes to sign-in, keeping the destination',
      () {
        expect(go(signedOut, '/splash'), '/login');
        expect(
          go(signedOut, '/splash?from=%2Fmy-trips'),
          '/login?from=%2Fmy-trips',
        );
        expect(go(signedOut, '/splash?from=%2Flanguage'), '/language');
      },
    );

    test('a session that ended on the server is guarded the same way', () {
      expect(go(expired, '/payment'), '/login?from=%2Fpayment');
      expect(go(expired, '/login'), isNull);
    });
  });

  group('signed in', () {
    test('every location is allowed', () {
      for (final location in [...protectedLocations, '/language']) {
        expect(go(signedIn, location), isNull, reason: location);
      }
    });

    test('start-up and sign-in screens lead into the app', () {
      for (final location in ['/splash', '/login', '/otp', '/onboarding']) {
        expect(go(signedIn, location), '/home', reason: location);
      }
    });

    test('the remembered destination is opened after sign-in', () {
      expect(go(signedIn, '/login?from=%2Fticket%2Ftkt-1'), '/ticket/tkt-1');
      expect(go(signedIn, '/splash?from=%2Fmy-trips%2Fbk-1'), '/my-trips/bk-1');
    });
  });

  group('the remembered destination', () {
    test('must be a location inside the app', () {
      for (final from in [
        'https://evil.example/login',
        '//evil.example',
        r'/\evil.example',
        'javascript:alert(1)',
        'home',
        '',
      ]) {
        final location = Uri(path: '/login', queryParameters: {'from': from});
        expect(RouteGuard.returnTo(location), isNull, reason: from);
        expect(
          RouteGuard.redirect(auth: signedIn, location: location),
          '/home',
          reason: from,
        );
      }
    });

    test('is never a start-up or sign-in screen (no redirect loops)', () {
      for (final from in ['/login', '/otp', '/splash', '/onboarding']) {
        expect(
          RouteGuard.returnTo(
            Uri(path: '/login', queryParameters: {'from': from}),
          ),
          isNull,
          reason: from,
        );
      }
    });

    test('is carried forward, not nested, across redirects', () {
      // Opened a ticket link while the session was being checked, then
      // turned out to be signed out, then signed in.
      final atSplash = go(unknown, '/ticket/tkt-1')!;
      final atLogin = go(signedOut, atSplash)!;
      expect(atLogin, '/login?from=%2Fticket%2Ftkt-1');
      expect(go(signedIn, atLogin), '/ticket/tkt-1');
    });
  });

  test('route helpers encode identifiers', () {
    expect(AppRoutes.ticket('TKT 1/2'), '/ticket/TKT%201%2F2');
    expect(AppRoutes.myTrip('bk-1'), '/my-trips/bk-1');
    expect(AppRoutes.bus('b1'), '/bus/b1');
    expect(AppRoutes.trip('t1'), '/trip/t1');
  });
}
