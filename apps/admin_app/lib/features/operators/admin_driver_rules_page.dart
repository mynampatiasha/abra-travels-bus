import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class AdminDriverRulesPage extends ConsumerStatefulWidget {
  const AdminDriverRulesPage({super.key});

  @override
  ConsumerState<AdminDriverRulesPage> createState() =>
      _AdminDriverRulesPageState();
}

class _AdminDriverRulesPageState extends ConsumerState<AdminDriverRulesPage> {
  final _continuousHoursCtrl = TextEditingController(text: '4.5');
  final _breakMinutesCtrl = TextEditingController(text: '30');
  final _dailyHoursCtrl = TextEditingController(text: '9.0');
  final _restBetweenShiftsCtrl = TextEditingController(text: '11.0');

  final _highwaySpeedCtrl = TextEditingController(text: '80');
  final _citySpeedCtrl = TextEditingController(text: '50');
  final _relayDistanceCtrl = TextEditingController(text: '450');

  final _speedViolationThresholdCtrl = TextEditingController(text: '3');

  @override
  void dispose() {
    _continuousHoursCtrl.dispose();
    _breakMinutesCtrl.dispose();
    _dailyHoursCtrl.dispose();
    _restBetweenShiftsCtrl.dispose();
    _highwaySpeedCtrl.dispose();
    _citySpeedCtrl.dispose();
    _relayDistanceCtrl.dispose();
    _speedViolationThresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver rules & policies',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rest hours, driving speed limits and compliance checks.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Save rules'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AbraColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AbraSpacing.md),
              decoration: BoxDecoration(
                color: AbraColors.skyContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Not connected yet - built in Phase 9',
                style: TextStyle(
                  color: AbraColors.deepBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Form cards disabled
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duty & Rest Hours Policy',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _continuousHoursCtrl,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Max continuous driving (hours)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _breakMinutesCtrl,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Mandatory break (minutes)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _dailyHoursCtrl,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Max daily duty (hours)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _restBetweenShiftsCtrl,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Rest between shifts (hours)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
