import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:admin_app/core/browser_files.dart';
import 'package:admin_app/features/customers/admin_customers.dart';
import 'package:admin_app/features/kyc/admin_kyc_configuration.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

const path = 'settings/kyc-configuration';
JsonMap ownership() => {
  'key': 'ownership',
  'label': 'Do you own or lease buses?',
  'help': '',
  'appliesTo': 'OPERATOR',
  'type': 'SINGLE_CHOICE',
  'options': [
    {'value': 'own', 'label': 'Own'},
    {'value': 'lease', 'label': 'Lease'},
  ],
  'required': true,
  'active': true,
  'sortOrder': 0,
};
JsonMap rule() => {
  'key': 'lease_rule',
  'name': 'Lease agreement for leased buses',
  'appliesTo': 'OPERATOR',
  'documentKey': 'LEASE_AGREEMENT',
  'required': true,
  'active': true,
  'match': 'ALL',
  'conditions': [
    {
      'questionKey': 'ownership',
      'values': ['lease'],
    },
  ],
};
FakeBackend backend([Persona persona = Persona.superAdmin]) {
  final result = FakeBackend(persona);
  result.add('document-types', {
    'key': 'LEASE_AGREEMENT',
    'name': 'Lease agreement',
    'appliesTo': 'OPERATOR',
    'isActive': true,
    'isRequired': false,
    'requiresExpiry': false,
    'allowedMimeTypes': ['application/pdf'],
    'maxFileSizeMb': 5,
    'maxFiles': 1,
    'sortOrder': 0,
    'instructions': '',
  });
  result.kycConfiguration = {
    'schemaVersion': 1,
    'version': 1,
    'questions': [ownership()],
    'rules': [rule()],
  };
  return result;
}

Finder textField(String label) => find.widgetWithText(TextField, label);
Finder formField(String label) => find.widgetWithText(TextFormField, label);
Finder button(String label) => find.widgetWithText(AbraButton, label);
void pickSpreadsheet(Uint8List bytes, [String name = 'configuration.xlsx']) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('miguelruivo.flutter.plugins.filepicker'),
        (_) async => [
          {'name': name, 'size': bytes.length, 'bytes': bytes, 'path': null},
        ],
      );
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

Future<TestAdmin> start(
  WidgetTester tester,
  FakeBackend source, {
  Size size = const Size(1440, 900),
}) async {
  final app = TestAdmin.signedIn(source);
  await app.pump(tester, size: size);
  await open(tester, AdminRoutes.kycConfiguration);
  return app;
}

