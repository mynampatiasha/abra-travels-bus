import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

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
                      'Curated list of routes shown prominently on the customer app home screen.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add popular route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AbraColors.blue,
                      foregroundColor: Colors.white,
                    ),
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
                  decoration: InputDecoration(
                    hintText: 'Search routes by origin, destination...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Content Table Card
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStatePropertyAll(
                        isDark ? const Color(0xFF102030) : const Color(0xFFF8FAFB),
                      ),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Order', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Starting Fare', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Daily Buses', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: const <DataRow>[],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(AbraSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.star_outline, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 7',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
