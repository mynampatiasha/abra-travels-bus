import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientLiveTrackingScreen extends StatelessWidget {
  const ClientLiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeSos = kMockSos.where((s) {
      final status = s['status'] as String? ?? '';
      return ['NEW', 'ACKNOWLEDGED', 'RESPONDING'].contains(status);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PortalSectionTitle(
                title: 'Live buses and safety',
                subtitle: 'Where your running buses are, and any SOS from passengers.',
                breadcrumbs: ['Operations', 'Live'],
              ),
              const SizedBox(height: AbraSpacing.lg),

              // Active SOS Banners
              for (final sos in activeSos) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AbraSpacing.md),
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  decoration: BoxDecoration(
                    color: AbraColors.dangerContainer,
                    borderRadius: BorderRadius.circular(AbraRadius.md),
                    border: Border.all(color: AbraColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AbraColors.danger, size: 22),
                      const SizedBox(width: AbraSpacing.sm),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: AbraColors.danger, fontSize: 13, height: 1.4),
                            children: [
                              const TextSpan(text: 'SOS from ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: '${sos['customer']} ', style: const TextStyle(fontWeight: FontWeight.w800)),
                              TextSpan(text: 'on ${sos['trip']} (${sos['route']}): '),
                              TextSpan(text: '${sos['note']}. ', style: const TextStyle(fontStyle: FontStyle.italic)),
                              const TextSpan(text: "Abra's safety team is handling it. Status: "),
                              TextSpan(
                                text: '${sos['status']}.',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Grid: Left Map Telemetry & Right Running Now
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildMapCard(context)),
                    const SizedBox(width: AbraSpacing.xl),
                    Expanded(flex: 2, child: _buildRunningNowCard(context)),
                  ],
                )
              else ...[
                _buildMapCard(context),
                const SizedBox(height: AbraSpacing.lg),
                _buildRunningNowCard(context),
              ],

              const SizedBox(height: AbraSpacing.xl),

              // SOS History Table
              _buildSosHistoryCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_outlined, size: 20, color: AbraColors.teal),
                  const SizedBox(width: 8),
                  Text('Telemetry & GPS Map', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AbraColors.skyContainer,
                  borderRadius: BorderRadius.circular(AbraRadius.sm),
                ),
                child: const Text('Simulated Live GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AbraColors.deepBlue)),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AbraColors.navyContainer,
              borderRadius: BorderRadius.circular(AbraRadius.md),
              border: Border.all(color: AbraColors.border),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 48, color: AbraColors.textDisabled),
                  SizedBox(height: 12),
                  Text(
                    'Not connected yet - built in Phase 5',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningNowCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Running now (${kMockLive.length})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AbraColors.teal, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          if (kMockLive.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Not connected yet - built in Phase 5',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AbraColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            for (final l in kMockLive) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AbraSpacing.sm),
                padding: const EdgeInsets.all(AbraSpacing.md),
                decoration: BoxDecoration(
                  color: AbraColors.lightGray,
                  borderRadius: BorderRadius.circular(AbraRadius.md),
                  border: Border.all(color: AbraColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${l['bus']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        PortalStatusChip(status: '${l['state']}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${l['route']} · ${l['driver']}', style: const TextStyle(color: AbraColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((l['progress'] as num?) ?? 50) / 100,
                        backgroundColor: AbraColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AbraColors.teal),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${l['speed']} km/h · ${relativeTime(l['ping'] as String? ?? '')}',
                          style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                        ),
                        Tooltip(
                          message: 'Not connected yet',
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: null,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone, size: 14),
                                SizedBox(width: 4),
                                Text('Call'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildSosHistoryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SOS history', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AbraSpacing.md),
          if (kMockSos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Not connected yet - built in Phase 5', style: TextStyle(color: AbraColors.textSecondary, fontWeight: FontWeight.w600))),
            )
          else
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                  dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                  columns: const [
                    DataColumn(label: Text('When')),
                    DataColumn(label: Text('Passenger')),
                    DataColumn(label: Text('Trip')),
                    DataColumn(label: Text('Problem')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: kMockSos.map((s) {
                    return DataRow(
                      cells: [
                        DataCell(Text(relativeTime(s['at'] as String? ?? ''))),
                        DataCell(Text('${s['customer']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text('${s['trip']}')),
                        DataCell(Text('${s['note']}')),
                        DataCell(PortalStatusChip(status: '${s['status']}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
