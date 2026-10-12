import 'dart:ui' show SemanticsFlag;

import 'package:customer_app/app/providers.dart';
import 'package:customer_app/features/authentication/gate/require_sign_in.dart';
import 'package:customer_app/features/authentication/gate/sign_in_flow.dart';
import 'package:customer_app/features/authentication/gate/sign_in_intent.dart';
import 'package:customer_app/features/booking/boarding_dropping_screen.dart';
import 'package:customer_app/features/booking/seat_selection_screen.dart';
import 'package:customer_app/features/discovery/controllers/trip_selection_controller.dart';
import 'package:customer_app/features/discovery/screens/trip_details_screen.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:customer_app/routing/router_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_storage/shared_storage.dart';
import 'package:shared_ui/shared_ui.dart';

import 'discovery_test.dart'
    show FakeDiscoveryBackend, bengaluruId, isoDate, mysuruId, tripJson;
import 'support/test_app.dart';

const tripId = '66f0c0ffee0000000000abcd';
const code = '482915';

/// The discovery endpoints plus sign-in, like the backend.
class FakeBackend {
  final FakeDiscoveryBackend discovery = FakeDiscoveryBackend()
    ..trip = (_) => FakeResponse.ok(tripJson(tripId, _today, detail: true));

  static late DateTime _today;

  Future<FakeResponse> call(RecordedRequest request) async =>
      switch (request.path) {
        'auth/otp/send' => otpSentResponse(),
        'auth/otp/verify' => signInResponse,
        'me' => currentUserResponse,
        _ => await discovery(request),
      };
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

String locationOf(WidgetTester tester) =>
    topLocationOf(containerOf(tester).read(customerRouterProvider)).toString();

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, String location) async {
  containerOf(tester).read(customerRouterProvider).go(location);
  await settle(tester);
}

Finder get gateSheet => find.text('Log in or sign up');

Future<void> signInThroughSheet(WidgetTester tester) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(PhoneStep),
      matching: find.byType(TextField),
    ),
    '98765 43210',
  );
  await tester.pumpAndSettle();
  // The seat screen under the sheet has a "Continue" of its own.
  final send = find.descendant(
    of: find.byType(PhoneStep),
    matching: find.widgetWithText(AbraButton, 'Continue'),
  );
  await tester.ensureVisible(send);
  await tester.tap(send);
  await settle(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(CodeStep),
      matching: find.byType(TextField),
    ),
    code,
  );
  await settle(tester);
}

/// Opens the trip, chooses the second boarding point and taps "Select
/// seats": the seat map opens, for guests too.
Future<void> chooseAndSelectSeats(WidgetTester tester) async {
  await open(tester, '/trip/$tripId');
  final second = find.text('Second Stage');
  await tester.scrollUntilVisible(
    second,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(second);
  await tester.pumpAndSettle();
  await tester.tap(second);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(AbraButton, 'Select seats'));
  await settle(tester);
}

/// Taps seat [id] on the seat map.
Future<void> chooseSeat(WidgetTester tester, String id) async {
  final seat = find.descendant(
    of: find.byType(SeatSelectionScreen),
    matching: find.text(id),
  );
  await tester.ensureVisible(seat);
  await tester.tap(seat);
  await tester.pumpAndSettle();
}

/// Taps the "Continue" of the seat screen.
Future<void> tapSeatContinue(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SeatSelectionScreen),
      matching: find.widgetWithText(AbraButton, 'Continue'),
    ),
  );
  await settle(tester);
}

/// Guest path to the gate: trip, boarding point, seat map, one seat,
/// "Continue".
Future<void> chooseSeatAndContinue(WidgetTester tester) async {
  await chooseAndSelectSeats(tester);
  await chooseSeat(tester, 'L1');
  await tapSeatContinue(tester);
}

TripSelection selectionOf(WidgetTester tester) =>
    containerOf(tester).read(tripSelectionProvider(tripId));

