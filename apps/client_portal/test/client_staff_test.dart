import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Map<String, Object?> portalUserRecord({
  required String id,
  required String name,
  required String email,
  required String role,
  required String roleName,
  required String status,
  String? lastSeen,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'email': email,
  'role': role,
  'roleName': roleName,
  'status': status,
  'lastSeen': lastSeen,
  'createdAt': '2026-10-15T12:00:00.000Z',
};

FakeBackend withPortalUsers(Persona persona) {
  final backend = FakeBackend(persona);
  final users = <Map<String, Object?>>[
    portalUserRecord(
      id: 'u-1',
      name: 'Kaveri Owner',
      email: 'owner@kaveriexpress.in',
      role: 'SUPER_ADMIN',
      roleName: 'Owner',
      status: 'ACTIVE',
      lastSeen: '2026-10-20T10:00:00.000Z',
    ),
    portalUserRecord(
      id: 'u-2',
      name: 'Ramesh Manager',
      email: 'ramesh@kaveriexpress.in',
      role: 'ADMIN',
      roleName: 'Manager',
      status: 'ACTIVE',
    ),
    portalUserRecord(
      id: 'u-3',
      name: 'Suresh Booking',
      email: 'suresh@kaveriexpress.in',
      role: 'SUPPORT',
      roleName: 'Booking staff',
      status: 'INVITED',
    ),
  ];

  backend.overrides['GET client/users'] = (request) {
    final search = (request.options.queryParameters['search'] ?? '')
        .toString()
        .toLowerCase();
    final role = request.options.queryParameters['role'];
    final status = request.options.queryParameters['status'];

    final filtered = users.where((u) {
      if (search.isNotEmpty) {
        final matches = (u['name'] as String).toLowerCase().contains(search) ||
            (u['email'] as String).toLowerCase().contains(search);
        if (!matches) return false;
      }
      if (role != null && role != 'ALL' && u['role'] != role) return false;
      if (status != null && status != 'ALL' && u['status'] != status) {
        return false;
      }
      return true;
    }).toList();

    return FakeResponse.ok(<String, Object?>{
      'items': filtered,
      'total': filtered.length,
      'page': 1,
      'limit': 50,
    });
  };

  backend.overrides['POST client/users'] = (request) {
    final body = (request.body as Map?) ?? const {};
    final newUser = portalUserRecord(
      id: 'u-new',
      name: (body['name'] as String?) ?? 'New Staff',
      email: (body['email'] as String?) ?? 'new@kaveriexpress.in',
      role: (body['role'] as String?) ?? 'SUPPORT',
      roleName: (body['role'] as String?) == 'ADMIN'
          ? 'Manager'
          : (body['role'] as String?) == 'ACCOUNTS'
              ? 'Accounts'
              : 'Booking staff',
      status: 'INVITED',
    );
    users.add(newUser);
    return FakeResponse.ok(newUser);
  };

  backend.overrides['PATCH client/users/u-2'] = (request) {
    final body = (request.body as Map?) ?? const {};
    final target = users.firstWhere((u) => u['id'] == 'u-2');
    if (body['name'] != null) target['name'] = body['name'];
    return FakeResponse.ok(target);
  };

  backend.overrides['POST client/users/u-2/deactivate'] = (request) {
    final target = users.firstWhere((u) => u['id'] == 'u-2');
    target['status'] = 'DEACTIVATED';
    return FakeResponse.ok(target);
  };

  backend.overrides['POST client/users/u-2/activate'] = (request) {
    final target = users.firstWhere((u) => u['id'] == 'u-2');
    target['status'] = 'ACTIVE';
    return FakeResponse.ok(target);
  };

  backend.overrides['GET client/users/export?format=csv'] = (request) {
    return const FakeResponse(
      200,
      'Name,Email,Role,Status\nKaveri Owner,owner@kaveriexpress.in,Owner,ACTIVE',
    );
  };

  backend.overrides['GET client/users/matrix'] = (request) {
    return FakeResponse.ok(<String, Object?>{
      'roles': [
        {'key': 'OPERATOR_ADMIN', 'name': 'Owner'},
        {'key': 'OPERATOR_MANAGER', 'name': 'Manager'},
        {'key': 'BOOKING_STAFF', 'name': 'Booking staff'},
        {'key': 'ACCOUNT_STAFF', 'name': 'Accounts'},
      ],
      'pages': [
        {
          'id': 'buses',
          'title': 'Fleet & Buses',
          'levels': {
            'owner': 'FULL',
            'manager': 'EDIT',
            'booking': 'VIEW',
            'accounts': 'NONE',
          },
        },
        {
          'id': 'routes',
          'title': 'Routes & Stops',
          'levels': {
            'owner': 'FULL',
            'manager': 'EDIT',
            'booking': 'NONE',
            'accounts': 'NONE',
          },
        },
      ],
    });
  };

  return backend;
}

Future<TestPortal> openStaffRoles(
  WidgetTester tester,
  FakeBackend backend,
) async {
  final app = TestPortal.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, PortalRoutes.staffRoles);
  await settle(tester);
  return app;
}

