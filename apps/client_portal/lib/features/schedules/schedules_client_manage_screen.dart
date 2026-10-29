import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';
import '../routes/routes_client_manage_screen.dart';

// ===== 1. MODELS =====

class ClientScheduleItem {
  ClientScheduleItem({
    required this.id,
    required this.operatorId,
    required this.routeId,
    required this.route,
    required this.busId,
    required this.bus,
    required this.time,
    required this.days,
    required this.from,
    required this.to,
    required this.status,
    required this.fare,
  });

  final String id;
  final String operatorId;
  final String routeId;
  final String route;
  final String busId;
  final String bus;
  final String time;
  final List<String> days;
  final String from;
  final String to;
  final String status;
  final int fare;

  factory ClientScheduleItem.fromJson(Map<String, dynamic> json) {
    return ClientScheduleItem(
      id: json['id'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      route: json['route'] as String? ?? '',
      busId: json['busId'] as String? ?? '',
      bus: json['bus'] as String? ?? '',
      time: json['time'] as String? ?? '',
      days: (json['days'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      fare: (json['fare'] as num?)?.toInt() ?? 0,
    );
  }
}

class BusOption {
  BusOption({required this.id, required this.label});
  final String id;
  final String label;
}

// ===== 2. PROVIDERS =====

final clientSchedulesProvider = FutureProvider.autoDispose
    .family<List<ClientScheduleItem>, (String, String)>((ref, args) async {
  final (statusFilter, search) = args;
  try {
    final client = ref.watch(appDependenciesProvider).apiClient;
    final query = <String, dynamic>{'pageSize': 100};
    if (statusFilter != 'ALL') {
      query['status'] = statusFilter;
    }
    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    final response = await client.get('client/schedules', query: query);
    final List<ClientScheduleItem> items = [];
    if (response.data is List) {
      for (final raw in response.data as List) {
        if (raw is Map) {
          items.add(ClientScheduleItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    } else if (response.data is Map && (response.data as Map)['items'] is List) {
      for (final raw in (response.data as Map)['items'] as List) {
        if (raw is Map) {
          items.add(ClientScheduleItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return items;
  } catch (_) {
    return <ClientScheduleItem>[];
  }
});

// ===== 3. SCREEN =====

class ClientSchedulesScreen extends ConsumerStatefulWidget {
  const ClientSchedulesScreen({super.key});

  @override
  ConsumerState<ClientSchedulesScreen> createState() => _ClientSchedulesScreenState();
}

class _ClientSchedulesScreenState extends ConsumerState<ClientSchedulesScreen> {
  String _statusFilter = 'ALL';
  final _searchCtrl = TextEditingController();
  final Set<String> _generatingScheduleIds = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(clientSchedulesProvider);
  }

  void _exportCsv(List<ClientScheduleItem> schedules) {
    final buffer = StringBuffer();
    buffer.writeln('Route,Bus,Departure Time,Days,Valid From,Valid Till,Status');
    for (final sc in schedules) {
      final route = sc.route.replaceAll('"', '""');
      final bus = sc.bus.replaceAll('"', '""');
      final days = sc.days.join(';').replaceAll('"', '""');
      buffer.writeln('"$route","$bus","${sc.time}","$days","${sc.from}","${sc.to}","${sc.status}"');
    }
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    downloadTextFile('schedules_$stamp.csv', buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The file is ready.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 768;
    final search = _searchCtrl.text.trim();
    final asyncSchedules = ref.watch(clientSchedulesProvider((_statusFilter, search)));

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
                onPressed: () => unawaited(_showAddScheduleDialog(context)),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Filter toolbar
          Container(
            padding: const EdgeInsets.all(AbraSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isNarrow ? double.infinity : 220,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search route or bus',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: isNarrow ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                    ],
                    onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear'),
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _statusFilter = 'ALL';
                    });
                  },
                ),
                asyncSchedules.maybeWhen(
                  data: (schedules) => OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    onPressed: () => _exportCsv(schedules),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: asyncSchedules.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AbraColors.danger),
                      const SizedBox(height: 12),
                      Text('Failed to load schedules: $err', style: const TextStyle(color: AbraColors.danger)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
              data: (schedules) => schedules.isEmpty
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
                              onPressed: () => unawaited(_showAddScheduleDialog(context)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
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
                          rows: schedules.map((sc) {
                            final daysList = sc.days.isNotEmpty ? sc.days : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            final daysStr = daysList.length >= 7 ? 'Every day' : daysList.join(', ');
                            final isGenerating = _generatingScheduleIds.contains(sc.id);

                            return DataRow(cells: [
                              DataCell(Text(sc.route, style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text(sc.bus)),
                              DataCell(Text(sc.time, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(daysStr)),
                              DataCell(Text(sc.to)),
                              DataCell(PortalStatusChip(status: sc.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: isGenerating
                                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.calendar_month, size: 14),
                                      label: Text(isGenerating ? 'Generating...' : 'Create trips'),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                      onPressed: isGenerating ? null : () => _generateTrips(context, sc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AbraColors.danger),
                                      tooltip: 'Delete schedule',
                                      onPressed: () => _confirmDeleteSchedule(context, sc),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _generateTrips(BuildContext context, ClientScheduleItem sc) async {
    setState(() => _generatingScheduleIds.add(sc.id));
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      final res = await client.post('client/schedules/${sc.id}/generate-trips');
      String msg = 'Trips generation complete';
      if (res.data is Map && (res.data as Map)['message'] != null) {
        msg = (res.data as Map)['message'].toString();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AbraColors.tealDark,
          ),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate trips: $err'),
            backgroundColor: AbraColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generatingScheduleIds.remove(sc.id));
      }
    }
  }

  Future<void> _showAddScheduleDialog(BuildContext context) async {
    // 1. Fetch available routes
    final routesAsync = await ref.read(clientRoutesProvider(('ALL', '')).future);
    final availableRoutes = routesAsync.isNotEmpty ? routesAsync : <ClientRouteItem>[];

    // 2. Fetch active buses
    final client = ref.read(appDependenciesProvider).apiClient;
    final List<BusOption> busOptions = <BusOption>[];
    try {
      final busesRes = await client.get('client/buses', query: {'status': 'ACTIVE', 'pageSize': 100});
      final rawList = busesRes.data is List ? (busesRes.data as List<dynamic>) : const <dynamic>[];
      for (final b in rawList) {
        if (b is Map) {
          final id = b['id']?.toString() ?? '';
          final reg = b['registrationNumber']?.toString() ?? b['reg']?.toString() ?? 'Bus';
          final type = b['busType']?.toString() ?? b['type']?.toString() ?? '';
          busOptions.add(BusOption(id: id, label: '$reg • $type'));
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    String? selectedRouteId = availableRoutes.isNotEmpty ? availableRoutes.first.id : null;
    String? selectedBusId = busOptions.isNotEmpty ? busOptions.first.id : null;

    final timeCtrl = TextEditingController();
    final today = DateTime.now();
    final fromDateStr = today.toIso8601String().split('T').first;
    final toDateStr = today.add(const Duration(days: 60)).toIso8601String().split('T').first;
    final fromCtrl = TextEditingController(text: fromDateStr);
    final toCtrl = TextEditingController(text: toDateStr);
    final days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    await showDialog<void>(
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
                  if (availableRoutes.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedRouteId,
                      decoration: const InputDecoration(labelText: 'Route *'),
                      items: availableRoutes.map((r) {
                        return DropdownMenuItem(value: r.id, child: Text(r.name));
                      }).toList(),
                      onChanged: (v) => setDState(() => selectedRouteId = v),
                    )
                  else
                    const TextField(
                      decoration: InputDecoration(labelText: 'Route', hintText: 'Create a route first'),
                      enabled: false,
                    ),
                  const SizedBox(height: 12),
                  if (busOptions.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedBusId,
                      decoration: const InputDecoration(labelText: 'Bus (Active only) *'),
                      items: busOptions.map((b) {
                        return DropdownMenuItem(value: b.id, child: Text(b.label));
                      }).toList(),
                      onChanged: (v) => setDState(() => selectedBusId = v),
                    )
                  else
                    const TextField(
                      decoration: InputDecoration(labelText: 'Bus', hintText: 'Add an active bus first'),
                      enabled: false,
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Departure time (e.g. 21:30) *')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'From (YYYY-MM-DD) *'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'Till (YYYY-MM-DD) *'))),
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
              onPressed: () async {
                if (selectedRouteId == null || selectedBusId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Route and Bus are required'), backgroundColor: AbraColors.danger),
                  );
                  return;
                }
                if (days.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pick at least one day'), backgroundColor: AbraColors.danger),
                  );
                  return;
                }
                if (toCtrl.text.compareTo(fromCtrl.text) < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Till date must be after From date'), backgroundColor: AbraColors.danger),
                  );
                  return;
                }

                try {
                  final cli = ref.read(appDependenciesProvider).apiClient;
                  await cli.post('client/schedules', body: {
                    'routeId': selectedRouteId,
                    'busId': selectedBusId,
                    'time': timeCtrl.text.trim(),
                    'days': days.toList(),
                    'from': fromCtrl.text.trim(),
                    'to': toCtrl.text.trim(),
                    'status': 'ACTIVE',
                  });

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Schedule created successfully')),
                    );
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save schedule: $err'), backgroundColor: AbraColors.danger),
                    );
                  }
                }
              },
              child: const Text('Save schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSchedule(BuildContext context, ClientScheduleItem sc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete schedule for ${sc.route}?'),
        content: Text('Are you sure you want to delete the ${sc.time} schedule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () async {
              try {
                final client = ref.read(appDependenciesProvider).apiClient;
                await client.delete('client/schedules/${sc.id}');
                if (context.mounted) {
                  Navigator.pop(ctx);
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted schedule for ${sc.route}')),
                  );
                }
              } catch (err) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete schedule: $err'), backgroundColor: AbraColors.danger),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
