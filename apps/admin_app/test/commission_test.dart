// The Commission page (demo page `commission`). Adapted from the screen test that came with the
// downloaded Commission feature: the same cases, run through this app's fake backend.
import 'package:admin_app/features/commission/commission_admin_manage_screen.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_admin.dart';

/// A platform role that may look at commission and download it, but not change it.
const accounts = Persona(
  name: 'Aruna Accounts',
  userType: 'STAFF',
  roleKey: 'ACCOUNTS',
  permissions: {'commissions.read', 'commissions.export'},
);

Map<String, Object?> rule(
  String id,
  String scope,
  String target, {
  String status = 'ACTIVE',
  String mode = 'PERCENT',
  int value = 1000,
}) => <String, Object?>{
  'id': id,
  'scope': scope,
  'targetId': 't-$id',
  'targetName': target,
  'mode': mode,
  'value': value,
  'effectiveFrom': '2026-10-14',
  'agreedNote': 'Agreed on call',
  'version': 1,
  'status': status,
};

FakeBackend withCommission(Persona persona) {
  final backend = FakeBackend(persona);
  final rules = <Map<String, Object?>>[
    rule('CR-1', 'OPERATOR', 'Kaveri Express'),
    rule('CR-2', 'OPERATOR', 'Deccan Voyager', mode: 'FLAT', value: 6000),
    rule('CR-3', 'BUS_TYPE', 'Non-AC Seater', status: 'INACTIVE', value: 700),
  ];
  FakeResponse denied() => FakeResponse.error(403, 'PERMISSION_DENIED');
  bool may(String key) => persona.permissions.contains(key);
  final overrides = backend.overrides;
  overrides['GET admin/commission/default'] = (_) => may('commissions.read')
      ? FakeResponse.ok(<String, Object?>{
          'mode': 'PERCENT',
          'value': 1000,
          'configured': true,
        })
      : denied();
  overrides['GET admin/commission/rules'] = (_) => may('commissions.read')
      ? FakeResponse.ok(
          rules,
          meta: <String, Object?>{'page': 1, 'pageSize': 10, 'total': 3},
        )
      : denied();
  overrides['GET admin/commission/history'] = (_) => FakeResponse.ok(
    <Map<String, Object?>>[],
    meta: <String, Object?>{'page': 1, 'pageSize': 20, 'total': 0},
  );
  overrides['PUT admin/commission/default'] = (_) => FakeResponse.ok(null);
  return backend;
}

