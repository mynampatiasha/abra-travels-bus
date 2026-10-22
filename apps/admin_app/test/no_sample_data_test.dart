import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin app contains no sample data outside allow list', () {
    // Files still using sample data or containing mock in name, each with the session responsible for removing it.
    const allowList = <String, String>{
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
      // Fixed numbers on menu badges, made-up activity times and demo sign-in.
      RegExp(r"'(kyc|payments|refunds|tickets|places|sos|bookings)':\s*[1-9]"),
      RegExp(r"'\d+ (min|mins|hour|hours) ago'"),
      RegExp(r'Demo Session|signInDemo|enterDemoSession'),
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
