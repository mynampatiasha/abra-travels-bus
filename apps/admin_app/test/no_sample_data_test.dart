import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin app contains no sample data outside allow list', () {
    // Files still using sample data or containing mock in name, each with the session responsible for removing it.
    const allowList = <String, String>{
      'features/operations/operations_mock_store.dart': 'Phase 2 session (phase2-supply-v2)',
      'features/operations/admin_trips_page.dart': 'Phase 2 session (phase2-supply-v2)',
      'features/operations/admin_inventory_page.dart': 'Phase 2 session (phase2-supply-v2)',
      'features/sales/sales_mock_store.dart': 'Phase 2 session (admin_trips_page.dart imports BookingRecord until connected)',
      'features/support/support_mock_store.dart': 'CONNECT session (connect-group-a) connects admin_messages_page',
      'features/support/admin_messages_page.dart': 'CONNECT session (connect-group-a)',
      'features/commission/admin_payout_page.dart': 'Session A (branch phase2-payout)',
      'features/staff/admin_staff_page.dart': 'Staff session (phase7-staff)',
    };

    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final sampleRegexes = <RegExp>[
      RegExp(r'Kaveri', caseSensitive: false),
      RegExp(r'Ramesh', caseSensitive: false),
      RegExp(r'Godavari', caseSensitive: false),
      RegExp(r'Vindhya', caseSensitive: false),
      RegExp(r'Alpha Lines', caseSensitive: false),
      RegExp(r'Geetha', caseSensitive: false),
      RegExp(r'Mohan Das', caseSensitive: false),
      RegExp(r'Sunil Varma', caseSensitive: false),
      RegExp(r'New Horizon', caseSensitive: false),
      RegExp(r'PNR\d+', caseSensitive: false),
      RegExp(r'ABR\d{3,}', caseSensitive: false),
      RegExp(r'SOS-\d+', caseSensitive: false),
      RegExp(r'Random\('),
    ];

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relPath = entity.path
            .replaceAll(r'\', '/')
            .replaceFirst(RegExp(r'^.*?lib/'), '');

        if (allowList.containsKey(relPath)) {
          continue;
        }

        if (relPath.toLowerCase().contains('mock')) {
          violations.add('Mock in filename: $relPath');
        }

        final content = entity.readAsStringSync();
        for (final regex in sampleRegexes) {
          final match = regex.firstMatch(content);
          if (match != null) {
            violations.add('Sample pattern "${regex.pattern}" matched in $relPath: "${match.group(0)}"');
            break;
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Found forbidden sample data or mock files:\n${violations.join('\n')}',
    );
  });
}
