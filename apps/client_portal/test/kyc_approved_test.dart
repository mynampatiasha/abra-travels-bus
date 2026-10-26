import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

void main() {
  group('approved KYC page', () {
    testWidgets('shows what was submitted, when, and each file to view or save', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = FakeBackend(Persona.owner);
      backend.overrides['GET onboarding/submissions/company-file'] = (req) => FakeResponse.ok(<String, Object?>{
        'id': 'company-file',
        'status': 'APPROVED',
        'submitCount': 2,
        'submittedAt': '2026-10-23T06:23:00.000Z',
        'decidedAt': '2026-10-23T06:24:00.000Z',
        'documents': <Object?>[
          <String, Object?>{
            'documentTypeId': 'gst',
            'key': 'GST_CERT',
            'name': 'GST certificate',
            'status': 'APPROVED',
            'rejectionReason': null,
            'expiryDate': '2027-03-31',
            'reviewedAt': '2026-10-23T06:24:00.000Z',
            'files': <Object?>[
              <String, Object?>{
                'id': 'f1',
                'originalName': 'gst.pdf',
                'mimeType': 'application/pdf',
                'sizeBytes': 2048,
                'uploadedAt': '2026-10-23T06:20:00.000Z',
              },
            ],
          },
        ],
      });

      await TestPortal.signedIn(backend).pump(tester);
      await open(tester, '/kyc-verification');

      expect(find.text('Your company is approved'), findsOneWidget);
      expect(find.text('Submitted documents'), findsOneWidget);
      expect(find.text('GST certificate'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      // India time: 06:23 UTC is 11:53 am
      expect(find.textContaining('23 Oct 2026, 11:53 am'), findsWidgets);
      expect(find.textContaining('23 Oct 2026, 11:54 am'), findsWidgets);
      expect(find.text('Sent for review: 2 times'), findsOneWidget);
      expect(find.textContaining('gst.pdf'), findsOneWidget);
      expect(find.textContaining('Valid till 2027-03-31'), findsOneWidget);
      expect(find.byTooltip('View'), findsOneWidget);
      expect(find.byTooltip('Download'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });
  });
}
