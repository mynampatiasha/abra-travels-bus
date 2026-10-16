import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/widgets/portal_info_banner.dart';
import '../../core/widgets/portal_section_title.dart';

class ClientDriverRulesScreen extends StatefulWidget {
  const ClientDriverRulesScreen({super.key});

  @override
  State<ClientDriverRulesScreen> createState() =>
      _ClientDriverRulesScreenState();
}

class _ClientDriverRulesScreenState extends State<ClientDriverRulesScreen> {
  double _maxContinuousDriveHours = 4.0;
  int _mandatoryRestMinutes = 30;
  double _maxDailyDrivingHours = 8.0;
  double _minRestBetweenShifts = 11.0;

  bool _requirePreTripChecklist = true;
  bool _requirePostTripLog = true;
  bool _enforceSobrietyCheck = true;
  bool _speedAlertThreshold = true;
  int _maxSpeedLimit = 80;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Driver rules',
            subtitle: 'Safety shift limits, mandatory rest breaks and compliance rules',
            breadcrumbs: const ['Fleet', 'Driver rules'],
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save safety rules'),
                style: FilledButton.styleFrom(
                  backgroundColor: AbraColors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Driver safety rules updated successfully'),
                      backgroundColor: AbraColors.tealDark,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.lg),
          const PortalInfoBanner(
            message:
                'These safety limits prevent driver fatigue and are strictly enforced when assigning drivers to schedules and live trips.',
            tone: PortalBannerTone.info,
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Shift & Duty Limits Card
          _buildCard(
            title: 'Driving Hour Limits',
            subtitle: 'Configure maximum permissible driving times before mandatory rest breaks',
            child: Column(
              children: [
                _buildSliderTile(
                  title: 'Maximum continuous driving time',
                  value: _maxContinuousDriveHours,
                  min: 2.0,
                  max: 6.0,
                  divisions: 8,
                  suffix: '${_maxContinuousDriveHours.toStringAsFixed(1)} hours',
                  onChanged: (v) => setState(() => _maxContinuousDriveHours = v),
                ),
                const Divider(),
                _buildSliderTile(
                  title: 'Mandatory rest break duration',
                  value: _mandatoryRestMinutes.toDouble(),
                  min: 15.0,
                  max: 60.0,
                  divisions: 9,
                  suffix: '$_mandatoryRestMinutes minutes',
                  onChanged: (v) => setState(() => _mandatoryRestMinutes = v.round()),
                ),
                const Divider(),
                _buildSliderTile(
                  title: 'Maximum driving time in any 24-hour cycle',
                  value: _maxDailyDrivingHours,
                  min: 6.0,
                  max: 12.0,
                  divisions: 12,
                  suffix: '${_maxDailyDrivingHours.toStringAsFixed(1)} hours',
                  onChanged: (v) => setState(() => _maxDailyDrivingHours = v),
                ),
                const Divider(),
                _buildSliderTile(
                  title: 'Minimum rest period between two scheduled trips',
                  value: _minRestBetweenShifts,
                  min: 8.0,
                  max: 16.0,
                  divisions: 8,
                  suffix: '${_minRestBetweenShifts.toStringAsFixed(1)} hours',
                  onChanged: (v) => setState(() => _minRestBetweenShifts = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          // Checklist & Safety Checks Card
          _buildCard(
            title: 'Compliance & Safety Checklists',
            subtitle: 'Mandatory checks required before and during trips',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mandatory pre-trip vehicle inspection checklist', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Driver must tick off tyres, brakes, wipers and emergency door before departing.', style: TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
                  value: _requirePreTripChecklist,
                  onChanged: (v) => setState(() => _requirePreTripChecklist = v),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Mandatory post-trip odometer and fuel log', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Driver must log ending odometer reading upon arriving at terminus.', style: TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
                  value: _requirePostTripLog,
                  onChanged: (v) => setState(() => _requirePostTripLog = v),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Mandatory breathalyzer & sobriety verification', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Record zero-alcohol test at boarding depot before handover.', style: TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
                  value: _enforceSobrietyCheck,
                  onChanged: (v) => setState(() => _enforceSobrietyCheck = v),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Fleet overspeed telemetry alert', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Flag trip in Live Tracking if vehicle exceeds $_maxSpeedLimit km/h for > 60 seconds.', style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
                  value: _speedAlertThreshold,
                  onChanged: (v) => setState(() => _speedAlertThreshold = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AbraSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AbraSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: AbraColors.blue,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              suffix,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue),
            ),
          ),
        ],
      ),
    );
  }
}
