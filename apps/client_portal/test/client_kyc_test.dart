import 'package:client_portal/app/providers.dart';
import 'package:client_portal/features/dashboard/client_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_portal.dart';

FakeBackend pendingClient({String status = 'DRAFT'}) {
  final backend = FakeBackend(Persona.owner);
  final file = backend.addCompanyFile(status: status);
  backend.clientKyc = {
    'approved': false,
    'companyName': 'Alpha Lines',
    'companyStatus': 'PENDING_APPROVAL',
    'submissionId': file['id'],
    'status': status,
    'kyc': {
      'version': 1,
      'answers': <String, Object?>{},
      'requirements': <Object?>[],
      if (status == 'PENDING') 'introductionAcceptedAt': '2026-10-09T00:00:00Z',
      'configuration': {
        'questions': [
          {
            'key': 'gst',
            'label': 'Are you GST registered?',
            'help': 'This decides whether a GST certificate is needed.',
            'required': true,
            'active': true,
            'appliesTo': 'OPERATOR',
            'sortOrder': 1,
            'type': 'BOOLEAN',
            'options': <Object?>[],
          },
        ],
      },
    },
  };
  return backend;
}

void main() {
  testWidgets(
    'pending clients see the introduction and cannot open the dashboard',
    (tester) async {
      final backend = pendingClient();
      await TestPortal.signedIn(backend).pump(tester);
      expect(locationOf(tester), '/kyc');
      expect(find.text('Welcome to Abra Travels'), findsOneWidget);
      await open(tester, '/dashboard');
      expect(locationOf(tester), '/kyc');
      expect(find.text('Bookings today'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'company details and question answers are saved before documents appear',
    (tester) async {
      final backend = pendingClient();
      await TestPortal.signedIn(backend).pump(tester);
      await tester.tap(find.text('Continue to KYC'));
      await settle(tester);
      expect(find.text('Are you GST registered? *'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.tap(find.text('Save answers and view documents'));
      await settle(tester);
      final kyc = backend.clientKyc['kyc']! as Map<Object?, Object?>;
      expect(kyc['answers'], {'gst': 'false'});
      expect(
        find.text('Upload your documents and submit for verification.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'submitted clients stay under verification until the server approves',
    (tester) async {
      final backend = pendingClient(status: 'PENDING');
      await TestPortal.signedIn(backend).pump(tester);
      expect(find.textContaining('Under verification'), findsOneWidget);
      await open(tester, '/dashboard');
      expect(locationOf(tester), '/kyc');
      backend.clientKyc['approved'] = true;
      backend.clientKyc['status'] = 'APPROVED';
      final approval = containerOf(
        tester,
      ).read(accessProvider.notifier).refreshApproval();
      await settle(tester);
      await approval;
      await open(tester, '/dashboard');
      expect(locationOf(tester), '/dashboard');
      expect(find.byType(ClientDashboardScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'after Send for review the screen shows the waiting state, not the form',
    (tester) async {
      final backend = pendingClient();
      // Every document is in: the file may be sent.
      backend.of('submissions').single['canSubmit'] = true;
      await TestPortal.signedIn(backend).pump(tester);
      await tester.tap(find.text('Continue to KYC'));
      await settle(tester);
      await tester.tap(find.text('No'));
      await tester.tap(find.text('Save answers and view documents'));
      await settle(tester);
      final send = find.text('Send for review');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await settle(tester);
      expect(find.textContaining('Under verification'), findsOneWidget);
      expect(find.text('Edit answers'), findsNothing);
      expect(find.text('Save answers and view documents'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Google button is present alongside the existing password login',
    (tester) async {
      await TestPortal(FakeBackend(Persona.owner)).pump(tester);
      expect(find.byTooltip('Continue with Google'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Email or phone number'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    },
  );
}
