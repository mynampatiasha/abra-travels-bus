import 'dart:io';

import 'package:admin_app/app/providers.dart';
import 'package:admin_app/bootstrap/admin_environment.dart';
import 'package:admin_app/features/auth/sign_in_screen.dart';
import 'package:admin_app/features/catalogue/pages/trips_page.dart';
import 'package:admin_app/l10n/admin_strings.dart';
import 'package:admin_app/routing/admin_route_guard.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:admin_app/shell/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Finder field(String label) => find.widgetWithText(TextField, label);
Finder formField(String label) => find.widgetWithText(TextFormField, label);

/// The word in a table row, not in a summary card above the table that may use the same word.
Finder inTable(String text) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(text));
Finder navItem(String label) => find.descendant(
  of: find.byType(AdminShell),
  matching: find.widgetWithText(ListTile, label),
);

/// Brings [finder] into view (tables and forms scroll), then taps it.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// What is typed in the form field labelled [label].
String textIn(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(
        of: formField(label),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

Future<void> signIn(
  WidgetTester tester, {
  String email = 'staff@example.com',
  String password = 'correct-horse-battery',
}) async {
  await tester.enterText(field('Email'), email);
  await tester.enterText(field('Password'), password);
  await tapOn(tester, find.widgetWithText(AbraButton, 'Sign in'));
  await settle(tester);
}

Future<void> choose(WidgetTester tester, String label, String option) async {
  await tapOn(
    tester,
    find.widgetWithText(DropdownButtonFormField<String>, label).last,
  );
  await settle(tester);
  await tapOn(tester, find.text(option).last);
  await settle(tester);
}

Future<void> save(WidgetTester tester, [String label = 'Save']) async {
  // The form on top, when a dialog behind it has a button of the same name
  final button = find.widgetWithText(AbraButton, label).last;
  await tester.ensureVisible(button);
  await tester.pump();
  await tapOn(tester, button);
  await settle(tester);
}

/// A catalogue with two operators, as the backend would hold it.
FakeBackend seeded(Persona persona) {
  final backend = FakeBackend(persona);
  backend.of('operators').addAll([
    {
      'id': operatorAId,
      'companyName': 'Alpha Lines',
      'displayName': 'Alpha',
      'status': 'ACTIVE',
    },
    {
      'id': operatorBId,
      'companyName': 'Beta Travels',
      'displayName': null,
      'status': 'PENDING_APPROVAL',
    },
  ]);
  final bengaluru = backend.add('cities', {
    'name': 'Bengaluru',
    'state': 'Karnataka',
    'countryCode': 'IN',
    'slug': 'bengaluru',
    'isPopular': true,
    'sortOrder': 1,
    'isActive': true,
  });
  final tirupati = backend.add('cities', {
    'name': 'Tirupati',
    'state': 'Andhra Pradesh',
    'countryCode': 'IN',
    'slug': 'tirupati',
    'isPopular': false,
    'sortOrder': 0,
    'isActive': false,
  });
  final sleeper = backend.add('bus-types', {
    'key': 'AC_SLEEPER',
    'name': 'AC Sleeper',
    'isAc': true,
    'berthType': 'SLEEPER',
    'isActive': true,
  });
  final shared = backend.add('locations', {
    'cityId': bengaluru['id'],
    'operatorId': null,
    'name': 'Majestic',
    'address': 'Gandhi Nagar',
    'isActive': true,
  });
  final own = backend.add('locations', {
    'cityId': tirupati['id'],
    'operatorId': operatorAId,
    'name': 'Alpha office',
    'address': 'Main Road',
    'isActive': true,
  });
  backend.add('locations', {
    'cityId': bengaluru['id'],
    'operatorId': operatorBId,
    'name': 'Beta office',
    'address': 'Ring Road',
    'isActive': true,
  });
  final busA = backend.add('buses', {
    'operatorId': operatorAId,
    'registrationNumber': 'KA01AB1234',
    'name': 'Alpha Express',
    'busTypeId': sleeper['id'],
    'amenities': ['WIFI'],
    'seatCapacity': 36,
    'status': 'ACTIVE',
  });
  backend.add('buses', {
    'operatorId': operatorBId,
    'registrationNumber': 'KA02CD5678',
    'name': 'Beta Cruiser',
    'busTypeId': sleeper['id'],
    'amenities': <String>[],
    'seatCapacity': 40,
    'status': 'MAINTENANCE',
  });
  final routeA = backend.add('routes', {
    'operatorId': operatorAId,
    'name': 'Bengaluru to Tirupati',
    'originCityId': bengaluru['id'],
    'destinationCityId': tirupati['id'],
    'estimatedDurationMinutes': 300,
    'stops': <Object?>[],
    'status': 'ACTIVE',
  });
  Map<String, Object?> trip(String operatorId, String status, String date) => {
    'operatorId': operatorId,
    'busId': busA['id'],
    'routeId': routeA['id'],
    'status': status,
    'travelDate': date,
    'departureTime': '21:30',
    'departureAt': '2099-01-01T16:00:00.000Z',
    'durationMinutes': 300,
    'startingFarePaise': 85000,
    'bus': {
      'name': 'Alpha Express',
      'registrationNumber': 'KA01AB1234',
      'busTypeName': 'AC Sleeper',
    },
    'boardingPoints': [
      {
        'pointId': 'p1',
        'locationId': shared['id'],
        'name': 'Majestic',
        'offsetMinutes': 0,
      },
    ],
    'droppingPoints': [
      {
        'pointId': 'p2',
        'locationId': own['id'],
        'name': 'Alpha office',
        'offsetMinutes': 300,
      },
    ],
    'seatCounts': {'total': 0, 'available': 0},
    'cancellationReason': null,
  };
  backend
    ..add('trips', trip(operatorAId, 'DRAFT', '2099-01-01'))
    ..add('trips', trip(operatorAId, 'SCHEDULED', '2099-01-02'))
    ..add('trips', trip(operatorBId, 'DRAFT', '2099-01-03'));
  return backend;
}

void main() {
  group('sign-in', () {
    testWidgets('with nothing stored the sign-in screen opens and nothing is '
        'requested', (tester) async {
      final app = TestAdmin(FakeBackend(Persona.superAdmin));
      await app.pump(tester);

      expect(locationOf(tester), AdminRoutes.signIn);
      expect(find.text('Staff sign in'), findsOneWidget);
      expect(app.adapter.requests, isEmpty);
    });

    testWidgets('email and password are checked before anything is sent', (
      tester,
    ) async {
      final app = TestAdmin(FakeBackend(Persona.superAdmin));
      await app.pump(tester);
      await signIn(tester, email: 'not-an-email', password: '');

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(app.adapter.requests, isEmpty);
    });

    testWidgets('a Super Admin signs in, the permissions are loaded and the '
        'management area opens', (tester) async {
      final app = TestAdmin(seeded(Persona.superAdmin));
      await app.pump(tester);
      await signIn(tester);

      expect(app.requestsTo('auth/login').single.body, {
        'identifier': 'staff@example.com',
        'password': 'correct-horse-battery',
        'device': {'clientType': 'MOBILE'},
      });
      expect(app.requestsTo('me/permissions'), hasLength(1));
      expect(locationOf(tester), AdminRoutes.trips);
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('Asha Admin'), findsOneWidget);
      expect(find.text('All operators'), findsOneWidget);
      // Tokens in secure storage only; nothing sensitive in the log
      expect(
        await app.secureStore.read(AuthTokenStore.accessTokenKey),
        'access-SUPER_ADMIN',
      );
      expect(app.preferences.getString(AuthTokenStore.accessTokenKey), isNull);
      final log = app.logger.entries.toString();
      for (final secret in [
        'correct-horse-battery',
        'access-SUPER_ADMIN',
        'refresh-SUPER_ADMIN',
      ]) {
        expect(log, isNot(contains(secret)));
      }
    });

    testWidgets('a wrong password is explained and the password field is '
        'emptied', (tester) async {
      final app = TestAdmin(FakeBackend(Persona.superAdmin));
      await app.pump(tester);
      await signIn(tester, password: 'wrong-password');

      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Password')).controller!.text,
        isEmpty,
      );
      expect(locationOf(tester), AdminRoutes.signIn);
      expect(app.dependencies.sessionManager.state, isNot(isA<AuthSignedIn>()));
    });

    for (final (name, response, message) in [
      (
        'locked account',
        FakeResponse.error(423, 'ACCOUNT_LOCKED'),
        'Too many attempts. Try again later.',
      ),
      (
        'disabled account',
        FakeResponse.error(403, 'ACCOUNT_DISABLED'),
        'This account has been disabled.',
      ),
      (
        'server failure',
        FakeResponse.error(500, 'INTERNAL_ERROR', message: 'stack trace'),
        'Our service is having a problem',
      ),
    ]) {
      testWidgets('$name: a clear message, no technical detail', (
        tester,
      ) async {
        final backend = FakeBackend(Persona.superAdmin)
          ..overrides['POST auth/login'] = (_) => response;
        final app = TestAdmin(backend);
        await app.pump(tester);
        await signIn(tester);
        expect(find.textContaining(message), findsOneWidget);
        expect(find.textContaining('stack trace'), findsNothing);
      });
    }

    testWidgets('no connection is explained and signing in again works', (
      tester,
    ) async {
      final backend = seeded(Persona.superAdmin)..isOnline = false;
      final app = TestAdmin(backend);
      await app.pump(tester);
      await signIn(tester);
      expect(find.text('Check your connection and try again.'), findsOneWidget);

      backend.isOnline = true;
      await signIn(tester);
      expect(find.byType(AdminShell), findsOneWidget);
    });
  });

  group('two-step verification', () {
    Future<TestAdmin> toSecondStep(WidgetTester tester) async {
      final app = TestAdmin(seeded(Persona.superAdmin)..requireMfa = true);
      await app.pump(tester);
      await signIn(tester);
      expect(find.text('Two-step verification'), findsOneWidget);
      expect(find.byType(AdminShell), findsNothing);
      return app;
    }

    testWidgets('the code from the authenticator app completes the sign-in', (
      tester,
    ) async {
      final app = await toSecondStep(tester);
      await tester.enterText(field('Verification code'), '123456');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Verify'));
      await settle(tester);

      expect(
        app.requestsTo('auth/mfa/verify').single.body,
        allOf(
          containsPair('mfaToken', 'mfa-token'),
          containsPair('code', '123456'),
        ),
      );
      expect(find.byType(AdminShell), findsOneWidget);
    });

    testWidgets('a wrong code is refused and can be tried again', (
      tester,
    ) async {
      await toSecondStep(tester);
      await tester.enterText(field('Verification code'), '000000');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Verify'));
      await settle(tester);
      expect(
        find.text('That code is incorrect or has expired.'),
        findsOneWidget,
      );
      expect(find.byType(AdminShell), findsNothing);

      await tester.enterText(field('Verification code'), '123456');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Verify'));
      await settle(tester);
      expect(find.byType(AdminShell), findsOneWidget);
    });

    testWidgets('a recovery code works instead of the app', (tester) async {
      final app = await toSecondStep(tester);
      await tapOn(tester, find.text('Use a recovery code'));
      await tester.pump();
      await tester.enterText(field('Recovery code'), 'RECOVERY-1');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Verify'));
      await settle(tester);
      expect(
        app.requestsTo('auth/mfa/verify').single.body,
        allOf(
          containsPair('mfaToken', 'mfa-token'),
          containsPair('recoveryCode', 'RECOVERY-1'),
          isNot(contains('code')),
        ),
      );
      expect(find.byType(AdminShell), findsOneWidget);
    });

    testWidgets('going back returns to the password step', (tester) async {
      await toSecondStep(tester);
      await tapOn(tester, find.text('Back to sign in'));
      await tester.pump();
      expect(find.text('Staff sign in'), findsOneWidget);
    });

    testWidgets('an account that must still set up two-step verification is '
        'told so and gets no management screen', (tester) async {
      final app = TestAdmin(
        seeded(Persona.superAdmin)..mfaEnrollmentRequired = true,
      );
      await app.pump(tester);
      await signIn(tester);

      expect(find.text('Two-step verification must be set up'), findsOneWidget);
      expect(find.byType(AdminShell), findsNothing);
      expect(app.requestsTo('me/permissions'), isEmpty);
      await open(tester, AdminRoutes.trips);
      expect(find.byType(AdminShell), findsNothing);
    });
  });

  group('who may use the management app', () {
    for (final persona in [Persona.customer, Persona.driver]) {
      testWidgets('a ${persona.roleKey} account is refused, sees no management '
          'screen and can sign out', (tester) async {
        final app = TestAdmin(seeded(persona));
        await app.pump(tester);
        await signIn(tester);

        expect(
          find.text('This account cannot use the management app'),
          findsOneWidget,
        );
        expect(find.byType(AdminShell), findsNothing);
        // Not even the permissions are requested, let alone the catalogue
        expect(app.requestsTo('me/permissions'), isEmpty);
        expect(
          app.adapter.requests.where((r) => r.path.startsWith('catalogue/')),
          isEmpty,
        );
        for (final location in AdminRoutes.sections) {
          await open(tester, location);
          expect(find.byType(AdminShell), findsNothing, reason: location);
        }

        await tapOn(tester, find.widgetWithText(AbraButton, 'Sign out'));
        await settle(tester);
        expect(locationOf(tester), AdminRoutes.signIn);
        expect(
          await app.secureStore.read(AuthTokenStore.accessTokenKey),
          isNull,
        );
      });
    }

    testWidgets('a stored session opens the management area directly', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorAdmin));
      await app.pump(tester);
      expect(app.requestsTo('auth/login'), isEmpty);
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('Your operator'), findsOneWidget);
    });

    testWidgets('when the server ends the session the user is returned to '
        'sign-in with an explanation', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester);
      final ended = app.dependencies.sessionManager.onSessionRejected();
      await settle(tester);
      await ended;

      expect(locationOf(tester), AdminRoutes.signIn);
      expect(
        find.text('Your session has ended. Please sign in again.'),
        findsOneWidget,
      );
      expect(
        containerOf(tester).read(accessProvider).permissions.isEmpty,
        isTrue,
      );
    });

    testWidgets('signing out ends the session and forgets the permissions', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester);
      await tapOn(tester, find.byTooltip('Sign out'));
      await settle(tester);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Sign out'));
      await settle(tester);

      expect(app.requestsTo('auth/logout'), hasLength(1));
      expect(locationOf(tester), AdminRoutes.signIn);
      expect(app.dependencies.permissions.current.isEmpty, isTrue);
      await open(tester, AdminRoutes.buses);
      expect(locationOf(tester), AdminRoutes.signIn);
    });

    testWidgets('permissions that cannot be loaded show nothing, and a retry '
        'recovers', (tester) async {
      final backend = seeded(Persona.superAdmin)
        ..overrides['GET me/permissions'] = (_) =>
            FakeResponse.error(503, 'SERVICE_UNAVAILABLE');
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester);
      expect(find.text('Your access could not be loaded'), findsOneWidget);
      expect(find.byType(AdminShell), findsNothing);

      backend.overrides.clear();
      await tapOn(tester, find.widgetWithText(AbraButton, 'Try again'));
      await settle(tester);
      expect(find.byType(AdminShell), findsOneWidget);
    });
  });

  group('navigation follows permissions', () {
    Future<List<String>> sectionsFor(
      WidgetTester tester,
      Persona persona,
    ) async {
      final app = TestAdmin.signedIn(seeded(persona));
      await app.pump(tester);
      return [
        for (final label in [
          'Trips',
          'Buses',
          'Routes',
          'Locations',
          'Operators',
          'Cities and places',
          'Cities',
          'Bus types',
        ])
          if (navItem(label).evaluate().isNotEmpty) label,
      ];
    }

    testWidgets('Super Admin and Admin see every section', (tester) async {
      // Cities and Locations are tabs of "Cities and places" for them
      const all = [
        'Trips',
        'Buses',
        'Routes',
        'Operators',
        'Cities and places',
        'Bus types',
      ];
      expect(await sectionsFor(tester, Persona.superAdmin), all);
      expect(await sectionsFor(tester, Persona.admin), all);
    });

    testWidgets('Operator Admin and Operator Manager do not see the platform '
        'catalogue', (tester) async {
      expect(await sectionsFor(tester, Persona.operatorAdmin), [
        'Trips',
        'Buses',
        'Routes',
        'Locations',
        'Operators',
        'Bus types',
      ]);
      expect(await sectionsFor(tester, Persona.operatorManager), [
        'Trips',
        'Buses',
        'Routes',
        'Locations',
        'Bus types',
      ]);
    });

    testWidgets('support staff see only what they can read', (tester) async {
      expect(await sectionsFor(tester, Persona.support), [
        'Trips',
        'Buses',
        'Operators',
        'Bus types',
      ]);
    });

    testWidgets('a section typed into the address bar without its permission '
        'shows "no access" and requests nothing', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorManager));
      await app.pump(tester);
      for (final location in [AdminRoutes.cities, AdminRoutes.operators]) {
        await open(tester, location);
        expect(find.text('No access'), findsOneWidget, reason: location);
      }
      expect(app.requestsTo('catalogue/cities'), isEmpty);
      expect(app.requestsTo('catalogue/operators'), isEmpty);
    });

    testWidgets('choosing a section opens it', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester);
      await tapOn(tester, navItem('Cities and places'));
      await settle(tester);
      expect(locationOf(tester), AdminRoutes.places);
      expect(find.widgetWithText(AppBar, 'Cities and places'), findsOneWidget);
      expect(app.requestsTo('catalogue/locations'), isNotEmpty);
    });

    testWidgets('on a narrow screen the sections are in a drawer', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester, size: const Size(700, 900));
      expect(navItem('Cities and places'), findsNothing);
      await tapOn(tester, find.byTooltip('Open navigation menu'));
      await settle(tester);
      await tapOn(tester, find.widgetWithText(ListTile, 'Cities and places'));
      await settle(tester);
      expect(locationOf(tester), AdminRoutes.places);
      expect(tester.takeException(), isNull);
    });

    testWidgets('row actions stay on screen at laptop width', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      for (final size in const [Size(1366, 768), Size(1024, 768)]) {
        await app.pump(tester, size: size);
        for (final location in [
          AdminRoutes.buses,
          AdminRoutes.routes,
          AdminRoutes.locations,
          AdminRoutes.trips,
        ]) {
          await open(tester, location);
          final actions = find.descendant(
            of: find.byType(AdminShell),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  const {
                    'Edit',
                    'Change status',
                    'Disable',
                    'Enable',
                    'View',
                  }.contains(widget.tooltip),
            ),
          );
          expect(actions, findsWidgets, reason: location);
          for (final element in actions.evaluate()) {
            final box = tester.getRect(find.byWidget(element.widget));
            expect(
              box.left >= 0 && box.right <= size.width,
              isTrue,
              reason: '$location at ${size.width}: $box',
            );
          }
          expect(tester.takeException(), isNull, reason: location);
        }
      }
    });

    testWidgets('on a phone each record is a block with its actions', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester, size: const Size(390, 844));
      await open(tester, AdminRoutes.buses);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byTooltip('Edit'), findsWidgets);
      expect(find.byTooltip('Change status'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a reload keeps the open section', (tester) async {
      // A reload starts the app again at the address of the open section.
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.cities);
      expect(locationOf(tester), AdminRoutes.cities);

      final access = containerOf(tester).read(accessProvider);
      // While the session is checked the section travels with the address…
      final waiting = AdminRouteGuard.redirect(
        access: const AccessState(AccessLevel.pending),
        path: AdminRoutes.cities,
      );
      expect(waiting, '/splash?from=%2Fcities');
      // …and is where the user lands once access is known.
      expect(
        AdminRouteGuard.redirect(
          access: access,
          path: AdminRoutes.splash,
          from: Uri.parse(waiting!).queryParameters['from'],
        ),
        AdminRoutes.cities,
      );
      // Without a remembered section: the first one, as before.
      expect(
        AdminRouteGuard.redirect(access: access, path: AdminRoutes.splash),
        AdminRoutes.trips,
      );
    });

    testWidgets('a remembered section the user may not open is ignored', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorManager));
      await app.pump(tester);
      final access = containerOf(tester).read(accessProvider);
      expect(
        AdminRouteGuard.redirect(
          access: access,
          path: AdminRoutes.splash,
          from: AdminRoutes.cities,
        ),
        AdminRouteGuard.firstSection(access),
      );
    });

    test('the guard decides from permissions, never from a role name', () {
      const none = AccessState(AccessLevel.granted);
      expect(AdminRouteGuard.firstSection(none), isNull);
      expect(
        AdminRouteGuard.redirect(access: none, path: '/splash'),
        AdminRoutes.home,
      );
      expect(AdminRouteGuard.canOpen(none, AdminRoutes.trips), isFalse);
      expect(AdminRouteGuard.canOpen(none, '/unknown'), isFalse);
      for (final level in [
        AccessLevel.notStaff,
        AccessLevel.mfaSetupRequired,
        AccessLevel.failed,
      ]) {
        for (final path in AdminRoutes.sections) {
          expect(
            AdminRouteGuard.redirect(access: AccessState(level), path: path),
            AdminRoutes.home,
          );
        }
      }
      expect(
        AdminRouteGuard.redirect(
          access: const AccessState(AccessLevel.signedOut),
          path: '/trips',
        ),
        '/sign-in?from=%2Ftrips',
      );
      expect(
        AdminRouteGuard.redirect(
          access: const AccessState(AccessLevel.pending),
          path: '/trips',
        ),
        '/splash?from=%2Ftrips',
      );
      // Only a section is remembered, never an arbitrary address.
      expect(
        AdminRouteGuard.redirect(
          access: const AccessState(AccessLevel.pending),
          path: '/somewhere-else',
        ),
        AdminRoutes.splash,
      );
      expect(
        AdminRouteGuard.redirect(
          access: none,
          path: '/splash',
          from: '/cities',
        ),
        AdminRoutes.home,
      );
      expect(
        AdminRoutes.requiredPermission.values.toSet().difference(
          PermissionKeys.all,
        ),
        isEmpty,
        reason: 'every section uses a key of the shared registry',
      );
    });
  });

  group('cities', () {
    Future<TestAdmin> openCities(
      WidgetTester tester, [
      Persona? persona,
    ]) async {
      final app = TestAdmin.signedIn(seeded(persona ?? Persona.superAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.cities);
      return app;
    }

    testWidgets('are listed with their state and status', (tester) async {
      await openCities(tester);
      expect(find.text('Bengaluru'), findsOneWidget);
      expect(find.text('Andhra Pradesh'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Inactive'), findsWidgets);
      expect(find.text('1–2 of 2'), findsOneWidget);
    });

    testWidgets('search and the status filter are applied by the backend', (
      tester,
    ) async {
      final app = await openCities(tester);
      await tester.enterText(field('Search by name'), 'tir');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(app.requestsTo('catalogue/cities').last.options.queryParameters, {
        'page': 1,
        'pageSize': 20,
        'query': 'tir',
      });
      expect(find.text('Bengaluru'), findsNothing);
      expect(find.text('Tirupati'), findsOneWidget);

      await choose(tester, 'Status', 'Active');
      expect(
        app
            .requestsTo('catalogue/cities')
            .last
            .options
            .queryParameters['active'],
        'true',
      );
      expect(find.text('Nothing matches these filters.'), findsOneWidget);
    });

    testWidgets('are paged', (tester) async {
      final backend = seeded(Persona.superAdmin);
      for (var i = 0; i < 25; i++) {
        backend.add('cities', {
          'name': 'City $i',
          'state': 'S',
          'countryCode': 'IN',
          'slug': 'city-$i',
          'isPopular': false,
          'sortOrder': 0,
          'isActive': true,
        });
      }
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester);
      await open(tester, AdminRoutes.cities);
      expect(find.text('1–20 of 27'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );

      await tapOn(tester, find.byTooltip('Next page'));
      await settle(tester);
      expect(
        app.requestsTo('catalogue/cities').last.options.queryParameters['page'],
        2,
      );
      expect(find.text('21–27 of 27'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a city is created with validated input', (tester) async {
      final app = await openCities(tester);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));
      await settle(tester);
      expect(find.text('Add city'), findsOneWidget);

      await save(tester);
      expect(find.text('This field is required.'), findsNWidgets(2));
      expect(app.requestsTo('catalogue/cities', 'POST'), isEmpty);

      await tester.enterText(formField('Name'), ' Mysuru ');
      await tester.enterText(formField('State'), 'Karnataka');
      await tester.enterText(formField('Sort order'), '2.5');
      await save(tester);
      expect(find.text('Enter a whole number.'), findsOneWidget);
      await tester.enterText(formField('Sort order'), '2');
      await tester.enterText(formField('Latitude'), '12.2958');
      await tester.enterText(formField('Longitude'), '76.6394');
      await save(tester);

      expect(app.requestsTo('catalogue/cities', 'POST').single.body, {
        'name': 'Mysuru',
        'state': 'Karnataka',
        'isPopular': false,
        'sortOrder': 2,
        'latitude': 12.2958,
        'longitude': 76.6394,
      });
      expect(find.text('Add city'), findsNothing);
      expect(find.text('Mysuru'), findsOneWidget);
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('a rejection by the backend is shown in the form, which stays '
        'open with what was typed', (tester) async {
      final backend = seeded(Persona.superAdmin)
        ..overrides['POST catalogue/cities'] = (_) => FakeResponse.error(
          409,
          'ALREADY_REGISTERED',
          message: 'A city with this name already exists.',
        );
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester);
      await open(tester, AdminRoutes.cities);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));
      await settle(tester);
      await tester.enterText(formField('Name'), 'Bengaluru');
      await tester.enterText(formField('State'), 'Karnataka');
      await save(tester);

      expect(
        find.text('A city with this name already exists.'),
        findsOneWidget,
      );
      expect(find.text('Add city'), findsOneWidget);
      expect(textIn(tester, 'Name'), 'Bengaluru');
    });

    testWidgets('a city is edited and only its form fields are sent', (
      tester,
    ) async {
      final app = await openCities(tester);
      await tapOn(tester, find.byTooltip('Edit').first);
      await settle(tester);
      expect(find.text('Edit city'), findsOneWidget);
      await tester.enterText(formField('Name'), 'Bengaluru City');
      await save(tester);

      final request = app
          .requestsTo(
            'catalogue/cities/${app.backend.of('cities').first['id']}',
            'PUT',
          )
          .single;
      expect((request.body! as Map)['name'], 'Bengaluru City');
      expect((request.body! as Map).containsKey('slug'), isFalse);
      expect((request.body! as Map).containsKey('id'), isFalse);
      expect(find.text('Bengaluru City'), findsOneWidget);
    });

    testWidgets('disabling asks for confirmation first', (tester) async {
      final app = await openCities(tester);
      final id = app.backend.of('cities').first['id'];
      await tapOn(tester, find.byTooltip('Disable'));
      await settle(tester);
      expect(find.text('Disable Bengaluru?'), findsOneWidget);
      await tapOn(tester, find.text('Cancel'));
      await settle(tester);
      expect(app.requestsTo('catalogue/cities/$id/active'), isEmpty);

      await tapOn(tester, find.byTooltip('Disable'));
      await settle(tester);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Disable'));
      await settle(tester);
      expect(app.requestsTo('catalogue/cities/$id/active').single.body, {
        'active': false,
      });
      expect(find.byTooltip('Disable'), findsNothing);
      expect(find.byTooltip('Enable'), findsNWidgets(2));
    });

    testWidgets('loading failures are explained and can be retried', (
      tester,
    ) async {
      final backend = seeded(Persona.superAdmin);
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester);
      backend.overrides['GET catalogue/cities'] = (_) =>
          FakeResponse.error(500, 'INTERNAL_ERROR');
      await open(tester, AdminRoutes.cities);
      expect(find.text('Service unavailable'), findsOneWidget);
      backend.overrides.clear();
      await tapOn(tester, find.text('Try again'));
      await settle(tester);
      expect(find.text('Bengaluru'), findsOneWidget);
    });
  });

  group('read-only staff', () {
    testWidgets('see lists but no Add button and no row actions that change '
        'anything', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.support));
      await app.pump(tester);
      for (final location in [
        AdminRoutes.buses,
        AdminRoutes.operators,
        AdminRoutes.trips,
        AdminRoutes.busTypes,
      ]) {
        await open(tester, location);
        expect(
          find.widgetWithText(AbraButton, 'Add'),
          findsNothing,
          reason: location,
        );
        for (final tooltip in ['Edit', 'Disable', 'Enable', 'Change status']) {
          expect(
            find.byTooltip(tooltip),
            findsNothing,
            reason: '$location $tooltip',
          );
        }
      }
      // A trip can be viewed, without publish or cancel
      await open(tester, AdminRoutes.trips);
      await tapOn(tester, find.byTooltip('View').first);
      await settle(tester);
      expect(find.byType(TripDetailDialog), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Publish'), findsNothing);
      expect(find.widgetWithText(AbraButton, 'Cancel trip'), findsNothing);
      expect(
        app.adapter.requests.where(
          (r) => r.options.method != 'GET' && r.path.startsWith('catalogue/'),
        ),
        isEmpty,
      );
    });
  });

  group('operators', () {
    testWidgets('platform staff approve a pending operator, with a reason', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.operators);
      expect(inTable('Pending approval'), findsOneWidget);

      await tapOn(tester, find.byTooltip('Change status').last);
      await settle(tester);
      expect(find.text('Change operator status'), findsOneWidget);
      await choose(tester, 'Status', 'Active');
      await save(tester);
      expect(find.text('This field is required.'), findsOneWidget);
      await tester.enterText(formField('Reason'), 'Documents verified');
      await save(tester);

      expect(
        app.requestsTo('catalogue/operators/$operatorBId/status').single.body,
        {'status': 'ACTIVE', 'reason': 'Documents verified'},
      );
      expect(inTable('Pending approval'), findsNothing);
    });

    testWidgets('an Operator Admin sees only their operator and cannot change '
        'its status or register operators', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.operators);

      expect(find.text('Alpha Lines'), findsOneWidget);
      expect(find.text('Beta Travels'), findsNothing);
      expect(find.widgetWithText(AbraButton, 'Add'), findsNothing);
      expect(find.byTooltip('Change status'), findsNothing);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });
  });

  group('operator isolation', () {
    testWidgets('operator staff are shown only their own buses and trips, and '
        'are offered no operator filter', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.buses);

      expect(find.text('Alpha Express'), findsOneWidget);
      expect(find.text('Beta Cruiser'), findsNothing);
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Operator'),
        findsNothing,
      );
      for (final request in app.adapter.requests) {
        expect(
          request.options.queryParameters.containsKey('operatorId'),
          isFalse,
          reason: request.path,
        );
      }
      await open(tester, AdminRoutes.trips);
      expect(find.text('1–2 of 2'), findsOneWidget);
    });

    testWidgets('an operator adds a bus without choosing an operator: the '
        'request names none', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.buses);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));
      await settle(tester);

      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Operator'),
        findsNothing,
      );
      await tester.enterText(formField('Registration number'), 'KA05ZZ9999');
      await tester.enterText(formField('Name'), 'Alpha Night Rider');
      await choose(tester, 'Bus type', 'AC Sleeper');
      await tester.enterText(formField('Seat capacity'), '30');
      await tapOn(tester, find.widgetWithText(FilterChip, 'Wifi'));
      await tester.pump();
      await save(tester);

      final body =
          app.requestsTo('catalogue/buses', 'POST').single.body! as Map;
      expect(body.containsKey('operatorId'), isFalse);
      expect(body, {
        'registrationNumber': 'KA05ZZ9999',
        'name': 'Alpha Night Rider',
        'busTypeId': app.backend.of('bus-types').first['id'],
        'seatCapacity': 30,
        'amenities': ['WIFI'],
      });
      expect(find.text('Alpha Night Rider'), findsOneWidget);
    });

    testWidgets('platform staff choose the operator and can filter by it', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.buses);
      expect(find.text('Beta Cruiser'), findsOneWidget);

      await choose(tester, 'Operator', 'Beta Travels');
      expect(
        app
            .requestsTo('catalogue/buses')
            .last
            .options
            .queryParameters['operatorId'],
        operatorBId,
      );
      expect(find.text('Alpha Express'), findsNothing);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));
      await settle(tester);
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Operator'),
        findsWidgets,
      );
      await save(tester);
      expect(find.text('This field is required.'), findsWidgets);
    });

    testWidgets('locations: shared ones are marked and are read-only for '
        'operators; other operators\' locations are not shown', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.locations);

      expect(find.text('Majestic'), findsOneWidget);
      expect(find.text('Shared (platform)'), findsOneWidget);
      expect(find.text('Alpha office'), findsOneWidget);
      expect(find.text('Operator-owned'), findsOneWidget);
      expect(find.text('Beta office'), findsNothing);
      // One editable row: their own
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Disable'), findsOneWidget);
    });

    testWidgets(
      'platform staff see every location and can manage shared ones',
      (tester) async {
        final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
        await app.pump(tester);
        await open(tester, AdminRoutes.locations);
        expect(find.text('Beta office'), findsOneWidget);
        expect(find.byTooltip('Edit'), findsNWidgets(3));
      },
    );
  });

  group('buses and routes', () {
    testWidgets('a bus status is changed through a form', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.buses);
      final id = app.backend.of('buses').first['id'];
      await tapOn(tester, find.byTooltip('Change status'));
      await settle(tester);
      await choose(tester, 'Status', 'Maintenance');
      await tester.enterText(formField('Reason'), 'Service due');
      await save(tester);

      expect(app.requestsTo('catalogue/buses/$id/status').single.body, {
        'status': 'MAINTENANCE',
        'reason': 'Service due',
      });
      expect(inTable('Maintenance'), findsOneWidget);
    });

    testWidgets('a route is created with its stops by platform staff', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      app.backend.of('cities')[1]['isActive'] = true;
      final chittoor = app.backend.add('cities', {
        'name': 'Chittoor',
        'state': 'AP',
        'countryCode': 'IN',
        'slug': 'chittoor',
        'isPopular': false,
        'sortOrder': 0,
        'isActive': true,
      });
      await app.pump(tester);
      await open(tester, AdminRoutes.routes);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));
      await settle(tester);

      await choose(tester, 'Operator', 'Alpha');
      await choose(tester, 'Origin city', 'Bengaluru');
      await choose(tester, 'Destination city', 'Tirupati');
      await tester.enterText(formField('Name'), 'Via Chittoor');
      await tester.enterText(formField('Journey time (minutes)'), '300');
      await tapOn(tester, find.textContaining('Add: Stops'));
      await tester.pump();
      await choose(tester, 'City', 'Chittoor');
      await tester.enterText(formField('Minutes after departure'), '210');
      await save(tester);

      expect(app.requestsTo('catalogue/routes', 'POST').single.body, {
        'operatorId': operatorAId,
        'originCityId': app.backend.of('cities')[0]['id'],
        'destinationCityId': app.backend.of('cities')[1]['id'],
        'name': 'Via Chittoor',
        'estimatedDurationMinutes': 300,
        'stops': [
          {'cityId': chittoor['id'], 'offsetMinutes': 210},
        ],
      });
    });

    testWidgets('disabling a route asks for confirmation', (tester) async {
      final app = TestAdmin.signedIn(seeded(Persona.operatorAdmin));
      await app.pump(tester);
      await open(tester, AdminRoutes.routes);
      final id = app.backend.of('routes').first['id'];
      await tapOn(tester, find.byTooltip('Disable'));
      await settle(tester);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Disable'));
      await settle(tester);
      expect(app.requestsTo('catalogue/routes/$id/status').single.body, {
        'status': 'INACTIVE',
      });
    });
  });

  group('trips', () {
    Future<TestAdmin> openTrips(
      WidgetTester tester, [
      Persona persona = Persona.operatorAdmin,
    ]) async {
      final app = TestAdmin.signedIn(seeded(persona));
      await app.pump(tester);
      await open(tester, AdminRoutes.trips);
      return app;
    }

    testWidgets('are listed with their lifecycle status; only drafts can be '
        'edited', (tester) async {
      await openTrips(tester);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.byTooltip('View'), findsNWidgets(2));
      expect(find.byTooltip('Edit'), findsOneWidget);
    });

    testWidgets('a draft is created; the fare is entered in rupees and sent in '
        'paise', (tester) async {
      final app = await openTrips(tester);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));
      await settle(tester);
      expect(find.text('Create draft trip'), findsOneWidget);

      await save(tester);
      expect(find.text('This field is required.'), findsWidgets);
      expect(app.requestsTo('catalogue/trips', 'POST'), isEmpty);

      await choose(tester, 'Bus', 'Alpha Express (KA01AB1234)');
      await choose(tester, 'Route', 'Bengaluru to Tirupati');
      await tester.enterText(
        formField('Travel date (YYYY-MM-DD)'),
        '2099-02-01',
      );
      await tester.enterText(formField('Departure time (HH:mm)'), '21:30');
      await tester.enterText(formField('Lowest fare (rupees)'), '850.50');
      await tapOn(tester, find.textContaining('Add: Boarding points'));
      await tester.pump();
      await choose(tester, 'Location', 'Majestic');
      await tester.enterText(formField('Minutes after departure'), '0');
      final addDropping = find.textContaining('Add: Dropping points');
      await tester.ensureVisible(addDropping);
      await tapOn(tester, addDropping);
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(DropdownButtonFormField<String>, 'Location').last,
      );
      await choose(tester, 'Location', 'Alpha office');
      await tester.enterText(formField('Minutes after departure').last, '300');
      await save(tester);

      final body =
          app.requestsTo('catalogue/trips', 'POST').single.body! as Map;
      expect(body, {
        'busId': app.backend.of('buses').first['id'],
        'routeId': app.backend.of('routes').first['id'],
        'travelDate': '2099-02-01',
        'departureTime': '21:30',
        'startingFarePaise': 85050,
        'boardingPoints': [
          {
            'locationId': app.backend.of('locations')[0]['id'],
            'offsetMinutes': 0,
          },
        ],
        'droppingPoints': [
          {
            'locationId': app.backend.of('locations')[1]['id'],
            'offsetMinutes': 300,
          },
        ],
      });
      expect(body.containsKey('operatorId'), isFalse);
      expect(body.containsKey('status'), isFalse);
      // Only the operator's own and shared locations were offered
      expect(
        app
            .requestsTo('catalogue/locations')
            .last
            .options
            .queryParameters['active'],
        'true',
      );
    });

    testWidgets('the draft shows the publishing requirements as they are now', (
      tester,
    ) async {
      final app = await openTrips(tester);
      app.backend.of('buses').first['status'] = 'MAINTENANCE';
      await tapOn(tester, find.byTooltip('View').first);
      await settle(tester);

      expect(find.text('Publishing requirements'), findsOneWidget);
      // A draft has nothing on sale yet; it must not read as "0 of 0".
      expect(
        find.text('Not on sale yet. Seats open when the trip is published.'),
        findsOneWidget,
      );
      expect(find.textContaining('0 of 0'), findsNothing);
      String stateOf(String requirement) => tester
          .widget<Text>(
            find
                .descendant(
                  of: find.widgetWithText(ListTile, requirement),
                  matching: find.byType(Text),
                )
                .last,
          )
          .data!;
      expect(stateOf('Operator is active'), 'Met');
      expect(stateOf('Bus is active'), 'Not met');
      expect(stateOf('Bus has a seat capacity'), 'Met');
      expect(stateOf('Route is active'), 'Met');
      expect(stateOf('Boarding locations are active'), 'Met');
      await tester.scrollUntilVisible(
        find.text('Bus is free at this time'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(TripDetailDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // What the app cannot read is left to the server, and says so
      expect(
        stateOf('Bus is free at this time'),
        'Checked by the server on publishing',
      );
      expect(
        stateOf('Bus type is active'),
        'Checked by the server on publishing',
      );
    });

    testWidgets('publishing asks for confirmation, calls the backend and shows '
        'the new status', (tester) async {
      final app = await openTrips(tester);
      final id = app.backend.of('trips').first['id'];
      await tapOn(tester, find.byTooltip('View').first);
      await settle(tester);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Publish'));
      await settle(tester);
      expect(find.text('Publish this trip?'), findsOneWidget);
      await tapOn(tester, find.text('Cancel'));
      await settle(tester);
      expect(app.requestsTo('catalogue/trips/$id/publish'), isEmpty);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Publish'));
      await settle(tester);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Publish').last);
      await settle(tester);

      expect(app.requestsTo('catalogue/trips/$id/publish'), hasLength(1));
      expect(find.text('Trip published.'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Publish'), findsNothing);
      expect(find.text('Publishing requirements'), findsNothing);
      await tapOn(tester, find.text('Close'));
      await settle(tester);
      expect(find.text('Draft'), findsNothing);
      expect(find.text('Scheduled'), findsNWidgets(2));
    });

    testWidgets('when the backend refuses to publish, its reason is shown and '
        'the trip stays a draft', (tester) async {
      final app = await openTrips(tester);
      final id = app.backend.of('trips').first['id'];
      app.backend.overrides['POST catalogue/trips/$id/publish'] = (_) =>
          FakeResponse.error(
            400,
            'VALIDATION_FAILED',
            message: 'The bus is already on another trip during this time.',
          );
      await tapOn(tester, find.byTooltip('View').first);
      await settle(tester);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Publish'));
      await settle(tester);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Publish').last);
      await settle(tester);

      expect(find.text('The trip could not be published'), findsOneWidget);
      expect(
        find.text('The bus is already on another trip during this time.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AbraButton, 'Publish'), findsOneWidget);
      expect(app.backend.of('trips').first['status'], 'DRAFT');
    });

    testWidgets('cancelling needs a reason and takes the trip off sale', (
      tester,
    ) async {
      final app = await openTrips(tester);
      final id = app.backend.of('trips')[1]['id'];
      await tapOn(tester, find.byTooltip('View').last);
      await settle(tester);
      expect(find.widgetWithText(AbraButton, 'Publish'), findsNothing);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Cancel trip'));
      await settle(tester);
      expect(find.text('Cancel this trip?'), findsOneWidget);
      await save(tester, 'Cancel trip');
      expect(find.text('This field is required.'), findsOneWidget);
      expect(app.requestsTo('catalogue/trips/$id/cancel'), isEmpty);

      await tester.enterText(formField('Reason'), 'Bus breakdown');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Cancel trip').last);
      await settle(tester);

      expect(app.requestsTo('catalogue/trips/$id/cancel').single.body, {
        'reason': 'Bus breakdown',
      });
      expect(find.text('Trip cancelled.'), findsOneWidget);
      expect(find.text('Bus breakdown'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Cancel trip'), findsNothing);
    });

    testWidgets('a draft is edited', (tester) async {
      final app = await openTrips(tester);
      final id = app.backend.of('trips').first['id'];
      await tapOn(tester, find.byTooltip('Edit'));
      await settle(tester);
      expect(find.text('Edit draft trip'), findsOneWidget);
      expect(textIn(tester, 'Lowest fare (rupees)'), '850');
      await tester.enterText(formField('Departure time (HH:mm)'), '22:15');
      await save(tester);

      final body =
          app.requestsTo('catalogue/trips/$id', 'PUT').single.body! as Map;
      expect(body['departureTime'], '22:15');
      expect(body['startingFarePaise'], 85000);
      expect(body['boardingPoints'], [
        {
          'locationId': app.backend.of('locations')[0]['id'],
          'offsetMinutes': 0,
        },
      ]);
    });

    testWidgets('platform staff see the trips of every operator', (
      tester,
    ) async {
      await openTrips(tester, Persona.superAdmin);
      expect(find.text('1–3 of 3'), findsOneWidget);
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Operator'),
        findsOneWidget,
      );
    });
  });

  group('configuration and messages', () {
    test('the web build talks to the backend as a web client', () {
      const environment = AdminEnvironment(
        environmentName: 'development',
        apiBaseUrl: '',
      );
      final web = environment.toAppConfig(isWeb: true, isReleaseBuild: false);
      expect(web.appKind, AppKind.admin);
      expect(web.clientType, ClientType.web);
      expect(web.apiBaseUrl, Uri.parse('http://localhost:4000'));
      expect(
        environment
            .toAppConfig(
              isWeb: false,
              isReleaseBuild: false,
              platform: TargetPlatform.android,
            )
            .clientType,
        ClientType.mobile,
      );
      expect(
        () => const AdminEnvironment(
          environmentName: 'production',
          apiBaseUrl: 'http://api.example.com',
        ).toAppConfig(isWeb: true),
        throwsA(isA<ConfigurationException>()),
      );
      expect(
        () => environment.toAppConfig(isWeb: true, isReleaseBuild: true),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('AdminStrings and the English resource have the same keys', () {
      final english = parseArb(
        File('l10n/admin_en.arb').readAsStringSync(),
      ).keys.toSet();
      expect(AdminStrings.all.difference(english), isEmpty);
      expect(english.difference(AdminStrings.all), isEmpty);
      expect(AdminStrings.all.intersection(AbraStrings.all), isEmpty);
    });

    testWidgets('no screen showed a message key instead of text', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(seeded(Persona.superAdmin));
      await app.pump(tester);
      for (final location in AdminRoutes.sections) {
        await open(tester, location);
        final l10n = AbraLocalizations.of(
          tester.element(find.byType(AdminShell)),
        );
        expect(l10n.missingKeys, isEmpty, reason: location);
        expect(tester.takeException(), isNull, reason: location);
      }
      expect(find.byType(SignInScreen), findsNothing);
    });
  });
}
