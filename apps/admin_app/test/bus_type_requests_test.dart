import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_admin.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

FakeBackend withRequests(Persona persona) {
  final backend = FakeBackend(persona)
    ..add('bus-types', <String, Object?>{
      'key': 'AC_SLEEPER',
      'name': 'AC Sleeper',
      'isAc': true,
      'berthType': 'SLEEPER',
      'isActive': true,
    })
    ..add('bus-type-requests', <String, Object?>{
      'operatorName': 'Kaveri Express',
      'name': 'Mini Coach',
      'isAc': false,
      'berthType': 'MIXED',
      'status': 'PENDING',
      'reason': null,
      'requestedAt': DateTime.now()
          .subtract(const Duration(hours: 3))
          .toIso8601String(),
    });
  return backend;
}

Future<TestAdmin> openBusTypes(
  WidgetTester tester,
  FakeBackend backend, {
  String location = AdminRoutes.busTypes,
}) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, location);
  return app;
}

void main() {
  group('Bus type requests tab', () {
    testWidgets('Bus types page has a Requests tab with the number waiting', (
      tester,
    ) async {
      final app = await openBusTypes(tester, withRequests(Persona.superAdmin));
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('AC Sleeper'), findsWidgets);
      expect(
        app.requestsTo('admin/bus-type-requests/pending-count'),
        isNotEmpty,
      );
    });

    testWidgets('?tab=requests opens the requests; Approve sends it', (
      tester,
    ) async {
      final backend = withRequests(Persona.superAdmin);
      final app = await openBusTypes(
        tester,
        backend,
        location: '${AdminRoutes.busTypes}?tab=requests',
      );
      final request = backend.of('bus-type-requests').single;

      expect(find.text('Mini Coach'), findsOneWidget);
      expect(find.text('Non-AC Seater + Sleeper'), findsOneWidget);
      expect(find.text('Kaveri Express'), findsOneWidget);
      expect(find.text('3 h ago'), findsOneWidget);

      await tapOn(tester, find.byTooltip('Approve').first);
      expect(
        app.requestsTo(
          'admin/bus-type-requests/${request['id']}/approve',
          'POST',
        ),
        hasLength(1),
      );
      expect(
        find.text('Approved. The bus type is now on the list.'),
        findsOneWidget,
      );
    });

    testWidgets('Reject asks for the reason the operator reads', (
      tester,
    ) async {
      final backend = withRequests(Persona.superAdmin);
      final app = await openBusTypes(
        tester,
        backend,
        location: '${AdminRoutes.busTypes}?tab=requests',
      );
      final request = backend.of('bus-type-requests').single;

      await tapOn(tester, find.byTooltip('Reject').first);
      expect(inDialog(find.text('Reject request')), findsOneWidget);
      await tester.enterText(
        inDialog(find.byType(TextFormField)).first,
        'Use AC Seater + Sleeper',
      );
      await tapOn(tester, inDialog(find.text('Reject')).last);

      final sent = app
          .requestsTo(
            'admin/bus-type-requests/${request['id']}/reject',
            'POST',
          )
          .single;
      expect((sent.body! as Map)['reason'], 'Use AC Seater + Sleeper');
    });
  });
}
