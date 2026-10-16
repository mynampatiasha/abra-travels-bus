import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientTripsScreen extends StatefulWidget {
  const ClientTripsScreen({super.key});

  @override
  State<ClientTripsScreen> createState() => _ClientTripsScreenState();
}

class _ClientTripsScreenState extends State<ClientTripsScreen> {
  late List<Map<String, dynamic>> _trips;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _trips = List.from(kMockTrips);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _statusFilter == 'ALL'
        ? _trips
        : _trips.where((t) => t['status'] == _statusFilter).toList();

    final onSaleCount = _trips.where((t) => t['status'] == 'SCHEDULED').length;
    final draftCount = _trips.where((t) => t['status'] == 'DRAFT').length;
    final runningCount = _trips.where((t) => ['BOARDING', 'IN_TRANSIT', 'DEPARTED', 'DELAYED'].contains(t['status'])).length;
    final noDriverCount = _trips.where((t) => (t['driver'] as String? ?? '').isEmpty && t['status'] != 'CANCELLED').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalSectionTitle(
                title: 'Trips',
                subtitle: '${_trips.length} active and scheduled departures',
                breadcrumbs: const ['Sales Setup', 'Trips'],
                actions: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add single trip'),
                    style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                    onPressed: () => _showAddTripDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),
              // 4 KPIs matching prototype
              if (isNarrow)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PortalKpiCard(
                            icon: Icons.calendar_today,
                            value: '$onSaleCount',
                            label: 'On sale',
                            iconColor: AbraColors.teal,
                          ),
                        ),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(
                          child: PortalKpiCard(
                            icon: Icons.edit_note,
                            value: '$draftCount',
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
                            value: '$runningCount',
                            label: 'Running now',
                            iconColor: AbraColors.tealDark,
                          ),
                        ),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(
                          child: PortalKpiCard(
                            icon: Icons.person_off_outlined,
                            value: '$noDriverCount',
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
                        value: '$onSaleCount',
                        label: 'On sale',
                        iconColor: AbraColors.teal,
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(
                      child: PortalKpiCard(
                        icon: Icons.edit_note,
                        value: '$draftCount',
                        label: 'Drafts',
                        iconColor: AbraColors.blue,
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(
                      child: PortalKpiCard(
                        icon: Icons.navigation_outlined,
                        value: '$runningCount',
                        label: 'Running now',
                        iconColor: AbraColors.tealDark,
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(
                      child: PortalKpiCard(
                        icon: Icons.person_off_outlined,
                        value: '$noDriverCount',
                        label: 'Without a driver',
                        iconColor: AbraColors.orangeDark,
                      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  child: Wrap(
                    spacing: 8,
                    children: ['ALL', 'SCHEDULED', 'IN_TRANSIT', 'DRAFT', 'DELAYED', 'ARRIVED', 'CANCELLED'].map((st) =>
                      ChoiceChip(
                        label: Text(st.replaceAll('_', ' ')),
                        selected: _statusFilter == st,
                        onSelected: (_) => setState(() => _statusFilter = st),
                        selectedColor: AbraColors.skyContainer,
                      ),
                    ).toList(),
                  ),
                ),
                const Divider(height: 1, color: AbraColors.divider),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.directions_outlined, size: 48, color: AbraColors.textDisabled),
                          const SizedBox(height: 12),
                          Text(
                            _statusFilter != 'ALL' ? 'No trips matching this filter' : 'No trips yet',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusFilter != 'ALL' ? 'Try selecting another status tab' : 'Publish a trip to start taking bookings.',
                            style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                          ),
                          if (_statusFilter == 'ALL') ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add single trip'),
                              style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                              onPressed: () => _showAddTripDialog(context),
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
                        DataColumn(label: Text('Trip ID')),
                        DataColumn(label: Text('Route')),
                        DataColumn(label: Text('Bus')),
                        DataColumn(label: Text('Departure')),
                        DataColumn(label: Text('Occupancy')),
                        DataColumn(label: Text('Assigned Driver')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((t) {
                        final booked = t['booked'] as int? ?? 0;
                        final total = t['seats'] as int? ?? 36;
                        final pct = total > 0 ? (booked / total * 100).round() : 0;
                        final dep = '${t['depart']}'.replaceAll('T', ' ').substring(0, 16);
                        final driver = t['driver'] as String? ?? '';
                        return DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => _showTripDetail(context, t),
                                child: Text('${t['id']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue)),
                              ),
                            ),
                            DataCell(Text('${t['route']}')),
                            DataCell(Text('${t['busName']} (${t['bus']})')),
                            DataCell(Text(dep)),
                            DataCell(Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: LinearProgressIndicator(
                                    value: total > 0 ? booked / total : 0,
                                    color: pct > 75 ? AbraColors.teal : AbraColors.blue,
                                    backgroundColor: AbraColors.lightGray,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('$booked/$total ($pct%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            )),
                            DataCell(Text(
                              driver.isNotEmpty ? driver : '⚠️ Unassigned',
                              style: TextStyle(
                                color: driver.isNotEmpty ? AbraColors.textPrimary : AbraColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            )),
                            DataCell(PortalStatusChip(status: '${t['status']}')),
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
                                      if (val == 'publish') {
                                        setState(() => t['status'] = 'SCHEDULED');
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip published')));
                                      }
                                      if (val == 'delay') _delayTrip(context, t);
                                      if (val == 'cancel') _cancelTrip(context, t);
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'driver', child: Text('Assign Driver')),
                                      if (t['status'] == 'DRAFT')
                                        const PopupMenuItem(value: 'publish', child: Text('Publish')),
                                      if (t['status'] != 'CANCELLED' && t['status'] != 'ARRIVED') ...[
                                        const PopupMenuItem(value: 'delay', child: Text('Delay Trip')),
                                        const PopupMenuItem(value: 'cancel', child: Text('Cancel Trip', style: TextStyle(color: AbraColors.danger))),
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
              ],
            ),
          ),
        ],
      ),
    );
  },
);
}

  void _showTripDetail(BuildContext context, Map<String, dynamic> trip) {
    final tripBookings = kMockBookings.where((b) => b['route'] == trip['route']).toList();
    final booked = trip['booked'] as int? ?? 0;
    final total = trip['seats'] as int? ?? 36;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${trip['id']} · ${trip['route']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PortalStatusChip(status: '${trip['status']}'),
                    const SizedBox(width: 10),
                    Text(
                      '${trip['depart']}'.replaceAll('T', ' ').substring(0, 16),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text('• ${trip['bus']} • ${trip['type']}', style: const TextStyle(color: AbraColors.textSecondary)),
                  ],
                ),
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
                          Text('${trip['driver']}'.isEmpty ? 'Unassigned' : '${trip['driver']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Booked Seats', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('$booked / $total', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Base Fare', style: TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(formatRs(trip['fare'] as int? ?? 95000), style: const TextStyle(fontWeight: FontWeight.bold, color: AbraColors.tealDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Passenger Manifest', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                if (tripBookings.isEmpty)
                  const Text('No bookings on this departure yet.', style: TextStyle(fontSize: 12, color: AbraColors.textSecondary))
                else
                  for (final b in tripBookings)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AbraColors.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${b['customer']} (${b['phone']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('PNR: ${b['pnr']} · Seats: ${(b['seats'] as List).join(", ")}', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                            ],
                          ),
                          PortalStatusChip(status: '${b['status']}'),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Manifest (CSV)'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Manifest CSV exported for ${trip['id']}')),
              );
            },
          ),
          if (trip['status'] == 'DRAFT')
            FilledButton(
              onPressed: () {
                setState(() => trip['status'] = 'SCHEDULED');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip is now on sale!')));
              },
              child: const Text('Publish Trip'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _delayTrip(BuildContext context, Map<String, dynamic> trip) {
    final minCtrl = TextEditingController(text: '30');
    final reasonCtrl = TextEditingController(text: 'Traffic congestion on departure route');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report Delay for ${trip['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Delay in minutes')),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for delay')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                trip['status'] = 'DELAYED';
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${trip['id']} marked as delayed by ${minCtrl.text}m. Passengers notified.')),
              );
            },
            child: const Text('Delay and notify'),
          ),
        ],
      ),
    );
  }

  void _cancelTrip(BuildContext context, Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ${trip['id']}?'),
        content: const Text(
          'Cancelling this trip will initiate 100% full refunds to all booked passengers charged to your account. Are you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep trip')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () {
              setState(() => trip['status'] = 'CANCELLED');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Trip ${trip['id']} cancelled. Refunds initiated.')),
              );
            },
            child: const Text('Confirm cancel & refund'),
          ),
        ],
      ),
    );
  }

  void _assignDriver(BuildContext context, Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign driver to trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: kMockCrew.where((c) => c['role'] == 'DRIVER').map((driver) =>
            ListTile(
              leading: const Icon(Icons.person, color: AbraColors.blue),
              title: Text('${driver['name']}'),
              subtitle: Text('${driver['phone']} • DL: ${driver['licence']}'),
              onTap: () {
                setState(() => trip['driver'] = driver['name']);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned ${driver['name']}')));
              },
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _showAddTripDialog(BuildContext context) {
    String route = 'Bengaluru to Hyderabad';
    String bus = 'TS09 UB 4521';
    final depCtrl = TextEditingController(text: '2026-10-25 21:30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create single trip'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: route,
                decoration: const InputDecoration(labelText: 'Route'),
                items: kMockRoutes.map((r) => DropdownMenuItem<String>(value: '${r['name']}', child: Text('${r['name']}'))).toList(),
                onChanged: (v) => route = v ?? route,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: bus,
                decoration: const InputDecoration(labelText: 'Bus'),
                items: kMockBuses.map((b) => DropdownMenuItem<String>(value: '${b['reg']}', child: Text('${b['reg']} (${b['type']})'))).toList(),
                onChanged: (v) => bus = v ?? bus,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: depCtrl,
                decoration: const InputDecoration(labelText: 'Departure date & time (YYYY-MM-DD HH:MM)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                _trips.add({
                  'id': 'TRP${_trips.length + 1}',
                  'route': route,
                  'bus': bus,
                  'busName': 'Kaveri Express',
                  'depart': depCtrl.text.replaceAll(' ', 'T'),
                  'seats': 36,
                  'booked': 0,
                  'fare': 95000,
                  'driver': '',
                  'status': 'DRAFT',
                  'type': 'AC Sleeper',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip created as draft')));
            },
            child: const Text('Create trip'),
          ),
        ],
      ),
    );
  }
}
