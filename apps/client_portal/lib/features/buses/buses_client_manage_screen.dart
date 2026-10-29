import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

// ===== 1. MODELS =====

class ClientBusItem {
  ClientBusItem({
    required this.id,
    required this.registrationNumber,
    required this.name,
    required this.busTypeId,
    required this.busTypeName,
    required this.seatCapacity,
    required this.seatLayoutType,
    required this.status,
    this.make,
    String? displayName,
    this.insuranceExpiryDate,
    this.statusReason,
  }) : displayName = displayName ?? (make == null ? busTypeName : '$make $busTypeName');

  final String id;
  final String registrationNumber;
  final String name;
  final String busTypeId;
  final String busTypeName;
  final String? make;

  /// Ready-made name for lists, e.g. "Volvo AC Sleeper" (the bus type alone when there is no make).
  final String displayName;
  final int seatCapacity;
  final String seatLayoutType;
  final String status;
  final String? insuranceExpiryDate;
  final String? statusReason;

  factory ClientBusItem.fromJson(Map<String, dynamic> json) {
    return ClientBusItem(
      id: json['id'] as String? ?? '',
      registrationNumber: json['registrationNumber'] as String? ?? json['reg'] as String? ?? '',
      name: json['name'] as String? ?? '',
      busTypeId: json['busTypeId'] as String? ?? '',
      busTypeName: json['busTypeName'] as String? ?? json['type'] as String? ?? 'Standard',
      make: json['make'] as String?,
      displayName: json['displayName'] as String?,
      seatCapacity: (json['seatCapacity'] as num?)?.toInt() ?? (json['seats'] as num?)?.toInt() ?? 40,
      seatLayoutType: json['seatLayoutType'] as String? ?? json['layout'] as String? ?? '2+2 Seater',
      status: json['status'] as String? ?? 'ACTIVE',
      insuranceExpiryDate: json['insuranceExpiryDate'] as String? ?? json['insExp'] as String?,
      statusReason: json['statusReason'] as String?,
    );
  }
}

class ClientBusKpisData {
  ClientBusKpisData({
    this.totalBuses = 0,
    this.activeCount = 0,
    this.pendingCount = 0,
    this.maintenanceCount = 0,
    this.expiringIn30DaysCount = 0,
  });

  final int totalBuses;
  final int activeCount;
  final int pendingCount;
  final int maintenanceCount;
  final int expiringIn30DaysCount;

