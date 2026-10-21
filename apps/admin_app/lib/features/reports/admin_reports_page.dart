import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _rangeDays = 30;

  final List<String> _tabs = [
    'Sales',
    'Operators',
    'Routes',
    'Cancellations',
    'Refunds',
    'Occupancy',
    'Commission',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Performance and analytics for the last $_rangeDays days.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ...[7, 30, 90].map((d) {
                      final isSelected = _rangeDays == d;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _rangeDays = d),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected ? AbraColors.navy : Colors.white,
                            foregroundColor: isSelected ? Colors.white : Colors.grey.shade800,
                            side: BorderSide(
                              color: isSelected ? AbraColors.navy : Colors.grey.shade300,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: Text('$d days'),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Not connected yet',
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export CSV'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AbraColors.navy,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AbraColors.blue,
                unselectedLabelColor: Colors.grey.shade700,
                indicatorColor: AbraColors.blue,
                indicatorWeight: 3,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Chart Container
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Padding(
                padding: EdgeInsets.all(AbraSpacing.xxl),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 48, color: AbraColors.textDisabled),
                      SizedBox(height: AbraSpacing.md),
                      Text(
                        'Not connected yet - built in Phase 7',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Table Container
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Padding(
                padding: EdgeInsets.all(AbraSpacing.xxl),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_chart_outlined, size: 48, color: AbraColors.textDisabled),
                      SizedBox(height: AbraSpacing.md),
                      Text(
                        'Not connected yet - built in Phase 7',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
