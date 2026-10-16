import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientDriverReportsScreen extends StatefulWidget {
  const ClientDriverReportsScreen({super.key});

  @override
  State<ClientDriverReportsScreen> createState() =>
      _ClientDriverReportsScreenState();
}

class _ClientDriverReportsScreenState extends State<ClientDriverReportsScreen> {
  String _filterStatus = 'ALL';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _reports = [
    {
      'id': 'REP1001',
      'driver': 'Ramesh K',
      'bus': 'TS09 UB 4521',
      'trip': 'BLR → HYD (21:30)',
      'date': '2026-10-14 21:00',
      'odometer': '142,580 km',
      'status': 'PASSED',
      'notes': 'All systems green. Tyres and emergency doors checked.',
      'checks': {
        'Tyres & Pressure': true,
        'Service & Hand Brakes': true,
        'Headlights & Indicators': true,
        'AC & Ventilation': true,
        'Emergency Exit & Hammers': true,
        'First Aid Box Stocked': true,
      },
    },
    {
      'id': 'REP1002',
      'driver': 'Suresh M',
      'bus': 'TS09 UB 4522',
      'trip': 'BLR → MAA (22:00)',
      'date': '2026-10-14 21:15',
      'odometer': '98,340 km',
      'status': 'PASSED',
      'notes': 'Normal pre-trip check completed.',
      'checks': {
        'Tyres & Pressure': true,
        'Service & Hand Brakes': true,
        'Headlights & Indicators': true,
        'AC & Ventilation': true,
        'Emergency Exit & Hammers': true,
        'First Aid Box Stocked': true,
      },
    },
    {
      'id': 'REP1003',
      'driver': 'Anand R',
      'bus': 'KA01 CD 5678',
      'trip': 'BLR → MYS (18:00)',
      'date': '2026-10-13 17:30',
      'odometer': '210,120 km',
      'status': 'OVERDUE',
      'notes': 'Post-trip log pending from driver.',
      'checks': {
        'Tyres & Pressure': false,
        'Service & Hand Brakes': false,
        'Headlights & Indicators': false,
        'AC & Ventilation': false,
        'Emergency Exit & Hammers': false,
        'First Aid Box Stocked': false,
      },
    },
    {
      'id': 'REP1004',
      'driver': 'Priya D',
      'bus': 'TS09 UB 4521',
      'trip': 'HYD → BLR (06:00)',
      'date': '2026-10-13 05:40',
      'odometer': '141,920 km',
      'status': 'PASSED',
      'notes': 'Clean cabin, passenger seatbelts checked.',
      'checks': {
        'Tyres & Pressure': true,
        'Service & Hand Brakes': true,
        'Headlights & Indicators': true,
        'AC & Ventilation': true,
        'Emergency Exit & Hammers': true,
        'First Aid Box Stocked': true,
      },
    },
    {
      'id': 'REP1005',
      'driver': 'Ramesh K',
      'bus': 'KA05 AB 1234',
      'trip': 'BLR → HYD (21:30)',
      'date': '2026-10-12 20:50',
      'odometer': '45,210 km',
      'status': 'FLAGGED',
      'notes': 'Left front wiper blade worn; replaced before departure.',
      'checks': {
        'Tyres & Pressure': true,
        'Service & Hand Brakes': true,
        'Headlights & Indicators': true,
        'AC & Ventilation': true,
        'Emergency Exit & Hammers': true,
        'First Aid Box Stocked': true,
      },
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _reports.where((r) {
      if (_filterStatus != 'ALL' && r['status'] != _filterStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = (r['driver'] as String).toLowerCase().contains(q) ||
            (r['bus'] as String).toLowerCase().contains(q) ||
            (r['id'] as String).toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Driver reports',
            subtitle: 'Pre-trip safety inspections, duty checklists and punctuality logs',
            breadcrumbs: const ['Fleet', 'Driver reports'],
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exported 5 inspection reports to CSV')),
                  );
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New inspection'),
                style: FilledButton.styleFrom(
                  backgroundColor: AbraColors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showNewReportDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),
          // KPI cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 760;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                childAspectRatio: isWide ? 2.3 : 1.8,
                mainAxisSpacing: AbraSpacing.md,
                crossAxisSpacing: AbraSpacing.md,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  PortalKpiCard(
                    icon: Icons.checklist_rtl_outlined,
                    value: '18',
                    label: 'Reports this week',
                  ),
                  PortalKpiCard(
                    icon: Icons.verified_outlined,
                    value: '96%',
                    label: 'Checklist compliance',
                    iconColor: AbraColors.teal,
                  ),
                  PortalKpiCard(
                    icon: Icons.warning_amber_outlined,
                    value: '1',
                    label: 'Overdue reports',
                    iconColor: AbraColors.danger,
                  ),
                  PortalKpiCard(
                    icon: Icons.timer_outlined,
                    value: '94.2%',
                    label: 'On-time departure',
                    iconColor: AbraColors.orange,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Filter toolbar
          Container(
            padding: const EdgeInsets.all(AbraSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by driver name, bus number or report ID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AbraRadius.md),
                        borderSide: BorderSide(color: AbraColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                DropdownButton<String>(
                  value: _filterStatus,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                    DropdownMenuItem(value: 'PASSED', child: Text('Passed')),
                    DropdownMenuItem(value: 'OVERDUE', child: Text('Overdue')),
                    DropdownMenuItem(value: 'FLAGGED', child: Text('Flagged')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _filterStatus = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          // Table Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AbraColors.lightGray),
                columns: const [
                  DataColumn(label: Text('Report ID', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Driver', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Bus Reg', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Trip', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Submitted At', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Odometer', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
                rows: filtered.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r['id'] as String, style: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.blue))),
                      DataCell(Text(r['driver'] as String)),
                      DataCell(Text(r['bus'] as String, style: const TextStyle(fontFamily: 'monospace'))),
                      DataCell(Text(r['trip'] as String)),
                      DataCell(Text(r['date'] as String, style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary))),
                      DataCell(Text(r['odometer'] as String)),
                      DataCell(PortalStatusChip(status: r['status'] as String)),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          tooltip: 'View inspection details',
                          onPressed: () => _showReportDetails(context, r),
                        ),
                      ),
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

  void _showReportDetails(BuildContext context, Map<String, dynamic> r) {
    final checks = r['checks'] as Map<String, dynamic>? ?? {};
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.fact_check_outlined, color: AbraColors.blue),
            const SizedBox(width: 8),
            Text('Inspection: ${r['id']}'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Driver: ${r['driver']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  PortalStatusChip(status: r['status'] as String),
                ],
              ),
              Text('Bus: ${r['bus']} • Trip: ${r['trip']}', style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
              const Divider(height: 24),
              const Text('Safety Checklist Items:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              for (final entry in checks.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        entry.value == true ? Icons.check_circle : Icons.cancel,
                        color: entry.value == true ? AbraColors.teal : AbraColors.danger,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                      Text(
                        entry.value == true ? 'PASSED' : 'FLAGGED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: entry.value == true ? AbraColors.tealDark : AbraColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Text('Notes: ${r['notes']}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showNewReportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Pre-Trip Inspection Report'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: 'Ramesh K',
                decoration: const InputDecoration(labelText: 'Driver'),
                items: const [
                  DropdownMenuItem(value: 'Ramesh K', child: Text('Ramesh K')),
                  DropdownMenuItem(value: 'Suresh M', child: Text('Suresh M')),
                  DropdownMenuItem(value: 'Priya D', child: Text('Priya D')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: 'TS09 UB 4521',
                decoration: const InputDecoration(labelText: 'Bus'),
                items: const [
                  DropdownMenuItem(value: 'TS09 UB 4521', child: Text('TS09 UB 4521 (Kaveri Gold 1)')),
                  DropdownMenuItem(value: 'TS09 UB 4522', child: Text('TS09 UB 4522 (Kaveri Silver 2)')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '142,600',
                decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Inspection report recorded successfully')),
              );
            },
            child: const Text('Save report'),
          ),
        ],
      ),
    );
  }
}
