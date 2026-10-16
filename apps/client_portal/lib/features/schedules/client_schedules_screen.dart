import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientSchedulesScreen extends StatefulWidget {
  const ClientSchedulesScreen({super.key});

  @override
  State<ClientSchedulesScreen> createState() => _ClientSchedulesScreenState();
}

class _ClientSchedulesScreenState extends State<ClientSchedulesScreen> {
  late List<Map<String, dynamic>> _schedules;

  @override
  void initState() {
    super.initState();
    _schedules = List.from(kMockSchedules);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Schedules',
            subtitle: 'Repeat a trip on chosen days, then create the trips in one go.',
            breadcrumbs: const ['Sales setup', 'Schedules'],
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New schedule'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: () => _showAddScheduleDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: _schedules.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 48, color: AbraColors.textDisabled),
                          const SizedBox(height: 12),
                          const Text('No schedules yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Create a schedule to repeat trips automatically.', style: TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New schedule'),
                            style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                            onPressed: () => _showAddScheduleDialog(context),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                      dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                      columns: const [
                        DataColumn(label: Text('Route')),
                        DataColumn(label: Text('Bus')),
                        DataColumn(label: Text('Departs')),
                        DataColumn(label: Text('Days')),
                        DataColumn(label: Text('Valid till')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _schedules.map((sc) {
                        final daysList = (sc['days'] as List?)?.map((e) => '$e').toList() ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final daysStr = daysList.length >= 7 ? 'Every day' : daysList.join(', ');

                        return DataRow(cells: [
                          DataCell(Text('${sc['route']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text('${sc['bus']}')),
                          DataCell(Text('${sc['time']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(daysStr)),
                          DataCell(Text('${sc['to']}')),
                          DataCell(PortalStatusChip(status: '${sc['status']}')),
                          DataCell(
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month, size: 14),
                              label: const Text('Create trips'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Created 14 trips for ${sc['route']} in the Trips section')),
                                );
                              },
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
  }

  void _showAddScheduleDialog(BuildContext context) {
    String route = kMockRoutes.isNotEmpty ? kMockRoutes.first['name'] as String : 'General Route';
    String bus = kMockBuses.isNotEmpty ? kMockBuses.first['reg'] as String : 'General Fleet';
    final timeCtrl = TextEditingController(text: '21:30');
    final fromCtrl = TextEditingController(text: '2026-10-15');
    final toCtrl = TextEditingController(text: '2026-12-15');
    final days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('New schedule'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: route,
                    decoration: const InputDecoration(labelText: 'Route'),
                    items: (kMockRoutes.isNotEmpty
                        ? kMockRoutes.map((r) => DropdownMenuItem(value: '${r['name']}', child: Text('${r['name']}'))).toList()
                        : [const DropdownMenuItem(value: 'General Route', child: Text('General Route'))]),
                    onChanged: (v) => setDState(() => route = v ?? route),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: bus,
                    decoration: const InputDecoration(labelText: 'Bus'),
                    items: (kMockBuses.isNotEmpty
                        ? kMockBuses.map((b) => DropdownMenuItem(value: '${b['reg']}', child: Text('${b['reg']} • ${b['type']}'))).toList()
                        : [const DropdownMenuItem(value: 'General Fleet', child: Text('General Fleet'))]),
                    onChanged: (v) => setDState(() => bus = v ?? bus),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Departure time (e.g. 21:30)')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'From (YYYY-MM-DD)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'Till (YYYY-MM-DD)'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Days of the week', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) {
                      final sel = days.contains(d);
                      return FilterChip(
                        label: Text(d),
                        selected: sel,
                        selectedColor: AbraColors.skyContainer,
                        onSelected: (val) {
                          setDState(() {
                            if (val) {
                              days.add(d);
                            } else if (days.length > 1) {
                              days.remove(d);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _schedules.add({
                    'id': 'SC${_schedules.length + 1}',
                    'operatorId': 'OP1',
                    'routeId': 'RT1',
                    'route': route,
                    'bus': bus,
                    'time': timeCtrl.text,
                    'days': List.from(days),
                    'from': fromCtrl.text,
                    'to': toCtrl.text,
                    'status': 'ACTIVE',
                    'fare': 95000,
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule saved')));
              },
              child: const Text('Save schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
