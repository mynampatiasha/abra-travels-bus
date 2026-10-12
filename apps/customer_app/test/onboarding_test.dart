import 'package:customer_app/features/language/language_screen.dart';
import 'package:customer_app/features/onboarding/first_launch.dart';
import 'package:customer_app/features/onboarding/onboarding_screen.dart';
import 'package:customer_app/routing/app_routes.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:customer_app/routing/route_guard.dart';
import 'package:customer_app/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';

import 'support/test_app.dart';

String locationOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
).read(customerRouterProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  group('first launch', () {
    testWidgets('a new device starts with the tour, after the splash '
        'screen', (tester) async {
      final app = TestApp(isFirstLaunch: true);
      await app.pump(tester);

      expect(locationOf(tester), AppRoutes.onboarding);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      // Nothing is asked of the server to show it.
      expect(app.requestedPaths, isEmpty);
    });

    testWidgets('Skip leads to the language step, then Home; the tour is not '
        'shown again', (tester) async {
      final app = TestApp(isFirstLaunch: true);
      await app.pump(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(locationOf(tester), AppRoutes.language);
      expect(find.byType(LanguageScreen), findsOneWidget);
      expect(app.preferences.getBool(WelcomeSeen.preferenceKey), isTrue);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.home);
      expect(find.byType(AppShell), findsOneWidget);

      // The next start of the app goes straight to Home.
      await app.pump(tester);
      expect(locationOf(tester), AppRoutes.home);
    });

    testWidgets('the last page of the tour leads to the language step', (
      tester,
    ) async {
      final app = TestApp(isFirstLaunch: true);
      await app.pump(tester);
      expect(find.text('Discover your next journey'), findsOneWidget);

      for (var page = 1; page < OnboardingStep.all.length; page++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      // Features that are not in the app yet are marked, not presented as
      // working.
      expect(find.text('Safety and support'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Next'), findsNothing);

      await tester.tap(find.text('Start exploring'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.language);
      expect(app.preferences.getBool(WelcomeSeen.preferenceKey), isTrue);
    });

    testWidgets('Skip is on every page of the tour', (tester) async {
      final app = TestApp(isFirstLaunch: true);
      await app.pump(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.language);
    });

    testWidgets('the tour and the language step fit small phones and wide '
        'screens', (tester) async {
      for (final size in const [
        Size(320, 568),
        Size(430, 932),
        Size(1366, 768),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final app = TestApp(isFirstLaunch: true);
        await app.pump(tester);
        expect(find.text('Skip'), findsOneWidget, reason: '$size');
        expect(tester.takeException(), isNull, reason: 'tour at $size');
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'language at $size');
      }
    });

    test('only a device that has not seen it is sent to the tour', () {
      String? start(AuthState auth, {required bool seen}) =>
          RouteGuard.redirect(
            auth: auth,
            location: Uri.parse(AppRoutes.splash),
            hasSeenOnboarding: seen,
          );
      expect(start(const AuthSignedOut(), seen: false), AppRoutes.onboarding);
      expect(start(const AuthSignedOut(), seen: true), AppRoutes.home);
      // A link still wins over the tour.
      expect(
        RouteGuard.redirect(
          auth: const AuthSignedOut(),
          location: Uri.parse('/splash?from=%2Fsearch'),
          hasSeenOnboarding: false,
        ),
        '/search',
      );
      // The tour and the language step are open without an account.
      for (final path in [AppRoutes.onboarding, AppRoutes.language]) {
        expect(
          RouteGuard.redirect(
            auth: const AuthSignedOut(),
            location: Uri.parse(path),
          ),
          isNull,
        );
      }
    });
  });

  group('sign-in', () {
    testWidgets('offers the mobile number only (no Google or Apple buttons)', (
      tester,
    ) async {
      final app = TestApp();
      await app.pump(tester);
      await tester.tap(
        find.descendant(of: find.byType(AppBar), matching: find.text('Log in')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('Apple'), findsNothing);
      expect(app.requestedPaths, isEmpty);
    });
  });
}
