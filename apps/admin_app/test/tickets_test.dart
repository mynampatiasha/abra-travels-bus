// Support tickets (admin): the list, the filters, one ticket, reply, assign, resolve, reopen.
import 'package:admin_app/features/support/admin_tickets_page.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_admin.dart';

/// May read tickets but not answer them.
const viewer = Persona(
  name: 'Vik Viewer',
  userType: 'STAFF',
  roleKey: 'ACCOUNTS',
  permissions: {'support.read'},
);

Map<String, Object?> ticket(
  String id,
  String number, {
  String status = 'OPEN',
  bool overdue = false,
  bool assignedToMe = false,
  String message = 'My payment failed but the money was taken.',
}) => <String, Object?>{
  'id': id,
  'ticketNumber': number,
  'customerId': 'cust-1',
  'customerName': 'Zainab Khan',
  'category': 'PAYMENT',
  'message': message,
  'bookingRef': 'ABR12345',
  'status': status,
  'priority': 'NORMAL',
  'assignedToName': assignedToMe ? 'Asha Admin' : '',
  'assignedToMe': assignedToMe,
  'respondBy': null,
  'overdue': overdue,
  'lastReplyBy': 'CUSTOMER',
  'repliesCount': 1,
  'createdAt': '2026-10-28T08:00:00.000Z',
  'updatedAt': '2026-10-28T08:00:00.000Z',
};

Map<String, Object?> detail(Map<String, Object?> base) => <String, Object?>{
  ...base,
  'replies': <Map<String, Object?>>[
    <String, Object?>{
      'id': 'r1',
      'authorType': 'STAFF',
      'authorName': 'Asha Admin',
      'body': 'We are checking with the bank.',
      'at': '2026-10-28T09:00:00.000Z',
    },
  ],
  'proofs': <Map<String, Object?>>[
    <String, Object?>{'id': 'p1', 'originalName': 'screenshot.png', 'mimeType': 'image/png', 'sizeBytes': 10},
  ],
};

FakeBackend withTickets(Persona persona, {String status = 'OPEN', bool overdue = false}) {
  final backend = FakeBackend(persona);
  final overrides = backend.overrides;
  FakeResponse guarded(String key, FakeResponse Function() ok) =>
      persona.permissions.contains(key) ? ok() : FakeResponse.error(403, 'PERMISSION_DENIED');
  final first = ticket('t1', 'TK-1', status: status, overdue: overdue);
  overrides['GET admin/support/tickets'] = (_) => guarded(
    'support.read',
    () => FakeResponse.ok(
      <Map<String, Object?>>[first, ticket('t2', 'TK-2', message: 'Where is my refund?')],
      meta: <String, Object?>{'page': 1, 'pageSize': 10, 'total': 2},
    ),
  );
  overrides['GET admin/support/tickets/t1'] = (_) => guarded('support.read', () => FakeResponse.ok(detail(first)));
  overrides['GET admin/support/canned-replies'] = (_) => guarded(
    'support.read',
    () => FakeResponse.ok(<Map<String, Object?>>[
      <String, Object?>{'id': 'c1', 'title': 'Refund timeline', 'body': 'Refunds reach you in 5 to 7 days.'},
    ]),
  );
  overrides['GET admin/support/availability'] = (_) => guarded(
    'support.read',
    () => FakeResponse.ok(<String, Object?>{'available': false, 'capacity': 5, 'open': 0}),
  );
  overrides['PUT admin/support/availability'] = (request) => guarded(
    'support.manage',
    () => FakeResponse.ok(<String, Object?>{
      'available': (request.body! as Map)['available'],
      'capacity': 5,
      'open': 2,
    }),
  );
  overrides['DELETE admin/support/canned-replies/c1'] = (_) =>
      guarded('support.manage', () => FakeResponse.ok(<String, Object?>{'deleted': true}));
  for (final action in ['reply', 'assign', 'resolve', 'reopen']) {
    overrides['POST admin/support/tickets/t1/$action'] = (_) =>
        guarded('support.manage', () => FakeResponse.ok(detail(first)));
  }
  return backend;
}

