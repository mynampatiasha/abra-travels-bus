import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Finder field(String label) => find.widgetWithText(TextField, label);
Finder button(String label) => find.widgetWithText(AbraButton, label);

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

String typed(WidgetTester tester, String label) =>
    tester.widget<TextField>(field(label)).controller!.text;

Future<TestAdmin> openSettings(
  WidgetTester tester,
  Persona persona, {
  void Function(FakeBackend backend)? prepare,
  String? card = 'WhatsApp',
}) async {
  final backend = FakeBackend(persona);
  prepare?.call(backend);
  final app = TestAdmin.signedIn(backend);
  await app.pump(tester);
  await open(tester, AdminRoutes.settings);
  // A card opens its form in a pop-up
  if (card != null) await tapOn(tester, find.text(card));
  return app;
}

void main() {
  group('settings: who sees what', () {
    testWidgets('a Super Admin has Settings in the menu and can open it', (
      tester,
    ) async {
      await openSettings(tester, Persona.superAdmin, card: null);

      expect(locationOf(tester), AdminRoutes.settings);
      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_SideNavigation',
          ),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );
      // one card for each connection, with where it stands
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Not complete'), findsNWidgets(2));
      expect(button('Save'), findsNothing);

      await tapOn(tester, find.text('WhatsApp'));
      expect(button('Save'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('the search box finds a card by what it holds', (tester) async {
      await openSettings(tester, Persona.superAdmin, card: null);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search settings'),
        'smtp',
      );
      await settle(tester);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search settings'),
        'nothing like this',
      );
      await settle(tester);
      expect(find.text('No settings match your search.'), findsOneWidget);
    });

    testWidgets('closing the pop-up shows the card with the new state', (
      tester,
    ) async {
      await openSettings(tester, Persona.superAdmin);
      await tester.enterText(field('Phone number ID'), '109876543210987');
      await tester.enterText(
        field('Access token'),
        'EAAbigSecretTokenValue1234',
      );
      await tapOn(tester, button('Save'));
      await tapOn(tester, find.byTooltip('Close'));
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Not complete'), findsOneWidget);
    });

    testWidgets('a regular administrator can look but not change', (
      tester,
    ) async {
      final app = await openSettings(tester, Persona.admin);

      expect(
        find.text(
          'You can view these settings. Only a Super Admin can change them.',
        ),
        findsOneWidget,
      );
      expect(button('Save'), findsNothing);
      expect(button('Test connection'), findsNothing);
      expect(
        tester.widget<TextField>(field('Phone number ID')).enabled,
        isFalse,
      );
      expect(app.requestsTo('settings/integrations/whatsapp', 'PUT'), isEmpty);
    });

    testWidgets('someone without the settings permission has no menu entry and '
        'cannot open the page', (tester) async {
      final app = await openSettings(tester, Persona.support, card: null);

      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_SideNavigation',
          ),
          matching: find.text('Settings'),
        ),
        findsNothing,
      );
      expect(find.text('Test connection'), findsNothing);
      expect(app.requestsTo('settings/integrations/whatsapp'), isEmpty);
    });
  });

  group('settings: WhatsApp', () {
    testWidgets('shows what is missing and never asks for a saved secret', (
      tester,
    ) async {
      await openSettings(tester, Persona.superAdmin);

      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Not complete'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Still missing: Access token, Phone number ID'),
        findsOneWidget,
      );
      expect(typed(tester, 'Access token'), isEmpty);
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('saving sends the typed values, the token and a reason, then '
        'shows the setup as ready without the token', (tester) async {
      final app = await openSettings(tester, Persona.superAdmin);

      await tester.enterText(field('Phone number ID'), '109876543210987');
      await tester.enterText(
        field('WhatsApp Business Account ID'),
        '208765432109876',
      );
      await tester.enterText(
        field('Phone number (display)'),
        '+91 90000 00000',
      );
      await tester.enterText(
        field('Webhook verify token'),
        'abra_webhook_verify_123',
      );
      await tester.enterText(
        field('Access token'),
        'EAAbigSecretTokenValue1234',
      );
      await tester.enterText(field('Code message template name'), 'otp_login');
      await tester.enterText(field('Template language'), 'en');
      await tapOn(tester, button('Save'));

      final body =
          app.requestsTo('settings/integrations/whatsapp', 'PUT').single.body
              as Map;
      expect(body, {
        'enabled': true,
        'businessAccountId': '208765432109876',
        'phoneDisplay': '+91 90000 00000',
        'webhookVerifyToken': 'abra_webhook_verify_123',
        'phoneNumberId': '109876543210987',
        'accessToken': 'EAAbigSecretTokenValue1234',
        'otpTemplateName': 'otp_login',
        'otpTemplateLanguage': 'en',
        'notificationTemplateName': null,
        'notificationTemplateLanguage': null,
        'otpFallbackToSms': true,
        'reason': 'Updated in the management app',
      });
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      // the secret field is emptied and only its last four are shown
      expect(typed(tester, 'Access token'), isEmpty);
      expect(typed(tester, 'Webhook verify token'), isEmpty);
      expect(
        find.text('Saved, ending 1234. Leave empty to keep it.'),
        findsOneWidget,
      );
      expect(find.text('EAAbigSecretTokenValue1234'), findsNothing);
    });

    testWidgets('saving without typing a token keeps the saved one', (
      tester,
    ) async {
      final app = await openSettings(tester, Persona.superAdmin);

      await tester.enterText(field('Phone number ID'), '109876543210987');
      await tapOn(tester, button('Save'));

      final body =
          app.requestsTo('settings/integrations/whatsapp', 'PUT').single.body
              as Map;
      expect(body.containsKey('accessToken'), isFalse);
      // an emptied optional field is sent as null, which clears it
      expect(body['businessAccountId'], isNull);
    });

    testWidgets('a reason typed by the administrator is the one sent', (
      tester,
    ) async {
      final app = await openSettings(tester, Persona.superAdmin);

      await tester.enterText(
        field('Reason for this change'),
        'Rotated the token',
      );
      await tester.enterText(field('Phone number ID'), '109876543210987');
      await tapOn(tester, button('Save'));

      final body =
          app.requestsTo('settings/integrations/whatsapp', 'PUT').single.body
              as Map;
      expect(body['reason'], 'Rotated the token');
    });

    testWidgets('the connection test says why it failed, then that it worked', (
      tester,
    ) async {
      final app = await openSettings(tester, Persona.superAdmin);

      await tapOn(tester, button('Test connection'));
      expect(find.text('Save the access token first.'), findsOneWidget);

      await tester.enterText(field('Phone number ID'), '109876543210987');
      await tester.enterText(
        field('Access token'),
        'EAAbigSecretTokenValue1234',
      );
      await tapOn(tester, button('Save'));
      await tapOn(tester, button('Test connection'));

      expect(
        find.text('Connected to WhatsApp: number +91 98765 43210.'),
        findsOneWidget,
      );
      expect(
        app.requestsTo(
          'settings/integrations/whatsapp/test-connection',
          'POST',
        ),
        hasLength(2),
      );
    });

    testWidgets('when the backend refuses the change, its reason is shown', (
      tester,
    ) async {
      await openSettings(
        tester,
        Persona.superAdmin,
        prepare: (backend) =>
            backend.overrides['PUT settings/integrations/whatsapp'] = (_) =>
                FakeResponse.error(
                  400,
                  'VALIDATION_FAILED',
                  message:
                      'phoneNumberId: must be the numeric id shown by Meta',
                ),
      );

      await tester.enterText(field('Phone number ID'), 'abc');
      await tapOn(tester, button('Save'));

      expect(
        find.text('phoneNumberId: must be the numeric id shown by Meta'),
        findsOneWidget,
      );
      // the form stays as typed so the mistake can be fixed
      expect(typed(tester, 'Phone number ID'), 'abc');
    });
  });

  group('settings: email', () {
    Future<TestAdmin> openEmail(WidgetTester tester) async {
      return openSettings(tester, Persona.superAdmin, card: 'Email');
    }

    testWidgets('starts with the address from the server and what is missing', (
      tester,
    ) async {
      await openEmail(tester);

      expect(typed(tester, 'From address'), 'no-reply@abratravels.local');
      expect(find.text('Still missing: SMTP host, Port'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('saving sends the SMTP details; the password is never shown '
        'again', (tester) async {
      final app = await openEmail(tester);

      await tester.enterText(field('SMTP host'), 'smtp-relay.brevo.com');
      await tester.enterText(field('Port'), '587');
      await tester.enterText(field('Username'), 'mailer@abra.test');
      await tester.enterText(field('Password'), 'p@ss w0rd with spaces');
      await tester.enterText(field('Sender name'), 'Abra Travels');
      await tester.enterText(field('From address'), 'hello@abratravels.in');
      await tapOn(tester, button('Save'));

      final body =
          app.requestsTo('settings/integrations/email', 'PUT').single.body
              as Map;
      expect(body, {
        'enabled': true,
        'host': 'smtp-relay.brevo.com',
        'port': 587,
        'security': 'STARTTLS',
        'username': 'mailer@abra.test',
        'password': 'p@ss w0rd with spaces',
        'fromName': 'Abra Travels',
        'fromAddress': 'hello@abratravels.in',
        'replyTo': null,
        'reason': 'Updated in the management app',
      });
      expect(find.text('Ready'), findsOneWidget);
      expect(typed(tester, 'Password'), isEmpty);
      expect(find.text('Saved. Leave empty to keep it.'), findsOneWidget);
    });

    testWidgets('the security option is sent as chosen', (tester) async {
      final app = await openEmail(tester);

      await tapOn(
        tester,
        find.widgetWithText(DropdownButtonFormField<String>, 'Security').last,
      );
      await tapOn(tester, find.text('SSL (usually port 465)').last);
      await tester.enterText(field('SMTP host'), 'smtp.example.com');
      await tester.enterText(field('Port'), '465');
      await tapOn(tester, button('Save'));

      final body =
          app.requestsTo('settings/integrations/email', 'PUT').single.body
              as Map;
      expect(body['security'], 'SSL');
      expect(body.containsKey('password'), isFalse);
    });

    testWidgets('the connection test and the test email report what happened', (
      tester,
    ) async {
      final app = await openEmail(tester);

      await tapOn(tester, button('Test connection'));
      expect(
        find.text('Enter the host and the port and save, then test again.'),
        findsOneWidget,
      );

      await tester.enterText(field('SMTP host'), 'smtp.example.com');
      await tester.enterText(field('Port'), '587');
      await tapOn(tester, button('Save'));
      await tapOn(tester, button('Test connection'));
      expect(
        find.text('Connected to smtp.example.com:587 and signed in.'),
        findsOneWidget,
      );

      await tapOn(tester, button('Send test email'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Send the test email to'),
        'owner@client.test',
      );
      await tapOn(tester, find.widgetWithText(FilledButton, 'Send test email'));

      expect(
        find.text('A test email was sent to owner@client.test.'),
        findsOneWidget,
      );
      expect(
        (app
                .requestsTo('settings/integrations/email/test-email', 'POST')
                .single
                .body
            as Map)['to'],
        'owner@client.test',
      );
    });

    testWidgets('cancelling the test email dialog sends nothing', (
      tester,
    ) async {
      final app = await openEmail(tester);

      await tapOn(tester, button('Send test email'));
      await tapOn(tester, find.widgetWithText(TextButton, 'Cancel'));

      expect(app.requestsTo('settings/integrations/email/test-email'), isEmpty);
    });
  });
}
