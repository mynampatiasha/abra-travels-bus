import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

Map<String, Object?> bus({String? make}) => <String, Object?>{
  'id': 'b-1',
  'registrationNumber': 'KA01AB1234',
  'name': 'Express Star',
  'busTypeId': 'bt-1',
  'busTypeName': 'AC Sleeper',
  'make': ?make,
  'displayName': make == null ? 'AC Sleeper' : '$make AC Sleeper',
  'seatCapacity': 36,
  'seatLayoutType': '2+2 Seater',
  'status': 'ACTIVE',
  'amenities': <Object?>[],
};

FakeBackend withBuses(List<Map<String, Object?>> buses) {
  final backend = FakeBackend(Persona.owner);
  backend.overrides['GET client/buses'] = (req) => FakeResponse.ok(buses);
  backend.overrides['GET client/buses/kpis'] = (req) =>
      FakeResponse.ok(<String, Object?>{'totalBuses': buses.length});
  backend.overrides['GET catalogue/bus-types'] = (req) => FakeResponse.ok(<Object?>[
    <String, Object?>{'id': 'bt-1', 'name': 'AC Sleeper', 'isActive': true},
    <String, Object?>{'id': 'bt-2', 'name': 'Non-AC Seater', 'isActive': true},
  ]);
  backend.overrides['GET catalogue/amenities'] = (req) => FakeResponse.ok(<Object?>[]);
  backend.overrides['POST client/buses'] = (req) => FakeResponse.ok(bus());
  backend.overrides['POST client/bus-type-requests'] = (req) =>
      FakeResponse.ok(<String, Object?>{'id': 'r-1', 'status': 'PENDING'});
  return backend;
}

Future<TestPortal> openBuses(WidgetTester tester, FakeBackend backend) async {
  final app = TestPortal.signedIn(backend);
  await app.pump(tester);
  await open(tester, PortalRoutes.buses);
  return app;
}

Future<void> openAddBus(WidgetTester tester) async {
  await tester.tap(find.text('Add bus').first);
  await settle(tester);
}

Finder inDialog(Finder finder) => find.descendant(of: find.byType(AlertDialog), matching: finder);

void main() {
  group('buses client screen', () {
    testWidgets('lists a ready-made name such as "Volvo AC Sleeper"', (tester) async {
      await openBuses(tester, withBuses(<Map<String, Object?>>[bus(make: 'Volvo')]));
      expect(find.text('Volvo AC Sleeper'), findsOneWidget);
    });

    testWidgets('a bus without a make shows its bus type', (tester) async {
      await openBuses(tester, withBuses(<Map<String, Object?>>[bus()]));
      expect(find.text('AC Sleeper'), findsOneWidget);
    });

    testWidgets('Add bus: bus types come from the server and the make is sent', (tester) async {
      final app = await openBuses(tester, withBuses(<Map<String, Object?>>[bus()]));
      await openAddBus(tester);

      expect(app.requestsTo('catalogue/bus-types', 'GET'), isNotEmpty);
      await tester.enterText(inDialog(find.byType(TextField)).at(0), 'KA09XY4321');
      await tester.enterText(inDialog(find.byType(TextField)).at(1), 'Night Rider');
      await tester.tap(inDialog(find.text('Bus Type*')));
      await settle(tester);
      await tester.tap(find.text('Non-AC Seater').last);
      await settle(tester);
      await tester.tap(inDialog(find.text('Make (optional)')));
      await settle(tester);
      expect(find.text('Mercedes-Benz'), findsWidgets);
      expect(find.text('Other (type it)'), findsWidgets);
      await tester.tap(find.text('Scania').last);
      await settle(tester);
      await tester.enterText(inDialog(find.byType(TextField)).last, '40');
      await tester.tap(find.text('Send for approval'));
      await settle(tester);

      final sent = app.requestsTo('client/buses', 'POST').single.body! as Map;
      expect(sent['make'], 'Scania');
      expect(sent['busTypeId'], 'bt-2');
    });

    testWidgets('Add bus: "Other" make is typed in and sent as typed', (tester) async {
      final app = await openBuses(tester, withBuses(<Map<String, Object?>>[bus()]));
      await openAddBus(tester);

      await tester.enterText(inDialog(find.byType(TextField)).at(0), 'KA09XY4321');
      await tester.enterText(inDialog(find.byType(TextField)).at(1), 'Night Rider');
      await tester.tap(inDialog(find.text('Bus Type*')));
      await settle(tester);
      await tester.tap(find.text('AC Sleeper').last);
      await settle(tester);
      await tester.tap(inDialog(find.text('Make (optional)')));
      await settle(tester);
      await tester.tap(find.text('Other (type it)').last);
      await settle(tester);
      expect(inDialog(find.text('Make of the bus*')), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextField, 'Make of the bus*'),
        ),
        'Force Motors',
      );
      await tester.enterText(inDialog(find.byType(TextField)).last, '30');
      await tester.tap(find.text('Send for approval'));
      await settle(tester);

      final sent = app.requestsTo('client/buses', 'POST').single.body! as Map;
      expect(sent['make'], 'Force Motors');
    });

    testWidgets('"My bus type isn\'t listed" sends a request to Abra', (tester) async {
      final app = await openBuses(tester, withBuses(<Map<String, Object?>>[bus()]));
      await openAddBus(tester);

      await tester.tap(inDialog(find.text("My bus type isn't listed")));
      await settle(tester);
      expect(find.text('Send request'), findsOneWidget);
      await tester.tap(find.text('Send request'));
      await settle(tester);
      expect(find.text('Enter the bus type name.'), findsOneWidget);
      expect(app.requestsTo('client/bus-type-requests', 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Bus type name (e.g. Mini Coach)*'), 'Mini Coach');
      await tester.tap(find.byType(Switch));
      await settle(tester);
      await tester.tap(find.text('Send request'));
      await settle(tester);

      final sent = app.requestsTo('client/bus-type-requests', 'POST').single.body! as Map;
      expect(sent, <String, Object?>{'name': 'Mini Coach', 'isAc': false, 'berthType': 'SLEEPER'});
      expect(find.textContaining('Request sent to Abra'), findsOneWidget);
    });
  });
}