void main() {
  late FakeBackend backend;
  late TestApp app;

  Future<void> start(
    WidgetTester tester, {
    Map<String, String> stored = const {},
    InMemoryPreferencesStore? preferences,
  }) async {
    FakeBackend._today = DateTime.utc(
      tester.binding.clock.now().year,
      tester.binding.clock.now().month,
      tester.binding.clock.now().day,
    );
    backend = FakeBackend();
    app = TestApp(
      handler: (request) => backend(request),
      stored: stored,
      devicePreferences: preferences,
    );
    await app.pump(tester);
  }

  group('guests', () {
    testWidgets('browse Home, results and a trip without a token', (
      tester,
    ) async {
      await start(tester);
      backend.discovery.trips = [tripJson(tripId, FakeBackend._today)];
      expect(locationOf(tester), '/home');
      await open(
        tester,
        '/search/results?origin=$bengaluruId&originName=Bengaluru'
        '&destination=$mysuruId&destinationName=Mysuru'
        '&date=${isoDate(FakeBackend._today)}',
      );
      expect(find.text('Abra Travels'), findsOneWidget);
      await open(tester, '/trip/$tripId');
      expect(find.byType(TripDetailsScreen), findsOneWidget);
      expect(gateSheet, findsNothing);
      for (final request in app.adapter.requests) {
        expect(request.header('Authorization'), isNull, reason: request.path);
      }
    });

    testWidgets('My trips shows a friendly guest card, not an error', (
      tester,
    ) async {
      await start(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('My trips'),
        ),
      );
      await settle(tester);
      expect(locationOf(tester), '/my-trips');
      expect(find.text('Log in to see your trips'), findsOneWidget);
      expect(find.byType(AbraFailureView), findsNothing);
      expect(gateSheet, findsNothing, reason: 'opens only when asked');

      await tester.tap(find.widgetWithText(AbraButton, 'Log in / Sign up'));
      await settle(tester);
      expect(gateSheet, findsOneWidget);
      await signInThroughSheet(tester);
      expect(gateSheet, findsNothing);
      expect(locationOf(tester), '/my-trips');
      expect(find.text('Log in to see your trips'), findsNothing);
    });

    testWidgets('Profile shows the "Log in / Sign up" card; language, help, '
        'terms, privacy and About still work', (tester) async {
      await start(tester);
      await open(tester, '/profile');
      expect(
        find.text('Book faster, find your tickets and manage your trips.'),
        findsOneWidget,
      );
      expect(find.text('Sign out'), findsNothing);
      for (final (item, title) in [
        ('Language', 'Language'),
        ('Terms & Conditions', 'Terms & Conditions'),
        ('Privacy Policy', 'Privacy Policy'),
        ('About Abra Travels', 'About Abra Travels'),
      ]) {
        await tester.scrollUntilVisible(
          find.text(item),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text(item));
        await settle(tester);
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text(title)),
          findsOneWidget,
          reason: item,
        );
        expect(gateSheet, findsNothing, reason: item);
        await tester.pageBack();
        await settle(tester);
        expect(locationOf(tester), '/profile');
      }
    });
  });

  group('the login gate', () {
    testWidgets('"Select seats" opens the seat map for a guest; "Continue" '
        'opens the gate and, after the code, the same seats are still '
        'chosen', (tester) async {
      await start(tester);
      await chooseAndSelectSeats(tester);
      expect(gateSheet, findsNothing, reason: 'looking is open to guests');
      expect(locationOf(tester), '/trip/$tripId/seats');
      expect(find.byType(SeatSelectionScreen), findsOneWidget);

      await chooseSeat(tester, 'L1');
      await tapSeatContinue(tester);
      expect(gateSheet, findsOneWidget);
      expect(locationOf(tester), '/trip/$tripId/seats');
      await signInThroughSheet(tester);

      expect(gateSheet, findsNothing);
      expect(app.sessionManager.state, isA<AuthSignedIn>());
      // Back on the same screen, nothing chosen again.
      expect(locationOf(tester), '/trip/$tripId/seats');
      expect(find.byType(SeatSelectionScreen), findsOneWidget);
      expect(selectionOf(tester).seatIds, ['L1']);
      expect(selectionOf(tester).boardingPointId, 'bp-2');
      expect(
        find.text('Logged in. Your seats are still selected'),
        findsOneWidget,
      );
      // The seat screen is a step above the trip: Close returns to it.
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(locationOf(tester), '/trip/$tripId');
      expect(selectionOf(tester).boardingPointId, 'bp-2');
    });

    testWidgets('signed in, "Continue" goes on to the boarding and dropping '
        'points at once', (tester) async {
      await start(tester, stored: storedSession);
      await chooseSeatAndContinue(tester);
      expect(gateSheet, findsNothing);
      expect(locationOf(tester), '/trip/$tripId/points');
      expect(find.byType(BoardingDroppingScreen), findsOneWidget);
    });

    testWidgets('cancelling keeps the customer where they were, with '
        'everything chosen', (tester) async {
      await start(tester);
      await chooseSeatAndContinue(tester);
      expect(gateSheet, findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SignInGateSheet),
          matching: find.byTooltip('Close'),
        ),
      );
      await settle(tester);
      expect(gateSheet, findsNothing);
      expect(locationOf(tester), '/trip/$tripId/seats');
      expect(find.byType(SeatSelectionScreen), findsOneWidget);
      expect(selectionOf(tester).seatIds, ['L1']);
      expect(selectionOf(tester).boardingPointId, 'bp-2');
      expect(app.sessionManager.state, isA<AuthSignedOut>());
      // Nothing is kept for a later start.
      expect(
        app.preferences.getString(PendingSignInIntent.preferenceKey),
        isNull,
      );
    });

    testWidgets('Back on the code step returns to the number; Back again '
        'closes the sheet', (tester) async {
      await start(tester);
      await chooseSeatAndContinue(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(PhoneStep),
          matching: find.byType(TextField),
        ),
        '98765 43210',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PhoneStep),
          matching: find.widgetWithText(AbraButton, 'Continue'),
        ),
      );
      await settle(tester);
      expect(find.byType(CodeStep), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(PhoneStep), findsOneWidget);
      expect(gateSheet, findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(gateSheet, findsNothing);
      expect(locationOf(tester), '/trip/$tripId/seats');
    });

    testWidgets('the seats survive the app being closed while the '
        'customer waits for the code', (tester) async {
      await start(tester);
      await chooseSeatAndContinue(tester);
      expect(gateSheet, findsOneWidget);
      final stored = app.preferences.getString(
        PendingSignInIntent.preferenceKey,
      );
      expect(stored, isNotNull);
      // Ids and counts only: no phone number, code or token.
      expect(stored, isNot(contains('9876')));
      expect(stored, isNot(contains('access')));

      // A new start of the app, with the same device settings.
      final preferences = app.preferences;
      await tester.pumpWidget(const SizedBox());
      await start(tester, preferences: preferences);

      expect(locationOf(tester), '/trip/$tripId/seats');
      expect(selectionOf(tester).seatIds, ['L1']);
      expect(selectionOf(tester).boardingPointId, 'bp-2');
      expect(gateSheet, findsOneWidget);
      await signInThroughSheet(tester);
      expect(locationOf(tester), '/trip/$tripId/seats');
      expect(selectionOf(tester).seatIds, ['L1']);
    });
  });

  group('a session the server ends', () {
    testWidgets('is announced on the screen the customer is on; public '
        'screens keep working', (tester) async {
      await start(tester, stored: storedSession);
      await open(tester, '/trip/$tripId');
      await app.run(tester, app.sessionManager.onSessionRejected());

      expect(find.text('Session ended'), findsOneWidget);
      expect(locationOf(tester), '/trip/$tripId');
      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(find.byType(TripDetailsScreen), findsOneWidget);
      expect(find.text('Abra Travels'), findsOneWidget);

      // "Log in" from the notice opens the gate and comes back here.
      await app.run(tester, Future<void>.value());
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.widgetWithText(AbraButton, 'Select seats'))
            .getSemanticsData()
            .hasFlag(SemanticsFlag.isEnabled),
        isTrue,
      );
      semantics.dispose();
    });
  });

  group('the kept intent', () {
    test('expires after 15 minutes and is ignored afterwards', () async {
      var now = DateTime.utc(2026, 10, 9, 10);
      final app = TestApp();
      final container = ProviderContainer(
        overrides: [
          appDependenciesProvider.overrideWithValue(app.dependencies),
          intentClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(pendingSignInIntentProvider.notifier)
          .save(const SignInIntent(returnLocation: '/trip/t-1'));
      expect(
        container.read(pendingSignInIntentProvider.notifier).fresh,
        isNotNull,
      );
      now = now.add(const Duration(minutes: 16));
      expect(
        container.read(pendingSignInIntentProvider.notifier).fresh,
        isNull,
      );

      // A new start drops what is too old.
      final restarted = ProviderContainer(
        overrides: [
          appDependenciesProvider.overrideWithValue(app.dependencies),
          intentClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(pendingSignInIntentProvider), isNull);
    });

    test('only in-app locations are ever followed', () {
      for (final location in ['https://evil.example', '//evil', r'/\x']) {
        expect(SignInIntent.isInAppLocation(location), isFalse);
      }
      expect(SignInIntent.isInAppLocation('/trip/t-1?x=1'), isTrue);
      expect(
        SignInIntent.tryParse(
          '{"returnLocation":"https://evil.example","createdAt":"2026-10-09"}',
        ),
        isNull,
      );
    });
  });
}
