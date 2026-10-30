import 'package:customer_app/features/profile/profile_repository.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_app.dart';

FakeResponse profile({String name = 'Asha Rao', String email = 'asha@example.com'}) =>
    FakeResponse.ok(<String, Object?>{
      'id': 'user-1',
      'name': name,
      'email': email,
      'phone': '+919876543210',
      'language': 'en',
      'signInMethod': 'whatsapp',
      'emailVerified': false,
      'joinedAt': '2026-10-01T00:00:00.000Z',
    });

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

Future<TestApp> openAt(
  WidgetTester tester,
  String location,
  Future<FakeResponse> Function(RecordedRequest request) handler,
) async {
  final app = TestApp(stored: storedSession, handler: handler);
  await app.pump(tester);
  ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).go(location);
  await settle(tester);
  return app;
}

void main() {
  test('the profile is read from the answer, with English as the fallback', () {
    final read = CustomerProfile.fromJson(<String, Object?>{
      'name': 'Asha',
      'phone': '+919876543210',
    });
    expect(read.email, isEmpty);
    expect(read.language, 'en');
  });

  testWidgets('Edit profile shows what the server holds and saves a change', (tester) async {
    late RecordedRequest saved;
    final app = await openAt(tester, '/profile/edit', (request) async {
      if (request.path == 'customer/profile' && request.method == 'PATCH') {
        saved = request;
        return profile(name: 'Asha R', email: 'new@example.com');
      }
      if (request.path == 'customer/profile') return profile();
      return currentUserResponse;
    });

    expect(find.widgetWithText(TextFormField, 'Asha Rao'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'asha@example.com'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '+919876543210'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Asha Rao'), 'Asha R');
    await tester.enterText(find.widgetWithText(TextFormField, 'asha@example.com'), 'new@example.com');
    await tester.tap(find.text('Save Changes'));
    await settle(tester);

    expect(saved.body, <String, Object?>{'name': 'Asha R', 'email': 'new@example.com'});
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(app.requestedPaths, contains('me'));
  });

  testWidgets('a wrong email is stopped on the phone and never sent', (tester) async {
    final app = await openAt(tester, '/profile/edit', (request) async {
      if (request.path == 'customer/profile') return profile();
      return currentUserResponse;
    });

    await tester.enterText(find.widgetWithText(TextFormField, 'asha@example.com'), 'asha-at-home');
    await tester.tap(find.text('Save Changes'));
    await settle(tester);

    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(app.adapter.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });

  testWidgets('an email that belongs to someone else is explained under the email', (tester) async {
    await openAt(tester, '/profile/edit', (request) async {
      if (request.path == 'customer/profile' && request.method == 'PATCH') {
        return FakeResponse.error(
          409,
          'ALREADY_REGISTERED',
          message: 'This email is already used by another account.',
        );
      }
      if (request.path == 'customer/profile') return profile();
      return currentUserResponse;
    });

    await tester.tap(find.text('Save Changes'));
    await settle(tester);

    expect(find.text('This email is already used by another account.'), findsOneWidget);
    expect(find.text('Profile saved.'), findsNothing);
  });

  testWidgets('Edit profile can be tried again after a failed load', (tester) async {
    var failing = true;
    await openAt(tester, '/profile/edit', (request) async {
      if (request.path == 'customer/profile') {
        return failing ? FakeResponse.error(422, 'VALIDATION_FAILED') : profile();
      }
      return currentUserResponse;
    });
    expect(find.widgetWithText(TextFormField, 'Asha Rao'), findsNothing);

    failing = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await settle(tester);
    expect(find.widgetWithText(TextFormField, 'Asha Rao'), findsOneWidget);
  });

  group('Delete account', () {
    testWidgets('the button waits for the tick', (tester) async {
      await openAt(tester, '/account-delete', (_) async => currentUserResponse);
      final button = find.widgetWithText(FilledButton, 'Delete My Account');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await settle(tester);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets("shows the server's sentence when a booking is still to be travelled on", (tester) async {
      final app = await openAt(tester, '/account-delete', (request) async {
        if (request.path == 'customer/account') {
          return FakeResponse.error(
            409,
            'INVALID_STATE_TRANSITION',
            message: 'You still have a booking to travel on. Cancel or complete it first, then delete your account.',
          );
        }
        return currentUserResponse;
      });
      await tester.tap(find.byType(Checkbox));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete My Account'));
      await settle(tester);

      expect(find.textContaining('You still have a booking to travel on'), findsOneWidget);
      expect(app.sessionManager.state, isA<AuthSignedIn>());
    });

    testWidgets('after the server deletes the account the phone is signed out', (tester) async {
      final app = await openAt(tester, '/account-delete', (request) async {
        if (request.path == 'customer/account') {
          return FakeResponse.ok(<String, Object?>{'deleted': true});
        }
        return currentUserResponse;
      });
      await tester.tap(find.byType(Checkbox));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete My Account'));
      await settle(tester);

      expect(app.requestedPaths, contains('customer/account'));
      expect(app.sessionManager.state, isA<AuthSignedOut>());
    });
  });

  testWidgets('Sign out of all devices asks first, then calls the server', (tester) async {
    final app = await openAt(tester, '/profile', (request) async {
      if (request.path == 'auth/logout-all') return FakeResponse.ok(null);
      return currentUserResponse;
    });

    await tester.scrollUntilVisible(
      find.text('Sign out of all devices'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Sign out of all devices'));
    await settle(tester);
    expect(app.requestedPaths, isNot(contains('auth/logout-all')));

    await tester.tap(find.text('Sign out everywhere'));
    await settle(tester);
    expect(app.requestedPaths, contains('auth/logout-all'));
    expect(app.sessionManager.state, isA<AuthSignedOut>());
  });
}
