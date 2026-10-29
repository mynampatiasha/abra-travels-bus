import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/app/driver_app.dart';

void main() {
  testWidgets('DriverApp basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DriverApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DriverApp), findsOneWidget);
  });

  testWidgets('a visitor who has not signed in lands on the sign-in screen, not the home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DriverApp()));
    await tester.pumpAndSettle();
    expect(find.text('Driver Login'), findsOneWidget);
    expect(find.text('Hello, Driver'), findsNothing);
  });

  testWidgets('sign-in asks for the mobile number and the password, with the code as the other way', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DriverApp()));
    await tester.pumpAndSettle();
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Sign in with a verification code instead'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsNothing);
    expect(find.text('Send Verification Code'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
