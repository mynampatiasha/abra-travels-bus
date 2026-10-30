import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';
import '../../routing/portal_routes.dart';

// ===== 1. MODELS =====

class ClientRouteStopItem {
  ClientRouteStopItem({
    required this.placeId,
    required this.name,
    required this.city,
    required this.offset,
    required this.type,
  });

  final String placeId;
  final String name;
  final String city;
  final int offset;
  final String type;

  factory ClientRouteStopItem.fromJson(Map<String, dynamic> json) {
    return ClientRouteStopItem(
      placeId: json['placeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'BOTH',
    );
  }

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'name': name,
    'city': city,
    'offset': offset,
    'type': type,
  };
}

class ClientRouteItem {
  ClientRouteItem({
    required this.id,
    this.operatorId,
    required this.name,
    required this.from,
    required this.to,
    required this.km,
    required this.hours,
    required this.status,
    required this.stops,
    this.tripsCount = 0,
    this.faresCount = 0,
    this.schedulesCount = 0,
  });

  final String id;
  final String? operatorId;
  final String name;
  final String from;
  final String to;
  final int km;
  final int hours;
  final String status;
  final List<ClientRouteStopItem> stops;
  final int tripsCount;
  final int faresCount;
  final int schedulesCount;

  bool get isShared => operatorId == null || operatorId!.isEmpty;

