import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_portal.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

const viewer = Persona(
  name: 'Vera Viewer',
  userType: 'OPERATOR_STAFF',
  roleKey: 'BOOKING_STAFF',
  operatorId: operatorAId,
  permissions: {'operators.read', 'documents.view'},
);

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('company profile', () {
    testWidgets('shows the company and its details as in the demo', (
      tester,
    ) async {
      final app = TestPortal.signedIn(FakeBackend(Persona.owner));
      await app.pump(tester);
      await open(tester, PortalRoutes.company);

      expect(find.text('Company profile'), findsOneWidget);
      expect(find.text('Details customers and Abra see.'), findsOneWidget);
      expect(find.text('Company'), findsOneWidget);
      expect(find.text('Bank account for payouts'), findsOneWidget);
      expect(
        find.text(
          'Changing the bank account pauses payouts until Abra verifies it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Not added'), findsOneWidget);
      expect(
        find.textContaining('Manual settlement', findRichText: true),
        findsOneWidget,
      );
      expect(find.widgetWithText(AbraButton, 'Save'), findsOneWidget);
      expect(
        find.widgetWithText(AbraButton, 'Save bank details'),
        findsOneWidget,
      );
    });

    testWidgets('saves the profile, and refuses a wrong email or GSTIN', (
      tester,
    ) async {
      final app = TestPortal.signedIn(FakeBackend(Persona.owner));
      await app.pump(tester);
      await open(tester, PortalRoutes.company);

      await tester.enterText(field('Email *'), 'nope');
      await tester.enterText(field('GSTIN'), '123');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Save'));
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.textContaining('Looks wrong'), findsOneWidget);
      expect(app.requestsTo('client/company', 'PUT'), isEmpty);

      await tester.enterText(field('Email *'), 'owner@alpha.test');
      await tester.enterText(field('GSTIN'), '36ABCDE1234F1Z5');
      await tester.enterText(field('City'), 'Hyderabad');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Save'));
      final sent = app.requestsTo('client/company', 'PUT').single.body! as Map;
      expect(sent['email'], 'owner@alpha.test');
      expect(sent['gstin'], '36ABCDE1234F1Z5');
      expect(sent['city'], 'Hyderabad');
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets(
      'saves the bank account, then shows it pending by its last four digits',
      (tester) async {
        final app = TestPortal.signedIn(FakeBackend(Persona.owner));
        await app.pump(tester);
        await open(tester, PortalRoutes.company);

        await tester.enterText(field('Account holder'), 'Alpha Lines Pvt Ltd');
        await tester.enterText(field('Account number'), '12ab');
        await tester.enterText(field('IFSC'), 'WRONG');
        await tapOn(
          tester,
          find.widgetWithText(AbraButton, 'Save bank details'),
        );
        expect(find.text('Enter 6 to 18 digits'), findsOneWidget);
        expect(
          find.textContaining('Looks wrong, for example HDFC'),
          findsOneWidget,
        );
        expect(app.requestsTo('client/company/bank', 'PUT'), isEmpty);

        await tester.enterText(field('Account number'), '123456789012');
        await tester.enterText(field('IFSC'), 'hdfc0001234');
        await tapOn(
          tester,
          find.widgetWithText(AbraButton, 'Save bank details'),
        );
        expect(app.requestsTo('client/company/bank', 'PUT').single.body, {
          'holderName': 'Alpha Lines Pvt Ltd',
          'accountNumber': '123456789012',
          'ifsc': 'HDFC0001234',
        });
        expect(find.text('Pending'), findsOneWidget);
        expect(find.textContaining('XXXXXX9012'), findsOneWidget);
        expect(
          find.text('Saved. Abra will verify the account.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows why Abra could not verify the account', (tester) async {
      final backend = FakeBackend(Persona.owner)
        ..company = <String, Object?>{
          'id': operatorAId,
          'companyName': 'Alpha Lines',
          'ownerName': 'Omar Operator',
          'email': 'omar@alpha.test',
          'supportPhone': '',
          'city': '',
          'gstin': '',
          'payoutMode': 'MANUAL',
          'bank': <String, Object?>{
            'holderName': 'Alpha Lines Pvt Ltd',
            'accountLast4': '9012',
            'ifsc': 'HDFC0001234',
            'status': 'FAILED',
            'note': 'Holder name does not match',
          },
        };
      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.company);

      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('Holder name does not match'), findsOneWidget);
    });

    testWidgets('a person who can only view it gets no Save buttons', (
      tester,
    ) async {
      final app = TestPortal.signedIn(FakeBackend(viewer));
      await app.pump(tester);
      await open(tester, PortalRoutes.company);

      expect(find.widgetWithText(AbraButton, 'Save'), findsNothing);
      expect(
        find.widgetWithText(AbraButton, 'Save bank details'),
        findsNothing,
      );
    });
  });
}
