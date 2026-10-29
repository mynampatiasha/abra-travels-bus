import 'package:admin_app/core/browser_files.dart' as browser;
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_admin.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Map<String, Object?> staffRecord({
  required String id,
  required String name,
  required String email,
  required String role,
  required String roleName,
  required String status,
  bool mfa = false,
  int overrides = 0,
  String? lastSeen,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'email': email,
  'role': role,
  'roleName': roleName,
  'status': status,
  'mfa': mfa,
  'overrides': overrides,
  'lastSeen': lastSeen,
};

FakeBackend withStaff(Persona persona) {
  final backend = FakeBackend(persona);
  final staffList = <Map<String, Object?>>[
    staffRecord(
      id: 'staff-1',
      name: 'Asha Admin',
      email: 'asha@abratravels.com',
      role: 'SUPER_ADMIN',
      roleName: 'Super Admin',
      status: 'ACTIVE',
      mfa: true,
      lastSeen: '2026-10-15T12:00:00.000Z',
    ),
    staffRecord(
      id: 'staff-2',
      name: 'Devan Support',
      email: 'devan@abratravels.com',
      role: 'SUPPORT',
      roleName: 'Support',
      status: 'ACTIVE',
      mfa: false,
    ),
    staffRecord(
      id: 'staff-3',
      name: 'Farah Pending',
      email: 'farah@abratravels.com',
      role: 'ADMIN',
      roleName: 'Admin',
      status: 'INVITED',
      mfa: false,
    ),
  ];

  backend.overrides['GET admin/staff/roles'] = (request) {
    return FakeResponse.ok(<Map<String, Object?>>[
      {'key': 'SUPER_ADMIN', 'name': 'Super Admin'},
      {'key': 'ADMIN', 'name': 'Admin'},
      {'key': 'SUPPORT', 'name': 'Support'},
      {'key': 'ACCOUNTS', 'name': 'Accounts'},
    ]);
  };

  backend.overrides['GET admin/staff'] = (request) {
    final search = (request.options.queryParameters['search'] ?? '').toString().toLowerCase();
    final role = request.options.queryParameters['role'];
    final status = request.options.queryParameters['status'];

    final filtered = staffList.where((s) {
      if (search.isNotEmpty) {
        final matches = (s['name'] as String).toLowerCase().contains(search) ||
            (s['email'] as String).toLowerCase().contains(search);
        if (!matches) return false;
      }
      if (role != null && role != 'ALL' && s['role'] != role) return false;
      if (status != null && status != 'ALL' && s['status'] != status) return false;
      return true;
    }).toList();

    return FakeResponse.ok(
      filtered,
      meta: <String, Object?>{
        'page': 1,
        'pageSize': 15,
        'total': filtered.length,
      },
    );
  };

  backend.overrides['POST admin/staff'] = (request) {
    final body = (request.body as Map?) ?? const {};
    final newMember = staffRecord(
      id: 'staff-new',
      name: (body['name'] as String?) ?? 'New Staff',
      email: (body['email'] as String?) ?? 'new@abratravels.com',
      role: (body['role'] as String?) ?? 'OPERATIONS',
      roleName: (body['role'] as String?) ?? 'Operations',
      status: 'INVITED',
    );
    staffList.add(newMember);
    return FakeResponse.ok(newMember);
  };

  backend.overrides['POST admin/staff/staff-3/resend'] = (request) {
    return FakeResponse.ok(<String, Object?>{'success': true});
  };

  backend.overrides['POST admin/staff/staff-2/deactivate'] = (request) {
    final target = staffList.firstWhere((s) => s['id'] == 'staff-2');
    target['status'] = 'DEACTIVATED';
    return FakeResponse.ok(target);
  };

  backend.overrides['GET admin/staff/export?page=1&pageSize=15&format=csv'] = (request) {
    return const FakeResponse(200, 'id,name,email\nstaff-1,Asha,asha@abratravels.com');
  };

  backend.overrides['POST staff-invitations/inspect'] = (request) {
    return FakeResponse.ok(<String, Object?>{
      'name': 'Farah Pending',
      'email': 'farah@abratravels.com',
      'roleKey': 'ADMIN',
      'roleName': 'Admin',
    });
  };

  backend.overrides['POST staff-invitations/accept'] = (request) {
    return FakeResponse.ok(<String, Object?>{'success': true});
  };

  return backend;
}

Future<TestAdmin> openStaff(WidgetTester tester, FakeBackend backend) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, AdminRoutes.staff);
  return app;
}

