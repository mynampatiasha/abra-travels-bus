import 'package:customer_app/features/info/info_repository.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_app.dart';

FakeResponse _page(String title, String body) => FakeResponse.ok(
  <String, Object?>{
    'key': 'terms',
    'title': title,
    'body': body,
    'updatedAt': '2026-10-20T10:00:00.000Z',
  },
);

Future<void> _open(WidgetTester tester, TestApp app, String location) async {
  await app.pump(tester);
  ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).go(location);
  await tester.pumpAndSettle();
}

void main() {
  group('information pages come from the backend', () {
    test('a page is read, split into paragraphs and keeps its date', () {
      final page = InfoPageContent.fromJson(<String, Object?>{
        'title': 'Terms',
        'body': 'First part.\n\n  Second part.  \n\n\nThird part.',
        'updatedAt': '2026-10-20T10:00:00.000Z',
      });
      expect(page.title, 'Terms');
      expect(page.paragraphs, <String>[
        'First part.',
        'Second part.',
        'Third part.',
      ]);
      expect(page.updatedAt, isNotNull);
    });

    test('FAQs and contact details are read; a broken FAQ is skipped', () {
      final faq = FaqItem.fromJson(<String, Object?>{
        'id': 'f1',
        'question': 'Q?',
        'answer': 'A.',
      });
      expect(faq.category, 'General');
      final contact = ContactDetails.fromJson(<String, Object?>{
        'configured': true,
        'phone': '+91 40 1234 5678',
        'email': '',
        'address': 'Hyderabad',
        'hours': '8am to 10pm',
      });
      expect(contact.configured, isTrue);
      expect(contact.email, isEmpty);
    });

    testWidgets('Terms shows the text staff published', (tester) async {
      final app = TestApp(
        handler: (request) async {
          if (request.path == 'content/pages/terms') {
            return _page(
              'Terms and conditions',
              'You must carry a photo ID.\n\nCancel before departure.',
            );
          }
          return currentUserResponse;
        },
      );
      await _open(tester, app, '/terms');

      expect(find.text('Terms and conditions'), findsOneWidget);
      expect(find.text('You must carry a photo ID.'), findsOneWidget);
      expect(find.text('Cancel before departure.'), findsOneWidget);
      expect(app.requestedPaths, contains('content/pages/terms'));
    });

    testWidgets('a page that is not published yet shows a not-found state '
        'and nothing made up', (tester) async {
      final app = TestApp(
        handler: (request) async {
          if (request.path == 'content/pages/privacy') {
            return FakeResponse.error(
              404,
              'RESOURCE_NOT_FOUND',
              message: 'This page is not published yet.',
            );
          }
          return currentUserResponse;
        },
      );
      await _open(tester, app, '/privacy');

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.textContaining('photo ID'), findsNothing);
      expect(find.text('Privacy policy'), findsNothing);
    });

    testWidgets('a failed load can be tried again', (tester) async {
      var failing = true;
      final app = TestApp(
        handler: (request) async {
          if (request.path == 'content/pages/about') {
            return failing
                ? FakeResponse.error(422, 'VALIDATION_FAILED')
                : _page('About Abra', 'We run buses you can trust.');
          }
          return currentUserResponse;
        },
      );
      await _open(tester, app, '/about');
      expect(find.text('We run buses you can trust.'), findsNothing);

      failing = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
      await tester.pumpAndSettle();
      expect(find.text('We run buses you can trust.'), findsOneWidget);
    });
  });
}
