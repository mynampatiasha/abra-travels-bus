import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_portal.dart';

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Future<void> signIn(
  WidgetTester tester, {
  String password = 'correct-horse-battery',
}) async {
  await tester.enterText(field('Email or phone number'), 'owner@example.com');
  await tester.enterText(field('Password'), password);
  await tapOn(tester, find.widgetWithText(AbraButton, 'Sign in'));
}

void main() {
  group('sign-in', () {
    testWidgets('client sign-in has compact social and phone actions', (
      tester,
    ) async {
      final app = TestPortal(FakeBackend(Persona.owner));
      await app.pump(tester);
      expect(find.byTooltip('Continue with Google'), findsOneWidget);
      expect(find.byTooltip('Continue with Apple'), findsOneWidget);
      expect(find.byTooltip('Continue with phone number'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tapOn(tester, find.byTooltip('Continue with phone number'));
      expect(find.text('Phone sign-in'), findsOneWidget);
      expect(field('Phone number'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bus owner signs in and lands on the dashboard', (
      tester,
    ) async {
      final app = TestPortal(FakeBackend(Persona.owner));
      await app.pump(tester);
      expect(locationOf(tester), PortalRoutes.signIn);

      await signIn(tester);
      expect(locationOf(tester), PortalRoutes.dashboard);
      expect(find.text('Bookings today'), findsOneWidget);
    });

    testWidgets('platform staff cannot use the portal', (tester) async {
      final backend = FakeBackend(Persona.support);
      final app = TestPortal(backend);
      await app.pump(tester);
      await signIn(tester);
      expect(locationOf(tester), PortalRoutes.home);
      expect(find.text('Bookings today'), findsNothing);
    });

    testWidgets('a wrong password stays on sign-in', (tester) async {
      final app = TestPortal(FakeBackend(Persona.owner));
      await app.pump(tester);
      await signIn(tester, password: 'wrong');
      expect(locationOf(tester), PortalRoutes.signIn);
    });
  });

  group('accept invitation', () {
    testWidgets('a good link shows the company', (tester) async {
      final app = TestPortal(FakeBackend(Persona.owner));
      await app.pump(tester);
      await open(tester, '/accept-invite?token=good-token');
      expect(find.text('Welcome to Abra Travels'), findsOneWidget);
      expect(find.textContaining('Alpha Lines'), findsWidgets);
    });

    testWidgets('a bad link explains', (tester) async {
      final app = TestPortal(FakeBackend(Persona.owner));
      await app.pump(tester);
      await open(tester, '/accept-invite?token=nope');
      expect(find.text('This link cannot be used'), findsOneWidget);
    });

    testWidgets('a short password is refused, a good one creates the account', (
      tester,
    ) async {
      final app = TestPortal(FakeBackend(Persona.owner));
      await app.pump(tester);
      await open(tester, '/accept-invite?token=good-token');

      await tester.enterText(field('Choose a password'), 'short');
      await tester.enterText(field('Repeat the password'), 'short');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Create my account'));
      expect(app.requestsTo('onboarding/invitations/accept'), isEmpty);

      await tester.enterText(
        field('Choose a password'),
        'a long enough phrase',
      );
      await tester.enterText(
        field('Repeat the password'),
        'a long enough phrase',
      );
      await tapOn(tester, find.widgetWithText(AbraButton, 'Create my account'));
      expect(app.requestsTo('onboarding/invitations/accept'), hasLength(1));
      expect(
        find.text('Your account is ready. Sign in to continue.'),
        findsOneWidget,
      );
    });
  });

  group('documents', () {
    testWidgets('a rejected file shows the note and the reason', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      final file = backend.addCompanyFile(
        status: 'REJECTED',
        decisionNote: 'The GST copy is blurred.',
        documents: [
          FakeBackend.document(
            'GST certificate',
            'gst-type',
            'REJECTED',
            reason: 'Blurred',
          ),
        ],
      );
      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.onboardingOf('${file['id']}'));

      expect(find.textContaining('Sent back'), findsOneWidget);
      expect(find.textContaining('The GST copy is blurred.'), findsWidgets);
      expect(find.textContaining('Blurred'), findsWidgets);
    });

    testWidgets('a waiting file cannot be sent again', (tester) async {
      final backend = FakeBackend(Persona.owner);
      final file = backend.addCompanyFile(status: 'PENDING');
      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.onboardingOf('${file['id']}'));

      expect(find.textContaining('Sent for review'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Send for review'), findsNothing);
    });

    testWidgets('a complete draft is sent for review', (tester) async {
      final backend = FakeBackend(Persona.owner);
      final file = backend.addCompanyFile(
        canSubmit: true,
        documents: [
          FakeBackend.document('GST certificate', 'gst-type', 'PENDING'),
        ],
      );
      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.onboardingOf('${file['id']}'));

      await tapOn(tester, find.widgetWithText(AbraButton, 'Send for review'));
      expect(
        app.requestsTo('onboarding/submissions/${file['id']}/submit', 'POST'),
        hasLength(1),
      );
    });

    testWidgets('a draft that is not ready lists what is missing', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      final file = backend.addCompanyFile(
        problems: ['GST certificate is required'],
      );
      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.onboardingOf('${file['id']}'));

      expect(find.text('Before you can send'), findsOneWidget);
      expect(
        find.textContaining('GST certificate is required'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AbraButton>(
              find.widgetWithText(AbraButton, 'Send for review'),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('dashboard', () {
    testWidgets('shows the company state and the buses waiting', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      backend.addCompanyFile(status: 'APPROVED');
      backend.add('buses', {
        'name': 'Alpha Express',
        'registrationNumber': 'KA01AB1234',
        'seatCapacity': 40,
        'status': 'PENDING_APPROVAL',
      });
      final app = TestPortal.signedIn(backend);
      await app.pump(tester);

      expect(locationOf(tester), PortalRoutes.dashboard);
      expect(find.text('Alpha Lines'), findsWidgets);
      expect(find.text('verified partner'), findsOneWidget);
      expect(find.textContaining('Alpha Express'), findsOneWidget);
    });

    testWidgets('with no buses it invites the first one', (tester) async {
      final backend = FakeBackend(Persona.owner);
      backend.addCompanyFile();
      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      expect(find.textContaining('No buses yet'), findsOneWidget);
    });
  });
}
