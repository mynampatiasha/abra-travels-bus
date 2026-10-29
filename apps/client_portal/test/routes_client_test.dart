import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

void main() {
  group('routes client screen', () {
    testWidgets('renders routes screen and handles empty state', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/routes'] = (req) => FakeResponse.ok(<Object?>[]);

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.routes);

      expect(find.text('Routes and stops'), findsWidgets);
      expect(find.text('No routes yet'), findsWidgets);
      expect(find.text('New route'), findsWidgets);
    });
  });
}
