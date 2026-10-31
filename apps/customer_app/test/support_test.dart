import 'dart:typed_data';

import 'package:customer_app/features/support/proof_picker.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_app.dart';

Map<String, Object?> faq(String id, String question, String category) => <String, Object?>{
  'id': id,
  'question': question,
  'answer': 'Answer to $question',
  'category': category,
  'order': 1,
  'status': 'PUBLISHED',
  'updatedAt': null,
};

Map<String, Object?> ticket({
  String id = 't1',
  String number = 'TK-1',
  String status = 'OPEN',
  String subject = 'Payment failed',
  List<Map<String, Object?>> replies = const <Map<String, Object?>>[],
}) => <String, Object?>{
  'id': id,
  'ticketNumber': number,
  'customerId': 'user-1',
  'customerName': 'Asha',
  'category': 'PAYMENT',
  'subject': subject,
  'message': 'My payment failed but the money was taken.',
  'bookingRef': 'ABR12345',
  'status': status,
  'priority': 'NORMAL',
  'assignedToName': '',
  'assignedToMe': false,
  'respondBy': null,
  'overdue': false,
  'lastReplyBy': 'CUSTOMER',
  'repliesCount': replies.length,
  'createdAt': '2026-10-28T08:00:00.000Z',
  'updatedAt': '2026-10-28T08:00:00.000Z',
  'replies': replies,
  'proofs': <Map<String, Object?>>[],
};

const contact = <String, Object?>{
  'configured': true,
  'phone': '+91 40 1234 5678',
  'email': 'help@abra.example',
  'address': '',
  'hours': '8am to 10pm',
  'updatedAt': null,
};

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

Future<TestApp> openSupport(
  WidgetTester tester,
  Future<FakeResponse> Function(RecordedRequest request) handler, {
  bool signedIn = true,
  ProofPicker? picker,
}) async {
  final app = TestApp(
    stored: signedIn ? storedSession : const <String, String>{},
    handler: handler,
    extraOverrides: [if (picker != null) proofPickerProvider.overrideWithValue(picker)],
  );
  await app.pump(tester, size: const Size(400, 1800));
  ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).go('/support');
  await settle(tester);
  return app;
}

Future<FakeResponse> Function(RecordedRequest) backend({
  List<Map<String, Object?>>? faqs,
  Map<String, Object?> contactDetails = contact,
  List<Map<String, Object?>>? tickets,
  Map<String, Object?>? detail,
}) {
  return (request) async {
    switch ('${request.method} ${request.path}') {
      case 'GET content/faqs':
        return FakeResponse.ok(faqs ?? <Map<String, Object?>>[]);
      case 'GET content/contact':
        return FakeResponse.ok(contactDetails);
      case 'GET customer/support/tickets':
        return FakeResponse.ok(tickets ?? <Map<String, Object?>>[]);
      case 'GET customer/support/tickets/t1':
        return FakeResponse.ok(detail ?? ticket());
    }
    return currentUserResponse;
  };
}

