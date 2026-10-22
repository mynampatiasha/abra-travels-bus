import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

void main() {
  group('crew client screen', () {
    testWidgets('renders crew management screen with KPI cards and actions', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/crew'] = (req) => FakeResponse.ok(<String, Object?>{
        'items': <Object?>[],
        'kpis': <String, Object?>{
          'totalDrivers': 0,
          'totalActive': 0,
          'totalOnLeave': 0,
          'expiringLicences30Days': 0,
        },
      });

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.crew);

      expect(find.text('Drivers and crew'), findsWidgets);
      expect(find.text('Drivers'), findsWidgets);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('On leave'), findsWidgets);
      expect(find.text('Licences expiring in 30 days'), findsWidgets);
      expect(find.text('Add person'), findsWidgets);
    });
  });
}
