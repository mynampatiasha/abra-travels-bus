import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

String _formatRs(int paise) => '₹${(paise / 100).toStringAsFixed(0)}';

// ===== 1. MODELS =====

class ClientTripItem {
  ClientTripItem({
    required this.id,
    required this.operatorId,
    required this.routeId,
    required this.route,
    required this.busId,
    required this.bus,
    this.busName,
    required this.busType,
    required this.travelDate,
    required this.departureAt,
    required this.arrivalAt,
    required this.departureTime,
    required this.startingFarePaise,
    this.seatLayoutVersionId,
    this.fareRuleSetVersionId,
    required this.status,
    required this.totalSeats,
    required this.availableSeats,
    required this.bookedSeats,
    required this.heldSeats,
    required this.blockedSeats,
    this.driver,
    this.conductor,
    this.delayMinutes,
    this.delayReason,
    this.cancellationReason,
  });

  final String id;
  final String operatorId;
  final String routeId;
  final String route;
  final String busId;
  final String bus;
  final String? busName;
  final String busType;
  final String travelDate;
  final String departureAt;
  final String arrivalAt;
  final String departureTime;
  final int startingFarePaise;
  final String? seatLayoutVersionId;
  final String? fareRuleSetVersionId;
  final String status;
  final int totalSeats;
  final int availableSeats;
  final int bookedSeats;
  final int heldSeats;
  final int blockedSeats;
  final String? driver;
  final String? conductor;
  final int? delayMinutes;
  final String? delayReason;
  final String? cancellationReason;

