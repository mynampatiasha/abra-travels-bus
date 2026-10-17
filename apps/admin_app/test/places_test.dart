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

FakeBackend withPlaces(Persona persona) => FakeBackend(persona)
  ..add('cities', <String, Object?>{
    'name': 'Hyderabad',
    'state': 'Telangana',
    'isActive': true,
  })
  ..add('locations', <String, Object?>{
    'name': 'Hyderabad Bus Stand',
    'address': '12, Main Road, Hyderabad',
    'usedFor': 'BOARDING',
    'source': 'ADMIN',
    'tripsUsing': 4,
    'isActive': true,
  })
  ..add('place-requests', <String, Object?>{
    'operatorName': 'Kaveri Express',
    'cityName': 'Hosur',
    'name': 'Hosur Bus Stand Gate 2',
    'address': 'Hosur Main Road',
    'status': 'PENDING',
    'reason': null,
    'requestedAt': DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String(),
  });

Future<TestAdmin> openPlaces(
  WidgetTester tester,
  FakeBackend backend, {
  String location = AdminRoutes.places,
}) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, location);
  return app;
}

void main() {
  group('Cities and places', () {
    testWidgets('shows the three tabs and the demo columns of Places', (
      tester,
    ) async {
      await openPlaces(tester, withPlaces(Persona.superAdmin));

      expect(find.text('Places'), findsOneWidget);
      expect(find.text('Cities'), findsWidgets);
      expect(find.text('Operator requests'), findsOneWidget);
      for (final column in <String>[
        'Place',
        'Used for',
        'Added by',
        'Trips using it',
      ]) {
        expect(find.text(column), findsWidgets, reason: column);
      }
      expect(find.text('Hyderabad Bus Stand'), findsOneWidget);
      expect(find.text('Boarding'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Admin'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('?tab=requests opens Operator requests; Approve sends it', (
      tester,
    ) async {
      final backend = withPlaces(Persona.superAdmin);
      final app = await openPlaces(
        tester,
        backend,
        location: '${AdminRoutes.places}?tab=requests',
      );
      final request = backend.of('place-requests').single;

      expect(find.text('Hosur Bus Stand Gate 2'), findsOneWidget);
      expect(find.text('Kaveri Express'), findsOneWidget);
      expect(find.text('3 h ago'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);

      await tapOn(tester, find.byTooltip('Approve').first);
      expect(
        app.requestsTo('admin/place-requests/${request['id']}/approve', 'POST'),
        hasLength(1),
      );
      expect(
        find.text('Approved. It is now available to every operator.'),
        findsOneWidget,
      );
    });

    testWidgets('Reject asks for the reason the operator reads', (
      tester,
    ) async {
      final backend = withPlaces(Persona.superAdmin);
      final app = await openPlaces(
        tester,
        backend,
        location: '${AdminRoutes.places}?tab=requests',
      );
      final request = backend.of('place-requests').single;

      await tapOn(tester, find.byTooltip('Reject').first);
      expect(inDialog(find.text('Reject request')), findsOneWidget);
      await tester.enterText(
        inDialog(find.byType(TextFormField)).first,
        'Too close to Gate 1',
      );
      await tapOn(tester, inDialog(find.text('Reject')).last);

      final sent = app
          .requestsTo('admin/place-requests/${request['id']}/reject', 'POST')
          .single;
      expect((sent.body! as Map)['reason'], 'Too close to Gate 1');
    });

    testWidgets('support staff without the catalogue do not get the page', (
      tester,
    ) async {
      final app = TestAdmin.signedIn(withPlaces(Persona.support));
      await app.pump(tester);
      await open(tester, AdminRoutes.places);
      expect(find.text('No access'), findsOneWidget);
      expect(app.requestsTo('admin/place-requests'), isEmpty);
    });
  });
}
