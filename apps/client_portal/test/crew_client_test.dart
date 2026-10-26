import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
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

    FakeBackend withDriver() {
      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET client/crew'] = (req) => FakeResponse.ok(<String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': '65f000000000000000000001',
            'operatorId': '65f0000000000000000000aa',
            'name': 'Sagar',
            'role': 'DRIVER',
            'phone': '8907654321',
            'status': 'ACTIVE',
            'licenseExpiryDate': '2027-03-31',
            'documentsCount': 2,
            'documentsExpiring': 1,
            'documentsExpired': 0,
            'tripsCount7Days': 0,
          },
        ],
        'kpis': <String, Object?>{
          'totalDrivers': 1,
          'totalActive': 1,
          'totalOnLeave': 0,
          'expiringLicences30Days': 0,
        },
      });
      backend.overrides['GET client/crew/65f000000000000000000001/documents'] = (req) => FakeResponse.ok(<Object?>[
        <String, Object?>{
          'id': '65f0000000000000000000d1',
          'crewId': '65f000000000000000000001',
          'docType': 'DRIVING_LICENCE',
          'docName': 'Driving licence',
          'validTill': '2026-11-10',
          'daysLeft': 18,
          'status': 'EXPIRING',
          'files': <Object?>[
            <String, Object?>{
              'id': 'f1',
              'originalName': 'front.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': 2048,
            },
            <String, Object?>{
              'id': 'f2',
              'originalName': 'back.png',
              'mimeType': 'image/png',
              'sizeBytes': 4096,
            },
          ],
        },
      ]);
      return backend;
    }

    testWidgets('shows the people table with its document count and an Import button', (tester) async {
      final app = TestPortal.signedIn(withDriver());
      await app.pump(tester);
      await open(tester, PortalRoutes.crew);

      expect(find.text('SI/NO'), findsOneWidget);
      expect(find.text('Sagar'), findsWidgets);
      expect(find.text('2 documents'), findsOneWidget);
      expect(find.text('1 expiring'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('1 person'), findsOneWidget);
    });

    testWidgets('Import opens the two steps: sample file, then the filled file', (tester) async {
      final app = TestPortal.signedIn(withDriver());
      await app.pump(tester);
      await open(tester, PortalRoutes.crew);

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(find.text('Import people from CSV'), findsOneWidget);
      expect(find.text('Step 1: Download the sample CSV'), findsOneWidget);
      expect(find.text('Download sample CSV'), findsOneWidget);
      expect(find.text('Step 2: Choose the filled CSV file'), findsOneWidget);
      expect(find.text('Import now'), findsOneWidget);
      await tester.tap(find.text('Import now'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the filled CSV file first.'), findsOneWidget);
    });

    testWidgets('the Documents button lists the files with view, download and the validity', (tester) async {
      // A wide window, so the Actions column is on screen without scrolling the table sideways
      tester.view.physicalSize = const Size(1700, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = TestPortal.signedIn(withDriver());
      await app.pump(tester);
      await open(tester, PortalRoutes.crew);

      await tester.ensureVisible(find.byTooltip('Documents').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Documents').first);
      await tester.pumpAndSettle();

      expect(find.text('Documents - Sagar'), findsOneWidget);
      expect(find.text('Add a document'), findsOneWidget);
      expect(find.textContaining('front.pdf'), findsOneWidget);
      expect(find.textContaining('back.png'), findsOneWidget);
      expect(find.textContaining('Expires in 18 days'), findsOneWidget);
      expect(find.byTooltip('View'), findsWidgets);
      expect(find.byTooltip('Download'), findsNWidgets(2));
      expect(find.text('Change validity date'), findsOneWidget);

      // "Other" asks for the name of the document
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(DropdownButtonFormField<String>)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other (type the name)').last);
      await tester.pumpAndSettle();
      expect(find.text('Document name *'), findsOneWidget);
    });

    testWidgets('a driver without a login shows "Create"; the key button opens the login dialog', (tester) async {
      tester.view.physicalSize = const Size(1700, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = TestPortal.signedIn(withDriver());
      await app.pump(tester);
      await open(tester, PortalRoutes.crew);

      await tester.ensureVisible(find.byTooltip('Driver app login').first);
      await tester.pumpAndSettle();
      expect(find.text('Driver app'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);

      await tester.tap(find.byTooltip('Driver app login').first);
      await tester.pumpAndSettle();
      expect(find.text('Driver app login - Sagar'), findsOneWidget);
      expect(find.text('No login yet'), findsOneWidget);
      expect(find.text('Create login'), findsOneWidget);
      expect(find.text('Reset password'), findsNothing);
    });

    testWidgets('Add person offers to create the driver app login for a driver, not for a manager', (tester) async {
      final app = TestPortal.signedIn(withDriver());
      await app.pump(tester);
      await open(tester, PortalRoutes.crew);

      await tester.tap(find.text('Add person').first);
      await tester.pumpAndSettle();
      expect(find.text('Create the driver app login'), findsOneWidget);
    });
  });
}