  factory ClientBusKpisData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClientBusKpisData();
    return ClientBusKpisData(
      totalBuses: (json['totalBuses'] as num?)?.toInt() ?? 0,
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      maintenanceCount: (json['maintenanceCount'] as num?)?.toInt() ?? 0,
      expiringIn30DaysCount: (json['expiringIn30DaysCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClientSeatLayoutData {
  ClientSeatLayoutData({
    required this.id,
    required this.busId,
    required this.version,
    required this.name,
    required this.layoutType,
    required this.decks,
    required this.map,
    required this.totalSeats,
    required this.ladiesSeatsCount,
  });

  final String id;
  final String busId;
  final int version;
  final String name;
  final String layoutType;
  final int decks;
  final List<String> map;
  final int totalSeats;
  final int ladiesSeatsCount;

  factory ClientSeatLayoutData.fromJson(Map<String, dynamic> json) {
    return ClientSeatLayoutData(
      id: json['id'] as String? ?? '',
      busId: json['busId'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? 'Main Layout',
      layoutType: json['layoutType'] as String? ?? '2+2 Seater',
      decks: (json['decks'] as num?)?.toInt() ?? 1,
      map: (json['map'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
      ladiesSeatsCount: (json['ladiesSeatsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ===== 2. PROVIDERS =====

final clientBusesProvider = FutureProvider.autoDispose
    .family<(List<ClientBusItem>, ClientBusKpisData), String>((ref, filterStatus) async {
  try {
    final client = ref.watch(appDependenciesProvider).apiClient;
    final query = <String, dynamic>{'pageSize': 50};
    if (filterStatus != 'ALL') {
      query['status'] = filterStatus;
    }
    final response = await client.get('client/buses', query: query);
    final items = response.decodeList((json) => ClientBusItem.fromJson(json));
    var kpis = ClientBusKpisData();
    try {
      final kpiRes = await client.get('client/buses/kpis');
      if (kpiRes.data is Map<String, dynamic>) {
        kpis = ClientBusKpisData.fromJson(kpiRes.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return (items, kpis);
  } catch (_) {
    return (<ClientBusItem>[], ClientBusKpisData());
  }
});

final clientBusLayoutProvider = FutureProvider.autoDispose
    .family<ClientSeatLayoutData?, String>((ref, busId) async {
  if (busId.isEmpty) return null;
  try {
    final client = ref.watch(appDependenciesProvider).apiClient;
    final response = await client.get('client/seat-layouts/$busId');
    if (response.data is Map<String, dynamic>) {
      return ClientSeatLayoutData.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  } catch (_) {
    return null;
  }
});

// ===== 3. MAIN CONTAINER SCREEN =====

class BusesClientManageScreen extends ConsumerStatefulWidget {
  const BusesClientManageScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<BusesClientManageScreen> createState() => _BusesClientManageScreenState();
}

class _BusesClientManageScreenState extends ConsumerState<BusesClientManageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbraColors.lightGray,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.xxl),
            child: TabBar(
              controller: _tabController,
              labelColor: AbraColors.blue,
              unselectedLabelColor: AbraColors.textSecondary,
              indicatorColor: AbraColors.blue,
              tabs: const [
                Tab(icon: Icon(Icons.directions_bus_outlined), text: 'Fleet Buses'),
                Tab(icon: Icon(Icons.grid_on_outlined), text: 'Seat Layout Designer'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ClientBusesView(
                  onOpenLayout: (busId) {
                    _tabController.animateTo(1);
                  },
                ),
                const _ClientSeatLayoutView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClientBusesScreen extends StatelessWidget {
  const ClientBusesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BusesClientManageScreen(initialTab: 0);
  }
}

class ClientSeatLayoutScreen extends StatelessWidget {
  const ClientSeatLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BusesClientManageScreen(initialTab: 1);
  }
}

// ===== 4. FLEET BUSES VIEW =====

class _ClientBusesView extends ConsumerStatefulWidget {
  const _ClientBusesView({required this.onOpenLayout});

  final void Function(String busId) onOpenLayout;

  @override
  ConsumerState<_ClientBusesView> createState() => _ClientBusesViewState();
}

class _ClientBusesViewState extends ConsumerState<_ClientBusesView> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final busesAsync = ref.watch(clientBusesProvider(_filter));

    return busesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading buses: $e')),
      data: (tuple) {
        final buses = tuple.$1;
        final kpis = tuple.$2;

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
                    subtitle: '${kpis.totalBuses} buses in your fleet',
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
                            Expanded(child: PortalKpiCard(icon: Icons.directions_bus, value: '${kpis.totalBuses}', label: 'Total buses')),
                            const SizedBox(width: AbraSpacing.md),
                            Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: '${kpis.activeCount}', label: 'Active', iconColor: AbraColors.teal)),
                          ],
                        ),
                        const SizedBox(height: AbraSpacing.md),
                        Row(
                          children: [
                            Expanded(child: PortalKpiCard(icon: Icons.hourglass_top, value: '${kpis.pendingCount}', label: 'Pending approval', iconColor: AbraColors.orange)),
                            const SizedBox(width: AbraSpacing.md),
                            Expanded(child: PortalKpiCard(icon: Icons.build_outlined, value: '${kpis.maintenanceCount}', label: 'Maintenance', iconColor: AbraColors.danger)),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: PortalKpiCard(icon: Icons.directions_bus, value: '${kpis.totalBuses}', label: 'Total buses')),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: '${kpis.activeCount}', label: 'Active', iconColor: AbraColors.teal)),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.hourglass_top, value: '${kpis.pendingCount}', label: 'Pending approval', iconColor: AbraColors.orange)),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.build_outlined, value: '${kpis.maintenanceCount}', label: 'Maintenance', iconColor: AbraColors.danger)),
                      ],
                    ),
                  const SizedBox(height: AbraSpacing.xl),
                  // Table Container
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
                        if (buses.isEmpty)
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
                                  DataColumn(label: Text('Layout')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Insurance Expiry')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: buses.map((bus) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(bus.registrationNumber, style: const TextStyle(fontWeight: FontWeight.w700))),
                                      DataCell(Text(bus.name)),
                                      DataCell(Text(bus.displayName)),
                                      DataCell(Text('${bus.seatCapacity} seats')),
                                      DataCell(Text(bus.seatLayoutType)),
                                      DataCell(PortalStatusChip(status: bus.status)),
                                      DataCell(Text(bus.insuranceExpiryDate != null ? bus.insuranceExpiryDate!.split('T').first : '—')),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.grid_on_outlined, size: 18),
                                              tooltip: 'Seat layout',
                                              onPressed: () => widget.onOpenLayout(bus.id),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.build_circle_outlined, size: 18),
                                              tooltip: bus.status == 'MAINTENANCE' ? 'Return to service' : 'Mark maintenance',
                                              onPressed: () => _toggleMaintenance(bus),
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
      },
    );
  }

