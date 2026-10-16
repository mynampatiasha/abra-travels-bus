import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'marketing_mock_store.dart';

/// Popular Routes screen matching prototypes/admin_demo_model.html.
class AdminPopularRoutesPage extends ConsumerStatefulWidget {
  const AdminPopularRoutesPage({super.key});

  @override
  ConsumerState<AdminPopularRoutesPage> createState() =>
      _AdminPopularRoutesPageState();
}

class _AdminPopularRoutesPageState
    extends ConsumerState<AdminPopularRoutesPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketingState = ref.watch(marketingStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    final sortedRoutes = List<PopularRouteRecord>.from(marketingState.popularRoutes)
      ..sort((a, b) => a.order.compareTo(b.order));

    final filtered = sortedRoutes.where((r) {
      if (_searchQuery.isNotEmpty) {
        return r.route.toLowerCase().contains(_searchQuery.toLowerCase());
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
                  'Marketing',
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
                  'Popular routes',
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
                      'Popular routes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shown on the customer app home and the public website.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddRouteDialog(context, sortedRoutes),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search popular routes...',
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
            const SizedBox(height: 16),

            // Routes DataTable
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
                        child: Text('No routes found'),
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
                          DataColumn(label: Text('Order')),
                          DataColumn(label: Text('Route')),
                          DataColumn(label: Text('Searches (30 d)')),
                          DataColumn(label: Text('Bookings (30 d)')),
                          DataColumn(label: Text('Shown')),
                        ],
                        rows: filtered.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final r = entry.value;
                          final isFirst = idx == 0;
                          final isLast = idx == filtered.length - 1;

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${r.order}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_upward,
                                          size: 16),
                                      tooltip: 'Move up',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: isFirst
                                          ? null
                                          : () {
                                              ref
                                                  .read(marketingStoreProvider
                                                      .notifier)
                                                  .movePopularRoute(r.id, -1);
                                            },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_downward,
                                          size: 16),
                                      tooltip: 'Move down',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: isLast
                                          ? null
                                          : () {
                                              ref
                                                  .read(marketingStoreProvider
                                                      .notifier)
                                                  .movePopularRoute(r.id, 1);
                                            },
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.route,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              DataCell(Text('${r.searches}')),
                              DataCell(Text('${r.bookings}')),
                              DataCell(
                                Switch(
                                  value: r.active,
                                  activeTrackColor: AbraColors.blue,
                                  onChanged: (_) {
                                    ref
                                        .read(marketingStoreProvider.notifier)
                                        .togglePopularRoute(r.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(r.active
                                            ? 'Hidden from home screen'
                                            : 'Shown on home screen'),
                                      ),
                                    );
                                  },
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

  void _showAddRouteDialog(
      BuildContext context, List<PopularRouteRecord> existing) {
    const candidateRoutes = [
      'Pune to Mumbai',
      'Mumbai to Pune',
      'Hyderabad to Warangal',
      'Warangal to Hyderabad',
      'Vijayawada to Visakhapatnam',
      'Visakhapatnam to Vijayawada',
      'Bengaluru to Mysuru',
      'Mysuru to Bengaluru',
      'Coimbatore to Kochi',
    ];

    final available = candidateRoutes
        .where((r) => !existing.any((e) => e.route == r))
        .toList();

    String selected = available.isNotEmpty ? available.first : '';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Add popular route'),
              content: available.isEmpty
                  ? const Text('All available routes are already featured.')
                  : DropdownButtonFormField<String>(
                      initialValue: selected,
                      decoration: const InputDecoration(
                        labelText: 'Select route',
                        border: OutlineInputBorder(),
                      ),
                      items: available.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selected = val);
                        }
                      },
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                if (available.isNotEmpty)
                  ElevatedButton(
                    onPressed: () {
                      if (selected.isEmpty) return;
                      ref
                          .read(marketingStoreProvider.notifier)
                          .addPopularRoute(selected);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added $selected to popular routes')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AbraColors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
