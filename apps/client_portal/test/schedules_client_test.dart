import 'package:client_portal/routing/portal_routes.dart';
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
  });
}
