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
    testWidgets('shows the short trip code, never the database id', (tester) async {
      const databaseId = '6ae41d23bd4329f6a562b9b3';
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/trips'] = (req) => FakeResponse.ok(<String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': databaseId,
            'code': 'TRP-1042',
            'route': 'Bengaluru to Tirupati',
            'bus': 'KA01AB1234',
            'busType': 'AC Sleeper',
            'travelDate': '2026-11-02',
            'departureAt': '2026-11-02T16:00:00.000Z',
            'departureTime': '21:30',
            'startingFarePaise': 120000,
            'status': 'DRAFT',
            'totalSeats': 36,
            'availableSeats': 36,
            'bookedSeats': 0,
          },
        ],
        'kpis': <String, Object?>{'onSale': 0, 'drafts': 1, 'running': 0, 'noDriver': 1},
      });

      final app = TestPortal.signedIn(backend);
      await app.pump(tester);
      await open(tester, PortalRoutes.trips);

      expect(find.text('TRP-1042'), findsOneWidget);
      expect(find.textContaining(databaseId), findsNothing);
    });

  });
}
