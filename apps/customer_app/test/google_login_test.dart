import 'package:customer_app/app/providers.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'support/test_app.dart';

void main() {
  testWidgets(
    'welcome closes after two seconds and preserves the current route',
    (tester) async {
      final app = TestApp(handler: (_) async => signInResponse);
      await app.pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final router = container.read(customerRouterProvider);
      router.go('/my-trips');
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Abra Travels!'), findsNothing);
      await app.run(
        tester,
        container
            .read(sessionManagerProvider)
            .signInWithOtp(phone: '+919876543210', code: '123456'),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Welcome to Abra Travels!'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/my-trips');
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('Welcome to Abra Travels!'), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/my-trips');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('My trips login dialog shows Google and Apple above mobile OTP', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester, size: const Size(1366, 768));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(customerRouterProvider).go('/my-trips');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byTooltip('Continue with Google'), findsOneWidget);
    expect(find.byTooltip('Continue with Apple'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mobile number'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer Google login is available alongside WhatsApp OTP', (
    tester,
  ) async {
    final app = TestApp(
      handler: (_) async => FakeResponse.ok({
        'expiresInSeconds': 300,
        'resendAfterSeconds': 60,
        'codeLength': 6,
        'channel': 'WHATSAPP',
      }),
    );
    await app.pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(customerRouterProvider).go('/login');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Continue with Google'), findsOneWidget);
    expect(find.byTooltip('Continue with Apple'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mobile number'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number'),
      '9876543210',
    );
    final send = find.text('Continue');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(app.requestedPaths, contains('auth/otp/send'));
    expect(find.byTooltip('Continue with Google'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
