// Help content and contact (admin): the contact details, the FAQs and the policy pages, all read
// from and saved to the backend.
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_admin.dart';

/// May look at the content but not change it.
const viewer = Persona(
  name: 'Vik Viewer',
  userType: 'STAFF',
  roleKey: 'SUPPORT',
  permissions: {'content.read'},
);

Map<String, Object?> faq(String id, String question, {String status = 'PUBLISHED'}) =>
    <String, Object?>{
      'id': id,
      'question': question,
      'answer': 'Answer to $question',
      'category': 'Cancellation',
      'order': 1,
      'status': status,
    };

Map<String, Object?> page(String key, String title, {String body = '', String status = 'DRAFT'}) =>
    <String, Object?>{
      'key': key,
      'title': title,
      'body': body,
      'status': status,
      'updatedBy': body.isEmpty ? '' : 'Asha Admin',
      'updatedAt': '2026-10-20T10:00:00.000Z',
    };

FakeBackend withContent(Persona persona, {List<Map<String, Object?>>? faqs}) {
  final backend = FakeBackend(persona);
  final overrides = backend.overrides;
  FakeResponse guarded(String key, FakeResponse Function() ok) =>
      persona.permissions.contains(key)
      ? ok()
      : FakeResponse.error(403, 'PERMISSION_DENIED');
  overrides['GET admin/content/contact'] = (_) => guarded(
    'content.read',
    () => FakeResponse.ok(<String, Object?>{
      'configured': true,
      'phone': '+91 40 1234 5678',
      'email': 'help@abra.example',
      'address': 'Hyderabad',
      'hours': '8am to 10pm',
    }),
  );
  overrides['GET admin/content/faqs'] = (_) => guarded(
    'content.read',
    () => FakeResponse.ok(
      faqs ?? <Map<String, Object?>>[faq('f1', 'How do I cancel?'), faq('f2', 'Which payments work?', status: 'DRAFT')],
      meta: <String, Object?>{'page': 1, 'pageSize': 100, 'total': 2},
    ),
  );
  overrides['GET admin/content/pages'] = (_) => guarded(
    'content.read',
    () => FakeResponse.ok(<Map<String, Object?>>[
      page('terms', 'Terms and conditions', body: 'Be kind.', status: 'PUBLISHED'),
      page('privacy', 'Privacy policy'),
      page('about', 'About Abra'),
    ]),
  );
  overrides['PUT admin/content/contact'] = (request) => guarded(
    'content.manage',
    () => FakeResponse.ok(<String, Object?>{
      'configured': true,
      ...(request.body! as Map<String, Object?>),
    }),
  );
  overrides['PUT admin/content/pages/privacy'] = (request) => guarded(
    'content.manage',
    () => FakeResponse.ok(<String, Object?>{
      'key': 'privacy',
      ...(request.body! as Map<String, Object?>),
      'updatedBy': 'Asha Admin',
    }),
  );
  overrides['POST admin/content/faqs'] = (_) => guarded('content.manage', () => FakeResponse.ok(faq('f3', 'New')));
  overrides['DELETE admin/content/faqs/f1'] = (_) => guarded('content.manage', () => FakeResponse.ok(faq('f1', 'How do I cancel?')));
  return backend;
}

Future<TestAdmin> openContent(WidgetTester tester, FakeBackend backend) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, AdminRoutes.content);
  return app;
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
  // a reload after a dialog closes needs a few more frames for the answer to arrive
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('Contact details', () {
    testWidgets('shows what the backend holds and saves a change', (tester) async {
      final app = await openContent(tester, withContent(Persona.superAdmin));

      expect(find.text('Contact details'), findsOneWidget);
      expect(find.widgetWithText(TextField, '+91 40 1234 5678'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'help@abra.example'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '+91 40 1234 5678'), '+91 40 9999 0000');
      await tapOn(tester, find.widgetWithText(FilledButton, 'Save'));

      final sent = app.requestsTo('admin/content/contact', 'PUT');
      expect(sent, hasLength(1));
      expect((sent.single.body! as Map)['phone'], '+91 40 9999 0000');
      expect(find.text('Contact details saved.'), findsOneWidget);
    });

    testWidgets('a view-only role cannot save: no button, and the fields are locked', (tester) async {
      await openContent(tester, withContent(viewer));

      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      final phone = tester.widget<TextField>(find.widgetWithText(TextField, '+91 40 1234 5678'));
      expect(phone.readOnly, isTrue);
    });
  });

  group('Frequently asked questions', () {
    testWidgets('lists the questions with their status; Super Admin can add, edit, delete', (tester) async {
      final app = await openContent(tester, withContent(Persona.superAdmin));
      await tapOn(tester, find.text('Frequently asked questions'));

      expect(find.text('How do I cancel?'), findsOneWidget);
      expect(find.text('Which payments work?'), findsOneWidget);
      expect(find.textContaining('Draft'), findsOneWidget);
      expect(find.text('Add question'), findsOneWidget);
      await tapOn(tester, find.text('Add question'));
      await tester.enterText(find.widgetWithText(TextField, 'Question'), 'Can I change my seat?');
      await tester.enterText(find.widgetWithText(TextField, 'Answer'), 'Cancel and book again.');
      await tapOn(tester, find.widgetWithText(FilledButton, 'Publish'));
      final created = app.requestsTo('admin/content/faqs', 'POST');
      expect(created, hasLength(1));
      expect((created.single.body! as Map)['status'], 'PUBLISHED');
      await tapOn(tester, find.widgetWithText(TextButton, 'Delete').first);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(app.requestsTo('admin/content/faqs/f1', 'DELETE'), hasLength(1));
    });

    testWidgets('a view-only role sees the questions but no buttons', (tester) async {
      await openContent(tester, withContent(viewer));
      await tapOn(tester, find.text('Frequently asked questions'));

      expect(find.text('How do I cancel?'), findsOneWidget);
      expect(find.text('Add question'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('an empty list says so', (tester) async {
      await openContent(tester, withContent(Persona.superAdmin, faqs: <Map<String, Object?>>[]));
      await tapOn(tester, find.text('Frequently asked questions'));
      expect(find.text('No questions yet.'), findsOneWidget);
    });
  });

  group('Policy pages', () {
    testWidgets('lists the three pages and publishes one', (tester) async {
      final app = await openContent(tester, withContent(Persona.superAdmin));
      await tapOn(tester, find.text('Policy pages'));

      expect(find.text('Terms and conditions'), findsOneWidget);
      expect(find.textContaining('Published by Asha Admin'), findsOneWidget);
      expect(find.text('Not written yet'), findsNWidgets(2));

      await tapOn(tester, find.widgetWithText(TextButton, 'Edit').at(1));
      await tester.enterText(find.widgetWithText(TextField, 'Text (a blank line starts a new paragraph)'), 'We keep your data safe.');
      await tapOn(tester, find.widgetWithText(FilledButton, 'Publish'));

      final sent = app.requestsTo('admin/content/pages/privacy', 'PUT');
      expect(sent, hasLength(1));
      expect((sent.single.body! as Map)['status'], 'PUBLISHED');
      expect((sent.single.body! as Map)['body'], 'We keep your data safe.');
    });

    testWidgets('a view-only role can read a page but not change it', (tester) async {
      await openContent(tester, withContent(viewer));
      await tapOn(tester, find.text('Policy pages'));

      await tapOn(tester, find.widgetWithText(TextButton, 'View').first);
      expect(find.widgetWithText(FilledButton, 'Publish'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
    });
  });
}
