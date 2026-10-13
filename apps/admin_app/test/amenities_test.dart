import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

FakeBackend withAmenities(Persona persona) {
  final backend = FakeBackend(persona)
    ..add('amenities', <String, Object?>{
      'key': 'WIFI',
      'name': 'Wi-Fi',
      'isActive': true,
    })
    ..add('amenities', <String, Object?>{
      'key': 'CHARGING_POINT',
      'name': 'Charging point',
      'isActive': true,
    })
    ..add('amenities', <String, Object?>{
      'key': 'BLANKET',
      'name': 'Blanket',
      'isActive': false,
    });
  return backend;
}

Future<TestAdmin> openBusTypes(WidgetTester tester, FakeBackend backend) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1200));
  await open(tester, AdminRoutes.busTypes);
  return app;
}

void main() {
  group('Amenities card on the Bus types page', () {
    testWidgets('lists every amenity with its state, switched off ones too', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openBusTypes(tester, withAmenities(Persona.superAdmin));

      expect(find.text('Amenities'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('Charging point'), findsOneWidget);
      expect(find.text('Blanket'), findsOneWidget);
      // the state is in words for screen readers, not only in colour
      expect(find.bySemanticsLabel(RegExp('Wi-Fi: on')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Blanket: off')), findsOneWidget);
      expect(find.byTooltip('Toggle Charging point'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a switch turns an amenity off, and on again', (tester) async {
      final semantics = tester.ensureSemantics();
      final backend = withAmenities(Persona.superAdmin);
      final app = await openBusTypes(tester, backend);
      final charging = backend
          .of('amenities')
          .firstWhere((record) => record['key'] == 'CHARGING_POINT');

      await tapOn(tester, find.byTooltip('Toggle Charging point'));
      var request = app
          .requestsTo('admin/amenities/${charging['id']}/active', 'PATCH')
          .single;
      expect((request.body! as Map)['active'], isFalse);
      expect(
        find.bySemanticsLabel(RegExp('Charging point: off')),
        findsOneWidget,
      );

      await tapOn(tester, find.byTooltip('Toggle Charging point'));
      request = app
          .requestsTo('admin/amenities/${charging['id']}/active', 'PATCH')
          .last;
      expect((request.body! as Map)['active'], isTrue);
      expect(
        find.bySemanticsLabel(RegExp('Charging point: on')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('Add amenity asks for a name and adds it', (tester) async {
      final backend = withAmenities(Persona.superAdmin);
      backend.overrides['POST admin/amenities'] = (request) {
        final created = backend.add('amenities', <String, Object?>{
          'key': 'RECLINING_SEATS',
          'name': (request.body! as Map)['name'],
          'isActive': true,
        });
        return FakeResponse.ok(created);
      };
      final app = await openBusTypes(tester, backend);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Add amenity'));
      expect(inDialog(find.text('Add amenity')), findsOneWidget);

      // an empty name is not sent
      await tapOn(tester, inDialog(find.widgetWithText(AbraButton, 'Add')));
      expect(app.requestsTo('admin/amenities', 'POST'), isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amenity name'),
        'Reclining seats',
      );
      await tapOn(tester, inDialog(find.widgetWithText(AbraButton, 'Add')));

      expect(
        (app.requestsTo('admin/amenities', 'POST').single.body! as Map)['name'],
        'Reclining seats',
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Reclining seats'), findsOneWidget);
    });

    testWidgets('a name that exists is refused in the window', (tester) async {
      final backend = withAmenities(Persona.superAdmin);
      backend.overrides['POST admin/amenities'] = (_) => FakeResponse.error(
        409,
        'ALREADY_REGISTERED',
        message: 'An amenity with this name already exists.',
      );
      await openBusTypes(tester, backend);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Add amenity'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amenity name'),
        'wifi',
      );
      await tapOn(tester, inDialog(find.widgetWithText(AbraButton, 'Add')));

      expect(
        find.text('An amenity with this name already exists.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('without catalogue.manage the amenities can be seen but not '
        'changed', (tester) async {
      final backend = withAmenities(
        const Persona(
          name: 'Kavya Catalogue',
          userType: 'STAFF',
          roleKey: 'CATALOGUE',
          permissions: <String>{
            PermissionKeys.catalogueRead,
            PermissionKeys.busesRead,
          },
        ),
      );
      await openBusTypes(tester, backend);

      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Add amenity'), findsNothing);
      final toggle = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.check).first,
      );
      expect(toggle.onPressed, isNull);
    });
  });

  group('the bus form offers the amenities that are switched on', () {
    testWidgets('names come from the server, not a fixed list', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      backend.overrides['GET catalogue/amenities'] = (_) =>
          FakeResponse.ok(<Object?>[
            <String, Object?>{'key': 'WIFI', 'name': 'Wi-Fi'},
            <String, Object?>{
              'key': 'RECLINING_SEATS',
              'name': 'Reclining seats',
            },
          ]);
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1400));
      await open(tester, AdminRoutes.buses);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));

      expect(app.requestsTo('catalogue/amenities', 'GET'), isNotEmpty);
      expect(
        find.widgetWithText(FilterChip, 'Reclining seats'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilterChip, 'Wi-Fi'), findsOneWidget);
      // the old fixed list is not shown
      expect(find.widgetWithText(FilterChip, 'Blanket'), findsNothing);
    });
  });
}