  factory ClientRouteItem.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List<dynamic>? ?? [];
    return ClientRouteItem(
      id: json['id'] as String? ?? '',
      operatorId: json['operatorId'] as String?,
      name: json['name'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      km: (json['km'] as num?)?.toInt() ?? 0,
      hours: (json['hours'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'ACTIVE',
      stops: rawStops
          .map((s) => ClientRouteStopItem.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      tripsCount: (json['tripsCount'] as num?)?.toInt() ?? 0,
      faresCount: (json['faresCount'] as num?)?.toInt() ?? 0,
      schedulesCount: (json['schedulesCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ===== 2. PROVIDERS =====

final clientRoutesProvider = FutureProvider.autoDispose
    .family<List<ClientRouteItem>, (String, String)>((ref, args) async {
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
    final response = await client.get('client/routes', query: query);
    final List<ClientRouteItem> items = [];
    if (response.data is List) {
      for (final raw in response.data as List) {
        if (raw is Map) {
          items.add(ClientRouteItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    } else if (response.data is Map && (response.data as Map)['items'] is List) {
      for (final raw in (response.data as Map)['items'] as List) {
        if (raw is Map) {
          items.add(ClientRouteItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return items;
  } catch (_) {
    return <ClientRouteItem>[];
  }
});

// ===== 3. SCREEN =====

class ClientRoutesScreen extends ConsumerStatefulWidget {
  const ClientRoutesScreen({super.key});

  @override
  ConsumerState<ClientRoutesScreen> createState() => _ClientRoutesScreenState();
}

class _ClientRoutesScreenState extends ConsumerState<ClientRoutesScreen> {
  String? _selectedRouteId;
  String _statusFilter = 'ALL';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(clientRoutesProvider);
  }

  void _exportCsv(List<ClientRouteItem> routes) {
    final buffer = StringBuffer();
    buffer.writeln('Route,From,To,Distance (km),Duration (h),Stops,Your Trips,Status,Ownership');
    for (final r in routes) {
      final name = r.name.replaceAll('"', '""');
      final from = r.from.replaceAll('"', '""');
      final to = r.to.replaceAll('"', '""');
      final owner = r.isShared ? 'Shared Abra' : 'Operator';
      buffer.writeln('"$name","$from","$to",${r.km},${r.hours},${r.stops.length},${r.tripsCount},"${r.status}","$owner"');
    }
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    downloadTextFile('routes_$stamp.csv', buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The file is ready.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchCtrl.text.trim();
    final asyncRoutes = ref.watch(clientRoutesProvider((_statusFilter, search)));

    return asyncRoutes.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AbraColors.danger),
              const SizedBox(height: 16),
              Text('Failed to load routes: $err', style: const TextStyle(color: AbraColors.danger)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (routes) {
        if (_selectedRouteId != null) {
          final selRoute = routes.cast<ClientRouteItem?>().firstWhere(
                (r) => r?.id == _selectedRouteId,
                orElse: () => null,
              );
          if (selRoute != null) {
            return _buildRouteDetailView(context, selRoute);
          }
        }
        return _buildRoutesTableView(context, routes);
      },
    );
  }

  Widget _buildRoutesTableView(BuildContext context, List<ClientRouteItem> routes) {
    final isNarrow = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Routes and stops',
            subtitle: "Boarding and dropping points come from Abra's list of places. Need a new one? Request it.",
            breadcrumbs: const ['Network', 'Routes'],
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.pin_drop_outlined, size: 16),
                label: const Text('Request a place'),
                onPressed: () => context.go(PortalRoutes.places),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New route'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: () => _openRouteFormDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Filter Toolbar
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
                      hintText: 'Search route or city',
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: () => _exportCsv(routes),
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
            child: routes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.route_outlined, size: 48, color: AbraColors.textDisabled),
                          const SizedBox(height: 12),
                          const Text('No routes yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Ask Abra to assign routes, or create trips on existing routes.', style: TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add route'),
                            style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                            onPressed: () => _openRouteFormDialog(context),
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
                        showCheckboxColumn: false,
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                        dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                        columns: const [
                          DataColumn(label: Text('Route')),
                          DataColumn(label: Text('Distance')),
                          DataColumn(label: Text('Duration')),
                          DataColumn(label: Text('Stops')),
                          DataColumn(label: Text('Your trips')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: routes.map((r) {
                          return DataRow(
                            onSelectChanged: (_) {
                              setState(() => _selectedRouteId = r.id);
                            },
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (r.isShared) ...[
                                      const SizedBox(width: 6),
                                      const Text('(Abra route)', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                                    ],
                                  ],
                                ),
                              ),
                              DataCell(Text('${r.km} km')),
                              DataCell(Text('${r.hours} h')),
                              DataCell(Text('${r.stops.length}')),
                              DataCell(Text('${r.tripsCount}')),
                              DataCell(PortalStatusChip(status: r.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => setState(() => _selectedRouteId = r.id),
                                      child: const Text('View stops', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                    if (!r.isShared)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AbraColors.danger),
                                        tooltip: 'Delete route',
                                        onPressed: () => _confirmDeleteRoute(context, r),
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
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetailView(BuildContext context, ClientRouteItem r) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalSectionTitle(
                title: r.name,
                subtitle: '${r.km} km · about ${r.hours} h',
                breadcrumbs: ['Network', 'Routes', r.name],
                actions: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('All routes'),
                    onPressed: () => setState(() => _selectedRouteId = null),
                  ),
                  if (!r.isShared) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit route'),
                      style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                      onPressed: () => _openRouteFormDialog(context, existingRoute: r),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16, color: AbraColors.danger),
                      label: const Text('Delete route', style: TextStyle(color: AbraColors.danger)),
                      onPressed: () => _confirmDeleteRoute(context, r),
                    ),
                  ] else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy as my route'),
                      onPressed: () => _copyRoute(context, r),
                    ),
                ],
              ),
              const SizedBox(height: AbraSpacing.md),
              if (r.isShared)
                Container(
                  margin: const EdgeInsets.only(bottom: AbraSpacing.lg),
                  padding: const EdgeInsets.all(AbraSpacing.sm),
                  decoration: BoxDecoration(
                    color: AbraColors.lightBlue,
                    borderRadius: BorderRadius.circular(AbraRadius.md),
                    border: Border.all(color: AbraColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AbraColors.deepBlue),
                      SizedBox(width: 8),
                      Text('Shared Abra route. Copy it to change the stops.', style: TextStyle(fontSize: 12, color: AbraColors.deepBlue)),
                    ],
                  ),
                ),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildStopsTimelineCard(context, r.stops)),
                    const SizedBox(width: AbraSpacing.xl),
                    Expanded(flex: 2, child: _buildUsedByAndMapCard(context, r.tripsCount, r.faresCount, r.schedulesCount, r.stops)),
                  ],
                )
              else ...[
                _buildStopsTimelineCard(context, r.stops),
                const SizedBox(height: AbraSpacing.lg),
                _buildUsedByAndMapCard(context, r.tripsCount, r.faresCount, r.schedulesCount, r.stops),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopsTimelineCard(BuildContext context, List<ClientRouteStopItem> stops) {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Stops in order (${stops.length})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AbraColors.lightGray, borderRadius: BorderRadius.circular(AbraRadius.sm)),
                child: const Text('Chronological sequence', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.lg),
          if (stops.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No stops configured for this route.', style: TextStyle(color: AbraColors.textSecondary)),
            )
          else
            for (var i = 0; i < stops.length; i++) ...[
              _buildStopTimelineItem(stops[i], isFirst: i == 0, isLast: i == stops.length - 1),
            ],
        ],
      ),
    );
  }

  Widget _buildStopTimelineItem(ClientRouteStopItem stop, {required bool isFirst, required bool isLast}) {
    final (chipBg, chipFg, chipLabel) = switch (stop.type) {
      'DROPPING' => (AbraColors.dangerContainer, AbraColors.danger, 'Dropping'),
      'BOTH' => (AbraColors.orangeContainer, AbraColors.orangeDark, 'Both'),
      _ => (AbraColors.tealContainer, AbraColors.tealDark, 'Boarding'),
    };

    final offset = stop.offset;
    final timeStr = offset == 0
        ? 'Start (0 min)'
        : '+${offset ~/ 60}h ${offset % 60}m';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: chipFg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: AbraColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(stop.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(chipLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chipFg)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${stop.city} · $timeStr', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsedByAndMapCard(BuildContext context, int trips, int fares, int scheds, List<ClientRouteStopItem> stops) {
    return Container(
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
          Text('Used by', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AbraSpacing.md),
          _kvRow('Your trips', '$trips'),
          _kvRow('Your fares', '$fares'),
          _kvRow('Your schedules', '$scheds'),
          const Divider(height: 24),
          Text('Route map view', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AbraSpacing.md),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AbraColors.navyContainer,
              borderRadius: BorderRadius.circular(AbraRadius.md),
              border: Border.all(color: AbraColors.border),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AbraColors.deepBlue.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                for (var i = 0; i < stops.length; i++)
                  Positioned(
                    left: stops.length <= 1
                        ? 100
                        : 20 + (i * 240 / (stops.length - 1)).clamp(0, 240),
                    top: i.isEven ? 70 : 100,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: stops[i].type == 'DROPPING' ? AbraColors.danger : AbraColors.teal,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 70,
                          child: Text(
                            stops[i].city,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AbraColors.navy),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  /// The active cities and the approved boarding and dropping places, from the server.
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _loadCitiesAndPlaces() async {
    final client = ref.read(appDependenciesProvider).apiClient;
    final citiesResponse = await client.get('client/place-requests/cities');
    final cities = <Map<String, dynamic>>[
      for (final raw in (citiesResponse.data is List ? citiesResponse.data as List : const <Object?>[]))
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    final cityNames = {for (final c in cities) c['id'] as String: c['name'] as String};
    final placesResponse = await client.get('catalogue/locations', query: <String, dynamic>{'active': true, 'pageSize': 100});
    final rawPlaces = placesResponse.data is Map && (placesResponse.data as Map)['items'] is List
        ? (placesResponse.data as Map)['items'] as List
        : placesResponse.data is List
            ? placesResponse.data as List
            : const <Object?>[];
    final places = <Map<String, dynamic>>[
      for (final raw in rawPlaces)
        if (raw is Map)
          {
            'id': raw['id'] as String,
            'name': raw['name'] as String,
            'city': cityNames[raw['cityId']] ?? '',
          },
    ];
    return (cities, places);
  }

  Future<void> _openRouteFormDialog(BuildContext context, {ClientRouteItem? existingRoute}) async {
    final isEdit = existingRoute != null;
    final List<Map<String, dynamic>> cities;
    final List<Map<String, dynamic>> places;
    try {
      (cities, places) = await _loadCitiesAndPlaces();
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load cities and places: $err'), backgroundColor: AbraColors.danger),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (cities.length < 2 || places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A route needs at least 2 active cities and approved places. Ask Abra to add them, or use "Request a place".'),
          backgroundColor: AbraColors.danger,
        ),
      );
      return;
    }
    final cityNames = <String>[for (final c in cities) c['name'] as String];
    if (isEdit) {
      for (final name in <String>[existingRoute.from, existingRoute.to]) {
        if (!cityNames.contains(name)) cityNames.add(name);
      }
    }
    final kmCtrl = TextEditingController(text: isEdit ? '${existingRoute.km}' : '');
    final hrsCtrl = TextEditingController(text: isEdit ? '${existingRoute.hours}' : '');
    String fromCity = isEdit ? existingRoute.from : cityNames[0];
    String toCity = isEdit ? existingRoute.to : cityNames[1];

    final List<Map<String, dynamic>> formStops = isEdit
        ? existingRoute.stops.map((s) => s.toJson()).toList()
        : <Map<String, dynamic>>[];
    for (final stop in formStops) {
      if (!places.any((p) => p['id'] == stop['placeId'])) {
        places.add(<String, dynamic>{'id': stop['placeId'], 'name': stop['name'], 'city': stop['city']});
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit route' : 'New route'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: fromCity,
                            decoration: const InputDecoration(labelText: 'From city *'),
                            items: cityNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setDlgState(() => fromCity = v ?? fromCity),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: toCity,
                            decoration: const InputDecoration(labelText: 'To city *'),
                            items: cityNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setDlgState(() => toCity = v ?? toCity),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: kmCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Distance (km) *'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: hrsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (hours) *'))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stops in chronological order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add stop'),
                          onPressed: () {
                            setDlgState(() {
                              final lastOffset = formStops.isNotEmpty ? (formStops.last['offset'] as int) : 0;
                              final first = places.first;
                              formStops.add({
                                'placeId': first['id'],
                                'name': first['name'],
                                'city': first['city'],
                                'offset': formStops.isEmpty ? 0 : lastOffset + 30,
                                'type': 'BOTH',
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < formStops.length; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AbraColors.lightGray,
                          borderRadius: BorderRadius.circular(AbraRadius.sm),
                          border: Border.all(color: AbraColors.border),
                        ),
                        child: Row(
                          children: [
                            Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 6),
                            // Move Up / Down
                            if (i > 0)
                              InkWell(
                                onTap: () {
                                  setDlgState(() {
                                    final prev = formStops[i - 1];
                                    formStops[i - 1] = formStops[i];
                                    formStops[i] = prev;
                                  });
                                },
                                child: const Icon(Icons.arrow_upward, size: 14, color: AbraColors.textSecondary),
                              ),
                            if (i < formStops.length - 1)
                              InkWell(
                                onTap: () {
                                  setDlgState(() {
                                    final next = formStops[i + 1];
                                    formStops[i + 1] = formStops[i];
                                    formStops[i] = next;
                                  });
                                },
                                child: const Icon(Icons.arrow_downward, size: 14, color: AbraColors.textSecondary),
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: formStops[i]['placeId'] as String,
                                  items: places.map((p) {
                                    return DropdownMenuItem<String>(
                                      value: p['id'] as String,
                                      child: Text('${p['name']} (${p['city']})', style: const TextStyle(fontSize: 12)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final p = places.firstWhere((x) => x['id'] == val);
                                      setDlgState(() {
                                        formStops[i]['placeId'] = val;
                                        formStops[i]['name'] = p['name'];
                                        formStops[i]['city'] = p['city'];
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: formStops[i]['type'] as String,
                                  items: const [
                                    DropdownMenuItem(value: 'BOARDING', child: Text('Boarding', style: TextStyle(fontSize: 11))),
                                    DropdownMenuItem(value: 'DROPPING', child: Text('Dropping', style: TextStyle(fontSize: 11))),
                                    DropdownMenuItem(value: 'BOTH', child: Text('Both', style: TextStyle(fontSize: 11))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() => formStops[i]['type'] = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 65,
                              child: TextFormField(
                                initialValue: '${formStops[i]['offset']}',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, labelText: '+Min'),
                                onChanged: (v) => formStops[i]['offset'] = int.tryParse(v) ?? 0,
                              ),
                            ),
                            if (formStops.length > 2) ...[
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AbraColors.danger),
                                onPressed: () {
                                  setDlgState(() => formStops.removeAt(i));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final km = int.tryParse(kmCtrl.text.trim());
                  final hrs = int.tryParse(hrsCtrl.text.trim());
                  if (km == null || km <= 0 || hrs == null || hrs <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter the distance and the duration'), backgroundColor: AbraColors.danger),
                    );
                    return;
                  }
                  final name = '$fromCity to $toCity';

                  // Client-side validations
                  if (formStops.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('A route requires at least 2 stops'), backgroundColor: AbraColors.danger),
                    );
                    return;
                  }
                  for (var s = 1; s < formStops.length; s++) {
                    if ((formStops[s]['offset'] as int) < (formStops[s - 1]['offset'] as int)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Stop ${s + 1} offset cannot be earlier than stop $s'), backgroundColor: AbraColors.danger),
                      );
                      return;
                    }
                  }

                  try {
                    final client = ref.read(appDependenciesProvider).apiClient;
                    if (isEdit) {
                      await client.put('client/routes/${existingRoute.id}', body: {
                        'from': fromCity,
                        'to': toCity,
                        'name': name,
                        'km': km,
                        'hours': hrs,
                        'stops': formStops,
                      });
                    } else {
                      await client.post('client/routes', body: {
                        'from': fromCity,
                        'to': toCity,
                        'name': name,
                        'km': km,
                        'hours': hrs,
                        'stops': formStops,
                      });
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Route $name saved')),
                      );
                    }
                  } catch (err) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(failureText(AbraLocalizations.of(context), err)),
                          backgroundColor: AbraColors.danger,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save route'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _copyRoute(BuildContext context, ClientRouteItem route) async {
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      final res = await client.post('client/routes/${route.id}/copy');
      final newId = res.data is Map ? (res.data as Map)['id'] as String? : null;
      if (context.mounted) {
        _refresh();
        if (newId != null) {
          setState(() => _selectedRouteId = newId);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied as your route: ${route.name} (mine)')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy route: $err'), backgroundColor: AbraColors.danger),
        );
      }
    }
  }

  void _confirmDeleteRoute(BuildContext context, ClientRouteItem route) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${route.name}?'),
        content: const Text('Are you sure you want to delete this route?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () async {
              try {
                final client = ref.read(appDependenciesProvider).apiClient;
                await client.delete('client/routes/${route.id}');
                if (context.mounted) {
                  Navigator.pop(ctx);
                  setState(() => _selectedRouteId = null);
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted route ${route.name}')),
                  );
                }
              } catch (err) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete route: $err'), backgroundColor: AbraColors.danger),
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
