import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// Offers and Coupons page matching prototypes/admin_demo_model.html.
class AdminOffersPage extends ConsumerStatefulWidget {
  const AdminOffersPage({super.key});

  @override
  ConsumerState<AdminOffersPage> createState() => _AdminOffersPageState();
}

class _AdminOffersPageState extends ConsumerState<AdminOffersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedFunder = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = 'ALL';
      _selectedFunder = 'ALL';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

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
                    color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Offers and coupons',
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
                      'Offers and coupons',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discount codes. They are checked on the server when a booking is made.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New offer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AbraColors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs Header
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AbraColors.blue,
                unselectedLabelColor: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                indicatorColor: AbraColors.blue,
                indicatorWeight: 2,
                tabs: const [
                  Tab(text: 'All offers'),
                  Tab(text: 'Test a coupon'),
                  Tab(text: 'Usage report'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab View Content
            SizedBox(
              height: 600,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllOffersTab(surfaceColor, borderColor, isDark),
                  _buildTestCouponTab(surfaceColor, borderColor, isDark),
                  _buildUsageReportTab(surfaceColor, borderColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllOffersTab(Color surfaceColor, Color borderColor, bool isDark) {
    return Column(
      children: [
        // Filter Bar Card
        Container(
          padding: const EdgeInsets.all(AbraSpacing.md),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search code, description...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedStatus,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                  DropdownMenuItem(value: 'PAUSED', child: Text('Paused')),
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedFunder,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All funders')),
                  DropdownMenuItem(value: 'PLATFORM', child: Text('Platform')),
                  DropdownMenuItem(value: 'OPERATOR', child: Text('Operator')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFunder = val);
                },
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Offers Table Card
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStatePropertyAll(
                      isDark ? const Color(0xFF102030) : const Color(0xFFF8FAFB),
                    ),
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Discount', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Scope & Funder', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Per user', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Usage / Limit', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Valid dates', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                    rows: const <DataRow>[],
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 3',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestCouponTab(Color surfaceColor, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule, size: 48, color: AbraColors.textDisabled),
            SizedBox(height: AbraSpacing.md),
            Text(
              'Not connected yet - built in Phase 3',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageReportTab(Color surfaceColor, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: AbraColors.textDisabled),
            SizedBox(height: AbraSpacing.md),
            Text(
              'Not connected yet - built in Phase 3',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
