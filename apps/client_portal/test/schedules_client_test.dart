import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

void main() {
  group('schedules client screen', () {
    testWidgets('renders schedules screen with empty state and add action', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/schedules'] = (req) => FakeResponse.ok(<Object?>[]);

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.schedules);

      expect(find.text('Schedules'), findsWidgets);
      expect(find.text('No schedules yet'), findsWidgets);
      expect(find.text('New schedule'), findsWidgets);
    });

    testWidgets('a schedule refused for a missing fare shows the server message, not an exception', (
      tester,
    ) async {
      const message = 'Add a fare for Bengaluru to Tirupati and AC Sleeper first. A trip cannot be priced without one.';
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/schedules'] = (req) => FakeResponse.ok(<Object?>[]);
      backend.overrides['GET client/routes'] = (req) => FakeResponse.ok(<Object?>[
        <String, Object?>{'id': 'r-1', 'name': 'Bengaluru to Tirupati', 'from': 'Bengaluru', 'to': 'Tirupati', 'km': 250, 'hours': 5, 'status': 'ACTIVE', 'stops': <Object?>[]},
      ]);
      backend.overrides['GET client/buses'] = (req) => FakeResponse.ok(<Object?>[
        <String, Object?>{'id': 'b-1', 'registrationNumber': 'KA01AB1234', 'name': 'Express', 'status': 'ACTIVE'},
      ]);
      backend.overrides['POST client/schedules'] = (req) => FakeResponse.error(400, 'VALIDATION_FAILED', message: message);

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.schedules);
      await tester.tap(find.text('New schedule').first);
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Departure time (e.g. 21:30) *'), '21:30');
      await tester.tap(find.text('Save schedule'));
      await settle(tester);

      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('AppException'), findsNothing);
    });
  });
}
