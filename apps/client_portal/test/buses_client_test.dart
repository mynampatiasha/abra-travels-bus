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

  group('bus documents dialog', () {
    Map<String, Object?> doc({String name = 'Insurance 2026-27', String status = 'EXPIRING', int daysLeft = 12}) => <String, Object?>{
      'id': 'd-1',
      'busId': 'b-1',
      'docType': 'INSURANCE',
      'docName': name,
      'validTill': '2026-11-20',
      'daysLeft': daysLeft,
      'status': status,
      'remindDaysBefore': <Object?>[30, 15, 7, 1],
      'files': <Object?>[
        <String, Object?>{'id': 'f-1', 'originalName': 'policy.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 2048},
      ],
    };

    FakeBackend withDocuments(List<Map<String, Object?>> docs) {
      final backend = withBuses(<Map<String, Object?>>[bus()]);
      backend.overrides['GET client/buses/b-1/documents'] = (req) => FakeResponse.ok(docs);
      backend.overrides['GET client/bus-document-types'] = (req) => FakeResponse.ok(<Object?>[
        <String, Object?>{'key': 'RC', 'label': 'Registration certificate (RC)', 'required': true},
        <String, Object?>{'key': 'INSURANCE', 'label': 'Insurance', 'required': true},
        <String, Object?>{'key': 'OTHER', 'label': 'Other', 'required': false},
      ]);
      backend.overrides['GET client/crew'] = (req) => FakeResponse.ok(<Object?>[
        <String, Object?>{'id': 'c-1', 'name': 'Ravi Kumar', 'role': 'DRIVER'},
      ]);
      backend.overrides['PATCH client/buses/b-1/documents/d-1'] = (req) => FakeResponse.ok(doc());
      backend.overrides['DELETE client/buses/b-1/documents/d-1'] = (req) =>
          FakeResponse.ok(<String, Object?>{'success': true});
      backend.overrides['PATCH client/buses/b-1'] = (req) => FakeResponse.ok(bus());
      return backend;
    }

    Future<TestPortal> openDocuments(WidgetTester tester, FakeBackend backend) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final app = await openBuses(tester, backend);
      await tester.ensureVisible(find.byTooltip('Documents').first);
      await tester.pump();
      await tester.tap(find.byTooltip('Documents').first);
      await settle(tester);
      return app;
    }

    testWidgets('lists the documents with their expiry date and reminder days', (tester) async {
      await openDocuments(tester, withDocuments(<Map<String, Object?>>[doc()]));
      expect(find.text('Documents - KA01AB1234'), findsOneWidget);
      expect(find.text('Insurance 2026-27'), findsOneWidget);
      expect(find.text('Expires in 12 days (2026-11-20)'), findsOneWidget);
      expect(find.text('Reminders: 30, 15, 7, 1 days before'), findsOneWidget);
      expect(find.text('policy.pdf (2 KB)'), findsOneWidget);
      // The kinds of document come from the server; required ones are starred
      expect(find.text('Add a document'), findsOneWidget);
    });

    testWidgets('says plainly when there are no documents yet', (tester) async {
      await openDocuments(tester, withDocuments(<Map<String, Object?>>[]));
      expect(find.textContaining('No documents yet'), findsOneWidget);
    });

    testWidgets('an expired document is shown as expired', (tester) async {
      await openDocuments(tester, withDocuments(<Map<String, Object?>>[doc(status: 'EXPIRED', daysLeft: -3)]));
      expect(find.text('Expired on 2026-11-20'), findsOneWidget);
    });

    testWidgets('the expiry date is needed before a document is uploaded', (tester) async {
      final app = await openDocuments(tester, withDocuments(<Map<String, Object?>>[]));
      await tester.tap(find.text('Upload'));
      await settle(tester);
      expect(find.text('Choose the expiry date (Valid till).'), findsOneWidget);
      expect(app.requestsTo('client/buses/b-1/documents', 'POST'), isEmpty);
    });

    testWidgets('a document can be renamed', (tester) async {
      final app = await openDocuments(tester, withDocuments(<Map<String, Object?>>[doc()]));
      await tester.ensureVisible(find.text('Rename'));
      await tester.tap(find.text('Rename'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Document name'), 'Insurance (New India)');
      await tester.tap(find.text('Save'));
      await settle(tester);
      final sent = app.requestsTo('client/buses/b-1/documents/d-1', 'PATCH').single.body! as Map;
      expect(sent, <String, Object?>{'docName': 'Insurance (New India)'});
    });

    testWidgets('the reminder days can be changed, and must be numbers', (tester) async {
      final app = await openDocuments(tester, withDocuments(<Map<String, Object?>>[doc()]));
      await tester.ensureVisible(find.text('Reminder days'));
      await tester.tap(find.text('Reminder days'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Days before expiry (e.g. 30, 15, 7, 1)'), 'soon');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Use numbers separated by commas.'), findsOneWidget);
      expect(app.requestsTo('client/buses/b-1/documents/d-1', 'PATCH'), isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Days before expiry (e.g. 30, 15, 7, 1)'), '45, 20, 3');
      await tester.tap(find.text('Save'));
      await settle(tester);
      final sent = app.requestsTo('client/buses/b-1/documents/d-1', 'PATCH').single.body! as Map;
      expect(sent, <String, Object?>{'remindDaysBefore': <Object?>[45, 20, 3]});
    });

    testWidgets('deleting a document asks first', (tester) async {
      final app = await openDocuments(tester, withDocuments(<Map<String, Object?>>[doc()]));
      await tester.ensureVisible(find.text('Delete document'));
      await tester.tap(find.text('Delete document'));
      await settle(tester);
      expect(find.text('Delete Insurance 2026-27?'), findsOneWidget);
      expect(app.requestsTo('client/buses/b-1/documents/d-1', 'DELETE'), isEmpty);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(app.requestsTo('client/buses/b-1/documents/d-1', 'DELETE'), hasLength(1));
    });

    testWidgets('the usual driver of the bus is chosen from the crew list', (tester) async {
      final app = await openDocuments(tester, withDocuments(<Map<String, Object?>>[]));
      await tester.tap(find.text('Usual driver'));
      await settle(tester);
      await tester.tap(find.text('Ravi Kumar').last);
      await settle(tester);
      final sent = app.requestsTo('client/buses/b-1', 'PATCH').single.body! as Map;
      expect(sent, <String, Object?>{'defaultDriverId': 'c-1'});
    });
  });
}
