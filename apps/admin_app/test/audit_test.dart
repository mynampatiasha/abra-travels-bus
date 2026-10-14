import 'package:admin_app/core/browser_files.dart' as browser;
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Map<String, Object?> entry(
  int day,
  String who,
  String action,
  String target, {
  bool sensitive = false,
}) => <String, Object?>{
  'at': '2026-01-${day.toString().padLeft(2, '0')}T10:00:00.000Z',
  'action': action.toLowerCase().replaceAll(' ', '.'),
  'actionLabel': action,
  'sensitive': sensitive,
  'actorName': who,
  'actorRoleLabel': 'Super Admin',
  'targetLabel': target,
  'ip': '10.0.0.$day',
  'reason': null,
  'before': sensitive
      ? <String, Object?>{'level': 'View'}
      : <String, Object?>{},
  'after': sensitive ? <String, Object?>{'level': 'Edit'} : <String, Object?>{},
};

FakeBackend withAudit(Persona persona) => FakeBackend(persona)
  ..add(
    'audit-logs',
    entry(10, 'Priya', 'Changed role access', 'Role: Finance', sensitive: true),
  )
  ..add(
    'audit-logs',
    entry(12, 'Anil', 'Added a banner', 'Banner: Diwali sale'),
  )
  ..add('audit-logs', entry(14, 'Priya', 'Downloaded a list', 'Cities'));

Future<TestAdmin> openAudit(WidgetTester tester, FakeBackend backend) async {
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, AdminRoutes.audit);
  return app;
}

void main() {
  group('Audit log', () {
    testWidgets(
      'shows the demo columns, newest first, with the Sensitive mark',
      (tester) async {
        await openAudit(tester, withAudit(Persona.superAdmin));

        for (final column in <String>[
          'When',
          'Who',
          'Action',
          'Target',
          'IP address',
        ]) {
          expect(find.text(column), findsWidgets, reason: column);
        }
        expect(find.text('Sensitive'), findsOneWidget);
        final newest = tester.getTopLeft(find.text('Downloaded a list')).dy;
        final oldest = tester.getTopLeft(find.text('Changed role access')).dy;
        expect(newest, lessThan(oldest));
      },
    );

    testWidgets('When sorts oldest first when tapped', (tester) async {
      final app = await openAudit(tester, withAudit(Persona.superAdmin));

      await tapOn(tester, find.text('When'));

      final oldest = tester.getTopLeft(find.text('Changed role access')).dy;
      final newest = tester.getTopLeft(find.text('Downloaded a list')).dy;
      expect(oldest, lessThan(newest));
      expect(
        app.adapter.requests.last.options.queryParameters['sort'],
        'oldest',
      );
    });

    testWidgets('Type: Sensitive only asks the server and narrows the list', (
      tester,
    ) async {
      final app = await openAudit(tester, withAudit(Persona.superAdmin));

      await tapOn(
        tester,
        find.widgetWithText(DropdownButtonFormField<String>, 'Type'),
      );
      await tapOn(tester, find.text('Sensitive only').last);

      expect(find.text('Changed role access'), findsOneWidget);
      expect(find.text('Added a banner'), findsNothing);
      expect(
        app.adapter.requests.last.options.queryParameters['type'],
        'sensitive',
      );
    });

    testWidgets(
      'a row opens the entry; a sensitive one shows before and after',
      (tester) async {
        await openAudit(tester, withAudit(Persona.superAdmin));

        await tapOn(tester, find.text('Changed role access'));

        expect(find.text('Audit entry'), findsOneWidget);
        final dialog = find.byType(AlertDialog);
        for (final label in <String>['Role', 'Change', 'Before', 'After']) {
          expect(
            find.descendant(of: dialog, matching: find.text(label)),
            findsOneWidget,
            reason: label,
          );
        }
        expect(find.textContaining('"level": "Edit"'), findsOneWidget);

        await tapOn(tester, find.widgetWithText(AbraButton, 'Close'));
        await tapOn(tester, find.text('Added a banner'));
        expect(find.text('Audit entry'), findsOneWidget);
        expect(find.text('Change'), findsNothing);
      },
    );

    testWidgets(
      'Export asks the server with the same filters and saves the file',
      (tester) async {
        final backend = withAudit(Persona.superAdmin);
        backend.overrides['GET audit-logs/export?sort=newest&format=csv'] =
            (_) => const FakeResponse(200, 'csv bytes');
        final app = await openAudit(tester, backend);
        browser.lastDownloadName = null;

        await tapOn(tester, find.widgetWithText(AbraButton, 'Export'));
        await tapOn(tester, find.text('CSV file'));

        expect(
          app.requestsTo('audit-logs/export?sort=newest&format=csv', 'GET'),
          hasLength(1),
        );
        expect(browser.lastDownloadName, startsWith('audit-log-'));
        expect(browser.lastDownloadName, endsWith('.csv'));
      },
    );

    testWidgets('a person who may read but not export sees no Export button', (
      tester,
    ) async {
      await openAudit(
        tester,
        withAudit(
          const Persona(
            name: 'Reader',
            userType: 'STAFF',
            roleKey: 'AUDITOR',
            permissions: {'audit.read'},
          ),
        ),
      );

      expect(find.text('Changed role access'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Export'), findsNothing);
    });

    testWidgets('nothing recorded yet says so', (tester) async {
      await openAudit(tester, FakeBackend(Persona.superAdmin));
      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });
  });
}
