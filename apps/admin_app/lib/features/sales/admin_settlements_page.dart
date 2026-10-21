import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// Admin Settlements screen matching prototypes/admin_demo_model.html.
class AdminSettlementsPage extends ConsumerStatefulWidget {
  const AdminSettlementsPage({this.initialSettlementId, super.key});

  final String? initialSettlementId;

  @override
  ConsumerState<AdminSettlementsPage> createState() => _AdminSettlementsPageState();
}

class _AdminSettlementsPageState extends ConsumerState<AdminSettlementsPage> {
  final _searchController = TextEditingController();
  String _statusFilter = 'ALL';
  String _modeFilter = 'ALL';
  String? _selectedSettlementId;

  @override
  void initState() {
    super.initState();
    _selectedSettlementId = widget.initialSettlementId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = 'ALL';
      _modeFilter = 'ALL';
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
                  'Not connected yet - built in Phase 6',
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

    if (_selectedSettlementId != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedSettlementId = null),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to settlements'),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.md),
              Container(
                padding: const EdgeInsets.all(AbraSpacing.xxl),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.account_balance_wallet_outlined, size: 48, color: AbraColors.textDisabled),
                    SizedBox(height: AbraSpacing.md),
                    Text(
                      'Not connected yet - built in Phase 6',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                Text('Settlements', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: AbraSpacing.xs),

            // Header with Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Settlements',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xxs),
                    Text(
                      'What Abra owes each operator for each billing cycle.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: AbraSpacing.sm,
                  children: <Widget>[
                    Tooltip(
                      message: 'Not connected yet',
                      child: FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Generate settlements'),
                      ),
                    ),
                    Tooltip(
                      message: 'Not connected yet',
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Payout file'),
                      ),
                    ),
                    Tooltip(
                      message: 'Not connected yet',
                      child: OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('GST statement'),
                      ),
                    ),
                  ],
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
                    _kpiCard(Icons.account_balance_wallet_outlined, 'Still to pay', isDark),
                    _kpiCard(Icons.check_circle_outline, 'Paid this cycle', isDark),
                    _kpiCard(Icons.hourglass_top_outlined, 'Waiting approval', isDark),
                    _kpiCard(Icons.warning_amber_rounded, 'On hold', isDark),
                  ],
                );
              },
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Filter Bar
            Container(
              padding: const EdgeInsets.all(AbraSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: Wrap(
                spacing: AbraSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search settlement ID, operator...',
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
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                      DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                      DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                      DropdownMenuItem(value: 'ON_HOLD', child: Text('On Hold')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _modeFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All payout modes')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS)')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI Auto-payout')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _modeFilter = val);
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

            // Settlements Table Card
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
                        DataColumn(label: Text('Settlement ID', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Operator', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Cycle', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Gross Bookings', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Abra Fee & GST', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Net Payout', style: TextStyle(fontWeight: FontWeight.w700))),
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
                        Icon(Icons.account_balance_wallet_outlined, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: AbraSpacing.md),
                        Text(
                          'Not connected yet - built in Phase 6',
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
