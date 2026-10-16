import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'sales_mock_store.dart';

/// Admin Payments screen matching prototypes/admin_demo_model.html.
class AdminPaymentsPage extends ConsumerStatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  ConsumerState<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends ConsumerState<AdminPaymentsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _modeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openPaymentDetail(PaymentRecord payment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13222F) : AbraColors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          title: Text('Payment ${payment.id}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final item in [
                  ('Booking ID', payment.bookingId),
                  ('PNR', payment.pnr),
                  ('Customer', payment.customer),
                  ('Operator', payment.operator),
                  ('Amount', formatRupees(payment.amount)),
                  ('Payment Mode', payment.mode),
                  ('Gateway ID', payment.gw),
                  ('Payment Status', payment.status),
                  ('Recorded at', formatDateTime(payment.at)),
                  if (payment.reason.isNotEmpty) ('Failure Reason', payment.reason),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(item.$1, style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
                        Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            if (payment.status == 'PENDING')
              FilledButton.icon(
                onPressed: () {
                  ref.read(salesStoreProvider.notifier).checkPaymentGateway(payment.id);
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gateway queried: payment verified as SUCCESS'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check with gateway'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final salesState = ref.watch(salesStoreProvider);

    final successCount = salesState.payments.where((p) => p.status == 'SUCCESS').length;
    final failedCount = salesState.payments.where((p) => p.status == 'FAILED').length;
    final pendingCount = salesState.payments.where((p) => p.status == 'PENDING').length;
    final totalCollected = salesState.payments
        .where((p) => p.status == 'SUCCESS')
        .fold<int>(0, (sum, p) => sum + p.amount);

    final failedOrPending = salesState.payments.where((p) => p.status == 'FAILED' || p.status == 'PENDING').toList();

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
                Text('Payments', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
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
                      'Payments',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xxs),
                    Text(
                      'Every transaction through payment gateways, diagnostics and reconciliation.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exported payments report to CSV'), behavior: SnackBarBehavior.floating),
                    );
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
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
                    _kpiCard(Icons.payment_outlined, '$successCount', 'Successful transactions', isDark),
                    _kpiCard(
                      Icons.cancel_outlined,
                      '$failedCount',
                      'Failed payments',
                      isDark,
                      isAlert: failedCount > 0,
                    ),
                    _kpiCard(Icons.hourglass_top_outlined, '$pendingCount', 'Pending confirmation', isDark),
                    _kpiCard(Icons.account_balance_wallet_outlined, formatLakhsOrRupees(totalCollected), 'Collected volume', isDark),
                  ],
                );
              },
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Tabs
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2A3E50) : AbraColors.divider)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AbraColors.blue,
                unselectedLabelColor: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                indicatorColor: AbraColors.blue,
                tabs: <Widget>[
                  Tab(text: 'All payments (${salesState.payments.length})'),
                  Tab(text: 'Failed & stuck (${failedOrPending.length})'),
                  Tab(text: 'Reconciliation (${salesState.reconCases.where((c) => c.status == 'OPEN').length})'),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),

            // Active Tab Content
            if (_tabController.index == 0)
              _buildPaymentsTable(
                payments: salesState.payments,
                isDark: isDark,
              )
            else if (_tabController.index == 1)
              _buildPaymentsTable(
                payments: failedOrPending,
                isDark: isDark,
                emptyTitle: 'No failed or stuck payments',
              )
            else
              _buildReconciliationTab(
                cases: salesState.reconCases,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(IconData icon, String value, String label, bool isDark, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            decoration: BoxDecoration(
              color: isAlert ? const Color(0xFFFDE8E8) : AbraColors.skyContainer,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(icon, color: isAlert ? const Color(0xFFB91C1C) : AbraColors.deepBlue, size: 22),
          ),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isAlert ? const Color(0xFFB91C1C) : (isDark ? const Color(0xFFE6EEF5) : AbraColors.textPrimary),
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable({
    required List<PaymentRecord> payments,
    required bool isDark,
    String emptyTitle = 'No payments found',
  }) {
    final filtered = payments.where((p) {
      if (_statusFilter != 'ALL' && p.status != _statusFilter) return false;
      if (_modeFilter != 'ALL' && p.mode != _modeFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = p.id.toLowerCase().contains(q) ||
            p.pnr.toLowerCase().contains(q) ||
            p.customer.toLowerCase().contains(q) ||
            p.gw.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Column(
      children: <Widget>[
        // Filter bar
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
                    hintText: 'Search payment ID, PNR, gateway...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                  DropdownMenuItem(value: 'SUCCESS', child: Text('Success')),
                  DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  DropdownMenuItem(value: 'REFUNDED', child: Text('Refunded')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _statusFilter = val);
                },
              ),
              DropdownButton<String>(
                value: _modeFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All modes')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'CARD', child: Text('Card')),
                  DropdownMenuItem(value: 'NETBANKING', child: Text('Netbanking')),
                  DropdownMenuItem(value: 'WALLET', child: Text('Wallet')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _modeFilter = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.md),

        // Table
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13222F) : AbraColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AbraSpacing.xxl),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        const Icon(Icons.payment_outlined, size: 48, color: AbraColors.textDisabled),
                        const SizedBox(height: AbraSpacing.md),
                        Text(emptyTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStatePropertyAll(
                      isDark ? const Color(0xFF102030) : const Color(0xFFF8FAFB),
                    ),
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Payment ID', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('PNR', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                    rows: filtered.map((p) {
                      return DataRow(
                        onSelectChanged: (_) => _openPaymentDetail(p),
                        cells: <DataCell>[
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(p.id, style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.blue)),
                                Text(p.gw, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
                              ],
                            ),
                          ),
                          DataCell(Text(p.pnr, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(p.customer)),
                          DataCell(Text(formatRupees(p.amount), style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(p.mode)),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _buildPaymentStatusChip(p.status),
                                if (p.reason.isNotEmpty)
                                  Text(
                                    p.reason,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          DataCell(Text(formatRelativeTime(p.at))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReconciliationTab({
    required List<ReconciliationCase> cases,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AbraSpacing.md),
          decoration: const BoxDecoration(
            color: AbraColors.skyContainer,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.info_outline, color: AbraColors.deepBlue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Compare gateway webhook events against platform records. Resolve discrepancies to prevent settlement mismatch.',
                  style: TextStyle(color: AbraColors.deepBlue, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13222F) : AbraColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
          ),
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Case ID', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('PNR', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Discrepancy Issue', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
            rows: cases.map((c) {
              return DataRow(
                cells: <DataCell>[
                  DataCell(Text(c.id, style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text(c.paymentId, style: const TextStyle(color: AbraColors.blue))),
                  DataCell(Text(c.pnr)),
                  DataCell(Text(c.issue, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(formatRupees(c.amount), style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.status == 'RESOLVED' ? const Color(0xFFE1F4EA) : const Color(0xFFFEF3C7),
                        borderRadius: const BorderRadius.all(Radius.circular(99)),
                      ),
                      child: Text(
                        c.status,
                        style: TextStyle(
                          color: c.status == 'RESOLVED' ? const Color(0xFF12663F) : const Color(0xFF7A4B00),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    c.status == 'OPEN'
                        ? FilledButton.tonal(
                            onPressed: () {
                              ref.read(salesStoreProvider.notifier).resolveReconCase(c.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Case ${c.id} marked as resolved')),
                              );
                            },
                            child: const Text('Mark resolved', style: TextStyle(fontSize: 12)),
                          )
                        : const Text('Completed', style: TextStyle(color: AbraColors.tealDark, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'SUCCESS':
        bg = const Color(0xFFE1F4EA);
        fg = const Color(0xFF12663F);
        break;
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF7A4B00);
        break;
      case 'FAILED':
        bg = const Color(0xFFFDE8E8);
        fg = const Color(0xFFB91C1C);
        break;
      case 'REFUNDED':
        bg = const Color(0xFFDDF3FC);
        fg = const Color(0xFF0B4EA2);
        break;
      default:
        bg = const Color(0xFFE5EAEE);
        fg = const Color(0xFF183247);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(Radius.circular(99))),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
