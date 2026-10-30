// Customers (admin): the list, the filters, one customer, and block, sign out, delete.
import 'package:admin_app/features/customers/admin_customers.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_admin.dart';

/// May look at customers but not change them.
const viewer = Persona(
  name: 'Vik Viewer',
  userType: 'STAFF',
  roleKey: 'SUPPORT',
  permissions: {'customers.read'},
);

/// May change customers but not delete them.
const editor = Persona(
  name: 'Eli Editor',
  userType: 'STAFF',
  roleKey: 'SUPPORT',
  permissions: {'customers.read', 'customers.update'},
);

Map<String, Object?> row(String id, String name, {String status = 'ACTIVE', String method = 'whatsapp'}) =>
    <String, Object?>{
      'id': id,
      'name': name,
      'email': '${name.split(' ').first.toLowerCase()}@example.com',
      'phone': '+91987650000${id.length}',
      'language': 'en',
      'signInMethod': method,
      'emailVerified': false,
      'joinedAt': '2026-10-01T00:00:00.000Z',
      'status': status,
      'bookings': 3,
      'spentPaise': 245000,
    };

Map<String, Object?> detail(String id, String name, {String status = 'ACTIVE'}) => <String, Object?>{
  ...row(id, name, status: status),
  'blocked': status == 'SUSPENDED'
      ? <String, Object?>{'reason': 'Abusive to drivers', 'at': '2026-10-20T10:00:00.000Z'}
      : null,
  'recentBookings': <Map<String, Object?>>[
    <String, Object?>{
      'id': 'b1',
      'pnr': 'ABR12345',
      'status': 'CONFIRMED',
      'amountPaise': 120000,
      'seats': 2,
      'bookedAt': '2026-10-05T00:00:00.000Z',
    },
  ],
  'devices': <Map<String, Object?>>[
    <String, Object?>{
      'id': 'd1',
      'current': false,
      'clientType': 'MOBILE',
      'deviceName': 'Pixel 7',
      'lastUsedAt': '2026-10-28T08:00:00.000Z',
    },
  ],
};

FakeBackend withCustomers(Persona persona, {String status = 'ACTIVE'}) {
  final backend = FakeBackend(persona);
  final overrides = backend.overrides;
  FakeResponse guarded(String key, FakeResponse Function() ok) =>
      persona.permissions.contains(key) ? ok() : FakeResponse.error(403, 'PERMISSION_DENIED');
  overrides['GET admin/customers'] = (_) => guarded(
    'customers.read',
    () => FakeResponse.ok(
      <Map<String, Object?>>[
        row('c1', 'Zainab Khan', status: status),
        row('c22', 'Ravi Kumar', method: 'google'),
      ],
      meta: <String, Object?>{'page': 1, 'pageSize': 20, 'total': 2},
    ),
  );
  overrides['GET admin/customers/c1'] = (_) =>
      guarded('customers.read', () => FakeResponse.ok(detail('c1', 'Zainab Khan', status: status)));
  overrides['POST admin/customers/c1/block'] = (_) =>
      guarded('customers.update', () => FakeResponse.ok(detail('c1', 'Zainab Khan', status: 'SUSPENDED')));
  overrides['POST admin/customers/c1/unblock'] = (_) =>
      guarded('customers.update', () => FakeResponse.ok(detail('c1', 'Zainab Khan')));
  overrides['POST admin/customers/c1/sessions/revoke'] = (_) =>
      guarded('customers.update', () => FakeResponse.ok(<String, Object?>{'signedOut': 1}));
  overrides['DELETE admin/customers/c1'] = (_) =>
      guarded('customers.account.delete', () => FakeResponse.ok(<String, Object?>{'deleted': true}));
  return backend;
}

Future<TestAdmin> openCustomers(WidgetTester tester, FakeBackend backend) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, AdminRoutes.customers);
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

Future<void> openZainab(WidgetTester tester) async {
  await tapOn(tester, find.text('Zainab Khan'));
}