  factory ClientTripItem.fromJson(Map<String, dynamic> json) {
    return ClientTripItem(
      id: json['id'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      route: json['route'] as String? ?? '',
      busId: json['busId'] as String? ?? '',
      bus: json['bus'] as String? ?? '',
      busName: json['busName'] as String?,
      busType: json['busType'] as String? ?? '',
      travelDate: json['travelDate'] as String? ?? '',
      departureAt: json['departureAt'] as String? ?? '',
      arrivalAt: json['arrivalAt'] as String? ?? '',
      departureTime: json['departureTime'] as String? ?? '',
      startingFarePaise: (json['startingFarePaise'] as num?)?.toInt() ?? 0,
      seatLayoutVersionId: json['seatLayoutVersionId'] as String?,
      fareRuleSetVersionId: json['fareRuleSetVersionId'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
      availableSeats: (json['availableSeats'] as num?)?.toInt() ?? 0,
      bookedSeats: (json['bookedSeats'] as num?)?.toInt() ?? 0,
      heldSeats: (json['heldSeats'] as num?)?.toInt() ?? 0,
      blockedSeats: (json['blockedSeats'] as num?)?.toInt() ?? 0,
      driver: json['driver'] as String?,
      conductor: json['conductor'] as String?,
      delayMinutes: (json['delayMinutes'] as num?)?.toInt(),
      delayReason: json['delayReason'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
    );
  }
}

class ClientTripKpisData {
  ClientTripKpisData({
    this.onSale = 0,
    this.drafts = 0,
    this.running = 0,
    this.noDriver = 0,
  });

  final int onSale;
  final int drafts;
  final int running;
  final int noDriver;

  factory ClientTripKpisData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClientTripKpisData();
    return ClientTripKpisData(
      onSale: (json['onSale'] as num?)?.toInt() ?? 0,
      drafts: (json['drafts'] as num?)?.toInt() ?? 0,
      running: (json['running'] as num?)?.toInt() ?? 0,
      noDriver: (json['noDriver'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClientSeatItem {
  ClientSeatItem({
    required this.seatNumber,
    required this.deck,
    required this.seatType,
    required this.status,
    required this.farePaise,
    this.blockReason,
  });

  final String seatNumber;
  final String deck;
  final String seatType;
  final String status;
  final int farePaise;
  final String? blockReason;

  factory ClientSeatItem.fromJson(Map<String, dynamic> json) {
    return ClientSeatItem(
      seatNumber: json['seatNumber'] as String? ?? '',
      deck: json['deck'] as String? ?? 'LOWER',
      seatType: json['seatType'] as String? ?? 'SEATER',
      status: json['status'] as String? ?? 'AVAILABLE',
      farePaise: (json['farePaise'] as num?)?.toInt() ?? 0,
      blockReason: json['blockReason'] as String?,
    );
  }
}

// ===== 2. PROVIDERS =====

final clientTripsProvider = FutureProvider.autoDispose
    .family<(List<ClientTripItem>, ClientTripKpisData), (String, String, String)>((ref, args) async {
  final (statusFilter, whenFilter, search) = args;
  try {
    final client = ref.watch(appDependenciesProvider).apiClient;
    final query = <String, dynamic>{'pageSize': 100};
    if (statusFilter != 'ALL') {
      query['status'] = statusFilter;
    }
    if (whenFilter != 'ALL') {
      query['when'] = whenFilter;
    }
    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final response = await client.get('client/trips', query: query);
    final List<ClientTripItem> items = [];
    var kpis = ClientTripKpisData();

    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      if (map['items'] is List) {
        for (final raw in map['items'] as List) {
          if (raw is Map<String, dynamic>) {
            items.add(ClientTripItem.fromJson(raw));
          }
        }
      }
      if (map['kpis'] is Map<String, dynamic>) {
        kpis = ClientTripKpisData.fromJson(map['kpis'] as Map<String, dynamic>);
      }
    } else if (response.data is List) {
      for (final raw in response.data as List) {
        if (raw is Map<String, dynamic>) {
          items.add(ClientTripItem.fromJson(raw));
        }
      }
    }

    return (items, kpis);
  } catch (_) {
    return (<ClientTripItem>[], ClientTripKpisData());
  }
});

// ===== 3. SCREEN =====

class ClientTripsScreen extends ConsumerStatefulWidget {
  const ClientTripsScreen({super.key});

  @override
  ConsumerState<ClientTripsScreen> createState() => _ClientTripsScreenState();
}

class _ClientTripsScreenState extends ConsumerState<ClientTripsScreen> {
  String _statusFilter = 'ALL';
  String _whenFilter = 'ALL';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(clientTripsProvider);
  }

  void _exportCsv(List<ClientTripItem> trips) {
    final buffer = StringBuffer();
    buffer.writeln('Trip ID,Route,Bus,Departure,Booked,Total Seats,Fare,Driver,Status');
    for (final t in trips) {
      final route = t.route.replaceAll('"', '""');
      final bus = t.bus.replaceAll('"', '""');
      final driver = (t.driver ?? '').replaceAll('"', '""');
      buffer.writeln('"${t.id}","$route","$bus","${t.departureAt}",${t.bookedSeats},${t.totalSeats},${t.startingFarePaise},"$driver","${t.status}"');
    }
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    downloadTextFile('trips_$stamp.csv', buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The file is ready.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchCtrl.text.trim();
    final asyncTrips = ref.watch(clientTripsProvider((_statusFilter, _whenFilter, search)));

    return asyncTrips.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AbraColors.danger),
              const SizedBox(height: 16),
              Text('Failed to load trips: $err', style: const TextStyle(color: AbraColors.danger)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (data) {
        final (trips, kpis) = data;
        return _buildContentView(context, trips, kpis);
      },
    );
  }

  Widget _buildContentView(BuildContext context, List<ClientTripItem> trips, ClientTripKpisData kpis) {
    final isNarrow = MediaQuery.of(context).size.width < 850;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Trips',
            subtitle: 'Publish a trip to put it on sale in the customer app.',
            breadcrumbs: const ['Sales setup', 'Trips'],
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New trip'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: () => _showAddTripDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),
          // 4 KPIs matching demo prototype
          if (isNarrow)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PortalKpiCard(
                        icon: Icons.calendar_today,
                        value: '${kpis.onSale}',
                        label: 'On sale',
                        iconColor: AbraColors.teal,
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(
                      child: PortalKpiCard(
                        icon: Icons.edit_note,
                        value: '${kpis.drafts}',
                        label: 'Drafts',
                        iconColor: AbraColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AbraSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: PortalKpiCard(
                        icon: Icons.navigation_outlined,
                        value: '${kpis.running}',
                        label: 'Running now',
                        iconColor: AbraColors.tealDark,
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(
                      child: PortalKpiCard(
                        icon: Icons.person_off_outlined,
                        value: '${kpis.noDriver}',
                        label: 'Without a driver',
                        iconColor: AbraColors.orangeDark,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: PortalKpiCard(
                    icon: Icons.calendar_today,
                    value: '${kpis.onSale}',
                    label: 'On sale',
                    iconColor: AbraColors.teal,
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Expanded(
                  child: PortalKpiCard(
                    icon: Icons.edit_note,
                    value: '${kpis.drafts}',
                    label: 'Drafts',
                    iconColor: AbraColors.blue,
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Expanded(
                  child: PortalKpiCard(
                    icon: Icons.navigation_outlined,
                    value: '${kpis.running}',
                    label: 'Running now',
                    iconColor: AbraColors.tealDark,
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Expanded(
                  child: PortalKpiCard(
                    icon: Icons.person_off_outlined,
                    value: '${kpis.noDriver}',
                    label: 'Without a driver',
                    iconColor: AbraColors.orangeDark,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AbraSpacing.xl),
          // Toolbar Container
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
                // Status Dropdown
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                      DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                      DropdownMenuItem(value: 'BOARDING', child: Text('Boarding')),
                      DropdownMenuItem(value: 'IN_TRANSIT', child: Text('In Transit')),
                      DropdownMenuItem(value: 'DELAYED', child: Text('Delayed')),
                      DropdownMenuItem(value: 'ARRIVED', child: Text('Arrived')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                ),
                // When Dropdown
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _whenFilter,
                    decoration: const InputDecoration(
                      labelText: 'When',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All time')),
                      DropdownMenuItem(value: 'up', child: Text('Upcoming')),
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'past', child: Text('Past')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _whenFilter = val);
                    },
                  ),
                ),
                // Search Input
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search trips...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                if (_statusFilter != 'ALL' || _whenFilter != 'ALL' || _searchCtrl.text.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _statusFilter = 'ALL';
                        _whenFilter = 'ALL';
                      });
                    },
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: trips.isEmpty ? null : () => _exportCsv(trips),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          // Table / Empty State Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: trips.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.directions_bus_outlined, size: 48, color: AbraColors.textDisabled),
                          const SizedBox(height: 12),
                          const Text(
                            'No trips yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Create a trip or generate them from a schedule.',
                            style: TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New trip'),
                            style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                            onPressed: () => _showAddTripDialog(context),
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
                          DataColumn(label: Text('Trip')),
                          DataColumn(label: Text('Departs')),
                          DataColumn(label: Text('Bus')),
                          DataColumn(label: Text('Driver')),
                          DataColumn(label: Text('Booked')),
                          DataColumn(label: Text('Fare')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: trips.map((t) {
                          final booked = t.bookedSeats;
                          final total = t.totalSeats > 0 ? t.totalSeats : 1;
                          final pct = (booked / total * 100).round();
                          final dep = t.departureAt.isNotEmpty && t.departureAt.contains('T')
                              ? t.departureAt.replaceAll('T', ' ').substring(0, 16)
                              : '${t.travelDate} ${t.departureTime}';
                          final driver = t.driver ?? '';

                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _showTripDetail(context, t),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t.id, style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue)),
                                      Text(t.route, style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text(dep)),
                              DataCell(Text(t.bus.isNotEmpty ? t.bus : (t.busName ?? 'Bus'))),
                              DataCell(
                                driver.isNotEmpty
                                    ? Text(driver, style: const TextStyle(fontWeight: FontWeight.w600))
                                    : const PortalStatusChip(status: 'DRAFT', label: 'Not assigned'),
                              ),
                              DataCell(Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: LinearProgressIndicator(
                                      value: booked / total,
                                      color: pct > 75 ? AbraColors.teal : AbraColors.blue,
                                      backgroundColor: AbraColors.lightGray,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('$booked/${t.totalSeats}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              )),
                              DataCell(Text(_formatRs(t.startingFarePaise), style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(PortalStatusChip(status: t.status)),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 18),
                                      tooltip: 'View details & manifest',
                                      onPressed: () => _showTripDetail(context, t),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (val) {
                                        if (val == 'driver') _assignDriver(context, t);
                                        if (val == 'publish') _publishTrip(context, t);
                                        if (val == 'delay') _delayTrip(context, t);
                                        if (val == 'cancel') _cancelTrip(context, t);
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'driver', child: Text('Assign Driver')),
                                        if (t.status == 'DRAFT')
                                          const PopupMenuItem(value: 'publish', child: Text('Publish')),
                                        if (t.status != 'CANCELLED' && t.status != 'ARRIVED') ...[
                                          const PopupMenuItem(value: 'delay', child: Text('Delay Trip')),
                                          const PopupMenuItem(
                                            value: 'cancel',
                                            child: Text('Cancel Trip', style: TextStyle(color: AbraColors.danger)),
                                          ),
                                        ],
                                      ],
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

  Future<void> _publishTrip(BuildContext context, ClientTripItem trip) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AbraLocalizations.of(context);
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await client.post('client/trips/${trip.id}/publish');
      _refresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('Published. Customers can book it now.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureText(l10n, e)), backgroundColor: AbraColors.danger),
      );
    }
  }

  void _showTripDetail(BuildContext context, ClientTripItem trip) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _TripDetailDialog(
        trip: trip,
        onRefresh: _refresh,
        onAssignDriver: () => _assignDriver(context, trip),
        onDelay: () => _delayTrip(context, trip),
        onCancel: () => _cancelTrip(context, trip),
        onPublish: () => _publishTrip(context, trip),
      ),
    );
  }

  void _delayTrip(BuildContext context, ClientTripItem trip) {
    final minCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delay ${trip.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Delay (minutes)', hintText: 'Enter 5 to 720'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (customers see it)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final mins = int.tryParse(minCtrl.text.trim()) ?? 0;
              final reason = reasonCtrl.text.trim();
              if (mins < 5 || mins > 720 || reason.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Enter minutes between 5 and 720, and a reason.')),
                );
                return;
              }
              final nav = Navigator.of(ctx);
              try {
                final client = ref.read(appDependenciesProvider).apiClient;
                await client.post('client/trips/${trip.id}/delay', body: {
                  'delayMinutes': mins,
                  'reason': reason,
                });
                nav.pop();
                _refresh();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Delayed. Passengers and Abra were notified.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to delay: $e'), backgroundColor: AbraColors.danger),
                );
              }
            },
            child: const Text('Delay and notify'),
          ),
        ],
      ),
    );
  }

  void _cancelTrip(BuildContext context, ClientTripItem trip) {
    final reasonCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ${trip.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AbraColors.dangerContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AbraColors.danger.withAlpha(50)),
              ),
              child: const Text(
                'Bookings get a full refund. You bear the refund because you cancelled.',
                style: TextStyle(color: AbraColors.danger, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason for cancellation', hintText: 'Enter reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep trip')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cancellation reason is required.')),
                );
                return;
              }
              final nav = Navigator.of(ctx);
              try {
                final client = ref.read(appDependenciesProvider).apiClient;
                await client.post('client/trips/${trip.id}/cancel', body: {'reason': reason});
                nav.pop();
                _refresh();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cancelled. Refunds started, passengers notified.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: AbraColors.danger),
                );
              }
            },
            child: const Text('Cancel trip and refund'),
          ),
        ],
      ),
    );
  }

  void _assignDriver(BuildContext context, ClientTripItem trip) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      final res = await client.get('client/crew', query: {'role': 'DRIVER', 'status': 'ACTIVE', 'pageSize': 100});
      final List<Map<String, dynamic>> drivers = [];
      if (res.data is List) {
        for (final raw in res.data as List) {
          if (raw is Map<String, dynamic>) drivers.add(raw);
        }
      } else if (res.data is Map && (res.data as Map)['items'] is List) {
        for (final raw in (res.data as Map)['items'] as List) {
          if (raw is Map<String, dynamic>) drivers.add(raw);
        }
      }

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Driver for ${trip.id}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a driver for this departure:', style: TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                const SizedBox(height: 12),
                if (drivers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No active drivers found. Add drivers in Crew management first.'),
                  )
                else
                  for (final d in drivers)
                    ListTile(
                      leading: const Icon(Icons.person, color: AbraColors.blue),
                      title: Text(d['name'] as String? ?? 'Driver'),
                      subtitle: Text('${d['phone'] ?? ''} • DL: ${d['licenseNumber'] ?? d['licence'] ?? 'N/A'}'),
                      trailing: (trip.driver == d['name'])
                          ? const Icon(Icons.check, color: AbraColors.teal)
                          : null,
                      onTap: () async {
                        final nav = Navigator.of(ctx);
                        try {
                          await client.post('client/trips/${trip.id}/driver', body: {
                            'driverId': d['id'],
                          });
                          nav.pop();
                          _refresh();
                          messenger.showSnackBar(
                            SnackBar(content: Text('${d['name']} assigned')),
                          );
                        } catch (err) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed: $err'), backgroundColor: AbraColors.danger),
                          );
                        }
                      },
                    ),
              ],
            ),
          ),
          actions: [
            if (trip.driver != null && trip.driver!.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  try {
                    await client.post('client/trips/${trip.id}/driver', body: {'driverId': null});
                    nav.pop();
                    _refresh();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Driver removed')),
                    );
                  } catch (err) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed: $err'), backgroundColor: AbraColors.danger),
                    );
                  }
                },
                child: const Text('Remove driver', style: TextStyle(color: AbraColors.danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load drivers: $e'), backgroundColor: AbraColors.danger),
      );
    }
  }

  void _showAddTripDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      final routesRes = await client.get('client/routes', query: {'pageSize': 100});
      final busesRes = await client.get('client/buses', query: {'pageSize': 100, 'status': 'ACTIVE'});

      final List<Map<String, dynamic>> routes = [];
      if (routesRes.data is List) {
        for (final r in routesRes.data as List) {
          if (r is Map<String, dynamic>) routes.add(r);
        }
      } else if (routesRes.data is Map && (routesRes.data as Map)['items'] is List) {
        for (final r in (routesRes.data as Map)['items'] as List) {
          if (r is Map<String, dynamic>) routes.add(r);
        }
      }

      final List<Map<String, dynamic>> buses = [];
      if (busesRes.data is List) {
        for (final b in busesRes.data as List) {
          if (b is Map<String, dynamic>) buses.add(b);
        }
      } else if (busesRes.data is Map && (busesRes.data as Map)['items'] is List) {
        for (final b in (busesRes.data as Map)['items'] as List) {
          if (b is Map<String, dynamic>) buses.add(b);
        }
      }

      if (!context.mounted) return;

      if (routes.isEmpty || buses.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please ensure you have at least one route and one active bus before adding a trip.'),
          ),
        );
        return;
      }

      String selectedRouteId = routes.first['id'] as String;
      String selectedBusId = buses.first['id'] as String;
      final now = DateTime.now().add(const Duration(days: 1));
      final dateCtrl = TextEditingController(text: now.toIso8601String().substring(0, 10));
      final timeCtrl = TextEditingController();
      final fareCtrl = TextEditingController();
      bool publishImmediately = false;

      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: const Text('New trip'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedRouteId,
                      decoration: const InputDecoration(labelText: 'Route'),
                      items: routes.map((r) => DropdownMenuItem<String>(
                        value: r['id'] as String,
                        child: Text(r['name'] as String? ?? 'Route'),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedRouteId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBusId,
                      decoration: const InputDecoration(labelText: 'Bus'),
                      items: buses.map((b) => DropdownMenuItem<String>(
                        value: b['id'] as String,
                        child: Text('${b['registrationNumber'] ?? b['name']} (${b['seatCapacity'] ?? 36} seats)'),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedBusId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(labelText: 'Travel Date (YYYY-MM-DD)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeCtrl,
                      decoration: const InputDecoration(labelText: 'Departure Time (HH:MM)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fareCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Starting Fare (₹)', suffixText: 'per seat'),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Publish immediately (put on sale)', style: TextStyle(fontSize: 13)),
                      value: publishImmediately,
                      onChanged: (val) => setDlgState(() => publishImmediately = val ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final fareVal = (double.tryParse(fareCtrl.text.trim()) ?? 0) * 100;
                  final nav = Navigator.of(ctx);
                  final l10n = AbraLocalizations.of(ctx);
                  try {
                    await client.post('client/trips', body: {
                      'routeId': selectedRouteId,
                      'busId': selectedBusId,
                      'travelDate': dateCtrl.text.trim(),
                      'departureTime': timeCtrl.text.trim(),
                      'startingFarePaise': fareVal.round(),
                      'publish': publishImmediately,
                    });
                    nav.pop();
                    _refresh();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(publishImmediately ? 'Published. Customers can book it now.' : 'Trip created as draft.'),
                      ),
                    );
                  } catch (err) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(failureText(l10n, err)),
                        backgroundColor: AbraColors.danger,
                      ),
                    );
                  }
                },
                child: const Text('Create trip'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to prepare trip form: $e'), backgroundColor: AbraColors.danger),
      );
    }
  }
}

