import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

FakeBackend withMessages(Persona persona) {
  return FakeBackend(persona)
    ..addMessage(
      channel: 'WHATSAPP',
      kind: 'BOOKING_CONFIRMED',
      recipientName: 'Priya Sharma',
      address: '+91 98765 43210',
      subject: 'Booking confirmed: Hyderabad to Bengaluru',
      body:
          'Hi Priya, your seat 12A on Hyderabad to Bengaluru is confirmed. PNR ABRK1234A.',
      status: 'SENT',
      bookingId: 'BK-1001',
      at: '2026-10-21T08:30:00.000Z',
    )
    ..addMessage(
      channel: 'EMAIL',
      kind: 'TICKET_PDF',
      recipientName: 'Rahul Verma',
      address: 'rahul.verma@example.com',
      subject: 'Your Abra Travels Ticket - HYD-BLR',
      body:
          'Dear Rahul, please find attached your ticket PDF for trip HYD-BLR.',
      status: 'SENT',
      bookingId: 'BK-1002',
      at: '2026-10-21T09:15:00.000Z',
    )
    ..addMessage(
      channel: 'WHATSAPP',
      kind: 'TRIP_REMINDER',
      recipientName: 'Anil Kumar',
      address: '+91 91234 56789',
      subject: 'Trip reminder: Departure at 21:00',
      body:
          'Hi Anil, your bus departs at 21:00 from MGBS Hyderabad. Boarding point: Platform 5.',
      status: 'FAILED',
      bookingId: 'BK-1003',
      at: '2026-10-21T09:45:00.000Z',
    );
}

Future<TestAdmin> openMessages(
  WidgetTester tester, {
  Persona persona = Persona.superAdmin,
  FakeBackend? backend,
}) async {
  final b = backend ?? withMessages(persona);
  final app = TestAdmin.signedIn(b);
  await app.pump(tester, size: const Size(1440, 1000));
  await open(tester, AdminRoutes.messages);
  return app;
}

void main() {
  group('Messages log', () {
    testWidgets('names the new message types and the SMS channel in words', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..addMessage(kind: 'BUS_CHANGED', subject: 'Bus changed for your trip: ABR1')
        ..addMessage(
          channel: 'SMS',
          kind: 'SOS_ALERT',
          subject: 'SOS alert from Asha',
        )
        ..addMessage(kind: 'TRAVEL_REMINDER', subject: 'Your trip is tomorrow: ABR2');
      await openMessages(tester, backend: backend);

      expect(find.text('Bus changed'), findsWidgets);
      expect(find.text('SOS alert'), findsWidgets);
      expect(find.text('Travel reminder'), findsWidgets);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('BUS_CHANGED'), findsNothing);
    });

    testWidgets('shows the demo stats and columns with real message records', (
      tester,
    ) async {
      await openMessages(tester);

      expect(locationOf(tester), AdminRoutes.messages);
      expect(find.text('Messages sent'), findsWidgets);

      // Stat cards matching demo
      expect(find.text('Sent today'), findsOneWidget);
      expect(find.text('WhatsApp messages'), findsOneWidget);
      expect(find.text('Emails'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);

      // Rows
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('rahul.verma@example.com'), findsOneWidget);
      expect(find.text('Anil Kumar'), findsOneWidget);
      expect(find.text('+91 91234 56789'), findsOneWidget);

      // Channels and Statuses
      expect(find.text('WhatsApp'), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('SENT'), findsNWidgets(2));
      expect(find.text('FAILED'), findsOneWidget);
    });

    testWidgets(
      'clicking a WhatsApp message opens WhatsApp detail dialog and allows resend',
      (tester) async {
        final app = await openMessages(tester);

        // Tap on Priya Sharma row
        await tapOn(tester, find.text('Priya Sharma'));

        // Verify dialog is open
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Booking confirmed: Hyderabad to Bengaluru'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('✓✓'), findsOneWidget);
        expect(
          find.text(
            'Hi Priya, your seat 12A on Hyderabad to Bengaluru is confirmed. PNR ABRK1234A.',
          ),
          findsOneWidget,
        );

        // Verify "Send again" button exists and works
        final sendAgainBtn = find.widgetWithText(AbraButton, 'Send again');
        expect(sendAgainBtn, findsOneWidget);
        await tapOn(tester, sendAgainBtn);

        // Verify resend API was called
        expect(
          app.adapter.requests.where((r) => r.path.contains('/resend') && r.options.method == 'POST'),
          isNotEmpty,
        );
        expect(find.textContaining('Sent again to'), findsOneWidget);
      },
    );

    testWidgets('clicking an Email message opens Email detail dialog', (
      tester,
    ) async {
      await openMessages(tester);

      // Tap on Rahul Verma row
      await tapOn(tester, find.text('Rahul Verma'));

      // Verify dialog is open
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Your Abra Travels Ticket - HYD-BLR'),
        ),
        findsWidgets,
      );
      expect(
        find.text(
          'Dear Rahul, please find attached your ticket PDF for trip HYD-BLR.',
        ),
        findsOneWidget,
      );

      // Close dialog
      await tapOn(tester, find.widgetWithText(OutlinedButton, 'Close'));
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('search filter queries messages', (tester) async {
      final app = await openMessages(tester);

      final searchField = find.widgetWithText(TextField, 'Customer, phone, email, PNR');
      await tester.enterText(searchField, 'Rahul');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(app.requestsTo('admin/messages'), isNotEmpty);
    });
  });
}
