import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// Incidents and Trip Sharing Audit page matching prototypes/admin_demo_model.html.
class AdminIncidentsPage extends ConsumerStatefulWidget {
  const AdminIncidentsPage({super.key});

  @override
  ConsumerState<AdminIncidentsPage> createState() => _AdminIncidentsPageState();
}

class _AdminIncidentsPageState extends ConsumerState<AdminIncidentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Incident filters
  final _searchIncidentsController = TextEditingController();
  String _selectedIncidentStatus = 'ALL';
  String _selectedIncidentSeverity = 'ALL';

  // Sharing filters
  final _searchSharingController = TextEditingController();
  String _selectedSharingStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchIncidentsController.dispose();
    _searchSharingController.dispose();
    super.dispose();
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
                  'Safety',
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
                  'Incidents',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incidents and trip sharing',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Safety log: accident, harassment or breakdown reports, and passenger live-location sharing audit.',
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
                    label: const Text('Log new incident'),
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
                  Tab(text: 'Incident log'),
                  Tab(text: 'Live sharing links'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab View
            SizedBox(
              height: 580,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIncidentsTab(surfaceColor, borderColor, isDark),
                  _buildSharingTab(surfaceColor, borderColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentsTab(Color surfaceColor, Color borderColor, bool isDark) {
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
                  controller: _searchIncidentsController,
                  decoration: InputDecoration(
                    hintText: 'Search incident ID, route, bus...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedIncidentStatus,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                  DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                  DropdownMenuItem(value: 'INVESTIGATING', child: Text('Investigating')),
                  DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedIncidentStatus = val);
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedIncidentSeverity,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All severities')),
                  DropdownMenuItem(value: 'HIGH', child: Text('High')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                  DropdownMenuItem(value: 'LOW', child: Text('Low')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedIncidentSeverity = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table Card
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
                      DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Trip & Operator', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Reported', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Severity', style: TextStyle(fontWeight: FontWeight.w700))),
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
                        Icon(Icons.report_problem_outlined, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 5',
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

  Widget _buildSharingTab(Color surfaceColor, Color borderColor, bool isDark) {
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
                  controller: _searchSharingController,
                  decoration: InputDecoration(
                    hintText: 'Search passenger, phone, token...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedSharingStatus,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All links')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSharingStatus = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table Card
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
                      DataColumn(label: Text('Passenger', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Trip & Bus', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Share Token', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Expires', style: TextStyle(fontWeight: FontWeight.w700))),
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
                        Icon(Icons.share_location_outlined, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 5',
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
}
