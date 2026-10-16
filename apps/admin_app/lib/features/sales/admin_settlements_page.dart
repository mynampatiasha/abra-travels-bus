import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'sales_mock_store.dart';

/// Admin Settlements screen matching prototypes/admin_demo_model.html.
class AdminSettlementsPage extends ConsumerStatefulWidget {
  const AdminSettlementsPage({this.initialSettlementId, super.key});

  final String? initialSettlementId;

  @override
  ConsumerState<AdminSettlementsPage> createState() => _AdminSettlementsPageState();
}

class _AdminSettlementsPageState extends ConsumerState<AdminSettlementsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
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

  void _openGenerateModal() {
    String selectedCycle = 'Last 7 days (1 Oct - 7 Oct)';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Generate settlements'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Billing cycle:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: AbraSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: selectedCycle,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Last 7 days (1 Oct - 7 Oct)', child: Text('Last 7 days (1 Oct - 7 Oct)')),
                    DropdownMenuItem(value: 'Previous 7 days (24 Sep - 30 Sep)', child: Text('Previous 7 days (24 Sep - 30 Sep)')),
                    DropdownMenuItem(value: 'Custom date range', child: Text('Custom date range')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedCycle = val);
                  },
                ),
                const SizedBox(height: AbraSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  decoration: const BoxDecoration(
                    color: AbraColors.skyContainer,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Text(
                    'Bookings already settled are skipped. Trips within the 2-day hold period will be queued for the next cycle.',
                    style: TextStyle(color: AbraColors.deepBlue, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Generated settlements for $selectedCycle')),
                );
              },
              child: const Text('Generate cycle'),
            ),
          ],
        ),
      ),
    );
  }

  void _openMarkPaidModal(SettlementRecord settlement) {
    final utrController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Confirm payment for ${settlement.id}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Net payable: ${formatRupees(settlement.net)} to ${settlement.operator}'),
              const SizedBox(height: AbraSpacing.md),
              if (settlement.mode == 'AUTO')
                const Text('Razorpay Route will automatically disburse to the verified bank account.')
              else ...<Widget>[
                const Text('Bank UTR reference (required for manual payout):', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: AbraSpacing.xs),
                TextField(
                  controller: utrController,
                  decoration: const InputDecoration(hintText: 'UTR987654321', border: OutlineInputBorder()),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (settlement.mode == 'MANUAL' && utrController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter bank UTR')));
                return;
              }
              ref.read(salesStoreProvider.notifier).paySettlement(settlement.id);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Settlement ${settlement.id} marked as PAID. Operator notified.')),
              );
            },
            child: const Text('Confirm payout'),
          ),
        ],
      ),
    );
  }

  void _openHoldModal(SettlementRecord settlement) {
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Put ${settlement.id} on hold'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Reason for withholding payout (required):', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AbraSpacing.xs),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Disputed refunds, bank verification pending...',
                  border: OutlineInputBorder(),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a hold reason')));
                return;
              }
              ref.read(salesStoreProvider.notifier).holdSettlement(settlement.id, reason);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settlement ${settlement.id} placed ON HOLD')));
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Hold payout'),
          ),
        ],
      ),
    );
  }

  void _openAdjustmentModal(SettlementRecord settlement) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add adjustment to ${settlement.id}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Adjustment Amount in Rupees (negative for penalty):', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AbraSpacing.xs),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(hintText: 'e.g. -500 or 1200', border: OutlineInputBorder()),
              ),
              const SizedBox(height: AbraSpacing.md),
              const Text('Reason:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AbraSpacing.xs),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: 'e.g. Breakdown compensation adjustment', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amountStr = amountController.text.trim();
              final amount = double.tryParse(amountStr);
              if (amount == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                return;
              }
              final paise = (amount * 100).round();
              ref.read(salesStoreProvider.notifier).addSettlementAdjustment(settlement.id, paise, reasonController.text.trim());
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adjustment of ${formatRupees(paise)} applied')));
            },
            child: const Text('Apply adjustment'),
          ),
        ],
      ),
    );
  }

  void _openReplyModal(SettlementRecord settlement) {
    final replyController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reply to ${settlement.operator}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Query: "${settlement.query}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFB91C1C))),
              const SizedBox(height: AbraSpacing.md),
              const Text('Response:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AbraSpacing.xs),
              TextField(
                controller: replyController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Explanation sent to operator by email...', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(salesStoreProvider.notifier).resolveSettlementQuery(settlement.id);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent and dispute closed')));
            },
            child: const Text('Send & close query'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final salesState = ref.watch(salesStoreProvider);

    if (_selectedSettlementId != null) {
      final selected = salesState.settlements.firstWhere(
        (s) => s.id == _selectedSettlementId,
        orElse: () => salesState.settlements.first,
      );
      final bookingLines = salesState.bookings.where((b) => b.operatorId == selected.operatorId).take(12).toList();

      return _SettlementDetailView(
        settlement: selected,
        bookingLines: bookingLines,
        onBack: () => setState(() => _selectedSettlementId = null),
        onApprove: () {
          ref.read(salesStoreProvider.notifier).approveSettlement(selected.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settlement ${selected.id} approved')));
        },
        onPay: () => _openMarkPaidModal(selected),
        onHold: () => _openHoldModal(selected),
        onReleaseHold: () {
          ref.read(salesStoreProvider.notifier).releaseSettlementHold(selected.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hold released on ${selected.id}')));
        },
        onAddAdjustment: () => _openAdjustmentModal(selected),
        onReplyQuery: () => _openReplyModal(selected),
        onDownloadStatement: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded settlement statement for ${selected.operator}')),
          );
        },
      );
    }

    final unpaidSum = salesState.settlements
        .where((s) => s.status != 'PAID')
        .fold<int>(0, (sum, s) => sum + s.net);
    final paidCount = salesState.settlements.where((s) => s.status == 'PAID').length;
    final draftCount = salesState.settlements.where((s) => s.status == 'DRAFT').length;
    final holdCount = salesState.settlements.where((s) => s.status == 'ON_HOLD').length;

    final filtered = salesState.settlements.where((s) {
      if (_statusFilter != 'ALL' && s.status != _statusFilter) return false;
      if (_modeFilter != 'ALL' && s.mode != _modeFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = s.id.toLowerCase().contains(q) || s.operator.toLowerCase().contains(q) || s.cycle.toLowerCase().contains(q);
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
                    FilledButton.icon(
                      onPressed: _openGenerateModal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Generate settlements'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloaded bank payout file (CSV)'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Payout file'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloaded GST statement (CSV)'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('GST statement'),
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
                    _kpiCard(Icons.account_balance_wallet_outlined, formatLakhsOrRupees(unpaidSum), 'Still to pay', isDark),
                    _kpiCard(Icons.check_circle_outline, '$paidCount', 'Paid this cycle', isDark),
                    _kpiCard(Icons.hourglass_top_outlined, '$draftCount', 'Waiting approval', isDark),
                    _kpiCard(Icons.warning_amber_rounded, '$holdCount', 'On hold', isDark, isAlert: holdCount > 0),
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
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
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
                      DropdownMenuItem(value: 'AUTO', child: Text('Automatic (Razorpay Route)')),
                      DropdownMenuItem(value: 'MANUAL', child: Text('Manual settlement')),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStatePropertyAll(
                    isDark ? const Color(0xFF102030) : const Color(0xFFF8FAFB),
                  ),
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Settlement ID', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Operator & Cycle', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Gross Sales', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Commission', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Refunds', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Net Payable', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Payout Mode', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                  ],
                  rows: filtered.map((s) {
                    return DataRow(
                      onSelectChanged: (_) => setState(() => _selectedSettlementId = s.id),
                      cells: <DataCell>[
                        DataCell(Text(s.id, style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.blue))),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(s.operator, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(s.cycle, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
                            ],
                          ),
                        ),
                        DataCell(Text(formatRupees(s.gross))),
                        DataCell(Text('- ${formatRupees(s.commission)}')),
                        DataCell(Text('- ${formatRupees(s.refunds)}')),
                        DataCell(Text(formatRupees(s.net), style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.blue))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: const BoxDecoration(color: AbraColors.skyContainer, borderRadius: BorderRadius.all(Radius.circular(4))),
                            child: Text(s.mode == 'AUTO' ? 'Automatic' : 'Manual', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AbraColors.deepBlue)),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _buildStatusChip(s.status),
                              if (s.query.isNotEmpty) ...<Widget>[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(color: Color(0xFFFDE8E8), borderRadius: BorderRadius.all(Radius.circular(4))),
                                  child: const Text('Disputed', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 10, fontWeight: FontWeight.w800)),
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
      case 'PAID':
        bg = const Color(0xFFE1F4EA);
        fg = const Color(0xFF12663F);
        break;
      case 'APPROVED':
        bg = const Color(0xFFDDF3FC);
        fg = const Color(0xFF0B4EA2);
        break;
      case 'DRAFT':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF7A4B00);
        break;
      case 'ON_HOLD':
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

/// Detail view for a specific settlement matching stDetail() in demo.
class _SettlementDetailView extends StatelessWidget {
  const _SettlementDetailView({
    required this.settlement,
    required this.bookingLines,
    required this.onBack,
    required this.onApprove,
    required this.onPay,
    required this.onHold,
    required this.onReleaseHold,
    required this.onAddAdjustment,
    required this.onReplyQuery,
    required this.onDownloadStatement,
  });

  final SettlementRecord settlement;
  final List<BookingRecord> bookingLines;
  final VoidCallback onBack;
  final VoidCallback onApprove;
  final VoidCallback onPay;
  final VoidCallback onHold;
  final VoidCallback onReleaseHold;
  final VoidCallback onAddAdjustment;
  final VoidCallback onReplyQuery;
  final VoidCallback onDownloadStatement;

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
            // Back Button and Breadcrumbs
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to settlements'),
                ),
                const Spacer(),
                Text('Sales / Settlements / ${settlement.id}', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: AbraSpacing.sm),

            // Header with Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${settlement.id} — ${settlement.operator}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xxs),
                    Text('${settlement.cycle} (${settlement.status})', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
                  ],
                ),
                Wrap(
                  spacing: AbraSpacing.sm,
                  children: <Widget>[
                    if (settlement.status == 'DRAFT')
                      FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve settlement'),
                      ),
                    if (settlement.status == 'APPROVED')
                      FilledButton.icon(
                        onPressed: onPay,
                        icon: const Icon(Icons.account_balance_wallet, size: 16),
                        label: Text(settlement.mode == 'AUTO' ? 'Release via Razorpay Route' : 'Mark paid'),
                        style: FilledButton.styleFrom(backgroundColor: AbraColors.tealDark),
                      ),
                    if (settlement.status == 'DRAFT' || settlement.status == 'APPROVED')
                      OutlinedButton.icon(
                        onPressed: onHold,
                        icon: const Icon(Icons.pause, size: 16),
                        label: const Text('Put on hold'),
                      ),
                    if (settlement.status == 'ON_HOLD')
                      FilledButton.icon(
                        onPressed: onReleaseHold,
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Release hold'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onDownloadStatement,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download statement'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),

            // Dispute Query Banner if query exists
            if (settlement.query.isNotEmpty) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AbraSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: const Color(0xFFF9C7C7)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Operator dispute raised:', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                          Text(settlement.query, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: onReplyQuery,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
                      child: const Text('Reply & resolve query'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
            ],

            // Summary and Adjustment 2 column row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Financial Summary Card
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(AbraSpacing.lg),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                          border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('Financial Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: AbraSpacing.md),
                            _summaryRow('Gross passenger sales', formatRupees(settlement.gross), false, isDark),
                            _summaryRow('Abra commission deducted', '- ${formatRupees(settlement.commission)}', false, isDark),
                            _summaryRow('Passenger refunds deducted', '- ${formatRupees(settlement.refunds)}', false, isDark),
                            if (settlement.adj != 0)
                              _summaryRow('Adjustments', formatRupees(settlement.adj), false, isDark),
                            const Divider(height: 18),
                            _summaryRow('Net payable to operator', formatRupees(settlement.net), true, isDark),
                            const SizedBox(height: AbraSpacing.sm),
                            _summaryRow('Payout mode', settlement.mode == 'AUTO' ? 'Automatic (Razorpay Route)' : 'Manual settlement', false, isDark),
                            _summaryRow('Total booking lines', '${settlement.lines} tickets', false, isDark),
                            if (settlement.holdReason.isNotEmpty)
                              _summaryRow('Hold reason', settlement.holdReason, false, isDark, isAlert: true),
                          ],
                        ),
                      ),
                    ),
                    if (isWide) const SizedBox(width: AbraSpacing.lg),

                    // Adjustment & Corrections Card
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(AbraSpacing.lg),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                          border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                const Text('Corrections & Penalties', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                TextButton.icon(
                                  onPressed: onAddAdjustment,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add adjustment'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AbraSpacing.xs),
                            Text(
                              'Add financial corrections, delay penalties or goodwill bonus to this cycle.',
                              style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: AbraSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AbraSpacing.md),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF8FAFB),
                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  const Text('Cycle net adjustment:', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    formatRupees(settlement.adj),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: settlement.adj < 0 ? const Color(0xFFB91C1C) : AbraColors.tealDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Booking Lines Table
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(AbraSpacing.lg),
                    child: Text(
                      'Booking lines in this cycle (${bookingLines.length} shown)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        isDark ? const Color(0xFF102030) : const Color(0xFFF8FAFB),
                      ),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('PNR', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Fare', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Commission', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Operator Gets', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: bookingLines.map((b) {
                        return DataRow(
                          cells: <DataCell>[
                            DataCell(Text(b.pnr, style: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.blue))),
                            DataCell(Text(b.route)),
                            DataCell(Text(formatRupees(b.amount))),
                            DataCell(Text(formatRupees(b.commission))),
                            DataCell(Text(formatRupees(b.amount - b.commission), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: const BoxDecoration(color: Color(0xFFE1F4EA), borderRadius: BorderRadius.all(Radius.circular(99))),
                                child: Text(b.status, style: const TextStyle(color: Color(0xFF12663F), fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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

  Widget _summaryRow(String label, String value, bool isTotal, bool isDark, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: isTotal ? 15 : 13, fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 17 : 13,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              color: isAlert ? const Color(0xFFB91C1C) : (isTotal ? AbraColors.blue : (isDark ? const Color(0xFFE6EEF5) : AbraColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
