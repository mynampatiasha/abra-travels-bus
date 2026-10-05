import 'dart:io';

import 'package:customer_app/bootstrap/app_dependencies.dart';
import 'package:customer_app/bootstrap/error_handling.dart';
import 'package:customer_app/core/async_value_view.dart';
import 'package:customer_app/l10n/customer_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_app.dart';

const launchLanguages = ['en', 'hi', 'te', 'kn', 'ta', 'ml', 'mr', 'bn'];

Map<String, String> arb(String tag) =>
    parseArb(File('l10n/customer_$tag.arb').readAsStringSync());

Future<void> pumpView(WidgetTester tester, Widget child) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('sign-in screen')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final config = AbraLocaleConfig();
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AbraTheme.light(),
      supportedLocales: config.supportedLocales,
      localizationsDelegates: [
        AbraLocalizationsDelegate(config: config, source: englishTranslations),
        ...GlobalMaterialLocalizations.delegates,
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('messages', () {
    test('CustomerStrings and the English resource have the same keys', () {
      final english = arb('en').keys.toSet();
      expect(CustomerStrings.all.difference(english), isEmpty);
      expect(english.difference(CustomerStrings.all), isEmpty);
    });

    test('app keys do not collide with the shared keys', () {
      expect(CustomerStrings.all.intersection(AbraStrings.all), isEmpty);
    });

    test(
      'other languages define no unknown keys and keep the placeholders',
      () {
        final english = arb('en');
        final placeholder = RegExp(r'\{(\w+)');
        Set<String> names(String message) =>
            placeholder.allMatches(message).map((m) => m.group(1)!).toSet();
        for (final tag in launchLanguages.skip(1)) {
          arb(tag).forEach((key, value) {
            expect(english.containsKey(key), isTrue, reason: '$tag:$key');
            expect(names(value), names(english[key]!), reason: '$tag:$key');
          });
        }
      },
    );

    testWidgets('the bundled resources load: app messages and shared '
        'messages, with English behind every launch language', (tester) async {
      final delegate = AbraLocalizationsDelegate(
        config: AbraLocaleConfig(),
        source: AppDependencies.bundledTranslations,
      );
      for (final tag in launchLanguages) {
        final l10n = await tester.runAsync(() => delegate.load(Locale(tag)));
        expect(
          l10n!.text(CustomerStrings.appName),
          'Abra Travels',
          reason: tag,
        );
        expect(l10n.text(AbraStrings.commonRetry), 'Try again', reason: tag);
        for (final key in CustomerStrings.all) {
          expect(l10n.has(key), isTrue, reason: '$tag:$key');
        }
        expect(l10n.missingKeys, isEmpty, reason: tag);
      }
    });
  });

  group('uncaught errors', () {
    test('are logged by type, without the error message', () {
      final logger = MemoryLogger();
      reportError(
        logger,
        StateError('card 4111 1111 1111 1111 for +919876543210'),
        StackTrace.current,
        source: 'framework',
      );

      final entry = logger.entries.single;
      expect(entry.level, LogLevel.error);
      expect(entry.context['type'], 'StateError');
      expect(entry.context['source'], 'framework');
      expect(entry.toString(), isNot(contains('4111')));
      expect(entry.toString(), isNot(contains('9876543210')));
    });

    testWidgets('framework and platform errors reach the logger, and the app '
        'keeps running', (tester) async {
      final logger = MemoryLogger();
      final previousFlutter = FlutterError.onError;
      final previousPlatform = PlatformDispatcher.instance.onError;
      final previousBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = previousFlutter;
        PlatformDispatcher.instance.onError = previousPlatform;
        ErrorWidget.builder = previousBuilder;
      });

      installErrorHandlers(logger, showDetails: false);
      final framework = FlutterError.onError!;
      final platform = PlatformDispatcher.instance.onError!;
      final fallback = ErrorWidget.builder(
        FlutterErrorDetails(exception: Exception('internal detail')),
      );
      // Restore before asserting so the test framework reports normally.
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
      ErrorWidget.builder = previousBuilder;

      framework(FlutterErrorDetails(exception: ArgumentError('token abc')));
      final handled = platform(
        const FormatException('otp 123456'),
        StackTrace.empty,
      );

      expect(handled, isTrue);
      expect(logger.entries.map((e) => e.context['type']), [
        'ArgumentError',
        'FormatException',
      ]);
      expect(logger.entries.map((e) => e.context['source']), [
        'framework',
        'platform',
      ]);
      expect(logger.entries.toString(), isNot(contains('abc')));
      expect(logger.entries.toString(), isNot(contains('123456')));

      // A widget that fails to build is replaced by a neutral box, never by
      // technical text - even outside the localized part of the app.
      expect(fallback, isA<BrokenWidgetFallback>());
      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: fallback),
      );
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('AsyncValueView (the network error boundary)', () {
    Widget view(AsyncValue<String> value, {VoidCallback? onRetry}) =>
        AsyncValueView<String>(
          value: value,
          onRetry: onRetry,
          data: (context, data) => Text('loaded $data'),
        );

    testWidgets('loading', (tester) async {
      await pumpView(tester, view(const AsyncLoading()));
      expect(find.byType(AbraLoadingView), findsOneWidget);
      expect(find.textContaining('loaded'), findsNothing);
    });

    testWidgets('data', (tester) async {
      await pumpView(tester, view(const AsyncData('trips')));
      expect(find.text('loaded trips'), findsOneWidget);
      expect(find.byType(AbraFailureView), findsNothing);
    });

    testWidgets('no connection: explains and retries', (tester) async {
      var retries = 0;
      await pumpView(
        tester,
        view(
          const AsyncError(AppException(NetworkFailure()), StackTrace.empty),
          onRetry: () => retries++,
        ),
      );
      expect(find.text('No internet connection'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    for (final (name, failure, title) in <(String, AppFailure, String)>[
      ('timeout', const TimeoutFailure(), 'This is taking too long'),
      ('502', const ServerFailure(statusCode: 502), 'Service unavailable'),
      (
        '500',
        const ApiFailure(
          code: ApiErrorCodes.internalError,
          message: 'MongoServerError: E11000 duplicate key',
          statusCode: 500,
          requestId: 'req-1',
        ),
        'Service unavailable',
      ),
      (
        '429',
        const ApiFailure(
          code: ApiErrorCodes.rateLimited,
          message: 'slow down',
          statusCode: 429,
          requestId: 'req-1',
        ),
        'Too many attempts',
      ),
    ]) {
      testWidgets('$name: shows the matching state, never the server text', (
        tester,
      ) async {
        await pumpView(
          tester,
          view(
            AsyncError(AppException(failure), StackTrace.empty),
            onRetry: () {},
          ),
        );
        expect(find.text(title), findsOneWidget);
        expect(find.textContaining('Mongo'), findsNothing);
        expect(find.textContaining('slow down'), findsNothing);
      });
    }

    testWidgets('403 and 404 offer no retry, because retrying cannot help', (
      tester,
    ) async {
      for (final (code, status, title) in [
        (ApiErrorCodes.permissionDenied, 403, 'No access'),
        (ApiErrorCodes.resourceNotFound, 404, 'Not found'),
      ]) {
        await pumpView(
          tester,
          view(
            AsyncError(
              ApiFailure(
                code: code,
                message: 'x',
                statusCode: status,
                requestId: 'req-1',
              ),
              StackTrace.empty,
            ),
            onRetry: () {},
          ),
        );
        expect(find.text(title), findsOneWidget);
        expect(find.byType(AbraButton), findsNothing);
      }
    });

    testWidgets('session ended: offers sign-in and goes there', (tester) async {
      await pumpView(
        tester,
        view(
          const AsyncError(
            AppException(SessionExpiredFailure()),
            StackTrace.empty,
          ),
          onRetry: () {},
        ),
      );
      expect(find.text('Session ended'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('sign-in screen'), findsOneWidget);
    });

    testWidgets('a programming error is shown as a generic problem, without '
        'its text', (tester) async {
      await pumpView(
        tester,
        view(AsyncError(StateError('null check on seat 14'), StackTrace.empty)),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('seat 14'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });

    test(
      'failureOf unwraps exceptions and never loses the kind of failure',
      () {
        const network = NetworkFailure();
        expect(failureOf(network), same(network));
        expect(failureOf(const AppException(network)), same(network));
        expect(failureOf(const FormatException('x')), isA<UnexpectedFailure>());
      },
    );
  });
}
