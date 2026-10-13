import 'package:admin_app/core/browser_files.dart' as browser;
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Future<TestAdmin> openAs(
  WidgetTester tester,
  FakeBackend backend,
  String location,
) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester);
  await open(tester, location);
  return app;
}

Persona staffWith(Set<String> permissions) => Persona(
  name: 'Kavya Catalogue',
  userType: 'STAFF',
  roleKey: 'CATALOGUE',
  permissions: permissions,
);

JsonMapLike busType() => <String, Object?>{
  'name': 'AC Sleeper',
  'key': 'AC_SLEEPER',
  'isAc': true,
  'berthType': 'SLEEPER',
  'isActive': true,
};

typedef JsonMapLike = Map<String, Object?>;

void main() {
  group('bus types: View and Delete', () {
    testWidgets('View opens the record in a window', (tester) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('bus-types', busType());
      final app = await openAs(tester, backend, AdminRoutes.busTypes);
      final id = backend.of('bus-types').single['id'];

      await tapOn(tester, find.byTooltip('View'));

      expect(app.requestsTo('catalogue/bus-types/$id', 'GET'), hasLength(1));
      expect(inDialog(find.text('AC Sleeper')), findsWidgets);
      expect(inDialog(find.text('AC_SLEEPER')), findsOneWidget);
      await tapOn(tester, inDialog(find.text('Close')));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Delete asks first, removes the record and offers Undo', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('bus-types', busType());
      final app = await openAs(tester, backend, AdminRoutes.busTypes);
      final id = backend.of('bus-types').single['id'];
      backend.overrides['POST catalogue/bus-types/$id/restore'] = (_) =>
          FakeResponse.ok(<String, Object?>{'id': id, 'deleted': false});

      await tapOn(tester, find.byTooltip('Delete'));
      expect(find.text('Delete AC Sleeper?'), findsOneWidget);
      await tapOn(tester, inDialog(find.text('Delete')));

      expect(app.requestsTo('catalogue/bus-types/$id', 'DELETE'), hasLength(1));
      expect(find.text('AC Sleeper deleted.'), findsOneWidget);
      expect(backend.of('bus-types'), isEmpty);

      await tapOn(tester, find.text('Undo'));
      expect(
        app.requestsTo('catalogue/bus-types/$id/restore', 'POST'),
        hasLength(1),
      );
    });

    testWidgets('a record that is in use is refused with the server sentence', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('bus-types', busType());
      final app = await openAs(tester, backend, AdminRoutes.busTypes);
      final id = backend.of('bus-types').single['id'];
      const sentence =
          'This bus type is used by 3 buses, so it cannot be deleted. '
          'Disable it instead.';
      backend.overrides['DELETE catalogue/bus-types/$id'] = (_) =>
          FakeResponse.error(409, 'RESOURCE_IN_USE', message: sentence);

      await tapOn(tester, find.byTooltip('Delete'));
      await tapOn(tester, inDialog(find.text('Delete')));

      expect(app.requestsTo('catalogue/bus-types/$id', 'DELETE'), hasLength(1));
      expect(find.text(sentence), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('without catalogue.delete there is View but no Delete', (
      tester,
    ) async {
      final backend = FakeBackend(
        staffWith(const {
          PermissionKeys.catalogueRead,
          PermissionKeys.busesRead,
          PermissionKeys.catalogueManage,
        }),
      )..add('bus-types', busType());
      await openAs(tester, backend, AdminRoutes.busTypes);

      expect(find.byTooltip('View'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
    });
  });

  group('Export', () {
    testWidgets('Excel file asks the server for an xlsx and saves it', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('bus-types', busType());
      backend.overrides['GET catalogue/bus-types/export?format=xlsx'] = (_) =>
          const FakeResponse(200, 'xlsx bytes');
      final app = await openAs(tester, backend, AdminRoutes.busTypes);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Export'));
      await tapOn(tester, find.text('Excel file'));

      expect(
        app.requestsTo('catalogue/bus-types/export?format=xlsx', 'GET'),
        hasLength(1),
      );
      expect(browser.lastDownloadName, startsWith('bus-types-'));
      expect(browser.lastDownloadName, endsWith('.xlsx'));
    });

    testWidgets('a refusal from the server is shown, not a file', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('bus-types', busType());
      backend.overrides['GET catalogue/bus-types/export?format=csv'] = (_) =>
          FakeResponse.error(403, 'PERMISSION_DENIED');
      browser.lastDownloadName = null;
      await openAs(tester, backend, AdminRoutes.busTypes);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Export'));
      await tapOn(tester, find.text('CSV file'));

      expect(browser.lastDownloadName, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('cities and document types', () {
    testWidgets('a city: View shows its details; Delete is offered', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('cities', <String, Object?>{
          'name': 'Hyderabad',
          'state': 'Telangana',
          'countryCode': 'IN',
          'slug': 'hyderabad',
          'isPopular': true,
          'isActive': true,
        });
      await openAs(tester, backend, AdminRoutes.cities);

      await tapOn(tester, find.byTooltip('View'));
      expect(inDialog(find.text('Telangana')), findsOneWidget);
      expect(inDialog(find.text('hyderabad')), findsOneWidget);
      await tapOn(tester, inDialog(find.text('Close')));
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('a document type: View lists the rules; Delete is offered', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('document-types', <String, Object?>{
          'name': 'GST certificate',
          'key': 'GST_CERTIFICATE',
          'appliesTo': 'OPERATOR',
          'isRequired': true,
          'requiresExpiry': false,
          'allowedMimeTypes': <String>['application/pdf', 'image/jpeg'],
          'maxFileSizeMb': 5,
          'maxFiles': 1,
          'instructions': 'Upload the certificate',
          'isActive': true,
        });
      await openAs(tester, backend, AdminRoutes.documentTypes);

      await tapOn(tester, find.byTooltip('View'));
      expect(inDialog(find.text('GST_CERTIFICATE')), findsOneWidget);
      expect(inDialog(find.text('Upload the certificate')), findsOneWidget);
      expect(
        inDialog(find.text('application/pdf, image/jpeg')),
        findsOneWidget,
      );
      await tapOn(tester, inDialog(find.text('Close')));
      expect(find.byTooltip('Delete'), findsOneWidget);
    });
  });

  group('invitations: View, Edit, Delete', () {
    Map<String, Object?> invitation(String status, {bool expired = false}) =>
        <String, Object?>{
          'companyName': 'Beta Travels',
          'ownerName': 'Bala',
          'email': 'bala@beta.test',
          'phone': null,
          'status': status,
          'expired': expired,
          'emailStatus': 'SENT',
          'expiresAt': '2026-10-14T10:00:00.000Z',
          'createdAt': '2026-10-07T10:00:00.000Z',
        };

    testWidgets('View shows the invitation', (tester) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('invitations', invitation('PENDING'));
      await openAs(tester, backend, AdminRoutes.invitations);

      await tapOn(tester, find.byTooltip('View'));
      expect(inDialog(find.text('bala@beta.test')), findsOneWidget);
      expect(inDialog(find.text('Bala')), findsOneWidget);
      await tapOn(tester, inDialog(find.text('Close')));
    });

    testWidgets('Edit sends only what changed (PATCH), and not an unchanged '
        'closing day', (tester) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('invitations', invitation('PENDING'));
      final id = backend.of('invitations').single['id'];
      backend.overrides['PATCH onboarding/invitations/$id'] = (_) =>
          FakeResponse.ok(backend.of('invitations').single);
      final app = await openAs(tester, backend, AdminRoutes.invitations);

      await tapOn(tester, find.byTooltip('Edit'));
      expect(find.text('Edit invitation'), findsOneWidget);
      expect(
        find.textContaining('A new email address makes the old link stop'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Owner's name"),
        'Balakrishna',
      );
      await tester.pump();
      await tapOn(tester, find.widgetWithText(AbraButton, 'Save'));

      final request = app
          .requestsTo('onboarding/invitations/$id', 'PATCH')
          .single;
      final body = request.body! as Map;
      expect(body['ownerName'], 'Balakrishna');
      expect(body['companyName'], 'Beta Travels');
      expect(body.containsKey('expiresAt'), isFalse);
      expect(find.text('Edit invitation'), findsNothing);
    });

    testWidgets('only a pending invitation can be edited, resent or '
        'withdrawn', (tester) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('invitations', invitation('ACCEPTED'));
      await openAs(tester, backend, AdminRoutes.invitations);

      expect(find.byTooltip('View'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Resend invitation'), findsNothing);
      expect(find.byTooltip('Withdraw invitation'), findsNothing);
      // The server would refuse to delete an accepted one: not offered
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('a withdrawn invitation can be deleted, with Undo', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('invitations', invitation('REVOKED'));
      final id = backend.of('invitations').single['id'];
      backend.overrides['DELETE onboarding/invitations/$id'] = (_) =>
          FakeResponse.ok(<String, Object?>{'id': id, 'deleted': true});
      backend.overrides['POST onboarding/invitations/$id/restore'] = (_) =>
          FakeResponse.ok(<String, Object?>{'id': id, 'deleted': false});
      final app = await openAs(tester, backend, AdminRoutes.invitations);

      await tapOn(tester, find.byTooltip('Delete'));
      expect(find.text('Delete Beta Travels?'), findsOneWidget);
      await tapOn(tester, inDialog(find.text('Delete')));
      expect(
        app.requestsTo('onboarding/invitations/$id', 'DELETE'),
        hasLength(1),
      );
      await tapOn(tester, find.text('Undo'));
      expect(
        app.requestsTo('onboarding/invitations/$id/restore', 'POST'),
        hasLength(1),
      );
    });

    testWidgets('the Status filter offers Expired and there is a search box', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('invitations', invitation('PENDING', expired: true));
      await openAs(tester, backend, AdminRoutes.invitations);

      expect(
        find.widgetWithText(TextField, 'Search company, owner or email'),
        findsOneWidget,
      );
      expect(find.text('Expired'), findsWidgets);
    });
  });
}