Future<void> capture(
  WidgetTester tester,
  String filename, {
  bool dialog = false,
}) async {
  final finder = find
      .ancestor(
        of: dialog
            ? find.byType(AlertDialog)
            : find.byType(AdminKycConfigurationPage),
        matching: find.byType(RepaintBoundary),
      )
      .last;
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    final file = File('build/$filename');
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  final documents = <JsonMap>[
    {
      'key': 'LEASE_AGREEMENT',
      'name': 'Lease agreement',
      'appliesTo': 'OPERATOR',
    },
  ];
  test(
    'Excel and CSV round trips preserve question, option and rule identities',
    () {
      final config = {
        'questions': [ownership()],
        'rules': [rule()],
      };
      final rows = kycSpreadsheetRows(config, documents);
      final excel = kycParseSpreadsheet(
        kycReadSpreadsheet(kycExcelBytes(rows), 'xlsx'),
        config,
        documents,
      );
      final csv = kycParseSpreadsheet(
        kycReadSpreadsheet(
          Uint8List.fromList(
            utf8.encode(const ListToCsvConverter().convert(rows)),
          ),
          'csv',
        ),
        config,
        documents,
      );
      expect(excel, {'schemaVersion': 1, ...config});
      expect(csv, excel);
      expect(rows.expand((r) => r), isNot(contains('ownership')));
      expect(rows.expand((r) => r), isNot(contains('LEASE_AGREEMENT')));
    },
  );
  test(
    'invalid spreadsheet headings and unknown condition answers are readable errors',
    () {
      final config = {
        'questions': [ownership()],
        'rules': [rule()],
      };
      expect(
        () => kycParseSpreadsheet(
          [
            ['Wrong headings'],
          ],
          config,
          documents,
        ),
        throwsFormatException,
      );
      final rows = kycSpreadsheetRows(config, documents);
      rows.last[31] = 'Unknown answer';
      expect(
        () => kycParseSpreadsheet(rows, config, documents),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Row 3'),
          ),
        ),
      );
    },
  );
  testWidgets(
    'Customers directory shows contact data, methods, details and filters',
    (tester) async {
      final source = backend();
      source.overrides['GET users'] = (_) => FakeResponse.ok(
        [
          {
            'id': 'customer1',
            'name': 'Asha Customer',
            'email': 'asha@example.com',
            'phone': '+919876543210',
            'status': 'ACTIVE',
            'loginMethods': ['Google', 'WhatsApp OTP'],
            'createdAt': '2026-10-01T00:00:00Z',
            'lastLoginAt': '2026-10-10T00:00:00Z',
          },
        ],
        meta: {'total': 1, 'page': 1, 'pageSize': 20},
      );
      final app = TestAdmin.signedIn(source);
      await app.pump(tester, size: const Size(390, 844));
      await open(tester, AdminRoutes.customers);
      expect(find.byType(AdminCustomersPage), findsOneWidget);
      expect(find.text('Asha Customer'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      await tap(tester, find.text('Asha Customer'));
      expect(
        find.widgetWithText(SelectableText, 'asha@example.com'),
        findsOneWidget,
      );
      await tap(tester, find.text('Close'));
      await tester.enterText(textField('Search name, email or phone'), 'asha');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(
        app.requestsTo('users', 'GET').last.options.queryParameters['userType'],
        'CUSTOMER',
      );
      expect(
        app.requestsTo('users', 'GET').last.options.queryParameters['search'],
        'asha',
      );
      expect(tester.takeException(), isNull);
    },
  );
  setUpAll(() async {
    // Use readable local fonts for visual inspection; tests remain portable when absent.
    final file = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (file.existsSync()) {
      for (final family in ['Roboto', 'Segoe UI']) {
        await (FontLoader(family)..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
      }
    }
    final icons = File(
      r'D:\Flutter\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
  });
  test(
    'configuration exports preserve rule references without server metadata',
    () {
      final data = backend().kycConfiguration;
      final export = kycExportData({
        ...data,
        'documents': [],
        'updatedAt': 'today',
      });
      expect(export.keys.toSet(), {'schemaVersion', 'questions', 'rules'});
      expect(
        ((export['rules'] as List).single
            as Map<Object?, Object?>)['documentKey'],
        'LEASE_AGREEMENT',
      );
    },
  );

  testWidgets('one page contains both tabs, filters and bulk tools', (
    tester,
  ) async {
    await start(tester, backend());
    expect(find.text('KYC questionnaire'), findsWidgets);
    expect(find.text('Preview checklist'), findsOneWidget);
    expect(find.text('Do you own or lease buses?'), findsOneWidget);
    expect(button('Add question'), findsOneWidget);
    expect(button('Export CSV'), findsOneWidget);
    expect(button('Export config'), findsOneWidget);
    expect(button('Import'), findsOneWidget);
    await tap(tester, find.text('Document rules').last);
    expect(find.text('Lease agreement for leased buses'), findsOneWidget);
    expect(button('Add rule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters records and clearing filters restores them', (
    tester,
  ) async {
    await start(tester, backend());
    await tester.enterText(
      textField('Search questions or document rules'),
      'not found',
    );
    await settle(tester);
    expect(find.text('Do you own or lease buses?'), findsNothing);
    expect(find.text('No entries match these filters.'), findsOneWidget);
    await tester.enterText(textField('Search questions or document rules'), '');
    await settle(tester);
    expect(find.text('Do you own or lease buses?'), findsOneWidget);
  });

  testWidgets(
    'create and edit a question save through the existing API with a revision',
    (tester) async {
      final app = await start(tester, backend());
      await tap(tester, button('Add question'));
      expect(formField('Key'), findsNothing);
      await tester.enterText(
        formField('Question text'),
        'What is your business type?',
      );
      await tester.enterText(formField('Option 1'), 'Company');
      await tester.enterText(formField('Option 2'), 'Individual');
      await tap(tester, button('Save'));
      expect(find.byType(AlertDialog), findsNothing);
      final first = app.requestsTo(path, 'PUT').single.body! as Map;
      expect(first['expectedVersion'], 1);
      expect(
        (first['questions'] as List).last,
        containsPair('label', 'What is your business type?'),
      );
      await tap(tester, find.byTooltip('Edit').last);
      expect(formField('Key'), findsNothing);
      await tester.enterText(
        formField('Question text'),
        'Choose your company type',
      );
      await tap(tester, button('Save'));
      expect(find.text('Choose your company type'), findsOneWidget);
      expect(
        (app.requestsTo(path, 'PUT').last.body! as Map)['expectedVersion'],
        2,
      );
    },
  );

  testWidgets('create a conditional rule, then edit and delete it', (
    tester,
  ) async {
    final source = backend();
    source.kycConfiguration['rules'] = <JsonMap>[];
    final app = await start(tester, source);
    await tap(tester, find.text('Document rules').last);
    await tap(tester, button('Add rule'));
    expect(formField('Key'), findsNothing);
    await tester.enterText(formField('Rule name'), 'Lease documents');
    await tap(
      tester,
      find.widgetWithText(DropdownButtonFormField<String>, 'Document').last,
    );
    await tap(tester, find.text('Lease agreement').last);
    await tap(tester, find.text('Add condition'));
    await tap(
      tester,
      find.widgetWithText(DropdownButtonFormField<String>, 'Question'),
    );
    await tap(tester, find.text('Do you own or lease buses?').last);
    await tap(tester, find.widgetWithText(FilterChip, 'Lease'));
    await tap(tester, button('Save'));
    final body = app.requestsTo(path, 'PUT').single.body! as Map;
    expect(
      ((body['rules'] as List).single as Map<Object?, Object?>)['conditions'],
      [
        {
          'questionKey': 'ownership',
          'values': ['lease'],
        },
      ],
    );
    await tap(tester, find.byTooltip('Edit'));
    await tester.enterText(formField('Rule name'), 'Updated lease documents');
    await tap(tester, button('Save'));
    expect(find.text('Updated lease documents'), findsOneWidget);
    await tap(tester, find.byTooltip('Delete'));
    await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    expect(source.kycConfiguration['rules'], isEmpty);
  });

  testWidgets(
    'export downloads a readable Excel configuration with stable identities',
    (tester) async {
      await start(tester, backend());
      final source = backend();
      await tester.enterText(
        textField('Search questions or document rules'),
        'hidden',
      );
      await tap(tester, button('Export CSV'));
      await tap(tester, find.text('Download Excel (.xlsx)'));
      expect(lastDownloadName, 'abra-kyc-configuration.xlsx');
      final data = kycParseSpreadsheet(
        kycReadSpreadsheet(lastDownloadBytes!, 'xlsx'),
        source.kycConfiguration,
        [
          {
            'key': 'LEASE_AGREEMENT',
            'name': 'Lease agreement',
            'appliesTo': 'OPERATOR',
          },
        ],
      );
      expect(data['questions'], hasLength(1));
      expect(data['rules'], hasLength(1));
      expect(data.containsKey('version'), isFalse);
    },
  );

  testWidgets(
    'import requires validation and explicit replacement confirmation',
    (tester) async {
      final app = await start(tester, backend());
      await tap(tester, button('Import'));
      await capture(tester, 'kyc_import_readable.png', dialog: true);
      expect(textField('Configuration JSON'), findsNothing);
      final replacement = {
        'schemaVersion': 1,
        'questions': [ownership()],
        'rules': <JsonMap>[],
      };
      pickSpreadsheet(kycExcelBytes(kycSpreadsheetRows(replacement, [])));
      expect(
        tester.widget<AbraButton>(button('Import').last).onPressed,
        isNull,
      );
      await tap(tester, find.text('Upload Excel or CSV'));
      expect(app.requestsTo('$path/validate-import', 'POST'), hasLength(1));
      expect(app.requestsTo(path, 'PUT'), isEmpty);
      await tap(tester, find.byType(CheckboxListTile));
      await tap(tester, button('Import').last);
      expect(app.backend.kycConfiguration['questions'], hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'invalid import changes nothing and displays the server explanation',
    (tester) async {
      final source = backend();
      source.overrides['POST $path/validate-import'] = (_) =>
          FakeResponse.error(
            400,
            'VALIDATION_FAILED',
            message: 'Rule refers to a missing question.',
          );
      final app = await start(tester, source);
      await tap(tester, button('Import'));
      pickSpreadsheet(
        kycExcelBytes(
          kycSpreadsheetRows(source.kycConfiguration, [
            {
              'key': 'LEASE_AGREEMENT',
              'name': 'Lease agreement',
              'appliesTo': 'OPERATOR',
            },
          ]),
        ),
      );
      await tap(tester, find.text('Upload Excel or CSV'));
      expect(find.text('Rule refers to a missing question.'), findsOneWidget);
      expect(app.requestsTo(path, 'PUT'), isEmpty);
      expect(
        tester.widget<AbraButton>(button('Import').last).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'preview sends selected answers and displays the server checklist',
    (tester) async {
      final source = backend();
      source.overrides['POST $path/preview'] = (_) => FakeResponse.ok({
        'missingQuestions': <String>[],
        'documents': [
          {
            'name': 'Lease agreement',
            'isRequired': true,
            'instructions': 'Upload your agreement',
          },
        ],
      });
      final app = await start(tester, source);
      await tap(tester, find.text('Preview checklist'));
      await tap(tester, find.widgetWithText(FilterChip, 'Lease'));
      await tap(tester, button('Show checklist'));
      expect(app.requestsTo('$path/preview', 'POST').single.body, {
        'appliesTo': 'OPERATOR',
        'answers': {'ownership': 'lease'},
      });
      expect(find.text('Lease agreement'), findsOneWidget);
      expect(find.text('Upload your agreement'), findsOneWidget);
    },
  );

  testWidgets('read-only staff cannot create, edit, delete or import', (
    tester,
  ) async {
    const viewer = Persona(
      name: 'Reviewer',
      userType: 'STAFF',
      roleKey: 'REVIEWER',
      permissions: {'documents.read'},
    );
    await start(tester, backend(viewer));
    expect(button('Add question'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(button('Import'), findsNothing);
    expect(button('Export CSV'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('operator staff cannot open platform KYC configuration', (
    tester,
  ) async {
    const operator = Persona(
      name: 'Operator',
      userType: 'OPERATOR_STAFF',
      roleKey: 'OPERATOR_ADMIN',
      operatorId: operatorAId,
      permissions: {'documents.read'},
    );
    final app = await start(tester, backend(operator));
    expect(find.widgetWithText(ListTile, 'KYC questionnaire'), findsNothing);
    expect(find.byType(AdminKycConfigurationPage), findsNothing);
    expect(app.requestsTo(path), isEmpty);
    expect(button('Add question'), findsNothing);
  });

  testWidgets('the Active switch turns a question off and on', (tester) async {
    final app = await start(tester, backend());
    await tap(tester, find.byType(Switch));
    final sent = app.requestsTo(path, 'PUT').single.body! as Map;
    expect((sent['questions'] as List).single, containsPair('active', false));
    expect(sent['reason'], 'Disabled KYC question ownership');
    await tap(tester, find.byType(Switch));
    expect(
      ((app.requestsTo(path, 'PUT').last.body! as Map)['questions'] as List)
          .single,
      containsPair('active', true),
    );
  });

  testWidgets('deleting a question can be undone', (tester) async {
    final app = await start(tester, backend());
    await tap(tester, find.byTooltip('Delete'));
    await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    expect(find.text('Do you own or lease buses?'), findsNothing);
    await tap(tester, find.text('Undo'));
    expect(find.text('Do you own or lease buses?'), findsOneWidget);
    expect(app.requestsTo(path, 'PUT'), hasLength(2));
  });

  testWidgets('a rule is listed with when it applies and the document asked', (
    tester,
  ) async {
    await start(tester, backend());
    await tap(tester, find.text('Document rules').last);
    expect(find.text('Do you own or lease buses?: Lease'), findsOneWidget);
    expect(find.text('Lease agreement'), findsOneWidget);
  });

  testWidgets('question lists are paged', (tester) async {
    final source = backend();
    source.kycConfiguration['questions'] = [
      for (var i = 0; i < 12; i++)
        {
          ...ownership(),
          'key': 'question_$i',
          'label': 'Business question $i',
          'sortOrder': i,
        },
    ];
    await start(tester, source);
    await tester.scrollUntilVisible(
      find.byTooltip('Next page'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(AdminKycConfigurationPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tap(tester, find.byTooltip('Next page'));
    expect(find.text('Business question 10'), findsOneWidget);
    expect(find.text('Business question 0'), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('layout fits a narrow screen and edit dialog', (tester) async {
    await start(tester, backend(), size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await capture(tester, 'kyc_mobile.png');
    await tap(tester, button('Add question'));
    expect(tester.takeException(), isNull);
    await capture(tester, 'kyc_mobile_question.png', dialog: true);
    await tap(tester, find.text('Cancel'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop overview screenshot', (tester) async {
    await start(tester, backend());
    await capture(tester, 'kyc_desktop.png');
    expect(tester.takeException(), isNull);
  });
}
