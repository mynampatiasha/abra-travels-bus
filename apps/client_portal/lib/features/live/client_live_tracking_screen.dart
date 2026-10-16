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
            child: Stack(
              children: [
                // Route highway visualization
                Center(
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: AbraColors.deepBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Route nodes
                Positioned(
                  left: 40,
                  top: 155,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AbraColors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Bengaluru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AbraColors.navy)),
                    ],
                  ),
                ),
                Positioned(
                  right: 40,
                  top: 155,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AbraColors.deepBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Hyderabad', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AbraColors.navy)),
                    ],
                  ),
                ),
                // Active bus pulse marker
                if (kMockLive.isNotEmpty) ...[
                  Positioned(
                    left: 200,
                    top: 130,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AbraColors.navy,
                            borderRadius: BorderRadius.circular(AbraRadius.sm),
                            boxShadow: AbraShadows.card,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_bus, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('${kMockLive.first['bus']} • ${kMockLive.first['speed']} km/h', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AbraColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AbraColors.danger.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Bottom coordinates overlay
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AbraRadius.sm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          kMockLive.isNotEmpty ? 'NH 44 Corridor · Anantapur Sector' : 'GPS Highway Telemetry',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          kMockLive.isNotEmpty ? 'Lat: 15.3173° N, Lng: 75.7139° E' : 'No active buses on road',
                          style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                child: Text('No bus is running\nBuses appear here when the driver starts the trip in the driver app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
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
                        OutlinedButton.icon(
                          icon: const Icon(Icons.phone, size: 14),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Calling driver ${l['driver']}...')),
                            );
                          },
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
              child: Center(child: Text('No SOS on your buses', style: TextStyle(color: AbraColors.textSecondary))),
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
