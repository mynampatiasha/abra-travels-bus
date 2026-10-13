import 'dart:convert';
import 'dart:typed_data';

import 'package:admin_app/core/browser_files.dart' as browser;
import 'package:admin_app/features/catalogue/widgets/server_import_dialog.dart';
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

Finder button(String label) => find.widgetWithText(AbraButton, label);

Map<String, Object?> answer({required bool dryRun}) => <String, Object?>{
  'dryRun': dryRun,
  'total': 3,
  'accepted': 1,
  'rejected': 2,
  'ignoredColumns': <String>['Status'],
  'rows': <Object?>[
    <String, Object?>{
      'row': 2,
      'label': 'Warangal',
      'status': dryRun ? 'OK' : 'CREATED',
      'errors': <String>[],
    },
    <String, Object?>{
      'row': 3,
      'label': 'Karimnagar',
      'status': 'ERROR',
      'errors': <String>['State: is required.'],
    },
    <String, Object?>{
      'row': 4,
      'label': 'Bengaluru',
      'status': 'ERROR',
      'errors': <String>['A city with this name already exists.'],
    },
  ],
};

void main() {
  tearDown(() {
    pickImportFile = () async => null;
  });

  group('server import: cities', () {
    testWidgets('checks the file first, shows what is wrong with each row, '
        'then imports the rows that are right', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      backend.overrides['POST catalogue/cities/import?dryRun=true'] = (_) =>
          FakeResponse.ok(answer(dryRun: true));
      backend.overrides['POST catalogue/cities/import?dryRun=false'] = (_) =>
          FakeResponse.ok(answer(dryRun: false));
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1200));
      await open(tester, AdminRoutes.cities);
      pickImportFile = () async => (
        'cities.csv',
        Uint8List.fromList(utf8.encode('City,State\nWarangal,Telangana')),
      );

      await tapOn(tester, button('Import'));
      expect(find.text('Import cities'), findsOneWidget);
      expect(find.text('Template (CSV)'), findsOneWidget);
      expect(find.text('Template (Excel)'), findsOneWidget);

      await tapOn(tester, button('Choose file'));

      // the check changed nothing on the server
      expect(
        app.requestsTo('catalogue/cities/import?dryRun=true', 'POST'),
        hasLength(1),
      );
      expect(
        app.requestsTo('catalogue/cities/import?dryRun=false', 'POST'),
        isEmpty,
      );
      expect(find.text('1 of 3 rows are ready to import.'), findsOneWidget);
      expect(
        find.text('2 rows have problems and will be left out:'),
        findsOneWidget,
      );
      expect(find.text('Row 3: Karimnagar'), findsOneWidget);
      expect(find.text('State: is required.'), findsOneWidget);
      expect(
        find.text('A city with this name already exists.'),
        findsOneWidget,
      );
      expect(find.text('Columns not used: Status.'), findsOneWidget);

      await tapOn(tester, button('Import 1 rows'));

      expect(
        app.requestsTo('catalogue/cities/import?dryRun=false', 'POST'),
        hasLength(1),
      );
      expect(find.text('1 rows imported. 2 left out.'), findsOneWidget);
      // nothing more to import; Close leaves
      expect(button('Import 1 rows'), findsNothing);
      await tapOn(tester, find.text('Close'));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the templates are downloaded as files', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      backend.overrides['GET catalogue/cities/import-template?format=csv'] =
          (_) =>
              const FakeResponse(200, 'City,State\r\nHyderabad,Telangana\r\n');
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1200));
      await open(tester, AdminRoutes.cities);

      await tapOn(tester, button('Import'));
      await tapOn(tester, find.text('Template (CSV)'));

      expect(browser.lastDownloadName, 'cities-import-template.csv');
      expect(
        String.fromCharCodes(browser.lastDownloadBytes!),
        startsWith('City,State'),
      );
    });

    testWidgets('a file the server cannot read says why and imports nothing', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin);
      backend.overrides['POST catalogue/cities/import?dryRun=true'] = (_) =>
          FakeResponse.error(
            400,
            'VALIDATION_FAILED',
            message:
                'The first row of the file must name these columns: "State".',
          );
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1200));
      await open(tester, AdminRoutes.cities);
      pickImportFile = () async =>
          ('cities.csv', Uint8List.fromList(utf8.encode('City\nPune')));

      await tapOn(tester, button('Import'));
      await tapOn(tester, button('Choose file'));

      expect(find.textContaining('must name these columns'), findsOneWidget);
      expect(button('Import 1 rows'), findsNothing);
    });

    testWidgets('only people who may add records see Import', (tester) async {
      final backend = FakeBackend(
        const Persona(
          name: 'Kavya Catalogue',
          userType: 'STAFF',
          roleKey: 'CATALOGUE',
          permissions: <String>{PermissionKeys.catalogueRead},
        ),
      );
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester);
      await open(tester, AdminRoutes.cities);

      expect(button('Import'), findsNothing);
      expect(button('Export'), findsNothing);
    });
  });
}
