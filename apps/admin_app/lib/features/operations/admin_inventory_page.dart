import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'operations_mock_store.dart';

/// Seat Inventory Monitor page matching prototypes/admin_demo_model.html.
class AdminInventoryPage extends ConsumerStatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  ConsumerState<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends ConsumerState<AdminInventoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedOperator = 'ALL';
  String _selectedOccupancy = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opsState = ref.watch(operationsStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    final now = DateTime.now();
    final trips = opsState.inventoryTrips;
    final totalSold = trips.fold<int>(0, (sum, t) => sum + t.booked);
    final totalHeld = trips.fold<int>(0, (sum, t) => sum + t.held);
    final lowOccupancyCount =
        trips.where((t) => t.isLowOccupancy(now)).length;

    final filtered = trips.where((t) {
      if (_selectedOperator != 'ALL' && t.operator != _selectedOperator) {
        return false;
      }
      if (_selectedOccupancy == 'low' && t.occupancy >= 0.25) return false;
      if (_selectedOccupancy == 'high' && t.occupancy <= 0.8) return false;
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
                  'Seat inventory',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seat inventory monitor',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sold, held and blocked seats across upcoming trips.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(operationsStoreProvider.notifier)
                        .releaseExpiredHolds();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Expired holds released. Seats are back on sale.'),
                        backgroundColor: Color(0xFF16A34A),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Release expired holds'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4 KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final kpiItems = [
                  _buildKpiCard(
                    'Trips on sale',
                    '${trips.length}',
                    null,
                    Icons.directions_bus_outlined,
                    surfaceColor,
                    borderColor,
                    isDark,
                  ),
                  _buildKpiCard(
                    'Seats sold',
                    '$totalSold',
                    null,
                    Icons.confirmation_number_outlined,
                    surfaceColor,
                    borderColor,
                    isDark,
                  ),
                  _buildKpiCard(
                    'Seats held right now',
                    '$totalHeld',
                    'Hold time is 10 minutes',
                    Icons.timer_outlined,
                    surfaceColor,
                    borderColor,
                    isDark,
                    isWarning: totalHeld > 0,
                  ),
                  _buildKpiCard(
                    'Low occupancy, in 2 days',
                    '$lowOccupancyCount',
                    lowOccupancyCount > 0 ? 'Check pricing' : '',
                    Icons.warning_amber_rounded,
                    surfaceColor,
                    borderColor,
                    isDark,
                    isAlert: lowOccupancyCount > 0,
                  ),
                ];

                if (!isWide) {
                  return Column(
                    children: kpiItems
                        .map((k) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: k,
                            ))
                        .toList(),
                  );
                }

                return Row(
                  children: kpiItems
                      .map((k) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: k,
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // Filter Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search by trip ID, route, operator, or bus...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedOperator,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem(
                          value: 'ALL', child: Text('Operator: All')),
                      ...{...trips.map((t) => t.operator)}.map((op) {
                        return DropdownMenuItem(value: op, child: Text(op));
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedOperator = val ?? 'ALL');
                    },
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedOccupancy,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'ALL', child: Text('Occupancy: All')),
                      DropdownMenuItem(
                          value: 'low', child: Text('Under 25% (Low)')),
                      DropdownMenuItem(
                          value: 'high', child: Text('Over 80% (High)')),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedOccupancy = val ?? 'ALL');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DataTable
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No trips match the inventory filters'),
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                        ),
                        columns: const [
                          DataColumn(label: Text('Trip')),
                          DataColumn(label: Text('Route')),
                          DataColumn(label: Text('Departs')),
                          DataColumn(label: Text('Sold')),
                          DataColumn(label: Text('Held')),
                          DataColumn(label: Text('Blocked')),
                          DataColumn(label: Text('Free')),
                          DataColumn(label: Text('Occupancy')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: filtered.map((trip) {
                          final occPct = (trip.occupancy * 100).round();
                          final isLow = trip.occupancy < 0.25;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  trip.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AbraColors.blue,
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      trip.route,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      trip.operator,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFF8BA2B9)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${trip.depart.day}/${trip.depart.month} ${trip.depart.hour}:${trip.depart.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${trip.booked}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              DataCell(
                                trip.held > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF332005)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${trip.held}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFFFCD34D)
                                                : const Color(0xFFB45309),
                                          ),
                                        ),
                                      )
                                    : const Text('0'),
                              ),
                              DataCell(Text('${trip.blocked}')),
                              DataCell(
                                Text(
                                  '${trip.free}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: trip.free < 5
                                        ? const Color(0xFFDC2626)
                                        : null,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 110,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$occPct%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isLow
                                              ? const Color(0xFFD97706)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      LinearProgressIndicator(
                                        value: trip.occupancy.clamp(0.0, 1.0),
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFE2E8F0),
                                        color: isLow
                                            ? const Color(0xFFF59E0B)
                                            : AbraColors.blue,
                                        minHeight: 4,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                OutlinedButton(
                                  onPressed: () =>
                                      _showTripSeatMapModal(context, trip),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Seat map'),
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
    );
  }

  Widget _buildKpiCard(
    String label,
    String value,
    String? sub,
    IconData icon,
    Color surfaceColor,
    Color borderColor,
    bool isDark, {
    bool isAlert = false,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert
              ? const Color(0xFFDC2626)
              : (isWarning ? const Color(0xFFD97706) : borderColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isAlert
                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                  : (isDark
                      ? const Color(0xFF0C2237)
                      : const Color(0xFFE0F2FE)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isAlert
                  ? const Color(0xFFDC2626)
                  : (isWarning ? const Color(0xFFD97706) : AbraColors.blue),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isAlert
                          ? const Color(0xFFDC2626)
                          : (isDark
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFB45309)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTripSeatMapModal(BuildContext context, InventoryTripRecord trip) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('${trip.id} - Seat layout & inventory'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip.route} (${trip.bus})',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Operator: ${trip.operator}  •  Driver: ${trip.driver}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegend(const Color(0xFF16A34A), 'Available'),
                      _buildLegend(const Color(0xFF0284C7), 'Sold (${trip.booked})'),
                      _buildLegend(const Color(0xFFD97706), 'Held (${trip.held})'),
                      _buildLegend(const Color(0xFF64748B), 'Blocked (${trip.blocked})'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Seat Grid Mockup
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.drive_eta, color: Colors.grey),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(trip.seats, (idx) {
                              Color seatColor;
                              if (idx < trip.booked) {
                                seatColor = const Color(0xFF0284C7);
                              } else if (idx < trip.booked + trip.held) {
                                seatColor = const Color(0xFFD97706);
                              } else if (idx <
                                  trip.booked + trip.held + trip.blocked) {
                                seatColor = const Color(0xFF64748B);
                              } else {
                                seatColor = const Color(0xFF16A34A);
                              }

                              return Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: seatColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
