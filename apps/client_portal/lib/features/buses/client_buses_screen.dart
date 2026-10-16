import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientBusesScreen extends StatefulWidget {
  const ClientBusesScreen({super.key});

  @override
  State<ClientBusesScreen> createState() => _ClientBusesScreenState();
}

class _ClientBusesScreenState extends State<ClientBusesScreen> {
  late List<Map<String, dynamic>> _buses;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _buses = List.from(kMockBuses);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'ALL'
        ? _buses
        : _buses.where((b) => b['status'] == _filter).toList();

    final activeCount = _buses.where((b) => b['status'] == 'ACTIVE').length;
    final pendingCount = _buses.where((b) => b['status'] == 'PENDING_APPROVAL').length;
    final maintCount = _buses.where((b) => b['status'] == 'MAINTENANCE').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalSectionTitle(
                title: 'Buses',
                subtitle: '${_buses.length} buses in your fleet',
                breadcrumbs: const ['Fleet', 'Buses'],
                actions: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add bus'),
                    style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                    onPressed: () => _showAddBusDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),
              // KPIs
              if (isNarrow)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: PortalKpiCard(icon: Icons.directions_bus, value: '${_buses.length}', label: 'Total buses')),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: '$activeCount', label: 'Active', iconColor: AbraColors.teal)),
                      ],
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    Row(
                      children: [
                        Expanded(child: PortalKpiCard(icon: Icons.hourglass_top, value: '$pendingCount', label: 'Pending approval', iconColor: AbraColors.orange)),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.build_outlined, value: '$maintCount', label: 'Maintenance', iconColor: AbraColors.danger)),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: PortalKpiCard(icon: Icons.directions_bus, value: '${_buses.length}', label: 'Total buses')),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: '$activeCount', label: 'Active', iconColor: AbraColors.teal)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.hourglass_top, value: '$pendingCount', label: 'Pending approval', iconColor: AbraColors.orange)),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.build_outlined, value: '$maintCount', label: 'Maintenance', iconColor: AbraColors.danger)),
                  ],
                ),
              const SizedBox(height: AbraSpacing.xl),
              // Filter tabs & Table
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
                        children: ['ALL', 'ACTIVE', 'PENDING_APPROVAL', 'MAINTENANCE'].map((status) {
                          final isSel = _filter == status;
                          return ChoiceChip(
                            label: Text(status.replaceAll('_', ' ')),
                            selected: isSel,
                            onSelected: (_) => setState(() => _filter = status),
                            selectedColor: AbraColors.skyContainer,
                            side: BorderSide(color: isSel ? AbraColors.blue : AbraColors.border),
                          );
                        }).toList(),
                      ),
                    ),
                const Divider(height: 1, color: AbraColors.divider),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.directions_bus_outlined, size: 48, color: AbraColors.textDisabled),
                          const SizedBox(height: 12),
                          Text(
                            _filter != 'ALL' ? 'No buses matching this filter' : 'No buses yet',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _filter != 'ALL' ? 'Try selecting another status filter' : 'Add your buses to get them approved.',
                            style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                          ),
                          if (_filter == 'ALL') ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add bus'),
                              style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                              onPressed: () => _showAddBusDialog(context),
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
                          DataColumn(label: Text('Registration')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Capacity')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Insurance Expiry')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filtered.map((bus) {
                          final status = '${bus['status']}';
                          return DataRow(
                            cells: [
                              DataCell(Text('${bus['reg']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text('${bus['name']}')),
                              DataCell(Text('${bus['type']}')),
                              DataCell(Text('${bus['seats']} seats')),
                              DataCell(PortalStatusChip(status: status)),
                              DataCell(Text('${bus['insExp']}')),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.build_circle_outlined, size: 18),
                                      tooltip: status == 'MAINTENANCE' ? 'Mark active' : 'Mark maintenance',
                                      onPressed: () {
                                        setState(() {
                                          bus['status'] = status == 'MAINTENANCE' ? 'ACTIVE' : 'MAINTENANCE';
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 18),
                                      tooltip: 'View details',
                                      onPressed: () => _showBusDetail(context, bus),
                                    ),
                                  ],
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
          ),
        ],
      ),
    );
  },
);
}

  void _showAddBusDialog(BuildContext context) {
    final regCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String type = 'AC Sleeper';
    int seats = 36;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add new bus'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: regCtrl, decoration: const InputDecoration(labelText: 'Registration Number (e.g. KA01 AB 1234)')),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Bus Name (e.g. Kaveri Express 5)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Bus Type'),
                items: kMockBusTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                onChanged: (v) => type = v ?? type,
              ),
              const SizedBox(height: 12),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seat Capacity'),
                onChanged: (v) => seats = int.tryParse(v) ?? seats,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (regCtrl.text.isNotEmpty) {
                setState(() {
                  _buses.add({
                    'id': 'BUS${_buses.length + 1}',
                    'operatorId': 'OP1',
                    'reg': regCtrl.text,
                    'name': nameCtrl.text.isEmpty ? 'Bus ${_buses.length + 1}' : nameCtrl.text,
                    'type': type,
                    'seats': seats,
                    'status': 'PENDING_APPROVAL',
                    'insExp': '2027-01-01',
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus added and sent for approval')));
              }
            },
            child: const Text('Add and submit'),
          ),
        ],
      ),
    );
  }

  void _showBusDetail(BuildContext context, Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${bus['name']} (${bus['reg']})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${bus['type']}'),
            const SizedBox(height: 6),
            Text('Capacity: ${bus['seats']} seats'),
            const SizedBox(height: 6),
            Text('Status: ${bus['status']}'),
            const SizedBox(height: 6),
            Text('Insurance Valid Until: ${bus['insExp']}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

