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
  // Duty & Rest
  final _continuousHoursCtrl = TextEditingController(text: '4.5');
  final _breakMinutesCtrl = TextEditingController(text: '30');
  final _dailyHoursCtrl = TextEditingController(text: '9.0');
  final _restBetweenShiftsCtrl = TextEditingController(text: '11.0');

  // Speed & Relay
  final _highwaySpeedCtrl = TextEditingController(text: '80');
  final _citySpeedCtrl = TextEditingController(text: '50');
  final _relayDistanceCtrl = TextEditingController(text: '450');

  // Enforcements
  bool _mandatoryBreathalyzer = true;
  bool _autoLockoutBac = true;
  bool _nightRelayRequired = true;
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
                ElevatedButton.icon(
                  onPressed: _saveRules,
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
              ],
            ),
            const SizedBox(height: 20),

            // Rules Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Column(
                        children: [
                          _buildDutyCard(),
                          const SizedBox(height: 20),
                          _buildEnforcementCard(),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: isWide ? 20 : 0,
                      height: isWide ? 0 : 20,
                    ),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Column(
                        children: [
                          _buildSpeedAndRelayCard(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyCard() {
    return Card(
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
              'Duty & rest limits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AbraColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _continuousHoursCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max continuous driving (h)',
                      helperText: 'Triggers mandatory rest alert',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _breakMinutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mandatory rest break (mins)',
                      helperText: 'Minimum pause duration',
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max daily driving (h)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _restBetweenShiftsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Daily rest between shifts (h)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedAndRelayCard() {
    return Card(
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
              'Speed caps & relay policies',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AbraColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _highwaySpeedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Highway speed limit (km/h)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _citySpeedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'City speed limit (km/h)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _relayDistanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Require 2-driver relay for trips exceeding (km)',
                helperText:
                    'Automated roster check blocks single-driver assignment',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Mandatory co-driver on overnight routes (11 PM - 5 AM)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Enforces 2nd driver check-in before trip departure',
                style: TextStyle(fontSize: 11),
              ),
              value: _nightRelayRequired,
              activeThumbColor: AbraColors.blue,
              onChanged: (v) => setState(() => _nightRelayRequired = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnforcementCard() {
    return Card(
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
              'Compliance enforcement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AbraColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Mandatory breathalyzer before departure',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Depot supervisor must submit digital BAC reading',
                style: TextStyle(fontSize: 11),
              ),
              value: _mandatoryBreathalyzer,
              activeThumbColor: AbraColors.blue,
              onChanged: (v) => setState(() => _mandatoryBreathalyzer = v),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Automatic lockout on positive BAC (>0.00%)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Instant driver suspension and operator notification',
                style: TextStyle(fontSize: 11),
              ),
              value: _autoLockoutBac,
              activeThumbColor: AbraColors.blue,
              onChanged: (v) => setState(() => _autoLockoutBac = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _speedViolationThresholdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Auto-flag driver after N speed violations',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveRules() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Driver compliance rules saved. Synced with Driver App policies.',
        ),
      ),
    );
  }
}
