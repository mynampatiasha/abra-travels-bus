import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientCrewScreen extends StatefulWidget {
  const ClientCrewScreen({super.key});

  @override
  State<ClientCrewScreen> createState() => _ClientCrewScreenState();
}

class _ClientCrewScreenState extends State<ClientCrewScreen> {
  late List<Map<String, dynamic>> _crew;
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _crew = List.from(kMockCrew);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _crew.where((c) {
      if (_roleFilter != 'ALL' && c['role'] != _roleFilter) return false;
      if (_statusFilter != 'ALL' && c['status'] != _statusFilter) return false;
      return true;
    }).toList();

    final driverCount = _crew.where((c) => c['role'] == 'DRIVER').length;
    final activeCount = _crew.where((c) => c['status'] == 'ACTIVE').length;
    final leaveCount = _crew.where((c) => c['status'] == 'ON_LEAVE').length;
    final expCount = _crew.where((c) => (c['licExp'] as String? ?? '').isNotEmpty).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalSectionTitle(
                title: 'Drivers and crew',
                subtitle: 'Drivers sign in to the driver app with their phone number.',
                breadcrumbs: const ['Fleet', 'Drivers and crew'],
                actions: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add person'),
                    style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                    onPressed: () => _showAddCrewDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),

              // 4 Prototype KPIs (Responsive)
              if (isNarrow)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: PortalKpiCard(icon: Icons.people, value: '$driverCount', label: 'Drivers', iconColor: AbraColors.blue)),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: '$activeCount', label: 'Active', iconColor: AbraColors.teal)),
                      ],
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    Row(
                      children: [
                        Expanded(child: PortalKpiCard(icon: Icons.pause_circle_outline, value: '$leaveCount', label: 'On leave', iconColor: AbraColors.orange)),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.description_outlined, value: '$expCount', label: 'Licences expiring in 30 days', iconColor: AbraColors.danger)),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: PortalKpiCard(icon: Icons.people, value: '$driverCount', label: 'Drivers', iconColor: AbraColors.blue)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: '$activeCount', label: 'Active', iconColor: AbraColors.teal)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.pause_circle_outline, value: '$leaveCount', label: 'On leave', iconColor: AbraColors.orange)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.description_outlined, value: '$expCount', label: 'Licences expiring in 30 days', iconColor: AbraColors.danger)),
                  ],
                ),
              const SizedBox(height: AbraSpacing.xl),

              // Filter Tabs & Table
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AbraRadius.lg),
                  border: Border.all(color: AbraColors.border),
                  boxShadow: AbraShadows.soft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AbraSpacing.md),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...['ALL', 'DRIVER', 'CONDUCTOR', 'MANAGER'].map((r) =>
                            ChoiceChip(
                              label: Text(r),
                              selected: _roleFilter == r,
                              onSelected: (_) => setState(() => _roleFilter = r),
                              selectedColor: AbraColors.skyContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...['ACTIVE', 'ON_LEAVE', 'INACTIVE'].map((s) =>
                            FilterChip(
                              label: Text(s.replaceAll('_', ' ')),
                              selected: _statusFilter == s,
                              onSelected: (val) => setState(() => _statusFilter = val ? s : 'ALL'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.people_outlined, size: 48, color: AbraColors.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                _roleFilter != 'ALL' ? 'No crew matching this role' : 'No crew members yet',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _roleFilter != 'ALL' ? 'Try selecting another role filter' : 'Add drivers and conductors to assign to trips.',
                                style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                              ),
                              if (_roleFilter == 'ALL') ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add crew member'),
                                  style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                                  onPressed: () => _showAddCrewDialog(context),
                                ),
                              ],
                            ],
                          ),
                        ),
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
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Licence')),
                            DataColumn(label: Text('Trips in 7 days')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.map((c) {
                            final tripsWk = kMockTrips.where((t) => t['driver'] == c['name']).length;
                            final lic = c['licence'] as String? ?? '-';
                            final licExp = c['licExp'] as String? ?? '';

                            return DataRow(cells: [
                              DataCell(Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('${c['phone']}', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                                ],
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AbraColors.skyContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${c['role']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AbraColors.deepBlue)),
                              )),
                              DataCell(Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(lic),
                                  if (licExp.isNotEmpty)
                                    Text('till $licExp', style: const TextStyle(fontSize: 10, color: AbraColors.orangeDark)),
                                ],
                              )),
                              DataCell(Text('$tripsWk')),
                              DataCell(PortalStatusChip(status: '${c['status']}')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _showEditCrewDialog(context, c),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCrewDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final licCtrl = TextEditingController();
    final licExpCtrl = TextEditingController();
    String role = 'DRIVER';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add person'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name *')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                    DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                  ],
                  onChanged: (v) => setDlgState(() => role = v ?? role),
                ),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *', hintText: '+91 98xxx xxxxx')),
                const SizedBox(height: 12),
                TextField(controller: licCtrl, decoration: const InputDecoration(labelText: 'Driving licence number', hintText: 'Drivers only')),
                const SizedBox(height: 12),
                TextField(controller: licExpCtrl, decoration: const InputDecoration(labelText: 'Licence valid till (YYYY-MM-DD)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                  setState(() {
                    _crew.add({
                      'id': 'CRW${_crew.length + 1}',
                      'operatorId': kMockOperatorId,
                      'name': nameCtrl.text.trim(),
                      'role': role,
                      'phone': phoneCtrl.text.trim(),
                      'licence': licCtrl.text.trim(),
                      'licExp': licExpCtrl.text.trim(),
                      'status': 'ACTIVE',
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${nameCtrl.text.trim()}. Invitation sent.')),
                  );
                }
              },
              child: const Text('Add person'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCrewDialog(BuildContext context, Map<String, dynamic> c) {
    final phoneCtrl = TextEditingController(text: '${c['phone']}');
    final licCtrl = TextEditingController(text: '${c['licence'] ?? ''}');
    String status = '${c['status']}';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Edit ${c['name']}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                TextField(controller: licCtrl, decoration: const InputDecoration(labelText: 'Licence number')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'ON_LEAVE', child: Text('On leave')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                  ],
                  onChanged: (v) => setDlgState(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  c['phone'] = phoneCtrl.text.trim();
                  c['licence'] = licCtrl.text.trim();
                  c['status'] = status;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated crew member')));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
