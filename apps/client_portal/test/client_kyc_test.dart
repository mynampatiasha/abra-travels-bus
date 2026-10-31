import 'package:client_portal/app/providers.dart';
import 'package:client_portal/features/dashboard/client_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
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

  group('login methods before KYC is finished', () {
    FakeBackend withMethods({bool hasPassword = false, String? phone}) {
      final backend = pendingClient();
      backend.overrides['GET client/kyc/login-methods'] = (req) => FakeResponse.ok(<String, Object?>{
        'phone': phone,
        'email': 'asha@example.com',
        'hasPassword': hasPassword,
        'socialLinked': true,
      });
      backend.overrides['POST me/password'] = (req) =>
          FakeResponse.ok(<String, Object?>{'otherSessionsSignedOut': 0});
      backend.overrides['POST auth/otp/send'] = (req) =>
          FakeResponse.ok(<String, Object?>{'codeLength': 6, 'resendAfterSeconds': 30});
      backend.overrides['POST client/kyc/login-methods/phone'] = (req) =>
          FakeResponse.ok(<String, Object?>{'linked': true});
      return backend;
    }

    testWidgets('the KYC screen offers Login methods, and the owner sees what is linked', (tester) async {
      final app = TestPortal.signedIn(withMethods(phone: '+919876543210'));
      await app.pump(tester);
      expect(locationOf(tester), '/kyc');
      await tester.tap(find.text('Login methods'));
      await settle(tester);
      expect(find.textContaining('Email: asha@example.com'), findsOneWidget);
      expect(find.textContaining('Phone: +919876543210'), findsOneWidget);
      expect(find.text('Your company approval stays with this account.'), findsNothing);
      expect(
        find.text('Link your login methods here. Your company approval stays with this account.'),
        findsOneWidget,
      );
      expect(app.requestsTo('client/kyc/login-methods', 'GET'), isNotEmpty);
    });

    testWidgets('an owner can set a password before KYC is finished', (tester) async {
      final app = TestPortal.signedIn(withMethods());
      await app.pump(tester);
      await tester.tap(find.text('Login methods'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'New password'), 'Fresh-owner-password-2026');
      await tester.ensureVisible(find.text('Save password'));
      await tester.tap(find.text('Save password'));
      await settle(tester);
      final sent = app.requestsTo('me/password', 'POST').single.body! as Map;
      expect(sent, <String, Object?>{'newPassword': 'Fresh-owner-password-2026'});
    });

    testWidgets('changing the password asks for the current one', (tester) async {
      final app = TestPortal.signedIn(withMethods(hasPassword: true));
      await app.pump(tester);
      await tester.tap(find.text('Login methods'));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'Current password'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Current password'), 'Old-owner-password-2026');
      await tester.enterText(find.widgetWithText(TextField, 'New password'), 'New-owner-password-2026');
      await tester.ensureVisible(find.text('Save password'));
      await tester.tap(find.text('Save password'));
      await settle(tester);
      final sent = app.requestsTo('me/password', 'POST').single.body! as Map;
      expect(sent, <String, Object?>{
        'newPassword': 'New-owner-password-2026',
        'currentPassword': 'Old-owner-password-2026',
      });
    });

    testWidgets('the phone number can be changed with a code sent to the new number', (tester) async {
      final app = TestPortal.signedIn(withMethods(phone: '+919876543210'));
      await app.pump(tester);
      await tester.tap(find.text('Login methods'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Phone number'), '9123456789');
      await tester.tap(find.text('Send code'));
      await settle(tester);
      expect((app.requestsTo('auth/otp/send', 'POST').single.body! as Map)['phone'], '+919123456789');
      await tester.enterText(find.widgetWithText(TextField, 'Verification code'), '123456');
      await tester.tap(find.text('Verify and link phone'));
      await settle(tester);
      final linked = app.requestsTo('client/kyc/login-methods/phone', 'POST').single.body! as Map;
      expect(linked, <String, Object?>{'phone': '+919123456789', 'code': '123456'});
    });
  });
}
