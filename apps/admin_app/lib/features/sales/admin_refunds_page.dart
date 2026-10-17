import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// Admin Refunds screen matching prototypes/admin_demo_model.html.
class AdminRefundsPage extends ConsumerStatefulWidget {
  const AdminRefundsPage({super.key});

  @override
  ConsumerState<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends ConsumerState<AdminRefundsPage> {
  final _searchController = TextEditingController();
  String _statusFilter = 'ALL';
  String _bearerFilter = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = 'ALL';
      _bearerFilter = 'ALL';
    });
  }

  Widget _kpiCard(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13222F) : AbraColors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AbraColors.skyContainer,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(icon, color: AbraColors.deepBlue, size: 22),
          ),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Not connected yet - built in Phase 4',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Breadcrumbs
            Row(
              children: <Widget>[
                const Text('Sales', style: TextStyle(color: AbraColors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(' / ', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
                Text('Refunds', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: AbraSpacing.xs),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Refunds',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xxs),
                    Text(
                      'Approve, track and retry passenger cancellation refunds.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
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
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),

            // 4 KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: AbraSpacing.md,
                  mainAxisSpacing: AbraSpacing.md,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  children: <Widget>[
                    _kpiCard(Icons.hourglass_top_outlined, 'Waiting approval', isDark),
                    _kpiCard(Icons.sync_outlined, 'Processing at gateway', isDark),
                    _kpiCard(Icons.check_circle_outlined, 'Completed & settled', isDark),
                    _kpiCard(Icons.warning_amber_outlined, 'Failed - needs retry', isDark),
                  ],
                );
              },
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Filter Bar Card
            Container(
              padding: const EdgeInsets.all(AbraSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: Wrap(
                spacing: AbraSpacing.md,
                runSpacing: AbraSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search refund ID, PNR, name...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                      DropdownMenuItem(value: 'INITIATED', child: Text('Waiting approval')),
                      DropdownMenuItem(value: 'PROCESSING', child: Text('Processing')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _bearerFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All bearers')),
                      DropdownMenuItem(value: 'OPERATOR', child: Text('Operator share')),
                      DropdownMenuItem(value: 'PLATFORM', child: Text('Platform share')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _bearerFilter = val);
                    },
                  ),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),

            // Table Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
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
                        DataColumn(label: Text('Refund ID', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('PNR', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Bearer', style: TextStyle(fontWeight: FontWeight.w700))),
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
                        Icon(Icons.replay, size: 48, color: AbraColors.textDisabled),
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
