import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_theme/shared_theme.dart';

import '../sales/sales_mock_store.dart';
import 'operations_mock_store.dart';

/// Admin Trips page matching prototypes/admin_demo_model.html.
class AdminTripsPage extends ConsumerStatefulWidget {
  const AdminTripsPage({super.key});

  @override
  ConsumerState<AdminTripsPage> createState() => _AdminTripsPageState();
}

class _AdminTripsPageState extends ConsumerState<AdminTripsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedOperator = 'ALL';
  String _selectedStatus = 'ALL';
  String _selectedRoute = 'ALL';
  String _selectedWhen = 'ALL'; // ALL, today, upcoming, past
  String? _selectedTripId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return AbraColors.blue;
      case 'BOARDING':
        return Colors.orange.shade700;
      case 'LIVE':
      case 'IN_TRANSIT':
      case 'DEPARTED':
        return Colors.green.shade700;
      case 'DELAYED':
        return Colors.amber.shade800;
      case 'CANCELLED':
        return Colors.red.shade700;
      case 'ARRIVED':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final opsState = ref.watch(operationsStoreProvider);
    final salesState = ref.watch(salesStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    final now = DateTime.now();
    final trips = opsState.inventoryTrips;

    // Distinct operators and routes for filter dropdowns
    final operators = trips.map((t) => t.operator).toSet().toList()..sort();
    final routes = trips.map((t) => t.route).toSet().toList()..sort();

    // If a trip is selected for detail view, show trip detail drilldown
    if (_selectedTripId != null) {
      final trip = trips.firstWhere(
        (t) => t.id == _selectedTripId,
        orElse: () => trips.first,
      );
      final tripBookings = salesState.bookings
          .where((b) => b.tripId == trip.id)
          .toList();

      return _TripDetailView(
        trip: trip,
        bookings: tripBookings,
        isDark: isDark,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        onBack: () => setState(() => _selectedTripId = null),
      );
    }

    final filtered = trips.where((t) {
      if (_selectedOperator != 'ALL' && t.operator != _selectedOperator) {
        return false;
      }
      if (_selectedStatus != 'ALL' && t.status != _selectedStatus) {
        return false;
      }
      if (_selectedRoute != 'ALL' && t.route != _selectedRoute) {
        return false;
      }
      if (_selectedWhen == 'today') {
        final diff = t.depart.difference(now).inHours;
        if (diff < -12 || diff > 24) return false;
      } else if (_selectedWhen == 'upcoming') {
        if (t.depart.isBefore(now)) return false;
      } else if (_selectedWhen == 'past') {
        if (t.depart.isAfter(now)) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = t.id.toLowerCase().contains(q) ||
            t.route.toLowerCase().contains(q) ||
            t.operator.toLowerCase().contains(q) ||
            t.bus.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: [
                Text(
                  'Operations',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Trips',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trips',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Every trip. Operators publish their own; here you can step in when something goes wrong.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFF8BA2B9)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddTripDialog(context, operators, routes),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add trip for operator'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Bar Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search box
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search by trip ID, route, operator, bus...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Operator dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedOperator,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Operator',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'ALL',
                              child: Text('All operators'),
                            ),
                            ...operators.map((op) => DropdownMenuItem(
                                  value: op,
                                  child: Text(op),
                                )),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedOperator = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                            DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                            DropdownMenuItem(value: 'BOARDING', child: Text('Boarding')),
                            DropdownMenuItem(value: 'DEPARTED', child: Text('Departed')),
                            DropdownMenuItem(value: 'IN_TRANSIT', child: Text('In transit')),
                            DropdownMenuItem(value: 'DELAYED', child: Text('Delayed')),
                            DropdownMenuItem(value: 'ARRIVED', child: Text('Arrived')),
                            DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStatus = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Export button
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Exporting ${trips.length} trips as CSV...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Export'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Route and When pills
                  Row(
                    children: [
                      // Route Dropdown
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedRoute,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Route',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'ALL',
                              child: Text('All routes'),
                            ),
                            ...routes.map((rt) => DropdownMenuItem(
                                  value: rt,
                                  child: Text(rt, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedRoute = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // When filter chips
                      Text(
                        'When: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildWhenChip('ALL', 'All'),
                          _buildWhenChip('today', 'Today'),
                          _buildWhenChip('upcoming', 'Upcoming'),
                          _buildWhenChip('past', 'Past'),
                        ],
                      ),
                      const Spacer(),

                      // Reset Filters button if any filter applied
                      if (_selectedOperator != 'ALL' ||
                          _selectedStatus != 'ALL' ||
                          _selectedRoute != 'ALL' ||
                          _selectedWhen != 'ALL' ||
                          _searchQuery.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _selectedOperator = 'ALL';
                              _selectedStatus = 'ALL';
                              _selectedRoute = 'ALL';
                              _selectedWhen = 'ALL';
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset filters'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trips Table Card
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No trips match the selected filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try changing or clearing your search criteria',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2), // Trip ID
                          1: FlexColumnWidth(2.5), // Route & Operator
                          2: FlexColumnWidth(1.5), // Bus
                          3: FlexColumnWidth(1.6), // Departs
                          4: FlexColumnWidth(1.3), // Status
                          5: FlexColumnWidth(1.6), // Seats & occupancy bar
                          6: FlexColumnWidth(1.1), // Starting Fare
                          7: FlexColumnWidth(1.0), // Actions
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          // Table Header
                          TableRow(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              border: Border(bottom: BorderSide(color: borderColor)),
                            ),
                            children: const [
                              _HeaderCell('Trip'),
                              _HeaderCell('Route'),
                              _HeaderCell('Bus'),
                              _HeaderCell('Departs'),
                              _HeaderCell('Status'),
                              _HeaderCell('Seats'),
                              _HeaderCell('From'),
                              _HeaderCell('Action'),
                            ],
                          ),
                          // Data Rows
                          for (final trip in filtered)
                            TableRow(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: borderColor)),
                              ),
                              children: [
                                // Trip ID
                                InkWell(
                                  onTap: () => setState(() => _selectedTripId = trip.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      trip.id,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AbraColors.blue,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),

                                // Route (bold) and Operator underneath
                                InkWell(
                                  onTap: () => setState(() => _selectedTripId = trip.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip.route,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          trip.operator,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Bus
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    trip.bus,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),

                                // Departs
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    DateFormat('dd MMM, HH:mm').format(trip.depart),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),

                                // Status chip
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(trip.status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _statusColor(trip.status).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        trip.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor(trip.status),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Seats occupancy ratio & visual progress bar
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${trip.booked}/${trip.seats} (${(trip.occupancy * 100).round()}%)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: trip.isLowOccupancy(now)
                                              ? Colors.amber.shade900
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: SizedBox(
                                          height: 6,
                                          child: LinearProgressIndicator(
                                            value: trip.occupancy.clamp(0.0, 1.0),
                                            backgroundColor: isDark
                                                ? Colors.white12
                                                : Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              trip.isLowOccupancy(now)
                                                  ? Colors.amber.shade700
                                                  : AbraColors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // From fare
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    '₹${(trip.fare / 100).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                // Action: Open button
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: TextButton(
                                    onPressed: () => setState(
                                      () => _selectedTripId = trip.id,
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                    child: const Text('Open →'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhenChip(String key, String label) {
    final isSelected = _selectedWhen == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedWhen = key),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AbraColors.blue,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showAddTripDialog(
    BuildContext context,
    List<String> operators,
    List<String> routes,
  ) {
    final formKey = GlobalKey<FormState>();
    String selectedOp = operators.isNotEmpty ? operators.first : 'Kaveri Express';
    String selectedRt = routes.isNotEmpty ? routes.first : 'Bengaluru to Hyderabad';
    String busReg = 'KA01 AB 9021';
    DateTime travelDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay departTime = const TimeOfDay(hour: 21, minute: 0);
    double fare = 1100.0;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add trip for an operator'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedOp,
                          decoration: const InputDecoration(
                            labelText: 'Operator',
                            border: OutlineInputBorder(),
                          ),
                          items: operators
                              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => selectedOp = val);
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRt,
                          decoration: const InputDecoration(
                            labelText: 'Route',
                            border: OutlineInputBorder(),
                          ),
                          items: routes
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => selectedRt = val);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: busReg,
                          decoration: const InputDecoration(
                            labelText: 'Bus registration number',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => busReg = val.trim(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: travelDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 60)),
                                  );
                                  if (picked != null) {
                                    setDlgState(() => travelDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(DateFormat('dd MMM yyyy').format(travelDate)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: departTime,
                                  );
                                  if (picked != null) {
                                    setDlgState(() => departTime = picked);
                                  }
                                },
                                icon: const Icon(Icons.access_time, size: 16),
                                label: Text(departTime.format(context)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: fare.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Lowest ticket fare (₹)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => fare = double.tryParse(val) ?? 1000.0,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Text(
                            'The bus must be active. Operators can refine seat tier fares from their client portal later.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final departDateTime = DateTime(
                      travelDate.year,
                      travelDate.month,
                      travelDate.day,
                      departTime.hour,
                      departTime.minute,
                    );
                    final newId = 'TRP-${3010 + DateTime.now().millisecond}';
                    ref.read(operationsStoreProvider.notifier).addTrip(
                          InventoryTripRecord(
                            id: newId,
                            route: selectedRt,
                            operator: selectedOp,
                            operatorId: 'OP-${selectedOp.hashCode}',
                            depart: departDateTime,
                            status: 'SCHEDULED',
                            seats: 36,
                            booked: 0,
                            held: 0,
                            blocked: 0,
                            fare: (fare * 100).toInt(),
                            bus: busReg,
                            driver: 'Not assigned',
                            conductor: 'Not assigned',
                          ),
                        );
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Trip $newId created successfully')),
                    );
                  },
                  child: const Text('Create trip'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }
}

/// Detailed Trip Screen matching prototypes/admin_demo_model.html (tripDetail).
class _TripDetailView extends ConsumerStatefulWidget {
  const _TripDetailView({
    required this.trip,
    required this.bookings,
    required this.isDark,
    required this.surfaceColor,
    required this.borderColor,
    required this.onBack,
  });

  final InventoryTripRecord trip;
  final List<BookingRecord> bookings;
  final bool isDark;
  final Color surfaceColor;
  final Color borderColor;
  final VoidCallback onBack;

  @override
  ConsumerState<_TripDetailView> createState() => _TripDetailViewState();
}

class _TripDetailViewState extends ConsumerState<_TripDetailView> {
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return AbraColors.blue;
      case 'BOARDING':
        return Colors.orange.shade700;
      case 'LIVE':
      case 'IN_TRANSIT':
      case 'DEPARTED':
        return Colors.green.shade700;
      case 'DELAYED':
        return Colors.amber.shade800;
      case 'CANCELLED':
        return Colors.red.shade700;
      case 'ARRIVED':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isLive = ['SCHEDULED', 'BOARDING', 'DELAYED', 'IN_TRANSIT', 'DEPARTED']
        .contains(trip.status);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs & Back link
            Row(
              children: [
                InkWell(
                  onTap: widget.onBack,
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Trips',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AbraColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  trip.id,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Header Row with Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.route,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${trip.id}  •  ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(trip.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              trip.status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(trip.status),
                              ),
                            ),
                          ),
                          Text(
                            '  •  ${trip.operator}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Operational Action buttons (Delay, Change driver, Cancel trip)
                if (isLive)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showDelayDialog(context, trip),
                        icon: const Icon(Icons.schedule, size: 16),
                        label: const Text('Delay'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showChangeDriverDialog(context, trip),
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: const Text('Change driver'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _showCancelTripDialog(context, trip),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancel trip'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Two-column body: Left (Seat Map) & Right (Details + Timeline)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Interactive Seat Map
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Seat map',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${trip.seats} total seats',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a free seat to block it (counter sale or damage). Held seats belong to customers who are paying.',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? const Color(0xFF8BA2B9)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Seat Grid
                        _buildSeatGrid(trip),
                        const SizedBox(height: 20),

                        // Legend
                        _buildSeatLegend(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right Column: Details Card & Timeline Card
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: widget.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _detailRow('Bus', '${trip.bus} (${trip.busType})'),
                            _detailRow(
                              'Departs',
                              DateFormat('dd MMM yyyy, HH:mm').format(trip.depart),
                            ),
                            _detailRow('Driver', trip.driver),
                            _detailRow('Conductor', trip.conductor),
                            _detailRow(
                              'Starting Fare',
                              '₹${(trip.fare / 100).toStringAsFixed(0)}',
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statBadge('Booked', trip.booked, const Color(0xFF1E3A8A)),
                                _statBadge('Held', trip.held, Colors.orange.shade800),
                                _statBadge('Blocked', trip.blocked, Colors.blueGrey),
                                _statBadge('Free', trip.free, Colors.green.shade700),
                              ],
                            ),
                            if (trip.delayMinutes > 0) ...[
                              const Divider(height: 24),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delayed by ${trip.delayMinutes} minutes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                    if (trip.delayReason.isNotEmpty)
                                      Text(
                                        'Reason: ${trip.delayReason}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            if (trip.status == 'CANCELLED') ...[
                              const Divider(height: 24),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  'Cancelled. ${trip.cancelReason.isNotEmpty ? "Reason: ${trip.cancelReason}" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Timeline Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: widget.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Timeline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _timelineEvent(
                              'Trip created',
                              'Scheduled by system',
                              Colors.green.shade600,
                            ),
                            _timelineEvent(
                              'Published by ${trip.operator}',
                              'Available for passenger bookings',
                              Colors.green.shade600,
                            ),
                            if (trip.status == 'DELAYED')
                              _timelineEvent(
                                'Delayed by ${trip.delayMinutes} min',
                                'Passengers notified by WhatsApp & SMS',
                                Colors.amber.shade700,
                              ),
                            if (trip.status == 'CANCELLED')
                              _timelineEvent(
                                'Trip cancelled',
                                'Full refunds initiated to all passengers',
                                Colors.red.shade700,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottom Section: Bookings on this trip Table
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bookings on this trip (${widget.bookings.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.bookings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No passenger bookings recorded for this trip yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.4), // PNR
                        1: FlexColumnWidth(2.0), // Customer
                        2: FlexColumnWidth(1.2), // Seats
                        3: FlexColumnWidth(1.4), // Amount
                        4: FlexColumnWidth(1.2), // Status
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: widget.borderColor)),
                          ),
                          children: const [
                            _HeaderCell('PNR'),
                            _HeaderCell('Customer'),
                            _HeaderCell('Seats'),
                            _HeaderCell('Amount'),
                            _HeaderCell('Status'),
                          ],
                        ),
                        for (final bk in widget.bookings)
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: widget.borderColor)),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  bk.pnr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AbraColors.blue,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  bk.customer,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  bk.seatList,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  '₹${(bk.amount / 100).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  bk.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: bk.status == 'CONFIRMED'
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatGrid(InventoryTripRecord trip) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(trip.seats, (idx) {
            final seatNum = idx + 1;
            final isBooked = trip.bookedSeats.contains(seatNum);
            final isHeld = trip.heldSeats.contains(seatNum);
            final isBlocked = trip.blockedSeats.contains(seatNum);

            Color bgColor;
            Color textColor;
            Border? border;

            if (isBooked) {
              bgColor = const Color(0xFF1E3A8A); // Dark navy
              textColor = Colors.white;
            } else if (isHeld) {
              bgColor = Colors.orange.shade700;
              textColor = Colors.white;
            } else if (isBlocked) {
              bgColor = Colors.blueGrey.shade600;
              textColor = Colors.white;
            } else {
              bgColor = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
              textColor = widget.isDark ? Colors.white : Colors.black87;
              border = Border.all(color: Colors.grey.shade400);
            }

            return InkWell(
              onTap: () {
                if (!isBooked && !isHeld) {
                  ref.read(operationsStoreProvider.notifier).toggleSeatBlock(
                        trip.id,
                        seatNum,
                      );
                  setState(() {});
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: border,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$seatNum',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSeatLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem('Free (tap to block)', Colors.white, border: true),
        _legendItem('Booked', const Color(0xFF1E3A8A)),
        _legendItem('Held', Colors.orange.shade700),
        _legendItem('Blocked', Colors.blueGrey.shade600),
      ],
    );
  }

  Widget _legendItem(String label, Color color, {bool border = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border ? Border.all(color: Colors.grey.shade400) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _timelineEvent(String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDelayDialog(BuildContext context, InventoryTripRecord trip) {
    int minutes = 30;
    String reason = 'Traffic congestion on highway';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delay trip'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: '$minutes',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Delay in minutes (5 to 720)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => minutes = int.tryParse(val) ?? 30,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason for delay',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => reason = val.trim(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Text(
                    'Booked customers receive a WhatsApp and push notification with updated ETA.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(operationsStoreProvider.notifier).delayTrip(
                      trip.id,
                      minutes,
                      reason,
                    );
                Navigator.of(dialogCtx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Trip ${trip.id} delayed by $minutes min.'),
                  ),
                );
              },
              child: const Text('Delay and notify'),
            ),
          ],
        );
      },
    );
  }

  void _showChangeDriverDialog(BuildContext context, InventoryTripRecord trip) {
    String selectedDriver = trip.driver;
    final drivers = [
      'Ramesh K',
      'Sunil Y',
      'Anwar S',
      'Prakash M',
      'Naveen B',
      'Karthik S',
      'Thomas Mathew',
    ];

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Change driver'),
          content: SizedBox(
            width: 400,
            child: DropdownButtonFormField<String>(
              initialValue: drivers.contains(selectedDriver)
                  ? selectedDriver
                  : drivers.first,
              decoration: const InputDecoration(
                labelText: 'Driver',
                border: OutlineInputBorder(),
              ),
              items: drivers
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) {
                if (val != null) selectedDriver = val;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(operationsStoreProvider.notifier).changeDriver(
                      trip.id,
                      selectedDriver,
                    );
                Navigator.of(dialogCtx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Driver changed to $selectedDriver')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCancelTripDialog(BuildContext context, InventoryTripRecord trip) {
    String reason = 'Mechanical failure on bus';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Cancel trip ${trip.id}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    '${widget.bookings.length} confirmed booking(s) will be cancelled and refunded in full. Customers will be alerted by push and WhatsApp.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation reason',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => reason = val.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Keep trip'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () {
                ref.read(operationsStoreProvider.notifier).cancelTrip(
                      trip.id,
                      reason,
                    );
                Navigator.of(dialogCtx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Trip ${trip.id} cancelled. Refunds initiated.'),
                  ),
                );
              },
              child: const Text('Cancel trip & refund'),
            ),
          ],
        );
      },
    );
  }
}
