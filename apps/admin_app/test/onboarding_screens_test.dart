import 'package:admin_app/core/browser_files.dart' as browser;
import 'package:admin_app/core/csv.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:admin_app/shell/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Finder formField(String label) => find.widgetWithText(TextFormField, label);
Finder button(String label) => find.widgetWithText(AbraButton, label);

/// The word in a table row, not in a summary card that may use the same word.
Finder inTable(String text) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(text));

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

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

void main() {
  group('the menu', () {
    testWidgets('offers Invitations and Reviews to staff who may use them', (
      tester,
    ) async {
      await openAs(tester, FakeBackend(Persona.superAdmin), AdminRoutes.trips);
      expect(
        find.descendant(
          of: find.byType(AdminShell),
          matching: find.widgetWithText(ListTile, 'Invitations'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AdminShell),
          matching: find.widgetWithText(ListTile, 'Reviews'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not offer them to read-only staff', (tester) async {
      await openAs(tester, FakeBackend(Persona.support), AdminRoutes.trips);
      expect(find.widgetWithText(ListTile, 'Invitations'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Reviews'), findsNothing);
      await open(tester, AdminRoutes.reviews);
      expect(find.text('Alpha Lines'), findsNothing);
    });

    testWidgets('has the notification bell in the top bar', (tester) async {
      await openAs(tester, FakeBackend(Persona.superAdmin), AdminRoutes.trips);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      await tapOn(tester, find.byTooltip('Notifications'));
      expect(find.text('No notifications yet.'), findsOneWidget);
    });
  });

  group('invitations', () {
    testWidgets('a bus owner is invited, and the outcome and link are shown', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin);
      final app = await openAs(tester, backend, AdminRoutes.invitations);

      await tapOn(tester, button('Add'));
      await tester.enterText(formField('Company name'), 'Alpha Lines');
      await tester.enterText(formField("Owner's name"), 'Anita Rao');
      await tester.enterText(formField("Owner's email"), 'anita@alpha.test');
      await tapOn(tester, button('Save'));

      final body =
          app.requestsTo('onboarding/invitations', 'POST').single.body as Map;
      expect(body['companyName'], 'Alpha Lines');
      expect(body['ownerName'], 'Anita Rao');
      expect(body['email'], 'anita@alpha.test');
      // optional fields left empty are not sent as empty text
      expect(body['displayName'], anyOf(isNull, isEmpty));

      expect(find.text('Invitation sent to anita@alpha.test.'), findsOneWidget);
      expect(
        find.text('http://localhost:5001/accept-invite?token=TESTTOKEN'),
        findsOneWidget,
      );
      await tapOn(tester, find.widgetWithText(FilledButton, 'Close'));
      expect(find.text('Alpha Lines'), findsWidgets);
    });

    testWidgets('a waiting invitation can be withdrawn after a confirmation', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin);
      final invitation = backend.add('invitations', <String, Object?>{
        'companyName': 'Beta Travels',
        'ownerName': 'Bala',
        'email': 'bala@beta.test',
        'status': 'PENDING',
        'expired': false,
        'emailStatus': 'SENT',
        'expiresAt': '2026-10-14T10:00:00.000Z',
        'createdAt': '2026-10-07T10:00:00.000Z',
      });
      final app = await openAs(tester, backend, AdminRoutes.invitations);

      expect(find.text('Beta Travels'), findsOneWidget);
      await tapOn(tester, find.byTooltip('Withdraw invitation'));
      expect(find.text('Withdraw this invitation?'), findsOneWidget);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Withdraw'));

      expect(
        app
            .requestsTo(
              'onboarding/invitations/${invitation['id']}/revoke',
              'POST',
            )
            .length,
        1,
      );
      expect(invitation['status'], 'REVOKED');
    });

    testWidgets('only waiting invitations offer actions', (tester) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('invitations', <String, Object?>{
          'companyName': 'Gamma Lines',
          'ownerName': 'Gita',
          'email': 'gita@gamma.test',
          'status': 'ACCEPTED',
          'expired': false,
          'emailStatus': 'SENT',
          'expiresAt': '2026-10-14T10:00:00.000Z',
          'createdAt': '2026-10-07T10:00:00.000Z',
        });
      await openAs(tester, backend, AdminRoutes.invitations);
      expect(find.text('Gamma Lines'), findsOneWidget);
      expect(find.text('Joined'), findsWidgets);
      expect(find.byTooltip('Withdraw invitation'), findsNothing);
      expect(find.byTooltip('Resend invitation'), findsNothing);
    });
  });

  group('reviews', () {
    testWidgets('the queue lists files waiting and opens one', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      final file = backend.addSubmission();
      await openAs(tester, backend, AdminRoutes.reviews);

      expect(inTable('Alpha Lines'), findsOneWidget);
      expect(inTable('Company documents'), findsOneWidget);
      // the summary card counts the files waiting for review
      expect(find.text('Waiting for review'), findsWidgets);

      await tapOn(tester, find.byTooltip('Review'));
      expect(locationOf(tester), AdminRoutes.reviewOf('${file['id']}'));
      expect(find.text('GST certificate'), findsOneWidget);
      expect(find.textContaining('gst.pdf'), findsOneWidget);
      // a required document the owner has not added is shown as missing
      expect(find.text('PAN card'), findsOneWidget);
      expect(find.text('Not added'), findsOneWidget);
    });

    testWidgets('a document is accepted, another rejected with a reason, and '
        'the file approved', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      final file = backend.addSubmission();
      final app = await openAs(
        tester,
        backend,
        AdminRoutes.reviewOf('${file['id']}'),
      );

      await tapOn(tester, button('Accept'));
      var review =
          app
                  .requestsTo(
                    'onboarding/submissions/${file['id']}/documents/gst-type/review',
                    'POST',
                  )
                  .last
                  .body
              as Map;
      expect(review['decision'], 'APPROVED');

      await tapOn(tester, button('Reject'));
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Why is it rejected? The owner will read this.',
        ),
        'The image is blurred',
      );
      await tapOn(tester, find.widgetWithText(FilledButton, 'Reject'));
      review =
          app
                  .requestsTo(
                    'onboarding/submissions/${file['id']}/documents/gst-type/review',
                    'POST',
                  )
                  .last
                  .body
              as Map;
      expect(review, {
        'decision': 'REJECTED',
        'reason': 'The image is blurred',
      });
      expect(find.text('The image is blurred'), findsOneWidget);

      // Approving needs every document accepted: accept the corrected one
      await tapOn(tester, button('Accept'));
      await tapOn(tester, button('Approve'));
      // the dialog's button is on top of the page's own Approve button
      await tapOn(tester, find.widgetWithText(FilledButton, 'Approve').last);
      expect(
        app
            .requestsTo('onboarding/submissions/${file['id']}/approve', 'POST')
            .length,
        1,
      );
      expect(file['status'], 'APPROVED');
    });

    testWidgets('a rejection needs a reason of some length', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      final file = backend.addSubmission();
      final app = await openAs(
        tester,
        backend,
        AdminRoutes.reviewOf('${file['id']}'),
      );
      await tapOn(tester, button('Reject'));
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Why is it rejected? The owner will read this.',
        ),
        'no',
      );
      await tapOn(tester, find.widgetWithText(FilledButton, 'Reject'));
      // the dialog stays open and nothing was sent
      expect(
        find.widgetWithText(
          TextField,
          'Why is it rejected? The owner will read this.',
        ),
        findsOneWidget,
      );
      expect(
        app.requestsTo(
          'onboarding/submissions/${file['id']}/documents/gst-type/review',
        ),
        isEmpty,
      );
    });

    testWidgets('a file can be sent back with a note to the owner', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin);
      final file = backend.addSubmission();
      final app = await openAs(
        tester,
        backend,
        AdminRoutes.reviewOf('${file['id']}'),
      );
      await tapOn(tester, button('Send back'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Note to the owner (optional)'),
        'Please fix the GST certificate',
      );
      await tapOn(
        tester,
        find.widgetWithText(FilledButton, 'Send back to the owner?'),
      );
      final body =
          app
                  .requestsTo(
                    'onboarding/submissions/${file['id']}/reject',
                    'POST',
                  )
                  .single
                  .body
              as Map;
      expect(body['note'], 'Please fix the GST certificate');
      expect(file['status'], 'REJECTED');
    });

    testWidgets('a file that was already decided offers no review buttons', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin);
      final file = backend.addSubmission(status: 'APPROVED');
      await openAs(tester, backend, AdminRoutes.reviewOf('${file['id']}'));
      expect(find.text('GST certificate'), findsOneWidget);
      expect(button('Accept'), findsNothing);
      expect(button('Approve'), findsNothing);
    });
  });

  group('export and summary cards', () {
    testWidgets('Export downloads everything the list shows as a CSV file', (
      tester,
    ) async {
      final backend = FakeBackend(Persona.superAdmin)
        ..add('document-types', <String, Object?>{
          'key': 'GST',
          'name': 'GST certificate',
          'appliesTo': 'OPERATOR',
          'isRequired': true,
          'requiresExpiry': false,
          'allowedMimeTypes': <String>['application/pdf'],
          'maxFiles': 1,
          'isActive': true,
        })
        ..add('document-types', <String, Object?>{
          'key': 'RC',
          'name': 'Registration, "RC" book',
          'appliesTo': 'BUS',
          'isRequired': true,
          'requiresExpiry': true,
          'allowedMimeTypes': <String>['application/pdf', 'image/png'],
          'maxFiles': 2,
          'isActive': false,
        });
      await openAs(tester, backend, AdminRoutes.documentTypes);
      // the cards count by state
      expect(find.text('Active'), findsWidgets);

      await tapOn(tester, button('Export'));
      expect(browser.lastDownloadName, startsWith('document-types_'));
      final rows = Csv.parse(browser.lastDownloadText!);
      expect(rows.first, contains('Name'));
      expect(rows, hasLength(3));
      expect(rows[1], contains('GST certificate'));
      // a name with a comma and quotes survives
      expect(rows[2], contains('Registration, "RC" book'));
      expect(rows[2], contains('PDF, PNG photo'));
    });
  });

  group('Csv', () {
    test('writes what a spreadsheet can read back', () {
      final text = Csv.encode(
        <String>['Name', 'Note'],
        <List<Object?>>[
          <Object?>['Alpha, Lines', 'said "hello"'],
          <Object?>['Line\nbreak', null],
        ],
      );
      expect(Csv.parse(text), <List<String>>[
        <String>['Name', 'Note'],
        <String>['Alpha, Lines', 'said "hello"'],
        <String>['Line\nbreak', ''],
      ]);
    });

    test('keeps a cell that looks like a formula as text', () {
      expect(
        Csv.line(<Object?>['=SUM(A1)', '-5', '+91 98765', '@home']),
        "'=SUM(A1),-5,'+91 98765,'@home",
      );
    });

    test('reads Windows line breaks, a byte-order mark and blank lines', () {
      expect(Csv.parse('\u{FEFF}a,b\r\n\r\n1,2\r\n'), <List<String>>[
        <String>['a', 'b'],
        <String>['1', '2'],
      ]);
    });
  });
}
