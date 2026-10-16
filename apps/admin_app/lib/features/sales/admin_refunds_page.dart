import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'sales_mock_store.dart';

/// Admin Refunds screen matching prototypes/admin_demo_model.html.
class AdminRefundsPage extends ConsumerStatefulWidget {
  const AdminRefundsPage({super.key});

  @override
  ConsumerState<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends ConsumerState<AdminRefundsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _bearerFilter = 'ALL';

  final Set<String> _selectedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRejectModal(RefundRecord refund) {
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reject refund ${refund.id}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('The customer will read this reason (required):', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AbraSpacing.sm),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Booking was already boarded or ticket non-refundable...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a rejection reason')));
                return;
              }
              ref.read(salesStoreProvider.notifier).rejectRefund(refund.id, reason);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refund ${refund.id} rejected')));
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reject refund'),
          ),
        ],
      ),
    );
  }

  void _openMarkPaidModal(RefundRecord refund) {
    final utrController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mark refund paid (${refund.id})'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Amount: ${formatRupees(refund.amount)} to ${refund.customer}'),
              const SizedBox(height: AbraSpacing.md),
              const Text('Bank UTR Reference (required):', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AbraSpacing.sm),
              TextField(
                controller: utrController,
                decoration: InputDecoration(
                  hintText: 'UTR123456789',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final utr = utrController.text.trim();
              if (utr.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter bank UTR reference')));
                return;
              }
              ref.read(salesStoreProvider.notifier).completeRefund(refund.id, utr);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Refund ${refund.id} marked as completed (UTR: $utr)')),
              );
            },
            child: const Text('Confirm paid'),
          ),
        ],
      ),
    );
  }

  void _bulkApprove() {
    for (final id in _selectedIds) {
      ref.read(salesStoreProvider.notifier).approveRefund(id);
    }
    final count = _selectedIds.length;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count refund(s) approved and sent to gateway for processing')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final salesState = ref.watch(salesStoreProvider);

    final waitingCount = salesState.refunds.where((r) => r.status == 'INITIATED').length;
    final processingCount = salesState.refunds.where((r) => r.status == 'PROCESSING').length;
    final completedCount = salesState.refunds.where((r) => r.status == 'COMPLETED').length;
    final failedCount = salesState.refunds.where((r) => r.status == 'FAILED').length;

    final filtered = salesState.refunds.where((r) {
      if (_statusFilter != 'ALL' && r.status != _statusFilter) return false;
      if (_bearerFilter != 'ALL' && r.bearer != _bearerFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = r.id.toLowerCase().contains(q) ||
            r.pnr.toLowerCase().contains(q) ||
            r.customer.toLowerCase().contains(q) ||
            r.reason.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

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
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exported refunds to CSV'), behavior: SnackBarBehavior.floating),
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
                    _kpiCard(Icons.hourglass_top_outlined, '$waitingCount', 'Waiting approval', isDark, isAlert: waitingCount > 0),
                    _kpiCard(Icons.sync_outlined, '$processingCount', 'Processing at gateway', isDark),
                    _kpiCard(Icons.check_circle_outline, '$completedCount', 'Completed refunds', isDark),
                    _kpiCard(Icons.error_outline, '$failedCount', 'Failed / rejected', isDark, isAlert: failedCount > 0),
                  ],
                );
              },
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Filter & Bulk Action Bar
            Container(
              padding: const EdgeInsets.all(AbraSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: Wrap(
                spacing: AbraSpacing.md,
                runSpacing: AbraSpacing.sm,
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
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                      DropdownMenuItem(value: 'INITIATED', child: Text('Initiated')),
                      DropdownMenuItem(value: 'PROCESSING', child: Text('Processing')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                  DropdownButton<String>(
                    value: _bearerFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All payers')),
                      DropdownMenuItem(value: 'Operator', child: Text('Paid by Operator')),
                      DropdownMenuItem(value: 'Platform', child: Text('Paid by Platform')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _bearerFilter = val);
                    },
                  ),
                  if (_selectedIds.isNotEmpty)
                    FilledButton.icon(
                      onPressed: _bulkApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: Text('Approve selected (${_selectedIds.length})'),
                      style: FilledButton.styleFrom(backgroundColor: AbraColors.tealDark),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.md),

            // Refunds Table
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AbraSpacing.xxl),
                      child: Center(
                        child: Text('No refunds matching criteria', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStatePropertyAll(
                          isDark ? const Color(0xFF102030) : const Color(0xFFF8FAFB),
                        ),
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Refund ID', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Amount & %', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Paid by', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('UTR', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Started', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                        ],
                        rows: filtered.map((r) {
                          final isSelected = _selectedIds.contains(r.id);
                          return DataRow(
                            selected: isSelected,
                            onSelectChanged: r.status == 'INITIATED'
                                ? (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.add(r.id);
                                      } else {
                                        _selectedIds.remove(r.id);
                                      }
                                    });
                                  }
                                : null,
                            cells: <DataCell>[
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(r.id, style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.blue)),
                                    Text('PNR: ${r.pnr}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(Text(r.customer, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(formatRupees(r.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: const BoxDecoration(
                                        color: AbraColors.skyContainer,
                                        borderRadius: BorderRadius.all(Radius.circular(4)),
                                      ),
                                      child: Text('${r.pct}%', style: const TextStyle(color: AbraColors.deepBlue, fontSize: 10, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(r.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                              DataCell(Text(r.bearer)),
                              DataCell(_buildStatusChip(r.status)),
                              DataCell(Text(r.utr.isNotEmpty ? r.utr : '-')),
                              DataCell(Text(formatRelativeTime(r.at))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (r.status == 'INITIATED') ...<Widget>[
                                      FilledButton.tonal(
                                        onPressed: () {
                                          ref.read(salesStoreProvider.notifier).approveRefund(r.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Refund ${r.id} approved for gateway processing')),
                                          );
                                        },
                                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                                        child: const Text('Approve', style: TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                                        tooltip: 'Reject',
                                        onPressed: () => _openRejectModal(r),
                                      ),
                                    ] else if (r.status == 'PROCESSING') ...<Widget>[
                                      FilledButton.tonal(
                                        onPressed: () => _openMarkPaidModal(r),
                                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                                        child: const Text('Mark paid', style: TextStyle(fontSize: 12)),
                                      ),
                                    ] else if (r.status == 'FAILED') ...<Widget>[
                                      IconButton(
                                        icon: const Icon(Icons.refresh, size: 18, color: AbraColors.blue),
                                        tooltip: 'Retry',
                                        onPressed: () {
                                          ref.read(salesStoreProvider.notifier).approveRefund(r.id);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retrying ${r.id}')));
                                        },
                                      ),
                                    ],
                                  ],
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

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'COMPLETED':
        bg = const Color(0xFFE1F4EA);
        fg = const Color(0xFF12663F);
        break;
      case 'PROCESSING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF7A4B00);
        break;
      case 'INITIATED':
        bg = const Color(0xFFDDF3FC);
        fg = const Color(0xFF0B4EA2);
        break;
      case 'FAILED':
        bg = const Color(0xFFFDE8E8);
        fg = const Color(0xFFB91C1C);
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
