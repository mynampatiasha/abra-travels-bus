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

String? go(
  AuthState auth,
  String location, {
  bool hasSeenOnboarding = true,
  bool splashDone = true,
  String? pendingReturn,
}) => RouteGuard.redirect(
  auth: auth,
  location: Uri.parse(location),
  hasSeenOnboarding: hasSeenOnboarding,
  splashDone: splashDone,
  pendingReturn: pendingReturn,
);

/// Every location that needs an account. Guests are not redirected away
/// from them: the screen shows its guest card and the sign-in sheet.
const protectedLocations = <String>[
  '/bus/bus-7',
  '/trip/trip-7/points',
  '/seats',
  '/passenger-details',
  '/booking-review',
  '/payment',
  '/booking-success',
  '/ticket/tkt-1',
  '/my-trips/bk-1',
  '/support/contact',
  '/profile/edit',
  '/profile/notifications',
  '/notifications',
  '/cancel-booking',
  '/live-tracking',
  '/women-safety',
  '/settings',
  '/account-delete',
];

/// Open to guests.
const publicLocations = <String>[
  '/home',
  '/my-trips',
  '/support',
  '/profile',
  '/language',
  '/onboarding',
  '/terms',
  '/privacy',
  '/about',
  '/search',
  '/search/city?field=from',
  '/search/results?origin=a&destination=b&date=2026-10-09',
  '/trip/66f0c0ffee0000000000abcd',
  '/trip/66f0c0ffee0000000000abcd/seats',
];

void main() {
  group('which locations need an account', () {
    test('booking steps and personal screens do', () {
      for (final location in protectedLocations) {
        expect(
          AppRoutes.isPublic(Uri.parse(location).path),
          isFalse,
          reason: location,
        );
      }
    });

    test('a location nobody defined does too', () {
      expect(AppRoutes.isPublic('/admin'), isFalse);
    });

    test('browsing, the tabs and the information pages do not', () {
      for (final location in publicLocations) {
        expect(
          AppRoutes.isPublic(Uri.parse(location).path),
          isTrue,
          reason: location,
        );
      }
    });

    test('only the trip and its seat map are open under /trip', () {
      expect(AppRoutes.isPublic('/trip/t-1'), isTrue);
      expect(AppRoutes.isPublic('/trip/t-1/seats'), isTrue);
      for (final path in [
        '/trip/t-1/points',
        '/trip/t-1/book',
        '/trip/t-1/seats/extra',
        '/trip//seats',
        '/trips/t-1',
      ]) {
        expect(AppRoutes.isPublic(path), isFalse, reason: path);
      }
    });
  });

  group('the splash screen', () {
    test('stays until it has played', () {
      for (final auth in [unknown, signedOut, signedIn]) {
        expect(go(auth, '/splash', splashDone: false), isNull);
      }
    });

    test('then opens Home without waiting for the session check', () {
      expect(go(unknown, '/splash'), '/home');
      expect(go(signedOut, '/splash'), '/home');
      expect(go(signedIn, '/splash'), '/home');
    });

    test('opens the tour on the first launch', () {
      expect(go(signedOut, '/splash', hasSeenOnboarding: false), '/onboarding');
      expect(go(unknown, '/splash', hasSeenOnboarding: false), '/onboarding');
    });

    test('opens the location that was asked for', () {
      expect(go(signedOut, '/splash?from=%2Flanguage'), '/language');
      expect(go(unknown, '/splash?from=%2Ftrip%2Ft-1'), '/trip/t-1');
      expect(
        go(signedOut, '/splash?from=%2Fmy-trips%2Fbk-1'),
        '/my-trips/bk-1',
      );
    });

    test('holds a personal location until the session is known', () {
      expect(go(unknown, '/splash?from=%2Fmy-trips%2Fbk-1'), isNull);
      expect(go(signedIn, '/splash?from=%2Fmy-trips%2Fbk-1'), '/my-trips/bk-1');
    });

    test('opens the screen of a recent action that waited for sign-in', () {
      expect(go(signedOut, '/splash', pendingReturn: '/trip/t-1'), '/trip/t-1');
      // A link wins over it, and the tour comes first on a new device.
      expect(
        go(signedOut, '/splash?from=%2Fabout', pendingReturn: '/trip/t-1'),
        '/about',
      );
      expect(
        go(
          signedOut,
          '/splash',
          hasSeenOnboarding: false,
          pendingReturn: '/trip/t-1',
        ),
        '/onboarding',
      );
      // Only in-app locations are followed.
      expect(
        go(signedOut, '/splash', pendingReturn: 'https://evil.example'),
        '/home',
      );
    });
  });

  group('while the stored session is being checked', () {
    test('public locations open at once', () {
      for (final location in publicLocations) {
        expect(go(unknown, location), isNull, reason: location);
      }
    });

    test('a personal location waits on the splash screen and is '
        'remembered', () {
      expect(go(unknown, '/my-trips/bk-1'), '/splash?from=%2Fmy-trips%2Fbk-1');
      expect(go(unknown, '/payment'), '/splash?from=%2Fpayment');
    });
  });

  group('signed out', () {
    test('every location opens; personal ones show the sign-in gate in '
        'place', () {
      for (final location in [...publicLocations, ...protectedLocations]) {
        expect(go(signedOut, location), isNull, reason: location);
        expect(go(expired, location), isNull, reason: location);
      }
    });

    test('the sign-in page is open, and the old code page leads to it', () {
      expect(go(signedOut, '/login'), isNull);
      expect(go(signedOut, '/login?from=%2Fticket%2Ft1'), isNull);
      expect(
        go(signedOut, '/otp?from=%2Fticket%2Ft1'),
        '/login?from=%2Fticket%2Ft1',
      );
    });
  });

  group('signed in', () {
    test('every location is allowed', () {
      for (final location in [...publicLocations, ...protectedLocations]) {
        expect(go(signedIn, location), isNull, reason: location);
      }
    });

    test('the sign-in page leads into the app', () {
      expect(go(signedIn, '/login'), '/home');
      expect(go(signedIn, '/otp'), '/login');
      expect(go(signedIn, '/splash?from=%2Flogin'), '/home');
    });

    test('the remembered destination is opened after sign-in', () {
      expect(go(signedIn, '/login?from=%2Fticket%2Ftkt-1'), '/ticket/tkt-1');
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
      for (final from in ['/login', '/otp', '/splash']) {
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
      // A ticket link opened while the session was being checked.
      final atSplash = go(unknown, '/ticket/tkt-1')!;
      expect(atSplash, '/splash?from=%2Fticket%2Ftkt-1');
      expect(go(unknown, atSplash), isNull);
      expect(go(signedOut, atSplash), '/ticket/tkt-1');
    });
  });

  test('route helpers encode identifiers', () {
    expect(AppRoutes.ticket('TKT 1/2'), '/ticket/TKT%201%2F2');
    expect(AppRoutes.myTrip('bk-1'), '/my-trips/bk-1');
    expect(AppRoutes.bus('b1'), '/bus/b1');
    expect(AppRoutes.trip('t1'), '/trip/t1');
    expect(AppRoutes.tripSeats('t 1'), '/trip/t%201/seats');
  });
}