Future<TestAdmin> openCommission(
  WidgetTester tester,
  FakeBackend backend, {
  Size size = const Size(1440, 1000),
}) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: size);
  await open(tester, AdminRoutes.commission);
  return app;
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  group('formatting', () {
    test('commission text matches the table', () {
      expect(formatCommission('PERCENT', 1000), '10%');
      expect(formatCommission('PERCENT', 1050), '10.5%');
      expect(formatCommission('FLAT', 6000), 'Rs 60 per seat');
    });
    test('rupees use Indian grouping', () {
      expect(formatRupees(240000), 'Rs 2,400');
      expect(formatRupees(4900), 'Rs 49');
      expect(formatRupees(6050), 'Rs 60.50');
      expect(formatRupees(12345600), 'Rs 1,23,456');
    });
    test('typed values become whole numbers x 100', () {
      expect(parseValueX100('10'), 1000);
      expect(parseValueX100('12.5'), 1250);
      expect(parseValueX100(' 60 '), 6000);
      expect(parseValueX100('abc'), isNull);
      expect(parseValueX100(''), isNull);
    });
  });

  group('Rules tab', () {
    testWidgets(
      'Super Admin sees the demo page: tabs, banner, default, rows, every button',
      (tester) async {
        await openCommission(tester, withCommission(Persona.superAdmin));
        // Title and the line under it come from the shell, as on every page
        expect(
          find.text(
            'Set what Abra earns on each booking. Operators can see it but not change it.',
          ),
          findsOneWidget,
        );
        for (final tab in ['Rules', 'Price calculator', 'Change history']) {
          expect(find.text(tab), findsOneWidget, reason: tab);
        }
        expect(
          find.textContaining('Order of rules: operator, then route'),
          findsOneWidget,
        );
        expect(find.text('Default rule'), findsOneWidget);
        expect(
          find.text('Used when nothing more specific applies'),
          findsOneWidget,
        );
        for (final column in [
          'ID',
          'Applies to',
          'Target',
          'Commission',
          'Effective from',
          'Version',
          'Status',
          'Agreed note',
          'Actions',
        ]) {
          expect(find.text(column), findsWidgets, reason: column);
        }
        expect(find.text('CR-1'), findsOneWidget);
        expect(find.text('Rs 60 per seat'), findsOneWidget);
        // Pills read like the demo's: words, not codes
        expect(find.text('Operator'), findsWidgets);
        expect(find.text('Bus type'), findsWidgets);
        expect(find.text('Active'), findsWidgets);
        expect(find.text('Inactive'), findsWidgets);
        expect(find.text('OPERATOR'), findsNothing);
        for (final button in [
          'Change',
          'New rule',
          'Export CSV',
          'Clear',
          'Table',
          'List',
        ]) {
          expect(find.text(button), findsOneWidget, reason: button);
        }
        expect(find.text('Deactivate'), findsNWidgets(2));
        expect(find.text('Activate'), findsOneWidget);
        expect(find.byTooltip('Delete'), findsNWidgets(3));
        expect(find.byTooltip('View'), findsNWidgets(3));
        expect(find.text('3 results'), findsOneWidget);
        expect(find.text('Page 1 of 1'), findsOneWidget);
      },
    );

    testWidgets(
      'a column header sorts on the server, and again turns the order round',
      (tester) async {
        final app = await openCommission(
          tester,
          withCommission(Persona.superAdmin),
        );
        await tapOn(tester, find.text('Target'));
        var last = app.requestsTo('admin/commission/rules', 'GET').last;
        expect(last.options.queryParameters['sort'], 'target');
        expect(last.options.queryParameters['dir'], 'asc');
        await tapOn(tester, find.text('Target'));
        last = app.requestsTo('admin/commission/rules', 'GET').last;
        expect(last.options.queryParameters['dir'], 'desc');
      },
    );

    testWidgets('Accounts can look and download but not change', (
      tester,
    ) async {
      await openCommission(tester, withCommission(accounts));
      expect(find.text('CR-1'), findsOneWidget);
      expect(find.byTooltip('View'), findsNWidgets(3));
      expect(find.text('Export CSV'), findsOneWidget);
      for (final hidden in [
        'New rule',
        'Change',
        'Edit',
        'Deactivate',
        'Activate',
      ]) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets(
      'Support does not get the page, and nothing is asked of the server',
      (tester) async {
        final app = await openCommission(
          tester,
          withCommission(Persona.support),
        );
        expect(find.text('No access'), findsOneWidget);
        expect(app.requestsTo('admin/commission/rules'), isEmpty);
      },
    );

    testWidgets('New rule dialog has the fields from the demo', (tester) async {
      await openCommission(tester, withCommission(Persona.admin));
      await tapOn(tester, find.text('New rule'));
      expect(find.text('New commission rule'), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      for (final field in [
        'Applies to',
        'Which one',
        'Type',
        'Value',
        'Effective from',
        'Agreed note',
        'Cancel',
        'Save rule',
      ]) {
        expect(
          find.descendant(of: dialog, matching: find.text(field)),
          findsOneWidget,
          reason: field,
        );
      }
    });

    testWidgets(
      'Edit locks Applies to and Which one, and says "Save as new version"',
      (tester) async {
        await openCommission(tester, withCommission(Persona.admin));
        await tapOn(tester, find.text('Edit').first);
        expect(find.text('Edit rule CR-1'), findsOneWidget);
        expect(find.text('Save as new version'), findsOneWidget);
        final dropdowns = tester
            .widgetList<DropdownButtonFormField<String>>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(DropdownButtonFormField<String>),
              ),
            )
            .toList();
        expect(dropdowns[0].onChanged, isNull);
        expect(dropdowns[1].onChanged, isNull);
        expect(dropdowns[2].onChanged, isNotNull);
      },
    );

    testWidgets('a percentage above 40 is refused before anything is sent', (
      tester,
    ) async {
      final app = await openCommission(
        tester,
        withCommission(Persona.superAdmin),
      );
      await tapOn(tester, find.text('Change'));
      expect(find.text('Default commission'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '41',
      );
      await tapOn(tester, find.text('Save'));
      expect(find.text('Percentage must be 0 to 40'), findsOneWidget);
      expect(app.requestsTo('admin/commission/default', 'PUT'), isEmpty);
    });

    testWidgets('Delete asks first, in the demo\'s words', (tester) async {
      await openCommission(tester, withCommission(Persona.superAdmin));
      await tapOn(tester, find.byTooltip('Delete').first);
      expect(find.text('Delete CR-1?'), findsOneWidget);
      expect(
        find.text(
          'This removes it from every list. You can undo for a few seconds.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('phone width: cards instead of the table, nothing overflows', (
      tester,
    ) async {
      await openCommission(
        tester,
        withCommission(Persona.superAdmin),
        size: const Size(390, 844),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('CR-1'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });
  });

  group('Change history tab', () {
    testWidgets('shows an empty message when nothing has changed', (
      tester,
    ) async {
      await openCommission(tester, withCommission(Persona.superAdmin));
      await tapOn(tester, find.text('Change history'));
      expect(find.text('No changes yet'), findsOneWidget);
    });
  });
}