  Future<void> _toggleMaintenance(ClientBusItem bus) async {
    final newStatus = bus.status == 'MAINTENANCE' ? 'ACTIVE' : 'MAINTENANCE';
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await client.post(
        'client/buses/${bus.id}/status',
        body: {'status': newStatus, 'reason': 'Operator requested status change'},
      );
      ref.invalidate(clientBusesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bus is now ${newStatus.toLowerCase()}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot change status: $e')));
      }
    }
  }

  /// Seat arrangements an operator can describe the bus with; the exact seats are drawn later
  /// in the seat layout designer.
  static const _arrangements = <String>[
    '2+2 Seater',
    '2+1 Seater',
    '2+1 Sleeper',
    '1+1 Sleeper',
    '2+1 Semi-sleeper',
  ];

  /// Makers an operator can pick; "Other" lets them type one.
  static const _makes = <String>[
    'Volvo',
    'Scania',
    'BharatBenz',
    'Ashok Leyland',
    'Tata',
    'Eicher',
    'Mercedes-Benz',
  ];
  static const _otherMake = 'Other';

  /// What an operator can say about a bus type they ask for (the server's berth types).
  static const _berthChoices = <String, String>{
    'SEATER': 'Seater',
    'SLEEPER': 'Sleeper',
    'SEMI_SLEEPER': 'Semi-sleeper',
    'MIXED': 'Seater + Sleeper',
  };

  /// "My bus type isn't listed": asks Abra to add a bus type. Abra approves it on the Bus types
  /// page and the operator is told.
  Future<void> _showBusTypeRequestDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AbraLocalizations.of(context);
    final nameCtrl = TextEditingController();
    var isAc = true;
    var berthType = 'SLEEPER';
    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> submit() async {
            if (nameCtrl.text.trim().length < 2) {
              setDlg(() => error = 'Enter the bus type name.');
              return;
            }
            setDlg(() {
              error = null;
              saving = true;
            });
            try {
              await ref.read(appDependenciesProvider).apiClient.post(
                'client/bus-type-requests',
                body: <String, dynamic>{
                  'name': nameCtrl.text.trim(),
                  'isAc': isAc,
                  'berthType': berthType,
                },
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Request sent to Abra. We will tell you when the bus type is added.'),
                ),
              );
            } catch (e) {
              setDlg(() {
                saving = false;
                error = failureText(l10n, e);
              });
            }
          }

          return AlertDialog(
            title: const Text("My bus type isn't listed"),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Bus type name (e.g. Mini Coach)*'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Air-conditioned (AC)'),
                    value: isAc,
                    onChanged: (v) => setDlg(() => isAc = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: berthType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Seats and berths*'),
                    items: [
                      for (final entry in _berthChoices.entries)
                        DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (v) => setDlg(() => berthType = v ?? berthType),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: AbraColors.danger)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: saving ? null : submit,
                child: Text(saving ? 'Sending…' : 'Send request'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The bus types and amenities Abra has switched on, from the server.
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _loadBusChoices() async {
    final client = ref.read(appDependenciesProvider).apiClient;
    final typesResponse = await client.get(
      'catalogue/bus-types',
      query: <String, dynamic>{'active': true, 'pageSize': 100},
    );
    final rawTypes = typesResponse.data is Map && (typesResponse.data as Map)['items'] is List
        ? (typesResponse.data as Map)['items'] as List
        : typesResponse.data is List
            ? typesResponse.data as List
            : const <Object?>[];
    final types = <Map<String, dynamic>>[
      for (final raw in rawTypes)
        if (raw is Map && raw['isActive'] != false) Map<String, dynamic>.from(raw),
    ];
    final amenitiesResponse = await client.get('catalogue/amenities');
    final amenities = <Map<String, dynamic>>[
      for (final raw in (amenitiesResponse.data is List ? amenitiesResponse.data as List : const <Object?>[]))
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    return (types, amenities);
  }

  Future<void> _showAddBusDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AbraLocalizations.of(context);
    final List<Map<String, dynamic>> busTypes;
    final List<Map<String, dynamic>> amenityChoices;
    try {
      (busTypes, amenityChoices) = await _loadBusChoices();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not load bus types: ${failureText(l10n, e)}')));
      return;
    }
    if (!context.mounted) return;
    if (busTypes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Abra has not added any bus types yet. Please contact Abra support.'),
          backgroundColor: AbraColors.danger,
        ),
      );
      return;
    }

    final regCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final seatsCtrl = TextEditingController();
    String? busTypeId;
    String? make;
    final otherMakeCtrl = TextEditingController();
    String? arrangement;
    DateTime? insuranceExpiry;
    final selectedAmenities = <String>{};
    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> submit() async {
            final seats = int.tryParse(seatsCtrl.text.trim());
            final makeText = make == _otherMake ? otherMakeCtrl.text.trim() : make;
            final problem = make == _otherMake && makeText!.length < 2
                ? 'Type the make of the bus, or choose one from the list.'
                : regCtrl.text.trim().isEmpty
                ? 'Enter the registration number.'
                : nameCtrl.text.trim().length < 2
                    ? 'Enter the bus name.'
                    : busTypeId == null
                        ? 'Choose the bus type.'
                        : seats == null || seats < 1 || seats > 100
                            ? 'Enter the number of seats (1 to 100).'
                            : null;
            if (problem != null) {
              setDlg(() => error = problem);
              return;
            }
            setDlg(() {
              error = null;
              saving = true;
            });
            try {
              final client = ref.read(appDependenciesProvider).apiClient;
              await client.post(
                'client/buses',
                body: <String, dynamic>{
                  'registrationNumber': regCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                  'busTypeId': busTypeId,
                  if (makeText != null && makeText.isNotEmpty) 'make': makeText,
                  'seatCapacity': seats,
                  'seatLayoutType': ?arrangement,
                  if (insuranceExpiry != null)
                    'insuranceExpiryDate':
                        '${insuranceExpiry!.year.toString().padLeft(4, '0')}-${insuranceExpiry!.month.toString().padLeft(2, '0')}-${insuranceExpiry!.day.toString().padLeft(2, '0')}',
                  'amenities': selectedAmenities.toList(),
                },
              );
              ref.invalidate(clientBusesProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Bus submitted for approval. You can draw its layout.')),
              );
            } catch (e) {
              setDlg(() {
                saving = false;
                error = failureText(l10n, e);
              });
            }
          }

          return AlertDialog(
            title: const Text('Add new bus (Send for approval)'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: regCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Registration Number (e.g. KA01 AB 1234)*'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Bus Name (e.g. Deluxe Express)*'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: busTypeId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Bus Type*'),
                      items: [
                        for (final t in busTypes)
                          DropdownMenuItem<String>(value: '${t['id']}', child: Text('${t['name']}')),
                      ],
                      onChanged: (v) => setDlg(() => busTypeId = v),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: saving ? null : () => _showBusTypeRequestDialog(ctx),
                        child: const Text("My bus type isn't listed"),
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: make,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Make (optional)'),
                      items: [
                        for (final m in [..._makes, _otherMake])
                          DropdownMenuItem<String>(value: m, child: Text(m == _otherMake ? 'Other (type it)' : m)),
                      ],
                      onChanged: (v) => setDlg(() => make = v),
                    ),
                    if (make == _otherMake) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: otherMakeCtrl,
                        decoration: const InputDecoration(labelText: 'Make of the bus*'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: arrangement,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Seat arrangement'),
                      items: [
                        for (final a in _arrangements)
                          DropdownMenuItem<String>(value: a, child: Text(a)),
                      ],
                      onChanged: (v) => setDlg(() => arrangement = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: seatsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Seat Capacity* (1 to 100)'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        insuranceExpiry == null
                            ? 'Insurance valid until (optional)'
                            : 'Insurance valid until ${insuranceExpiry!.day}/${insuranceExpiry!.month}/${insuranceExpiry!.year}',
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: insuranceExpiry ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked != null) setDlg(() => insuranceExpiry = picked);
                      },
                    ),
                    if (amenityChoices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in amenityChoices)
                            FilterChip(
                              label: Text('${a['name']}'),
                              selected: selectedAmenities.contains(a['key']),
                              onSelected: (on) => setDlg(() {
                                if (on) {
                                  selectedAmenities.add('${a['key']}');
                                } else {
                                  selectedAmenities.remove(a['key']);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: AbraColors.danger)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: saving ? null : submit,
                child: Text(saving ? 'Sending…' : 'Send for approval'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBusDetail(BuildContext context, ClientBusItem bus) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${bus.name} (${bus.registrationNumber})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${bus.displayName}'),
            const SizedBox(height: 6),
            Text('Capacity: ${bus.seatCapacity} seats'),
            const SizedBox(height: 6),
            Text('Layout Style: ${bus.seatLayoutType}'),
            const SizedBox(height: 6),
            Text('Status: ${bus.status}'),
            const SizedBox(height: 6),
            Text('Insurance Valid Until: ${bus.insuranceExpiryDate != null ? bus.insuranceExpiryDate!.split('T').first : '—'}'),
            if (bus.statusReason != null) ...[
              const SizedBox(height: 6),
              Text('Note: ${bus.statusReason}'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

// ===== 5. SEAT LAYOUT DESIGNER VIEW =====

class _ClientSeatLayoutView extends ConsumerStatefulWidget {
  const _ClientSeatLayoutView();

  @override
  ConsumerState<_ClientSeatLayoutView> createState() => _ClientSeatLayoutViewState();
}

class _ClientSeatLayoutViewState extends ConsumerState<_ClientSeatLayoutView> {
  String _selectedBusId = '';
  String _selectedTool = 'S';
  List<List<String>> _grid = [];
  bool _saving = false;

  void _initGrid(ClientSeatLayoutData? layout, ClientBusItem? bus) {
    if (layout != null && layout.map.isNotEmpty) {
      _grid = layout.map.map((row) => row.split('')).toList();
      return;
    }
    if (bus != null) {
      final isSleeper = bus.seatLayoutType.contains('Sleeper');
      final cols = isSleeper ? ['S', 'S', '_', 'S'] : ['S', 'S', '_', 'S', 'S'];
      final rowCount = (bus.seatCapacity / (isSleeper ? 3 : 4)).ceil();
      _grid = List.generate(rowCount, (_) => List<String>.from(cols));
      return;
    }
    _grid = [];
  }

  @override
  Widget build(BuildContext context) {
    final busesAsync = ref.watch(clientBusesProvider('ALL'));

    return busesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (tuple) {
        final buses = tuple.$1.where((b) => b.status != 'RETIRED').toList();
        if (buses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AbraSpacing.xxl),
            child: Center(child: Text('No buses available yet. Add a bus first.')),
          );
        }

        if (_selectedBusId.isEmpty || !buses.any((b) => b.id == _selectedBusId)) {
          _selectedBusId = buses.first.id;
        }

        final selectedBus = buses.firstWhere((b) => b.id == _selectedBusId);
        final layoutAsync = ref.watch(clientBusLayoutProvider(_selectedBusId));

        return layoutAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error loading layout: $e')),
          data: (layoutData) {
            if (_grid.isEmpty) {
              _initGrid(layoutData, selectedBus);
            }

            int seatCount = 0;
            int sleeperCount = 0;
            int ladiesCount = 0;

            for (final row in _grid) {
              for (final cell in row) {
                if (cell == 'S') seatCount++;
                if (cell == 'B') sleeperCount++;
                if (cell == 'L') ladiesCount++;
              }
            }

            final totalMapSeats = seatCount + sleeperCount + ladiesCount;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 850;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AbraSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PortalSectionTitle(
                        title: 'Seat layouts',
                        subtitle: 'Draw the real seat map. Customers pick seats from this map.',
                        breadcrumbs: const ['Fleet', 'Seat layouts'],
                        actions: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AbraRadius.md),
                              border: Border.all(color: AbraColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedBusId,
                                icon: const Icon(Icons.arrow_drop_down, color: AbraColors.navy),
                                items: buses.map((b) {
                                  return DropdownMenuItem<String>(
                                    value: b.id,
                                    child: Text(
                                      '${b.registrationNumber} · ${b.seatLayoutType}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedBusId = val;
                                      _grid = [];
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AbraSpacing.xl),
                      // Tool picker
                      Container(
                        padding: const EdgeInsets.all(AbraSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AbraRadius.lg),
                          border: Border.all(color: AbraColors.border),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Paint tool:', style: TextStyle(fontWeight: FontWeight.w700)),
                            _toolChip('S', 'Seat', Icons.event_seat, AbraColors.blue),
                            _toolChip('B', 'Sleeper berth', Icons.bed, AbraColors.deepBlue),
                            _toolChip('L', 'Ladies seat', Icons.female, Colors.pink),
                            _toolChip('_', 'Aisle', Icons.space_bar, Colors.grey),
                            _toolChip('.', 'Empty', Icons.close, Colors.red),
                          ],
                        ),
                      ),
                      const SizedBox(height: AbraSpacing.xl),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildCanvas(selectedBus)),
                            const SizedBox(width: AbraSpacing.xl),
                            Expanded(
                              flex: 2,
                              child: _buildSummaryCard(selectedBus, totalMapSeats, selectedBus.seatCapacity, seatCount, sleeperCount, ladiesCount),
                            ),
                          ],
                        )
                      else ...[
                        _buildCanvas(selectedBus),
                        const SizedBox(height: AbraSpacing.lg),
                        _buildSummaryCard(selectedBus, totalMapSeats, selectedBus.seatCapacity, seatCount, sleeperCount, ladiesCount),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _toolChip(String code, String label, IconData icon, Color color) {
    final isSel = _selectedTool == code;
    return InkWell(
      onTap: () => setState(() => _selectedTool = code),
      borderRadius: BorderRadius.circular(AbraRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AbraRadius.md),
          border: Border.all(color: isSel ? color : AbraColors.border, width: isSel ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(ClientBusItem bus) {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: Column(
        children: [
          Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AbraColors.navyContainer,
              borderRadius: BorderRadius.circular(AbraRadius.md),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus, size: 16, color: AbraColors.navy),
                  SizedBox(width: 8),
                  Text('Front / Driver Cabin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AbraColors.navy)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Grid
          Column(
            children: List.generate(_grid.length, (r) {
              final row = _grid[r];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(row.length, (c) {
                    final cell = row[c];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _grid[r][c] = _selectedTool;
                          });
                        },
                        child: _buildCellWidget(cell),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Row buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add row'),
                onPressed: () {
                  setState(() {
                    final defaultCols = _grid.isNotEmpty ? List<String>.from(_grid.last) : ['S', 'S', '_', 'S', 'S'];
                    _grid.add(defaultCols);
                  });
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('Remove row'),
                onPressed: _grid.length > 1
                    ? () {
                        setState(() {
                          _grid.removeLast();
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset'),
                onPressed: () {
                  setState(() {
                    _initGrid(null, bus);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCellWidget(String cell) {
    Color bg = Colors.white;
    Color border = AbraColors.border;
    IconData? icon;

    switch (cell) {
      case 'S':
        bg = AbraColors.skyContainer;
        border = AbraColors.blue;
        icon = Icons.event_seat;
        break;
      case 'B':
        bg = AbraColors.navyContainer;
        border = AbraColors.deepBlue;
        icon = Icons.bed;
        break;
      case 'L':
        bg = Colors.pink.shade50;
        border = Colors.pink;
        icon = Icons.female;
        break;
      case '_':
        bg = Colors.grey.shade100;
        border = Colors.transparent;
        break;
      case '.':
        bg = Colors.white;
        border = Colors.grey.shade300;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AbraRadius.sm),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Center(
        child: icon != null ? Icon(icon, size: 18, color: border) : null,
      ),
    );
  }

  Widget _buildSummaryCard(
    ClientBusItem bus,
    int totalMapSeats,
    int recordSeats,
    int seatCount,
    int sleeperCount,
    int ladiesCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          _summaryRow('Bus', bus.registrationNumber),
          _summaryRow('Seats in map', '$totalMapSeats'),
          _summaryRow('Seats on record', '$recordSeats'),
          _summaryRow('Regular seats', '$seatCount'),
          _summaryRow('Sleeper berths', '$sleeperCount'),
          _summaryRow('Ladies seats', '$ladiesCount'),
          _summaryRow('Rows', '${_grid.length}'),
          if (totalMapSeats != recordSeats) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AbraColors.skyContainer,
                borderRadius: BorderRadius.circular(AbraRadius.md),
              ),
              child: Text(
                'The map has $totalMapSeats seats, the bus record says $recordSeats. Saving updates the bus to $totalMapSeats seats.',
                style: const TextStyle(fontSize: 12, color: AbraColors.blue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save layout'),
              style: FilledButton.styleFrom(backgroundColor: AbraColors.teal),
              onPressed: _saving ? null : () => _saveLayout(bus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
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

  Future<void> _saveLayout(ClientBusItem bus) async {
    setState(() => _saving = true);
    try {
      final mapRows = _grid.map((r) => r.join('')).toList();
      final client = ref.read(appDependenciesProvider).apiClient;
      await client.put(
        'client/seat-layouts/${bus.id}',
        body: {
          'name': '${bus.seatLayoutType} Layout',
          'layoutType': bus.seatLayoutType,
          'decks': 1,
          'map': mapRows,
        },
      );
      ref.invalidate(clientBusLayoutProvider(bus.id));
      ref.invalidate(clientBusesProvider('ALL'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seat layout version saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving layout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
