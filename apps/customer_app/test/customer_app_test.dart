import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/startup_failure_app.dart';
import 'package:customer_app/features/language/language_screen.dart';
import 'package:customer_app/features/my_trips/booking_details_screen.dart';
import 'package:customer_app/features/startup/splash_screen.dart';
import 'package:customer_app/features/unavailable/feature_unavailable_screen.dart';
import 'package:customer_app/features/unavailable/page_not_found_screen.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:customer_app/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_app.dart';

GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
).read(customerRouterProvider);

String locationOf(WidgetTester tester) =>
    routerOf(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> open(WidgetTester tester, String location) async {
  routerOf(tester).go(location);
  await tester.pumpAndSettle();
}

const notBuiltLabel = 'Not available yet';

/// "Log in" in the shell's top bar (guests only).
Finder get logInInBar =>
    find.descendant(of: find.byType(AppBar), matching: find.text('Log in'));

/// The sign-in sheet (the login gate).
Finder get signInSheet => find.text('Log in or sign up');

void main() {
  group('start-up', () {
    testWidgets('with no stored session the app opens as a guest on the home '
        'screen, without calling the server', (tester) async {
      final app = TestApp();
      await app.pump(tester);

      expect(locationOf(tester), '/home');
      expect(find.byType(AppShell), findsOneWidget);
      expect(logInInBar, findsOneWidget);
      expect(app.requestedPaths, isEmpty);
      expect(app.sessionManager.state, const AuthSignedOut());
    });

    testWidgets('with a valid stored session the app opens the home shell', (
      tester,
    ) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);

      expect(app.requestedPaths, ['me']);
      expect(locationOf(tester), '/home');
      expect(find.byType(AppShell), findsOneWidget);
      expect(app.sessionManager.state, isA<AuthSignedIn>());
    });

    testWidgets('a stored session the server rejects is removed from the '
        'device; the app continues as a guest', (tester) async {
      final app = TestApp(
        stored: storedSession,
        handler: (_) async => FakeResponse.error(401, 'SESSION_REVOKED'),
      );
      await app.pump(tester);

      expect(locationOf(tester), '/home');
      expect(
        app.sessionManager.state,
        const AuthSignedOut(SignedOutReason.sessionExpired),
      );
      expect(await app.secureStore.read(AuthTokenStore.accessTokenKey), isNull);
      expect(
        await app.secureStore.read(AuthTokenStore.refreshTokenKey),
        isNull,
      );
      // No "session ended" sheet at start-up: the customer was not using
      // the session. Personal sections show the guest card; sign-in says
      // why it is needed again.
      expect(find.text('Session ended'), findsNothing);
      await open(tester, '/my-trips');
      expect(locationOf(tester), '/my-trips');
      expect(find.text('Log in to see your trips'), findsOneWidget);
      await tester.tap(find.widgetWithText(AbraButton, 'Log in / Sign up'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your session has ended. Please sign in again.'),
        findsOneWidget,
      );
    });

    testWidgets('without a connection the session is kept and the user can '
        'retry', (tester) async {
      var online = false;
      final app = TestApp(
        stored: storedSession,
        handler: (request) async =>
            online ? currentUserResponse : throw connectionError(request),
      );
      await app.pump(tester);

      // Browsing does not wait for the check.
      expect(locationOf(tester), '/home');
      expect(app.sessionManager.state, isA<AuthUnknown>());
      // A personal screen does, and offers the retry.
      await open(tester, '/my-trips/bk-1');
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(
        await app.secureStore.read(AuthTokenStore.refreshTokenKey),
        'session-1.refresh-1',
      );

      // Still offline: the failure stays, nothing crashes.
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No internet connection'), findsOneWidget);

      online = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/my-trips/bk-1');
      expect(app.sessionManager.state, isA<AuthSignedIn>());
    });

    testWidgets('a server failure at start-up is shown as such, with a retry', (
      tester,
    ) async {
      final app = TestApp(
        stored: storedSession,
        handler: (_) async => FakeResponse.error(503, 'SERVICE_UNAVAILABLE'),
      );
      await app.pump(tester);
      expect(locationOf(tester), '/home');
      await open(tester, '/ticket/t-1');

      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(locationOf(tester), startsWith('/splash'));
    });
  });

  group('authentication gate', () {
    testWidgets('a guest opening a personal screen stays there: the guest '
        'card is shown in its place and the sign-in sheet opens', (
      tester,
    ) async {
      final app = TestApp();
      await app.pump(tester);

      for (final location in ['/payment', '/ticket/tkt-1', '/my-trips/bk-1']) {
        await open(tester, location);
        expect(locationOf(tester), location);
        expect(signInSheet, findsOneWidget, reason: location);
        expect(find.byType(FeatureUnavailableBody), findsNothing);
        // Closing the sheet leaves the guest card, not the screen.
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(signInSheet, findsNothing);
        expect(find.text('Log in to continue'), findsOneWidget);
      }
    });

    testWidgets('after sign-in the screen they asked for appears', (
      tester,
    ) async {
      final app = TestApp();
      await app.pump(tester);
      await open(tester, '/my-trips/bk-1');
      expect(signInSheet, findsOneWidget);

      await app.signIn(tester);
      expect(signInSheet, findsNothing);
      expect(locationOf(tester), '/my-trips/bk-1');
      expect(find.byType(BookingDetailsScreen), findsOneWidget);
    });

    testWidgets('a deep link opened at launch survives the session check', (
      tester,
    ) async {
      final app = TestApp(stored: storedSession);
      tester.platformDispatcher.defaultRouteNameTestValue = '/ticket/tkt-9';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await app.pump(tester);

      expect(locationOf(tester), '/ticket/tkt-9');
      expect(signInSheet, findsNothing);
    });

    testWidgets('a signed-in user is not shown the sign-in page', (
      tester,
    ) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);

      await open(tester, '/login');
      expect(locationOf(tester), '/home');
    });

    testWidgets('when the server ends the session the customer stays where '
        'they are and is told so', (tester) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);
      await open(tester, '/payment');
      expect(find.byType(FeatureUnavailableScreen), findsOneWidget);

      // What the API client does when the server rejects the session.
      await app.run(tester, app.sessionManager.onSessionRejected());

      expect(locationOf(tester), '/payment');
      expect(find.text('Session ended'), findsOneWidget);
      expect(await app.secureStore.read(AuthTokenStore.accessTokenKey), isNull);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/payment');
      expect(find.text('Log in to continue'), findsOneWidget);
    });

    testWidgets('signing out keeps the customer in the app as a guest', (
      tester,
    ) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);
      await open(tester, '/my-trips');
      expect(logInInBar, findsNothing);

      app.adapter.handler = (_) async => FakeResponse.ok(null);
      await app.run(tester, app.sessionManager.signOut());
      expect(locationOf(tester), '/my-trips');
      expect(find.text('Log in to see your trips'), findsOneWidget);
      expect(find.text('Session ended'), findsNothing);

      await open(tester, '/home');
      expect(locationOf(tester), '/home');
      expect(logInInBar, findsOneWidget);
    });
  });

  group('app shell', () {
    testWidgets('switches between the four sections', (tester) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      for (final (label, location) in [
        ('My trips', '/my-trips'),
        ('Support', '/support'),
        ('Profile', '/profile'),
        ('Home', '/home'),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(locationOf(tester), location);
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text(label)),
          findsOneWidget,
        );
      }
    });

    testWidgets('uses a side rail on a tablet', (tester) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester, size: const Size(900, 1200));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/profile');
    });

    testWidgets('fits a small phone with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = TestApp(stored: storedSession);
      await app.pump(tester, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('survives rotation', (tester) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);
      await open(tester, '/my-trips');

      tester.view.physicalSize = const Size(800, 400);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(locationOf(tester), '/my-trips');
    });

    testWidgets('meets the tap-target, labelling and contrast guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = TestApp(stored: storedSession);
      await app.pump(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('screens that are not built yet', () {
    testWidgets('say so, and offer no controls', (tester) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);

      for (final (location, title) in [
        ('/bus/b-1', 'Bus details'),
        ('/seats', 'Choose seats'),
        ('/passenger-details', 'Passenger details'),
        ('/booking-review', 'Review booking'),
        ('/payment', 'Payment'),
        ('/booking-success', 'Booking'),
        ('/cancel-booking', 'Cancel booking'),
        ('/live-tracking', 'Live tracking'),
        ('/women-safety', 'Women Safety'),
        ('/settings', 'Settings'),
        ('/account-delete', 'Delete account'),
      ]) {
        await open(tester, location);
        final screen = find.byType(FeatureUnavailableScreen);
        expect(screen, findsOneWidget, reason: location);
        expect(find.text(title), findsWidgets, reason: location);
        expect(find.text(notBuiltLabel), findsOneWidget, reason: location);
        for (final control in [
          AbraButton,
          TextField,
          Checkbox,
          Switch,
          InkWell,
        ]) {
          expect(
            find.descendant(
              of: find.byType(FeatureUnavailableBody),
              matching: find.byType(control),
            ),
            findsNothing,
            reason: '$location has a $control',
          );
        }
      }
      expect(app.requestedPaths, ['me'], reason: 'no business API call');
    });

    testWidgets('the sections of the shell say so too', (tester) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);

      await open(tester, '/my-trips');
      expect(find.text('Upcoming (3)'), findsOneWidget);
      // The help centre has no articles yet; it says so.
      await open(tester, '/support');
      expect(find.text('Help centre'), findsWidgets);
      expect(find.text('Coming soon'), findsOneWidget);
    });
  });

  group('unknown locations', () {
    testWidgets('show "not found" with a way back into the app', (
      tester,
    ) async {
      final app = TestApp(stored: storedSession);
      await app.pump(tester);
      await open(tester, '/home');
      routerOf(tester).go('/no/such/page');
      await tester.pumpAndSettle();

      expect(find.byType(PageNotFoundScreen), findsOneWidget);
      expect(find.text('Not found'), findsOneWidget);
      await tester.tap(find.widgetWithText(AbraButton, 'Home'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/home');
    });
  });

  group('language', () {
    Future<TestApp> openLanguage(
      WidgetTester tester, {
      List<Locale> device = const [Locale('en')],
      TranslationSource? translations,
    }) async {
      final app = TestApp(
        stored: storedSession,
        deviceLocales: device,
        translations: translations,
      );
      await app.pump(tester);
      await tester.tap(find.byTooltip('Change language'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);
      return app;
    }

    testWidgets('lists the eight launch languages under their own names', (
      tester,
    ) async {
      await openLanguage(tester);
      for (final name in [
        'English',
        'हिन्दी',
        'తెలుగు',
        'ಕನ್ನಡ',
        'தமிழ்',
        'മലയാളം',
        'मराठी',
        'বাংলা',
      ]) {
        await tester.scrollUntilVisible(find.text(name), 100);
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('the choice applies at once, is stored, and is sent to the '
        'server', (tester) async {
      // Test data standing in for a reviewed Hindi translation.
      final translations = MemoryTranslationSource({
        'en': (await englishTranslations.load(const Locale('en')))!,
        'hi': {'languageTitle': 'LANGUAGE-HI'},
      });
      final app = await openLanguage(tester, translations: translations);
      expect(find.text('Language'), findsOneWidget);
      expect(app.dependencies.localeController.followsDevice, isTrue);

      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();

      expect(find.text('LANGUAGE-HI'), findsOneWidget);
      expect(app.preferences.getString('abra.preferences.locale_tag'), 'hi');
      // Not translated in the test data: English is shown, never a key.
      expect(find.text('Use device language'), findsOneWidget);

      await app.run(tester, app.sessionManager.reloadUser());
      expect(app.adapter.requests.last.header('Accept-Language'), 'hi');
    });

    testWidgets('an untranslated launch language shows English, not keys', (
      tester,
    ) async {
      final app = await openLanguage(tester);
      await tester.tap(find.text('தமிழ்'));
      await tester.pumpAndSettle();

      expect(app.dependencies.localeController.locale, const Locale('ta'));
      expect(find.text('Language'), findsOneWidget);
      expect(
        app.logger.entries.where((e) => e.message == 'Missing translation'),
        isEmpty,
      );
    });

    testWidgets('follows the device language until the user chooses', (
      tester,
    ) async {
      final app = await openLanguage(
        tester,
        device: const [Locale('kn', 'IN')],
      );
      final controller = app.dependencies.localeController;
      expect(controller.locale, const Locale('kn'));

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(controller.locale, const Locale('en'));

      await tester.tap(find.text('Use device language'));
      await tester.pumpAndSettle();
      expect(controller.locale, const Locale('kn'));
      expect(app.preferences.getString('abra.preferences.locale_tag'), isNull);
    });

    testWidgets('a right-to-left language mirrors the whole app', (
      tester,
    ) async {
      final config = AbraLocaleConfig(
        languages: const [
          SupportedLanguage(Locale('en'), 'English'),
          SupportedLanguage(Locale('ar'), 'العربية'),
        ],
      );
      // The launch languages are all left-to-right, so direction is checked
      // with the widgets the app is built from.
      await tester.pumpWidget(
        MaterialApp(
          theme: AbraTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: config.supportedLocales,
          localizationsDelegates: [
            AbraLocalizationsDelegate(
              config: config,
              source: englishTranslations,
            ),
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const FeatureUnavailableScreen(titleKey: 'routePaymentTitle'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(FeatureUnavailableBody))),
        TextDirection.rtl,
      );
      expect(find.text('Payment'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('when the app cannot start', () {
    testWidgets('a plain explanation is shown, with no technical detail and '
        'no dead buttons', (tester) async {
      await tester.pumpWidget(
        StartupFailureApp(translations: englishTranslations),
      );
      await tester.pumpAndSettle();

      expect(find.text('The app could not start'), findsOneWidget);
      expect(find.byType(AbraButton), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });

  test('the authentication state mirrors the shared session manager', () async {
    final app = TestApp();
    final container = ProviderContainer(
      overrides: [appDependenciesProvider.overrideWithValue(app.dependencies)],
    );
    addTearDown(container.dispose);
    final seen = <AuthState>[];
    container.listen(authStateProvider, (_, next) => seen.add(next));

    expect(container.read(authStateProvider), isA<AuthUnknown>());
    await app.sessionManager.restore();
    await Future<void>.delayed(Duration.zero);
    expect(seen.single, const AuthSignedOut());
    expect(container.read(authStateProvider), app.sessionManager.state);
  });
}
