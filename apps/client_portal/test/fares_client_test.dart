import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

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
  });
}
