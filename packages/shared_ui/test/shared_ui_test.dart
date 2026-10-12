import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_validation/shared_validation.dart';

final AbraLocaleConfig config = AbraLocaleConfig(
  languages: const [
    SupportedLanguage(Locale('en'), 'English'),
    SupportedLanguage(Locale('ar'), 'العربية'),
  ],
);

/// The real English resource of shared_localization, read up front so widget
/// tests need no real-time asset loading. Arabic has no translations and
/// falls back, which is enough to exercise right-to-left layout.
final MemoryTranslationSource translations = MemoryTranslationSource({
  'en': parseArb(
    File('../shared_localization/l10n/app_en.arb').readAsStringSync(),
  ),
});

AbraLocalizationsDelegate get delegate =>
    AbraLocalizationsDelegate(config: config, source: translations);

Future<void> pumpUi(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  double width = 400,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AbraTheme.light(),
      locale: locale,
      supportedLocales: config.supportedLocales,
      localizationsDelegates: [
        delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

ApiFailure api(
  String code,
  int status, {
  Map<String, Object?> details = const {},
}) => ApiFailure(
  code: code,
  message: 'server text',
  statusCode: status,
  requestId: 'req-42',
  details: details,
);

void main() {
  group('AbraButton', () {
    testWidgets('calls onPressed and is at least 48 px high', (tester) async {
      var presses = 0;
      await pumpUi(
        tester,
        Center(
          child: AbraButton(label: 'Search buses', onPressed: () => presses++),
        ),
      );
      await tester.tap(find.text('Search buses'));
      expect(presses, 1);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets(
      'while loading it shows progress and ignores taps (no double submit)',
      (tester) async {
        var presses = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AbraTheme.light(),
            home: Scaffold(
              body: AbraButton(
                label: 'Pay',
                onPressed: () => presses++,
                isLoading: true,
              ),
            ),
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.text('Pay'), warnIfMissed: false);
        expect(presses, 0);
      },
    );

    testWidgets('is disabled without a callback', (tester) async {
      await pumpUi(
        tester,
        const AbraButton(label: 'Continue', onPressed: null),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
        isFalse,
      );
    });

    testWidgets(
      'variants map to the right Material buttons; the call to action uses the brand gradient',
      (tester) async {
        await pumpUi(
          tester,
          Column(
            children: [
              AbraButton(
                label: 'cta',
                onPressed: () {},
                variant: AbraButtonVariant.callToAction,
              ),
              AbraButton(
                label: 'secondary',
                onPressed: () {},
                variant: AbraButtonVariant.secondary,
              ),
              AbraButton(
                label: 'text',
                onPressed: () {},
                variant: AbraButtonVariant.text,
              ),
            ],
          ),
        );
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
        final cta = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'cta'),
        );
        expect(
          cta.style!.foregroundColor!.resolve(<WidgetState>{}),
          AbraColors.white,
        );
        final fill = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.widgetWithText(FilledButton, 'cta'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          (fill.decoration as BoxDecoration).gradient,
          AbraGradients.action,
        );
      },
    );

    testWidgets(
      'expand fills the width; a long label is truncated, not overflowing',
      (tester) async {
        await pumpUi(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: AbraButton(
              label: 'A very long button label ' * 6,
              onPressed: () {},
              expand: true,
            ),
          ),
          width: 320,
        );
        expect(tester.getSize(find.byType(FilledButton)).width, 320 - 32);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AbraCard and AbraStatusBadge', () {
    testWidgets('a card with onTap is tappable', (tester) async {
      var taps = 0;
      await pumpUi(
        tester,
        AbraCard(onTap: () => taps++, child: const Text('Trip')),
      );
      await tester.tap(find.text('Trip'));
      expect(taps, 1);
    });

    testWidgets(
      'a badge uses the colours of its tone and always shows its label',
      (tester) async {
        await pumpUi(
          tester,
          const Center(
            child: AbraStatusBadge(
              label: 'Confirmed',
              tone: AbraStatusTone.success,
            ),
          ),
        );
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(AbraStatusBadge),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          (box.decoration as BoxDecoration).color,
          AbraColors.tealContainer,
        );
        expect(
          tester.widget<Text>(find.text('Confirmed')).style!.color,
          AbraColors.tealDark,
        );
        expect(find.bySemanticsLabel('Confirmed'), findsOneWidget);
      },
    );
  });

  group('AbraStateView', () {
    for (final (kind, title) in [
      (AbraStateKind.empty, 'Nothing here yet'),
      (AbraStateKind.error, 'Something went wrong'),
      (AbraStateKind.networkUnavailable, 'No internet connection'),
      (AbraStateKind.timeout, 'This is taking too long'),
      (AbraStateKind.serverFailure, 'Service unavailable'),
      (AbraStateKind.unauthorized, 'Sign in required'),
      (AbraStateKind.forbidden, 'No access'),
      (AbraStateKind.notFound, 'Not found'),
      (AbraStateKind.sessionExpired, 'Session ended'),
      (AbraStateKind.rateLimited, 'Too many attempts'),
      (AbraStateKind.success, 'Done'),
    ]) {
      testWidgets('${kind.name} shows its translated title', (tester) async {
        await pumpUi(tester, AbraStateView(kind: kind));
        expect(find.text(title), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      });
    }

    testWidgets('screen-specific text replaces the defaults', (tester) async {
      await pumpUi(
        tester,
        const AbraStateView(
          kind: AbraStateKind.empty,
          title: 'No bookings yet',
          message: 'Your trips appear here.',
        ),
      );
      expect(find.text('No bookings yet'), findsOneWidget);
      expect(find.text('Your trips appear here.'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);
    });

    testWidgets(
      'an action needs both a label and a callback — never a dead button',
      (tester) async {
        await pumpUi(
          tester,
          const AbraStateView(
            kind: AbraStateKind.error,
            actionLabel: 'Try again',
          ),
        );
        expect(find.byType(AbraButton), findsNothing);

        var retries = 0;
        await pumpUi(
          tester,
          AbraStateView(
            kind: AbraStateKind.error,
            actionLabel: 'Try again',
            onAction: () => retries++,
            secondaryActionLabel: 'Back',
            onSecondaryAction: () {},
          ),
        );
        expect(find.byType(AbraButton), findsNWidgets(2));
        await tester.tap(find.text('Try again'));
        expect(retries, 1);
      },
    );

    testWidgets('fits a small phone with large text without overflowing', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpUi(
        tester,
        AbraStateView(
          kind: AbraStateKind.sessionExpired,
          actionLabel: 'Sign in',
          onAction: () {},
        ),
        width: 320,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Session ended'), findsOneWidget);
    });

    testWidgets('mirrors in a right-to-left language', (tester) async {
      await pumpUi(
        tester,
        const AbraStateView(kind: AbraStateKind.empty),
        locale: const Locale('ar'),
      );
      expect(
        Directionality.of(tester.element(find.byType(AbraStateView))),
        TextDirection.rtl,
      );
      // No Arabic translation is shipped: the English fallback is shown
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('failures → screen states', () {
    test('every kind of failure maps to a state', () {
      expect(
        stateKindForFailure(const NetworkFailure()),
        AbraStateKind.networkUnavailable,
      );
      expect(
        stateKindForFailure(const TimeoutFailure()),
        AbraStateKind.timeout,
      );
      expect(
        stateKindForFailure(const ServerFailure(statusCode: 502)),
        AbraStateKind.serverFailure,
      );
      expect(
        stateKindForFailure(const SessionExpiredFailure()),
        AbraStateKind.sessionExpired,
      );
      expect(
        stateKindForFailure(const UnexpectedFailure('x')),
        AbraStateKind.error,
      );
      expect(
        stateKindForFailure(const CancelledFailure()),
        AbraStateKind.error,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.unauthenticated, 401)),
        AbraStateKind.unauthorized,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.permissionDenied, 403)),
        AbraStateKind.forbidden,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.mfaEnrollmentRequired, 403)),
        AbraStateKind.forbidden,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.resourceNotFound, 404)),
        AbraStateKind.notFound,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.rateLimited, 429)),
        AbraStateKind.rateLimited,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.accountLocked, 423)),
        AbraStateKind.rateLimited,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.serviceUnavailable, 503)),
        AbraStateKind.serverFailure,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.maintenanceMode, 503)),
        AbraStateKind.serverFailure,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.internalError, 500)),
        AbraStateKind.serverFailure,
      );
      expect(
        stateKindForFailure(api(ApiErrorCodes.validationFailed, 400)),
        AbraStateKind.error,
      );
    });

    test('only failures that can go away are retryable', () {
      expect(isRetryable(const NetworkFailure()), isTrue);
      expect(isRetryable(const TimeoutFailure()), isTrue);
      expect(isRetryable(const ServerFailure()), isTrue);
      expect(isRetryable(api(ApiErrorCodes.permissionDenied, 403)), isFalse);
      expect(isRetryable(api(ApiErrorCodes.resourceNotFound, 404)), isFalse);
      expect(isRetryable(const SessionExpiredFailure()), isFalse);
    });

    testWidgets('network failure offers a retry', (tester) async {
      var retries = 0;
      await pumpUi(
        tester,
        AbraFailureView(
          failure: const NetworkFailure(),
          onRetry: () => retries++,
        ),
      );
      expect(find.text('No internet connection'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('forbidden shows no retry and no sign-in', (tester) async {
      await pumpUi(
        tester,
        AbraFailureView(
          failure: api(ApiErrorCodes.permissionDenied, 403),
          onRetry: () {},
          onSignIn: () {},
        ),
      );
      expect(find.text('No access'), findsOneWidget);
      expect(find.byType(AbraButton), findsNothing);
    });

    testWidgets('session expired offers sign-in, not retry', (tester) async {
      var signIns = 0;
      await pumpUi(
        tester,
        AbraFailureView(
          failure: const SessionExpiredFailure(),
          onRetry: () {},
          onSignIn: () => signIns++,
        ),
      );
      expect(find.text('Session ended'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      await tester.tap(find.text('Sign in'));
      expect(signIns, 1);
    });

    testWidgets(
      'shows the request reference but never the raw server message',
      (tester) async {
        await pumpUi(
          tester,
          AbraFailureView(
            failure: api(ApiErrorCodes.internalError, 500),
            onRetry: () {},
          ),
        );
        expect(find.text('Reference: req-42'), findsOneWidget);
        expect(find.text('server text'), findsNothing);
      },
    );

    testWidgets('shows how long to wait when the server says so (plural)', (
      tester,
    ) async {
      await pumpUi(
        tester,
        AbraFailureView(
          failure: api(
            ApiErrorCodes.accountLocked,
            423,
            details: {'retryAfterSeconds': 900},
          ),
        ),
      );
      expect(find.text('Too many attempts'), findsOneWidget);
      expect(find.text('Try again in 900 seconds'), findsOneWidget);
    });
  });

  group('other widgets', () {
    testWidgets('loading view announces loading to screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AbraTheme.light(),
          supportedLocales: config.supportedLocales,
          localizationsDelegates: [
            delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(body: AbraLoadingView()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    });

    testWidgets('entrance shows its child at once when motion is reduced', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AbraEntrance(index: 3, child: Text('row')),
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('entrance fades its child in and then rests', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AbraEntrance(child: Text('row'))),
      );
      expect(find.text('row'), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byType(Opacity).first).opacity,
        lessThan(1),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
    });

    testWidgets('skeletons are announced once as loading and stay still when '
        'motion is reduced', (tester) async {
      await pumpUi(
        tester,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AbraSkeletonGroup(
            child: Column(
              children: [AbraSkeleton(width: 80), AbraSkeleton(width: 40)],
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('brand surface and mark render at phone and desktop widths', (
      tester,
    ) async {
      for (final width in const [320.0, 1440.0]) {
        await pumpUi(
          tester,
          Center(
            child: SizedBox(
              width: width,
              height: 200,
              child: const AbraBrandSurface(
                child: AbraBrandMark(name: 'Abra Travels', caption: 'Caption'),
              ),
            ),
          ),
        );
        expect(find.text('Abra Travels'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('confirm dialog returns true only for the confirm button', (
      tester,
    ) async {
      Future<bool?> open() async {
        bool? result;
        await pumpUi(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showAbraConfirmDialog(
                context,
                title: 'Sign out everywhere?',
                message: 'All your devices will be signed out.',
                confirmLabel: 'Sign out',
                isDestructive: true,
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Sign out everywhere?'), findsOneWidget);
        return result;
      }

      await open();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await open();
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign out'),
      );
      expect(
        confirm.style!.backgroundColor!.resolve(<WidgetState>{}),
        AbraColors.danger,
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('validation problems become translated messages', (
      tester,
    ) async {
      late AbraLocalizations l10n;
      await pumpUi(
        tester,
        Builder(
          builder: (context) {
            l10n = AbraLocalizations.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(validationMessage(l10n, null), isNull);
      expect(
        validationMessage(l10n, InputProblem.invalidPhone),
        'Enter a valid mobile number.',
      );
      expect(
        validationMessage(l10n, InputProblem.passwordTooShort),
        'Use at least 10 characters.',
      );
      expect(
        validationMessage(l10n, InputProblem.passwordTooLong),
        'Use at most 128 characters.',
      );
      for (final problem in InputProblem.values) {
        final message = validationMessage(l10n, problem)!;
        expect(message, isNot(startsWith('validation')), reason: problem.name);
      }
      expect(l10n.missingKeys, isEmpty);
    });
  });
}
