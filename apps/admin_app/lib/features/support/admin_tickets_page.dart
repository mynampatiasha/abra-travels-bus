import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class AdminTicketsPage extends ConsumerStatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  ConsumerState<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends ConsumerState<AdminTicketsPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedCategory = 'ALL';
  String _selectedPriority = 'ALL';
  String _selectedAssignee = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = 'ALL';
      _selectedCategory = 'ALL';
      _selectedPriority = 'ALL';
      _selectedAssignee = 'ALL';
    });
  }

  Widget _buildStatCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Not connected yet - built in Phase 4',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Support inbox',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer tickets, issues, refund requests, and enquiries.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create ticket'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AbraColors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4 Stats Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 600;
                final crossAxisCount = isWide ? 4 : (isMedium ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.3,
                  children: [
                    _buildStatCard('Open tickets', Icons.inbox, Colors.blue),
                    _buildStatCard('In progress', Icons.pending_actions, Colors.orange),
                    _buildStatCard('Overdue / Past SLA', Icons.warning_amber, Colors.red),
                    _buildStatCard('Resolved', Icons.check_circle_outline, Colors.green),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tickets...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                      DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In progress')),
                      DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                      DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Category: All')),
                      DropdownMenuItem(value: 'BOOKING_ISSUE', child: Text('Booking issue')),
                      DropdownMenuItem(value: 'REFUND_REQUEST', child: Text('Refund request')),
                      DropdownMenuItem(value: 'BUS_DELAY', child: Text('Bus delay')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _selectedPriority,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Priority: All')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                      DropdownMenuItem(value: 'HIGH', child: Text('High')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                      DropdownMenuItem(value: 'LOW', child: Text('Low')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPriority = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _selectedAssignee,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Assignee: All')),
                      DropdownMenuItem(value: 'UNASSIGNED', child: Text('Unassigned')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAssignee = val);
                    },
                  ),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Table Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(AbraSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.confirmation_number_outlined, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 4',
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