void main() {
  group('the list', () {
    testWidgets('comes from /admin/customers with bookings and money, not from sample data', (tester) async {
      final app = await openCustomers(tester, withCustomers(Persona.superAdmin));

      expect(find.byType(AdminCustomersPage), findsOneWidget);
      expect(find.text('Zainab Khan'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.textContaining('3 bookings'), findsWidgets);
      expect(find.textContaining('Rs 2,450'), findsWidgets);
      expect(find.text('Google'), findsOneWidget);
      expect(app.requestsTo('admin/customers', 'GET'), isNotEmpty);
      expect(app.requestsTo('users', 'GET'), isEmpty);
    });

    testWidgets('searching and filtering ask the server', (tester) async {
      final app = await openCustomers(tester, withCustomers(Persona.superAdmin));

      await tester.enterText(find.widgetWithText(TextField, 'Search name, email or phone'), 'zainab');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      final last = app.requestsTo('admin/customers', 'GET').last.options.queryParameters;
      expect(last['search'], 'zainab');
      expect(last.containsKey('userType'), isFalse);
    });

    testWidgets('a role without customers.read sees a refusal, not rows', (tester) async {
      final backend = withCustomers(const Persona(
        name: 'No Access',
        userType: 'STAFF',
        roleKey: 'SUPPORT',
        permissions: {'catalogue.read', 'customers.read'},
      ));
      backend.overrides['GET admin/customers'] = (_) => FakeResponse.error(403, 'PERMISSION_DENIED');
      await openCustomers(tester, backend);
      expect(find.text('Zainab Khan'), findsNothing);
    });
  });

  group('one customer', () {
    testWidgets('shows bookings, money, devices; Super Admin sees every action', (tester) async {
      final app = await openCustomers(tester, withCustomers(Persona.superAdmin));
      await openZainab(tester);

      expect(app.requestsTo('admin/customers/c1', 'GET'), hasLength(1));
      expect(find.textContaining('ABR12345'), findsOneWidget);
      expect(find.textContaining('Pixel 7'), findsOneWidget);
      expect(find.text('Block account'), findsOneWidget);
      expect(find.text('Sign out all devices'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('blocking needs a reason, then sends it', (tester) async {
      final app = await openCustomers(tester, withCustomers(Persona.superAdmin));
      await openZainab(tester);

      await tapOn(tester, find.text('Block account'));
      await tapOn(tester, find.widgetWithText(FilledButton, 'Block'));
      expect(find.text('Write why this account is blocked'), findsOneWidget);
      expect(app.requestsTo('admin/customers/c1/block', 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Reason'), 'Fake bookings');
      await tapOn(tester, find.widgetWithText(FilledButton, 'Block'));
      final sent = app.requestsTo('admin/customers/c1/block', 'POST');
      expect(sent, hasLength(1));
      expect((sent.single.body! as Map)['reason'], 'Fake bookings');
    });

    testWidgets('a blocked customer shows the reason and can be unblocked', (tester) async {
      final app = await openCustomers(tester, withCustomers(Persona.superAdmin, status: 'SUSPENDED'));
      await openZainab(tester);

      expect(find.textContaining('Abusive to drivers'), findsOneWidget);
      expect(find.text('Block account'), findsNothing);
      await tapOn(tester, find.text('Unblock'));
      expect(app.requestsTo('admin/customers/c1/unblock', 'POST'), hasLength(1));
    });

    testWidgets('sign out of all devices asks first', (tester) async {
      final app = await openCustomers(tester, withCustomers(Persona.superAdmin));
      await openZainab(tester);

      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Sign out all devices'));
      expect(app.requestsTo('admin/customers/c1/sessions/revoke', 'POST'), isEmpty);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Sign out all devices'));
      expect(app.requestsTo('admin/customers/c1/sessions/revoke', 'POST'), hasLength(1));
    });

    testWidgets('delete asks first, calls the server and closes', (tester) async {
      final app = await openCustomers(tester, withCustomers(Persona.superAdmin));
      await openZainab(tester);

      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Delete'));
      expect(app.requestsTo('admin/customers/c1', 'DELETE'), isEmpty);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(app.requestsTo('admin/customers/c1', 'DELETE'), hasLength(1));
      expect(find.text('Block account'), findsNothing);
    });

    testWidgets("the server's own sentence is shown when it refuses", (tester) async {
      final backend = withCustomers(Persona.superAdmin);
      backend.overrides['DELETE admin/customers/c1'] = (_) => FakeResponse.error(
        409,
        'INVALID_STATE_TRANSITION',
        message: 'This customer still has a booking to travel on. They must be cancelled or completed first.',
      );
      await openCustomers(tester, backend);
      await openZainab(tester);

      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Delete'));
      await tapOn(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(find.textContaining('still has a booking to travel on'), findsOneWidget);
    });

    testWidgets('a view-only role sees the customer but no action buttons', (tester) async {
      await openCustomers(tester, withCustomers(viewer));
      await openZainab(tester);

      expect(find.textContaining('ABR12345'), findsOneWidget);
      expect(find.text('Block account'), findsNothing);
      expect(find.text('Sign out all devices'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('a role that may edit but not delete has no Delete button', (tester) async {
      await openCustomers(tester, withCustomers(editor));
      await openZainab(tester);

      expect(find.text('Block account'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });
  });
}
