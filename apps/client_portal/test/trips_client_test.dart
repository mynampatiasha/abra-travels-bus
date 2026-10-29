import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

void main() {
  group('trips client screen', () {
    testWidgets('renders trips screen with KPIs and action buttons', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/trips'] = (req) => FakeResponse.ok(<String, Object?>{
        'items': <Object?>[],
        'kpis': <String, Object?>{
          'onSale': 0,
          'drafts': 0,
          'running': 0,
          'noDriver': 0,
        },
      });

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.trips);

      expect(find.text('Trips'), findsWidgets);
      expect(find.text('On sale'), findsWidgets);
      expect(find.text('Drafts'), findsWidgets);
      expect(find.text('Running now'), findsWidgets);
      expect(find.text('Without a driver'), findsWidgets);
      expect(find.text('New trip'), findsWidgets);
    });
  });
}