void main() {
  group('Admin Staff Management Screen', () {
    testWidgets('renders tabs and lists staff members', (tester) async {
      final backend = withStaff(Persona.superAdmin);
      await openStaff(tester, backend);

      expect(find.textContaining('Staff ('), findsOneWidget);
      expect(find.text('Permission matrix'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);

      expect(find.text('Asha Admin'), findsWidgets);
      expect(find.text('Devan Support'), findsOneWidget);
      expect(find.text('Farah Pending'), findsOneWidget);

      expect(find.text('asha@abratravels.com'), findsOneWidget);
      expect(find.text('ACTIVE'), findsWidgets);
      expect(find.text('INVITED'), findsOneWidget);
    });

    testWidgets('allows searching staff by name', (tester) async {
      final backend = withStaff(Persona.superAdmin);
      await openStaff(tester, backend);

      final searchField = find.widgetWithText(TextField, 'Name or email');
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Devan');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(find.text('Devan Support'), findsOneWidget);
      expect(find.text('Farah Pending'), findsNothing);
    });

    testWidgets('opens Add staff modal and invites new staff', (tester) async {
      final backend = withStaff(Persona.superAdmin);
      await openStaff(tester, backend);

      final addBtn = find.text('Add staff');
      expect(addBtn, findsOneWidget);
      await tapOn(tester, addBtn);

      expect(find.text('Add staff'), findsWidgets);

      final nameField = inDialog(find.widgetWithText(TextField, 'Full name'));
      final emailField = inDialog(find.widgetWithText(TextField, 'Email'));
      await tester.enterText(nameField, 'Kavita Manager');
      await tester.enterText(emailField, 'kavita@abratravels.com');
      await settle(tester);

      final sendBtn = inDialog(find.text('Send invitation'));
      await tapOn(tester, sendBtn);

      expect(find.text('Invitation sent to kavita@abratravels.com'), findsOneWidget);
    });

    testWidgets('exports staff CSV list', (tester) async {
      final backend = withStaff(Persona.superAdmin);
      await openStaff(tester, backend);

      final exportBtn = find.text('Export CSV');
      expect(exportBtn, findsOneWidget);
      await tapOn(tester, exportBtn);

      expect(browser.lastDownloadName, 'staff.csv');
      expect(find.text('Staff list downloaded (CSV)'), findsOneWidget);
    });

    testWidgets('handles resend invitation and deactivation', (tester) async {
      final backend = withStaff(Persona.superAdmin);
      await openStaff(tester, backend);

      // Resend invitation for Farah Pending
      final resendBtn = find.text('Resend invite');
      expect(resendBtn, findsOneWidget);
      await tapOn(tester, resendBtn);

      expect(find.text('Invitation resent to farah@abratravels.com'), findsOneWidget);

      // Dismiss prior snackbar so new one can render cleanly
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pump();

      // Deactivate Devan (second active member)
      final deactivateBtns = find.text('Deactivate');
      expect(deactivateBtns, findsWidgets);
      await tapOn(tester, deactivateBtns.at(1));

      // Deactivation dialog
      expect(find.text('Deactivate Devan Support'), findsOneWidget);
      final confirmBtn = inDialog(find.text('Deactivate'));
      await tapOn(tester, confirmBtn);

      expect(find.text('Deactivate Devan Support'), findsNothing);
      expect(find.text('DEACTIVATED'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);
    });
  });

  group('Staff Invitation Set-Password Screen', () {
    testWidgets('renders invitation preview and sets password', (tester) async {
      final backend = withStaff(Persona.superAdmin);
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1000));
      await open(tester, '/staff-invitation?token=valid-token-123');

      expect(find.text('Join Abra Travels Staff'), findsOneWidget);
      expect(find.textContaining('Farah Pending'), findsOneWidget);
      expect(find.textContaining('farah@abratravels.com'), findsOneWidget);

      final pwFields = find.byType(TextField);
      expect(pwFields, findsNWidgets(2));

      await tester.enterText(pwFields.at(0), 'Secret@123456');
      await tester.enterText(pwFields.at(1), 'Secret@123456');
      await settle(tester);

      final submitBtn = find.text('Set password & activate');
      await tapOn(tester, submitBtn);

      expect(find.text('Account Activated'), findsOneWidget);
      expect(find.text('Sign in now'), findsOneWidget);
    });
  });
}
