import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

Future<TestAdmin> openFeatureFlags(
  WidgetTester tester,
  Persona persona, {
  void Function(FakeBackend backend)? prepare,
}) async {
  final backend = FakeBackend(persona);
  prepare?.call(backend);
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, AdminRoutes.featureFlags);
  return app;
}

void main() {
  group('Feature flags and maintenance', () {
    testWidgets('a Super Admin sees flags with status badges and maintenance scopes', (
      tester,
    ) async {
      await openFeatureFlags(tester, Persona.superAdmin);

      expect(locationOf(tester), AdminRoutes.featureFlags);
      expect(find.text('Feature flags and maintenance'), findsOneWidget);
      expect(find.text('Feature flags'), findsWidgets);
      expect(find.widgetWithText(SwitchListTile, 'Live tracking'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Disabled'), findsWidgets);
      expect(find.text('Maintenance mode'), findsOneWidget);
      expect(
        find.text(
          'Staff with the maintenance permission can always sign in, so nobody gets locked out.',
        ),
        findsOneWidget,
      );
      expect(find.text('Global maintenance (All apps & APIs)'), findsOneWidget);
      expect(find.text('Save message and schedule'), findsOneWidget);
    });

    testWidgets('toggling a feature flag opens confirmation dialog and updates on submit', (
      tester,
    ) async {
      final app = await openFeatureFlags(tester, Persona.superAdmin);

      // Find switch for 'WhatsApp chatbot' (initial value is false)
      final chatbotTile = find.widgetWithText(SwitchListTile, 'WhatsApp chatbot');
      expect(chatbotTile, findsOneWidget);

      await tapOn(tester, find.descendant(of: chatbotTile, matching: find.byType(Switch)));
      expect(find.text('Turn on WhatsApp chatbot'), findsOneWidget);
      expect(
        find.text('Customers get this feature on their next app refresh.'),
        findsOneWidget,
      );

      // Confirm dialog button
      await tapOn(tester, find.widgetWithText(ElevatedButton, 'Turn on'));

      final requests = app.requestsTo('admin/feature-flags/whatsapp_chatbot', 'PUT');
      expect(requests, hasLength(1));
      expect((requests.single.body as Map)['on'], isTrue);
      expect(find.text('WhatsApp chatbot is now enabled.'), findsOneWidget);
    });

    testWidgets('toggling global maintenance shows confirmation dialog and sends PUT', (
      tester,
    ) async {
      final app = await openFeatureFlags(tester, Persona.superAdmin);

      final globalTile = find.widgetWithText(
        SwitchListTile,
        'Global maintenance (All apps & APIs)',
      );
      expect(globalTile, findsOneWidget);

      await tapOn(tester, find.descendant(of: globalTile, matching: find.byType(Switch)));
      expect(find.text('Global maintenance'), findsOneWidget);
      expect(
        find.text(
          'Customer, operator and partner apps stop working. Admin staff still get in.',
        ),
        findsOneWidget,
      );

      await tapOn(tester, find.widgetWithText(ElevatedButton, 'Turn on'));

      final requests = app.requestsTo('admin/maintenance', 'PUT');
      expect(requests, hasLength(1));
      expect((requests.single.body as Map)['scopes'], {'global': true});
      expect(find.text('Global maintenance mode enabled.'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
    });

    testWidgets('toggling a scope updates maintenance directly', (tester) async {
      final app = await openFeatureFlags(tester, Persona.superAdmin);

      final customerTile = find.widgetWithText(
        SwitchListTile,
        'Customer app maintenance',
      );
      expect(customerTile, findsOneWidget);

      await tapOn(tester, find.descendant(of: customerTile, matching: find.byType(Switch)));

      final requests = app.requestsTo('admin/maintenance', 'PUT');
      expect(requests, hasLength(1));
      expect((requests.single.body as Map)['scopes'], {'customer': true});
      expect(find.text('Customer app maintenance enabled.'), findsOneWidget);
    });

    testWidgets('saving schedule validates that ends is after starts', (tester) async {
      final app = await openFeatureFlags(tester, Persona.superAdmin);

      await tester.enterText(
        find.widgetWithText(TextField, 'Starts'),
        '2026-10-20T10:00:00Z',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Ends'),
        '2026-10-19T10:00:00Z',
      );
      await tapOn(tester, find.text('Save message and schedule'));

      expect(find.text('End must be after start'), findsOneWidget);
      expect(app.requestsTo('admin/maintenance', 'PUT'), isEmpty);
    });

    testWidgets('saving message and valid schedule sends PUT to maintenance', (tester) async {
      final app = await openFeatureFlags(tester, Persona.superAdmin);

      await tester.enterText(
        find.widgetWithText(TextField, 'Message customers see'),
        'Scheduled upgrade on Saturday midnight.',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Starts'),
        '2026-10-20T10:00:00Z',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Ends'),
        '2026-10-21T10:00:00Z',
      );
      await tapOn(tester, find.text('Save message and schedule'));

      final requests = app.requestsTo('admin/maintenance', 'PUT');
      expect(requests, hasLength(1));
      final body = requests.single.body as Map;
      expect(body['message'], 'Scheduled upgrade on Saturday midnight.');
      expect(body['from'], '2026-10-20T10:00:00Z');
      expect(body['to'], '2026-10-21T10:00:00Z');
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('an administrator without settings.update has read-only access', (
      tester,
    ) async {
      final app = await openFeatureFlags(tester, Persona.admin);

      expect(locationOf(tester), AdminRoutes.featureFlags);
      // Save button should not be present
      expect(find.text('Save message and schedule'), findsNothing);

      // Switches are disabled (onChanged is null)
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      for (final s in switches) {
        expect(s.onChanged, isNull);
      }
      expect(app.requestsTo('admin/feature-flags/live_tracking', 'PUT'), isEmpty);
    });

    testWidgets('a user without settings.read cannot open feature flags and sees forbidden', (
      tester,
    ) async {
      final app = await openFeatureFlags(tester, Persona.support);

      // Permission gate shows forbidden state, feature flags card is not displayed
      expect(find.byType(AbraStateView), findsOneWidget);
      expect(find.text('Message customers see'), findsNothing);
      expect(app.requestsTo('admin/feature-flags'), isEmpty);
    });
  });
}
