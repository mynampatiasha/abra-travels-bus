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

  final List<Map<String, dynamic>> _reports = const [];

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
              const Tooltip(
                message: 'Not connected yet',
                child: OutlinedButton(
                  onPressed: null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 16),
                      SizedBox(width: 8),
                      Text('Export CSV'),
                    ],
                  ),
                ),
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
                    value: 'Not connected yet - built in Phase 9',
                    label: 'Reports this week',
                  ),
                  PortalKpiCard(
                    icon: Icons.verified_outlined,
                    value: 'Not connected yet - built in Phase 9',
                    label: 'Checklist compliance',
                    iconColor: AbraColors.teal,
                  ),
                  PortalKpiCard(
                    icon: Icons.warning_amber_outlined,
                    value: 'Not connected yet - built in Phase 9',
                    label: 'Overdue reports',
                    iconColor: AbraColors.danger,
                  ),
                  PortalKpiCard(
                    icon: Icons.timer_outlined,
                    value: 'Not connected yet - built in Phase 9',
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
                        borderSide: const BorderSide(color: AbraColors.border),
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
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.checklist_rtl_outlined, size: 48, color: AbraColors.textDisabled),
                          SizedBox(height: 12),
                          Text(
                            'Not connected yet - built in Phase 9',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'When connected, driver inspection reports will appear here.',
                            style: TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
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
                initialValue: 'Driver 1',
                decoration: const InputDecoration(labelText: 'Driver'),
                items: const [
                  DropdownMenuItem(value: 'Driver 1', child: Text('Driver 1')),
                  DropdownMenuItem(value: 'Driver 2', child: Text('Driver 2')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: 'Bus 1',
                decoration: const InputDecoration(labelText: 'Bus'),
                items: const [
                  DropdownMenuItem(value: 'Bus 1', child: Text('Bus 1')),
                  DropdownMenuItem(value: 'Bus 2', child: Text('Bus 2')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '0',
                decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          const Tooltip(
            message: 'Not connected yet',
            child: FilledButton(
              onPressed: null,
              child: Text('Save report'),
            ),
          ),
        ],
      ),
    );
  }
}