Future<TestAdmin> openTickets(WidgetTester tester, FakeBackend backend) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, AdminRoutes.tickets);
  return app;
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('the list', () {
    testWidgets('comes from /admin/support/tickets, not from sample data', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));

      expect(find.byType(AdminTicketsPage), findsOneWidget);
      expect(find.text('TK-1'), findsOneWidget);
      expect(find.text('TK-2'), findsOneWidget);
      expect(find.text('Where is my refund?'), findsOneWidget);
      expect(find.text('2 tickets'), findsOneWidget);
      expect(find.textContaining('Not connected yet'), findsNothing);
      expect(app.requestsTo('admin/support/tickets', 'GET'), isNotEmpty);
    });

    testWidgets('flags a ticket that nobody answered in time', (tester) async {
      await openTickets(tester, withTickets(Persona.superAdmin, overdue: true));
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('searching and filtering ask the server', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));

      await tester.enterText(find.widgetWithText(TextField, 'Search ticket, customer or message'), 'refund');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(app.requestsTo('admin/support/tickets', 'GET').last.options.queryParameters['search'], 'refund');

      await tapOn(tester, find.widgetWithText(FilterChip, 'Overdue only'));
      expect(app.requestsTo('admin/support/tickets', 'GET').last.options.queryParameters['overdue'], 'true');
      await tapOn(tester, find.widgetWithText(FilterChip, 'Assigned to me'));
      expect(app.requestsTo('admin/support/tickets', 'GET').last.options.queryParameters['mine'], 'true');
    });

    testWidgets('a refusal from the server is shown with Try again', (tester) async {
      final backend = withTickets(Persona.superAdmin);
      backend.overrides['GET admin/support/tickets'] = (_) =>
          FakeResponse.error(409, 'INVALID_STATE_TRANSITION', message: 'Tickets are being moved. Try again in a minute.');
      await openTickets(tester, backend);
      expect(find.text('Tickets are being moved. Try again in a minute.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    });
  });

  group('automatic assignment', () {
    testWidgets('the switch shows my status and turning it on tells the server and reloads the list', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));
      expect(find.text('I am available for tickets'), findsOneWidget);
      expect(find.textContaining('Switch on to receive tickets automatically'), findsOneWidget);
      final before = app.requestsTo('admin/support/tickets', 'GET').length;

      await tapOn(tester, find.byType(Switch));

      final sent = app.requestsTo('admin/support/availability', 'PUT');
      expect(sent, hasLength(1));
      expect((sent.single.body! as Map)['available'], true);
      expect(find.textContaining('You hold 2 of 5'), findsOneWidget);
      expect(app.requestsTo('admin/support/tickets', 'GET').length, greaterThan(before));
    });

    testWidgets('a view-only role cannot switch it', (tester) async {
      await openTickets(tester, withTickets(viewer));
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('the Unassigned filter asks for tickets nobody has taken', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));
      await tapOn(tester, find.widgetWithText(FilterChip, 'Unassigned'));
      expect(app.requestsTo('admin/support/tickets', 'GET').last.options.queryParameters['unassigned'], 'true');
    });

    testWidgets('says who has a ticket and whether it was assigned automatically', (tester) async {
      final backend = withTickets(Persona.superAdmin);
      final auto = ticket('t1', 'TK-1', assignedToMe: true)..['autoAssigned'] = true;
      backend.overrides['GET admin/support/tickets'] = (_) => FakeResponse.ok(
        <Map<String, Object?>>[auto, ticket('t2', 'TK-2')],
        meta: <String, Object?>{'page': 1, 'pageSize': 10, 'total': 2},
      );
      await openTickets(tester, backend);
      expect(find.textContaining('assigned automatically'), findsOneWidget);
      expect(find.textContaining('waiting for an agent'), findsOneWidget);
    });
  });

  group('export', () {
    testWidgets('Export CSV asks for every ticket that matches, 100 at a time', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));
      await tapOn(tester, find.text('Export CSV'));

      final sizes = app
          .requestsTo('admin/support/tickets', 'GET')
          .map((r) => r.options.queryParameters['pageSize'])
          .toList();
      expect(sizes, contains(100));
      expect(find.text('Export CSV'), findsOneWidget);
    });
  });

  group('one ticket', () {
    testWidgets('shows the message, the replies and the proof files', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));
      await tapOn(tester, find.text('TK-1'));

      expect(app.requestsTo('admin/support/tickets/t1', 'GET'), hasLength(1));
      expect(find.textContaining('We are checking with the bank.'), findsOneWidget);
      expect(find.textContaining('screenshot.png'), findsOneWidget);
      expect(find.textContaining('booking ABR12345'), findsOneWidget);
    });

    testWidgets('a reply is sent with its text, and a ready-made reply fills the box', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));
      await tapOn(tester, find.text('TK-1'));

      await tapOn(tester, find.byType(DropdownButtonFormField<String>).last);
      await tapOn(tester, find.text('Refund timeline').last);
      expect(find.text('Refunds reach you in 5 to 7 days.'), findsOneWidget);

      await tapOn(tester, find.widgetWithText(FilledButton, 'Send reply'));
      final sent = app.requestsTo('admin/support/tickets/t1/reply', 'POST');
      expect(sent, hasLength(1));
      expect((sent.single.body! as Map)['message'], 'Refunds reach you in 5 to 7 days.');
      expect(find.text('Reply sent.'), findsOneWidget);
    });

    testWidgets('a ready-made reply can be removed', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));
      await tapOn(tester, find.text('TK-1'));
      expect(find.text('Remove this ready-made reply'), findsNothing);

      await tapOn(tester, find.byType(DropdownButtonFormField<String>).last);
      await tapOn(tester, find.text('Refund timeline').last);
      await tapOn(tester, find.text('Remove this ready-made reply'));

      expect(app.requestsTo('admin/support/canned-replies/c1', 'DELETE'), hasLength(1));
      expect(find.text('Ready-made reply removed.'), findsOneWidget);
    });

    testWidgets('assign and resolve call the server', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin));
      await tapOn(tester, find.text('TK-1'));

      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Assign to me'));
      expect((app.requestsTo('admin/support/tickets/t1/assign', 'POST').single.body! as Map)['assignToMe'], true);
      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Mark resolved'));
      expect(app.requestsTo('admin/support/tickets/t1/resolve', 'POST'), hasLength(1));
    });

    testWidgets('a resolved ticket offers Reopen and no reply box', (tester) async {
      final app = await openTickets(tester, withTickets(Persona.superAdmin, status: 'RESOLVED'));
      await tapOn(tester, find.text('TK-1'));

      expect(find.widgetWithText(FilledButton, 'Send reply'), findsNothing);
      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Reopen'));
      expect(app.requestsTo('admin/support/tickets/t1/reopen', 'POST'), hasLength(1));
    });

    testWidgets("the server's sentence is shown when it refuses", (tester) async {
      final backend = withTickets(Persona.superAdmin);
      backend.overrides['POST admin/support/tickets/t1/resolve'] = (_) =>
          FakeResponse.error(409, 'INVALID_STATE_TRANSITION', message: 'This ticket is already resolved.');
      await openTickets(tester, backend);
      await tapOn(tester, find.text('TK-1'));
      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Mark resolved'));
      expect(find.text('This ticket is already resolved.'), findsOneWidget);
    });

    testWidgets('a view-only role sees the ticket but has no buttons', (tester) async {
      await openTickets(tester, withTickets(viewer));
      await tapOn(tester, find.text('TK-1'));

      expect(find.textContaining('We are checking with the bank.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Send reply'), findsNothing);
      expect(find.text('Mark resolved'), findsNothing);
      expect(find.text('Assign to me'), findsNothing);
    });
  });
}
