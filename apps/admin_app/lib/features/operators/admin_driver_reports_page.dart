import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class AdminDriverReportsPage extends ConsumerStatefulWidget {
  const AdminDriverReportsPage({super.key});

  @override
  ConsumerState<AdminDriverReportsPage> createState() =>
      _AdminDriverReportsPageState();
}

class _AdminDriverReportsPageState
    extends ConsumerState<AdminDriverReportsPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildStatCard(String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13222F) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF2A3E50) : Colors.grey.shade300),
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
                  'Not connected yet - built in Phase 9',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9FB6C9) : Colors.grey.shade600,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3E50) : Colors.grey.shade300;

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
                  'Operators',
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
                  'Driver safety reports',
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
                      'Driver safety reports',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pre-departure breathalyzer logs, duty hours, speeding events and disciplinary actions.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AbraColors.navy,
                      side: BorderSide(color: isDark ? const Color(0xFF2A3E50) : Colors.grey.shade300),
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
                    _buildStatCard('Drivers tested today', Icons.verified_user, Colors.blue, isDark),
                    _buildStatCard('BAC compliant (0.00)', Icons.check_circle, Colors.green, isDark),
                    _buildStatCard('Speed / duty alerts', Icons.warning_amber, Colors.orange, isDark),
                    _buildStatCard('Suspended / Disqualified', Icons.block, Colors.red, isDark),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 250,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search driver, operator, bus...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                      DropdownMenuItem(value: 'COMPLIANT', child: Text('Compliant')),
                      DropdownMenuItem(value: 'WARNING', child: Text('Warning')),
                      DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ],
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(AbraSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_outlined, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 9',
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