void main() {
  group('Client Portal Staff Roles Screen', () {
    testWidgets('renders portal staff members and tabs', (tester) async {
      final backend = withPortalUsers(Persona.owner);
      await openStaffRoles(tester, backend);

      expect(find.text('Staff and roles'), findsWidgets);
      expect(find.textContaining('Portal users ('), findsOneWidget);
      expect(find.text('Permission matrix'), findsOneWidget);

      expect(find.text('Kaveri Owner'), findsWidgets);
      expect(find.text('Ramesh Manager'), findsOneWidget);
      expect(find.text('Suresh Booking'), findsOneWidget);
      expect(find.text('owner@kaveriexpress.in'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Invited'), findsOneWidget);
    });

    testWidgets('searches portal staff by name', (tester) async {
      final backend = withPortalUsers(Persona.owner);
      await openStaffRoles(tester, backend);

      final searchFields = find.byType(TextField);
      expect(searchFields, findsWidgets);

      await tester.enterText(searchFields.first, 'Ramesh');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(find.text('Ramesh Manager'), findsOneWidget);
      expect(find.text('Suresh Booking'), findsNothing);
    });

    testWidgets('switches to Permission matrix tab', (tester) async {
      final backend = withPortalUsers(Persona.owner);
      await openStaffRoles(tester, backend);

      final matrixTab = find.text('Permission matrix');
      expect(matrixTab, findsOneWidget);
      await tapOn(tester, matrixTab);

      expect(find.textContaining('Owner has full access to everything'), findsOneWidget);
      expect(find.text('Fleet & Buses'), findsOneWidget);
      expect(find.text('Routes & Stops'), findsOneWidget);
    });

    testWidgets('shows Not connected yet when matrix endpoint fails', (tester) async {
      final backend = withPortalUsers(Persona.owner);
      backend.overrides['GET client/users/matrix'] =
          (request) => const FakeResponse(500, 'Server error');
      await openStaffRoles(tester, backend);

      final matrixTab = find.text('Permission matrix');
      await tapOn(tester, matrixTab);

      expect(find.text('Not connected yet'), findsOneWidget);
    });

    testWidgets('invites new user via dialog', (tester) async {
      final backend = withPortalUsers(Persona.owner);
      await openStaffRoles(tester, backend);

      final addBtn = find.text('Add user');
      expect(addBtn, findsOneWidget);
      await tapOn(tester, addBtn);

      expect(inDialog(find.text('Add user')), findsOneWidget);

      final dialogTextFields = inDialog(find.byType(TextField));
      expect(dialogTextFields, findsNWidgets(2));

      await tester.enterText(dialogTextFields.at(0), 'Anita Accounts');
      await tester.enterText(dialogTextFields.at(1), 'anita@kaveriexpress.in');
      await settle(tester);

      final submitBtn = inDialog(find.text('Send invitation'));
      await tapOn(tester, submitBtn);

      expect(find.text('Invitation sent'), findsOneWidget);
    });

    testWidgets('deactivates and activates user', (tester) async {
      final backend = withPortalUsers(Persona.owner);
      await openStaffRoles(tester, backend);

      final deactivateBtns = find.byTooltip('Deactivate');
      expect(deactivateBtns, findsWidgets);

      // Deactivate second active user (Ramesh Manager)
      await tapOn(tester, deactivateBtns.at(1));

      expect(inDialog(find.text('Deactivate Ramesh Manager')), findsOneWidget);
      final confirmBtn = inDialog(find.text('Deactivate'));
      await tapOn(tester, confirmBtn);

      expect(find.text('Deactivate successful'), findsOneWidget);
    });
  });
}
