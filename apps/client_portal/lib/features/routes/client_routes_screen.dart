import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';
import '../../routing/portal_routes.dart';

class ClientRoutesScreen extends StatefulWidget {
  const ClientRoutesScreen({super.key});

  @override
  State<ClientRoutesScreen> createState() => _ClientRoutesScreenState();
}

class _ClientRoutesScreenState extends State<ClientRoutesScreen> {
  late List<Map<String, dynamic>> _routes;
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _routes = List.from(kMockRoutes);
  }

  Map<String, dynamic>? get _selectedRoute {
    if (_selectedRouteId == null) return null;
    try {
      return _routes.firstWhere((r) => r['id'] == _selectedRouteId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selRoute = _selectedRoute;

    if (selRoute != null) {
      return _buildRouteDetailView(context, selRoute);
    }

    return _buildRoutesTableView(context);
  }

  Widget _buildRoutesTableView(BuildContext context) {
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: _routes.isEmpty
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
                  rows: _routes.map((r) {
                    final stops = (r['stops'] as List?) ?? [];
                    final isMine = r['operatorId'] == kMockOperatorId;
                    final tripsCount = kMockTrips.where((t) => t['routeId'] == r['id']).length;

                    return DataRow(
                      onSelectChanged: (_) {
                        setState(() => _selectedRouteId = r['id'] as String);
                      },
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (!isMine) ...[
                                const SizedBox(width: 6),
                                const Text('(Abra route)', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                        DataCell(Text('${r['km']} km')),
                        DataCell(Text('${r['hours']} h')),
                        DataCell(Text('${stops.length}')),
                        DataCell(Text('$tripsCount')),
                        DataCell(PortalStatusChip(status: '${r['status']}')),
                        DataCell(
                          TextButton(
                            onPressed: () => setState(() => _selectedRouteId = r['id'] as String),
                            child: const Text('View stops', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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

  Widget _buildRouteDetailView(BuildContext context, Map<String, dynamic> r) {
    final stops = (r['stops'] as List<dynamic>?)?.map((s) => Map<String, dynamic>.from(s as Map)).toList() ?? [];
    final isMine = r['operatorId'] == kMockOperatorId;
    final tripsCount = kMockTrips.where((t) => t['routeId'] == r['id']).length;
    final faresCount = kMockFares.where((f) => f['routeId'] == r['id']).length;
    final schedCount = kMockSchedules.where((s) => s['routeId'] == r['id']).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalSectionTitle(
                title: '${r['name']}',
                subtitle: '${r['km']} km · about ${r['hours']} h',
                breadcrumbs: ['Network', 'Routes', '${r['name']}'],
                actions: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('All routes'),
                    onPressed: () => setState(() => _selectedRouteId = null),
                  ),
                  if (isMine)
                    FilledButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit route'),
                      style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                      onPressed: () => _openRouteFormDialog(context, existingRoute: r),
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy as my route'),
                      onPressed: () {
                        final newId = 'RT${_routes.length + 1}';
                        final copy = Map<String, dynamic>.from(r);
                        copy['id'] = newId;
                        copy['operatorId'] = kMockOperatorId;
                        copy['name'] = '${r['name']} (mine)';
                        setState(() {
                          _routes.add(copy);
                          _selectedRouteId = newId;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied as your route: ${copy['name']}')),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: AbraSpacing.md),
              if (!isMine)
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
                    Expanded(flex: 3, child: _buildStopsTimelineCard(context, stops)),
                    const SizedBox(width: AbraSpacing.xl),
                    Expanded(flex: 2, child: _buildUsedByAndMapCard(context, tripsCount, faresCount, schedCount, stops)),
                  ],
                )
              else ...[
                _buildStopsTimelineCard(context, stops),
                const SizedBox(height: AbraSpacing.lg),
                _buildUsedByAndMapCard(context, tripsCount, faresCount, schedCount, stops),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopsTimelineCard(BuildContext context, List<Map<String, dynamic>> stops) {
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

  Widget _buildStopTimelineItem(Map<String, dynamic> stop, {required bool isFirst, required bool isLast}) {
    final type = '${stop['type']}';
    final (chipBg, chipFg, chipLabel) = switch (type) {
      'DROPPING' => (AbraColors.dangerContainer, AbraColors.danger, 'Dropping'),
      'BOTH' => (AbraColors.orangeContainer, AbraColors.orangeDark, 'Both'),
      _ => (AbraColors.tealContainer, AbraColors.tealDark, 'Boarding'),
    };

    final offset = (stop['offset'] as num?)?.toInt() ?? 0;
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
                        Text('${stop['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(4)),
                          child: Text(chipLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chipFg)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${stop['city']} · $timeStr', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsedByAndMapCard(BuildContext context, int trips, int fares, int scheds, List<Map<String, dynamic>> stops) {
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
                            color: stops[i]['type'] == 'DROPPING' ? AbraColors.danger : AbraColors.teal,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 70,
                          child: Text(
                            '${stops[i]['city']}',
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

  void _openRouteFormDialog(BuildContext context, {Map<String, dynamic>? existingRoute}) {
    final isEdit = existingRoute != null;
    final kmCtrl = TextEditingController(text: isEdit ? '${existingRoute['km']}' : '570');
    final hrsCtrl = TextEditingController(text: isEdit ? '${existingRoute['hours']}' : '10');
    String fromCity = isEdit ? '${existingRoute['from']}' : 'Bengaluru';
    String toCity = isEdit ? '${existingRoute['to']}' : 'Hyderabad';

    List<Map<String, dynamic>> formStops = isEdit
        ? List<Map<String, dynamic>>.from(
            ((existingRoute['stops'] as List?) ?? []).map((s) => Map<String, dynamic>.from(s as Map)),
          )
        : [
            {'placeId': 'PL1', 'name': 'Majestic Bus Stand', 'city': 'Bengaluru', 'offset': 0, 'type': 'BOARDING'},
            {'placeId': 'PL4', 'name': 'MGBS Bus Stand', 'city': 'Hyderabad', 'offset': 600, 'type': 'DROPPING'},
          ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit route' : 'New route'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: fromCity,
                            decoration: const InputDecoration(labelText: 'From city *'),
                            items: kMockCities.map((c) => DropdownMenuItem(value: c['name'] as String, child: Text('${c['name']}'))).toList(),
                            onChanged: (v) => setDlgState(() => fromCity = v ?? fromCity),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: toCity,
                            decoration: const InputDecoration(labelText: 'To city *'),
                            items: kMockCities.map((c) => DropdownMenuItem(value: c['name'] as String, child: Text('${c['name']}'))).toList(),
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
                        const Text('Stops in order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add stop'),
                          onPressed: () {
                            setDlgState(() {
                              final lastOffset = formStops.isNotEmpty ? (formStops.last['offset'] as int) : 0;
                              formStops.add({
                                'placeId': 'PL2',
                                'name': 'Silk Board Junction',
                                'city': fromCity,
                                'offset': lastOffset + 30,
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
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: formStops[i]['placeId'] as String,
                                  items: kMockPlaces.map((p) {
                                    return DropdownMenuItem<String>(
                                      value: p['id'] as String,
                                      child: Text('${p['name']} (${p['city']})', style: const TextStyle(fontSize: 12)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final p = kMockPlaces.firstWhere((x) => x['id'] == val);
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
                            const SizedBox(width: 8),
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
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
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
                onPressed: () {
                  final km = int.tryParse(kmCtrl.text) ?? 500;
                  final hrs = int.tryParse(hrsCtrl.text) ?? 8;
                  final name = '$fromCity to $toCity';

                  if (isEdit) {
                    setState(() {
                      existingRoute['from'] = fromCity;
                      existingRoute['to'] = toCity;
                      existingRoute['name'] = name;
                      existingRoute['km'] = km;
                      existingRoute['hours'] = hrs;
                      existingRoute['stops'] = formStops;
                    });
                  } else {
                    setState(() {
                      _routes.add({
                        'id': 'RT${_routes.length + 1}',
                        'operatorId': kMockOperatorId,
                        'name': name,
                        'from': fromCity,
                        'to': toCity,
                        'km': km,
                        'hours': hrs,
                        'status': 'ACTIVE',
                        'stops': formStops,
                      });
                    });
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Route $name saved')),
                  );
                },
                child: const Text('Save route'),
              ),
            ],
          );
        },
      ),
    );
  }
}