void main() {
  group('Help centre', () {
    testWidgets('shows the published FAQs and the contact details staff saved', (tester) async {
      final app = await openSupport(
        tester,
        backend(faqs: [faq('f1', 'How do I cancel?', 'Cancellation'), faq('f2', 'Which payments work?', 'Payments')]),
      );

      expect(find.text('Cancellation'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      await tester.tap(find.text('Cancellation'));
      await settle(tester);
      expect(find.text('How do I cancel?'), findsOneWidget);
      expect(find.text('+91 40 1234 5678'), findsOneWidget);
      expect(find.text('help@abra.example'), findsOneWidget);
      expect(find.text('8am to 10pm'), findsOneWidget);
      expect(find.textContaining('Not connected yet'), findsNothing);
      expect(app.requestedPaths, containsAll(<String>['content/faqs', 'content/contact']));
    });

    testWidgets('says so when nothing is published and no contact details are saved', (tester) async {
      await openSupport(
        tester,
        backend(contactDetails: const <String, Object?>{'configured': false, 'phone': '', 'email': '', 'address': '', 'hours': ''}),
      );
      expect(find.text('No help articles yet'), findsOneWidget);
      expect(find.textContaining('Contact details have not been set up yet'), findsOneWidget);
    });

    testWidgets('a guest sees the sign-in prompt and no tickets request is made', (tester) async {
      final app = await openSupport(tester, backend(), signedIn: false);
      expect(find.text('Have a problem with a booking?'), findsOneWidget);
      expect(app.requestedPaths, isNot(contains('customer/support/tickets')));
    });
  });

  group('My tickets', () {
    testWidgets('lists my tickets with their number and status', (tester) async {
      await openSupport(tester, backend(tickets: [ticket(), ticket(id: 't2', number: 'TK-2', status: 'RESOLVED', subject: 'Refund late')]));
      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.text('TK-1'), findsOneWidget);
      expect(find.text('Refund late'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
    });

    testWidgets('says so when there are none', (tester) async {
      await openSupport(tester, backend());
      expect(find.text('You have not raised any tickets.'), findsOneWidget);
    });

    testWidgets('opens a ticket with my message and the staff reply, and sends a reply', (tester) async {
      late RecordedRequest sent;
      final app = await openSupport(tester, (request) async {
        if (request.method == 'POST' && request.path == 'customer/support/tickets/t1/replies') {
          sent = request;
          return FakeResponse.ok(ticket());
        }
        return backend(
          tickets: [ticket()],
          detail: ticket(replies: [
            <String, Object?>{
              'id': 'r1',
              'authorType': 'STAFF',
              'authorName': 'Asha Admin',
              'body': 'We are checking with the bank.',
              'at': '2026-10-28T09:00:00.000Z',
            },
          ]),
        )(request);
      });

      await tester.tap(find.text('Payment failed'));
      await settle(tester);
      expect(find.text('My payment failed but the money was taken.'), findsOneWidget);
      expect(find.text('We are checking with the bank.'), findsOneWidget);

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Write a message...'),
        'Here is the screenshot.',
      );
      await tester.tap(find.byIcon(Icons.send));
      await settle(tester);
      expect((sent.body! as Map)['message'], 'Here is the screenshot.');
      expect(app.requestedPaths, contains('customer/support/tickets/t1/replies'));
    });
  });

  group('Raising a ticket', () {
    Future<void> fillAndOpen(WidgetTester tester) async {
      await tester.tap(find.text('Create a ticket'));
      await settle(tester);
    }

    testWidgets('sends the category, subject, message, booking number and the proof file id', (tester) async {
      late RecordedRequest created;
      final app = await openSupport(
        tester,
        (request) async {
          if (request.method == 'POST' && request.path == 'files/proofs') {
            return FakeResponse.ok(<String, Object?>{'id': 'proof-1', 'originalName': 'shot.png'});
          }
          if (request.method == 'POST' && request.path == 'customer/support/tickets') {
            created = request;
            return FakeResponse.ok(ticket());
          }
          return backend()(request);
        },
        picker: () async => PickedProof(name: 'shot.png', bytes: Uint8List.fromList(<int>[1, 2, 3])),
      );
      await fillAndOpen(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Booking number (optional)'), 'abr12345');
      await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Payment failed');
      await tester.enterText(find.widgetWithText(TextFormField, 'Describe the problem'), 'My payment failed but the money was taken.');
      await tester.tap(find.text('Attach a screenshot or proof (optional)'));
      await settle(tester);
      expect(find.textContaining('shot.png'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit Ticket'));
      await settle(tester);
      debugPrint('PATHS ${app.adapter.requests.map((r) => '${r.method} ${r.path}').toList()}');

      final body = created.body! as Map;
      expect(body['category'], 'OTHER');
      expect(body['subject'], 'Payment failed');
      expect(body['bookingRef'], 'abr12345');
      expect(body['proofFileIds'], <String>['proof-1']);
      expect(app.requestedPaths.indexOf('files/proofs'), lessThan(app.requestedPaths.lastIndexOf('customer/support/tickets')));
    });

    testWidgets('a short subject is stopped on the phone and nothing is sent', (tester) async {
      final app = await openSupport(tester, backend());
      await fillAndOpen(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Hi');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit Ticket'));
      await settle(tester);

      expect(find.text('Please enter a subject (min 4 chars)'), findsOneWidget);
      expect(app.adapter.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets("shows the server's sentence when it refuses", (tester) async {
      await openSupport(tester, (request) async {
        if (request.method == 'POST' && request.path == 'customer/support/tickets') {
          return FakeResponse.error(
            400,
            'VALIDATION_FAILED',
            message: 'Tell us what went wrong',
            details: <String, Object?>{
              'issues': <Map<String, Object?>>[
                <String, Object?>{'path': 'message', 'message': 'Tell us what went wrong'},
              ],
            },
          );
        }
        return backend()(request);
      });
      await fillAndOpen(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Payment failed');
      await tester.enterText(find.widgetWithText(TextFormField, 'Describe the problem'), 'It failed at the last step.');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit Ticket'));
      await settle(tester);

      expect(find.text('Tell us what went wrong'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Submit Ticket'), findsOneWidget);
    });
  });
}
