import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

FakeResponse _busTypes(List<String> names) => FakeResponse.ok(<Object?>[
  for (final name in names) <String, Object?>{'id': 'bt-$name', 'name': name, 'isActive': true},
]);

void main() {
  group('fares client screen', () {
    testWidgets('renders fares screen with empty state and add action', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/fares'] = (req) => FakeResponse.ok(<Object?>[]);

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.fares);

      expect(find.text('Fares'), findsWidgets);
      expect(find.text('No fares yet'), findsWidgets);
      expect(find.text('New fare'), findsWidgets);
    });

    testWidgets('seat type list comes from the bus types on the server', (tester) async {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/fares'] = (req) => FakeResponse.ok(<Object?>[]);
      backend.overrides['GET catalogue/bus-types'] = (req) =>
          _busTypes(<String>['Scania Multi-Axle', 'Mini Coach']);

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.fares);
      await tester.tap(find.text('New fare').first);
      await settle(tester);

      expect(app.requestsTo('catalogue/bus-types', 'GET'), isNotEmpty);
      // The first bus type is the starting choice; no typed-in names such as "Luxury AC".
      expect(find.text('Scania Multi-Axle'), findsOneWidget);
      expect(find.text('Luxury AC'), findsNothing);

      await tester.tap(find.text('Scania Multi-Axle'));
      await settle(tester);
      expect(find.text('Mini Coach'), findsWidgets);
      expect(find.text('AC Sleeper'), findsNothing);
    });

    testWidgets('shows a plain message when Abra has no bus types', (tester) async {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/fares'] = (req) => FakeResponse.ok(<Object?>[]);
      backend.overrides['GET catalogue/bus-types'] = (req) => _busTypes(<String>[]);

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.fares);
      await tester.tap(find.text('New fare').first);
      await settle(tester);

      expect(find.textContaining('Abra has not added any bus types yet'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