// ===== 4. TRIP DETAILS & SEATS DIALOG =====

class _TripDetailDialog extends ConsumerStatefulWidget {
  const _TripDetailDialog({
    required this.trip,
    required this.onRefresh,
    required this.onAssignDriver,
    required this.onDelay,
    required this.onCancel,
    required this.onPublish,
  });

  final ClientTripItem trip;
  final VoidCallback onRefresh;
  final VoidCallback onAssignDriver;
  final VoidCallback onDelay;
  final VoidCallback onCancel;
  final VoidCallback onPublish;

  @override
  ConsumerState<_TripDetailDialog> createState() => _TripDetailDialogState();
}

class _TripDetailDialogState extends ConsumerState<_TripDetailDialog> {
  List<ClientSeatItem>? _seats;
  bool _loadingSeats = false;
  String? _seatsError;

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    setState(() {
      _loadingSeats = true;
      _seatsError = null;
    });
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      final res = await client.get('client/trips/${widget.trip.id}/seats');
      final List<ClientSeatItem> seats = [];
      if (res.data is List) {
        for (final raw in res.data as List) {
          if (raw is Map<String, dynamic>) {
            seats.add(ClientSeatItem.fromJson(raw));
          }
        }
      }
      setState(() {
        _seats = seats;
        _loadingSeats = false;
      });
    } catch (err) {
      setState(() {
        _seatsError = err.toString();
        _loadingSeats = false;
      });
    }
  }

  Future<void> _blockSeat(ClientSeatItem seat) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block seat ${seat.seatNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Blocking a seat holds it from public customer search and bookings.'),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for blocking')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block seat')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await client.post('client/trips/${widget.trip.id}/seats/block', body: {
        'seatNumbers': [seat.seatNumber],
        'reason': reasonCtrl.text.trim(),
      });
      await _loadSeats();
      widget.onRefresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('Seat(s) blocked.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AbraColors.danger),
      );
    }
  }

  Future<void> _unblockSeat(ClientSeatItem seat) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await client.post('client/trips/${widget.trip.id}/seats/unblock', body: {
        'seatNumbers': [seat.seatNumber],
      });
      await _loadSeats();
      widget.onRefresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('Seat(s) unblocked.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AbraColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final dep = t.departureAt.isNotEmpty && t.departureAt.contains('T')
        ? t.departureAt.replaceAll('T', ' ').substring(0, 16)
        : '${t.travelDate} ${t.departureTime}';

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('${t.id} · ${t.route}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PortalStatusChip(status: t.status),
                  const SizedBox(width: 10),
                  Text(dep, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('• ${t.bus} • ${t.busType}', style: const TextStyle(color: AbraColors.textSecondary)),
                ],
              ),
              if (t.status == 'DELAYED') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AbraColors.orangeContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: AbraColors.orangeDark),
                      const SizedBox(width: 8),
                      Text(
                        'Delayed by ${t.delayMinutes ?? 0} min${t.delayReason != null ? ': ${t.delayReason}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AbraColors.orangeDark),
                      ),
                    ],
                  ),
                ),
              ],
              if (t.status == 'CANCELLED') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AbraColors.dangerContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18, color: AbraColors.danger),
                      const SizedBox(width: 8),
                      Text(
                        'Cancelled${t.cancellationReason != null ? ': ${t.cancellationReason}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AbraColors.danger),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AbraColors.lightGray,
                  borderRadius: BorderRadius.circular(AbraRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Driver', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(t.driver ?? 'Unassigned', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Booked / Seats', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text('${t.bookedSeats} / ${t.totalSeats}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Blocked', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text('${t.blockedSeats}', style: const TextStyle(fontWeight: FontWeight.bold, color: AbraColors.orangeDark)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Base Fare', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(_formatRs(t.startingFarePaise), style: const TextStyle(fontWeight: FontWeight.bold, color: AbraColors.tealDark)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Seat Inventory', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Row(
                    children: [
                      _seatLegend(Colors.white, AbraColors.border, 'Free'),
                      const SizedBox(width: 8),
                      _seatLegend(AbraColors.blue, AbraColors.blue, 'Booked'),
                      const SizedBox(width: 8),
                      _seatLegend(AbraColors.orangeDark, AbraColors.orangeDark, 'Blocked'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loadingSeats)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_seatsError != null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Seats unavailable for draft trip until published.', style: TextStyle(color: AbraColors.textSecondary)),
                )
              else if (_seats == null || _seats!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No seat layout generated yet.', style: TextStyle(color: AbraColors.textSecondary)),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _seats!.map((s) {
                    Color bg = Colors.white;
                    Color textCol = AbraColors.textPrimary;
                    Color borderCol = AbraColors.border;

                    if (s.status == 'BOOKED') {
                      bg = AbraColors.blue;
                      textCol = Colors.white;
                      borderCol = AbraColors.blue;
                    } else if (s.status == 'BLOCKED') {
                      bg = AbraColors.orangeDark;
                      textCol = Colors.white;
                      borderCol = AbraColors.orangeDark;
                    }

                    return InkWell(
                      onTap: () {
                        if (s.status == 'AVAILABLE') {
                          _blockSeat(s);
                        } else if (s.status == 'BLOCKED') {
                          _unblockSeat(s);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: bg,
                          border: Border.all(color: borderCol),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            s.seatNumber,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textCol),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Export Manifest (CSV)'),
          onPressed: () {
            if (t.bookedSeats == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No bookings yet.')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exporting manifest for ${t.id}...')),
              );
            }
          },
        ),
        if (t.status == 'DRAFT')
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onPublish();
            },
            child: const Text('Publish Trip'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Widget _seatLegend(Color bg, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
      ],
    );
  }
}
