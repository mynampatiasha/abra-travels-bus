import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'marketing_mock_store.dart';

/// Offers and Coupons page matching prototypes/admin_demo_model.html.
class AdminOffersPage extends ConsumerStatefulWidget {
  const AdminOffersPage({super.key});

  @override
  ConsumerState<AdminOffersPage> createState() => _AdminOffersPageState();
}

class _AdminOffersPageState extends ConsumerState<AdminOffersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search & Filters for All offers tab
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedFunder = 'ALL';

  // State for Test a coupon tab
  String _testCode = 'WEEKEND15';
  final _testAmountController = TextEditingController(text: '1500');
  String _testCustomer = 'new';
  String _testDay = 'Sat';
  CouponTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _testAmountController.dispose();
    super.dispose();
  }

  void _runCouponTest() {
    final amount = int.tryParse(_testAmountController.text.trim()) ?? 0;
    final res = ref.read(marketingStoreProvider.notifier).testCoupon(
          code: _testCode,
          amountInRupees: amount,
          isNewCustomer: _testCustomer == 'new',
          dayOfWeek: _testDay,
        );
    setState(() {
      _testResult = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketingState = ref.watch(marketingStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

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
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
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
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showOfferFormDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
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
                unselectedLabelColor:
                    isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                indicatorColor: AbraColors.blue,
                indicatorWeight: 2,
                tabs: [
                  Tab(
                    child: Row(
                      children: [
                        const Text('All offers'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${marketingState.offers.length}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Tab(text: 'Test a coupon'),
                  const Tab(text: 'Usage report'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab View Content
            SizedBox(
              height: 680,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllOffersTab(
                      marketingState, surfaceColor, borderColor, isDark),
                  _buildTestCouponTab(
                      marketingState, surfaceColor, borderColor, isDark),
                  _buildUsageReportTab(
                      marketingState, surfaceColor, borderColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllOffersTab(
    MarketingState marketingState,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    final filtered = marketingState.offers.where((o) {
      if (_selectedStatus != 'ALL' && o.status != _selectedStatus) return false;
      if (_selectedFunder != 'ALL' && o.funder != _selectedFunder) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = o.code.toLowerCase().contains(q) ||
            o.desc.toLowerCase().contains(q) ||
            o.scope.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search offers by code, description, or scope...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedStatus,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'PAUSED', child: Text('Paused')),
                  DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                ],
                onChanged: (val) {
                  setState(() => _selectedStatus = val ?? 'ALL');
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedFunder,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Funded: All')),
                  DropdownMenuItem(value: 'PLATFORM', child: Text('Abra Travels')),
                  DropdownMenuItem(value: 'OPERATOR', child: Text('Operator')),
                ],
                onChanged: (val) {
                  setState(() => _selectedFunder = val ?? 'ALL');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Offers DataTable
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No offers match the filters'),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                      ),
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Discount')),
                        DataColumn(label: Text('Applies to')),
                        DataColumn(label: Text('Valid till')),
                        DataColumn(label: Text('Used')),
                        DataColumn(label: Text('Funded by')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((offer) {
                        final usagePct = offer.limit > 0
                            ? (offer.used / offer.limit).clamp(0.0, 1.0)
                            : 0.0;

                        return DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => _showOfferDetailsModal(context, offer),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      offer.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AbraColors.blue,
                                      ),
                                    ),
                                    Text(
                                      offer.desc,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFF8BA2B9)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                offer.type == 'PERCENT'
                                    ? '${offer.value / 100}% up to ${formatRupees(offer.maxDisc)}'
                                    : formatRupees(offer.value),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataCell(Text(offer.scope)),
                            DataCell(
                              Text(
                                '${offer.to.day}/${offer.to.month}/${offer.to.year}',
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    offer.limit > 0
                                        ? '${offer.used} / ${offer.limit}'
                                        : '${offer.used}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (offer.limit > 0) ...[
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 90,
                                      child: LinearProgressIndicator(
                                        value: usagePct,
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFE2E8F0),
                                        color: AbraColors.blue,
                                        minHeight: 4,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                offer.funder == 'PLATFORM'
                                    ? 'Abra Travels'
                                    : 'Operator',
                              ),
                            ),
                            DataCell(_buildStatusChip(offer.status, isDark)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton(
                                    onPressed: () =>
                                        _showOfferFormDialog(context, offer: offer),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 6),
                                  if (['ACTIVE', 'PAUSED'].contains(offer.status))
                                    OutlinedButton(
                                      onPressed: () {
                                        ref
                                            .read(marketingStoreProvider.notifier)
                                            .toggleOfferStatus(offer.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              offer.status == 'ACTIVE'
                                                  ? 'Paused ${offer.code}'
                                                  : 'Resumed ${offer.code}',
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        offer.status == 'ACTIVE'
                                            ? 'Pause'
                                            : 'Resume',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestCouponTab(
    MarketingState marketingState,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;
        final formCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test a coupon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check which coupon applies to a sample booking, exactly as the backend decides.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF8BA2B9)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _testCode,
                decoration: const InputDecoration(
                  labelText: 'Coupon code',
                  border: OutlineInputBorder(),
                ),
                items: marketingState.offers.map((o) {
                  return DropdownMenuItem(value: o.code, child: Text(o.code));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _testCode = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _testAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Booking amount (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _testCustomer,
                decoration: const InputDecoration(
                  labelText: 'Customer type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('New customer')),
                  DropdownMenuItem(value: 'old', child: Text('Existing customer')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _testCustomer = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _testDay,
                decoration: const InputDecoration(
                  labelText: 'Day of journey',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Mon', child: Text('Monday')),
                  DropdownMenuItem(value: 'Tue', child: Text('Tuesday')),
                  DropdownMenuItem(value: 'Wed', child: Text('Wednesday')),
                  DropdownMenuItem(value: 'Thu', child: Text('Thursday')),
                  DropdownMenuItem(value: 'Fri', child: Text('Friday')),
                  DropdownMenuItem(value: 'Sat', child: Text('Saturday')),
                  DropdownMenuItem(value: 'Sun', child: Text('Sunday')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _testDay = val);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _runCouponTest,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Check coupon'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AbraColors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        final resultCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evaluation result',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              if (_testResult == null)
                Text(
                  'Choose a code and press Check to evaluate business rules.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                )
              else if (_testResult!.isApplied)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF047857)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Coupon Applied Successfully',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Discount: ${formatRupees(_testResult!.discountPaise)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer pays: ${formatRupees(_testResult!.finalAmountPaise)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Funded by: ${_testResult!.funder == 'PLATFORM' ? 'Abra Travels' : 'Operator'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF450A0A)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF991B1B)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cancel,
                              color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Not applied',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._testResult!.reasons.map((r) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• $r',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );

        if (!isWide) {
          return Column(
            children: [
              formCard,
              const SizedBox(height: 20),
              resultCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: formCard),
            const SizedBox(width: 20),
            Expanded(child: resultCard),
          ],
        );
      },
    );
  }

  Widget _buildUsageReportTab(
    MarketingState marketingState,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          ),
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Times used')),
            DataColumn(label: Text('Estimated discount given')),
            DataColumn(label: Text('Funded by')),
            DataColumn(label: Text('Status')),
          ],
          rows: marketingState.offers.map((offer) {
            final estimatedDisc = offer.type == 'PERCENT'
                ? offer.used * (offer.maxDisc ~/ 2)
                : offer.used * offer.value;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    offer.code,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text('${offer.used}')),
                DataCell(
                  Text(
                    formatRupees(estimatedDisc),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Text(
                    offer.funder == 'PLATFORM' ? 'Abra Travels' : 'Operator',
                  ),
                ),
                DataCell(_buildStatusChip(offer.status, isDark)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isDark) {
    Color bg;
    Color fg;

    switch (status) {
      case 'ACTIVE':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
      case 'PAUSED':
        bg = isDark ? const Color(0xFF332005) : const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
      case 'EXPIRED':
      case 'DRAFT':
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showOfferDetailsModal(BuildContext context, OfferRecord offer) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(offer.code),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModalRow('Description', offer.desc),
                  _buildModalRow(
                    'Discount',
                    offer.type == 'PERCENT'
                        ? '${offer.value / 100}% up to ${formatRupees(offer.maxDisc)}'
                        : formatRupees(offer.value),
                  ),
                  _buildModalRow(
                    'Minimum booking',
                    formatRupees(offer.minAmt),
                  ),
                  _buildModalRow(
                    'Valid period',
                    '${offer.from.day}/${offer.from.month}/${offer.from.year} to ${offer.to.day}/${offer.to.month}/${offer.to.year}',
                  ),
                  _buildModalRow('Applies to', offer.scope),
                  _buildModalRow('Uses per customer', '${offer.perUser}'),
                  _buildModalRow(
                    'Total uses',
                    offer.limit > 0
                        ? '${offer.used} of ${offer.limit}'
                        : '${offer.used}',
                  ),
                  _buildModalRow(
                    'Funded by',
                    offer.funder == 'PLATFORM' ? 'Abra Travels' : 'Operator',
                  ),
                  _buildModalRow('Status', offer.status),
                  const SizedBox(height: 16),
                  const Text(
                    'Terms shown in the app:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ...offer.terms.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $t', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showOfferFormDialog(BuildContext context, {OfferRecord? offer}) {
    final isEdit = offer != null;
    final codeCtrl = TextEditingController(text: offer?.code ?? '');
    final descCtrl = TextEditingController(text: offer?.desc ?? '');
    String type = offer?.type ?? 'PERCENT';
    final valCtrl = TextEditingController(
      text: offer != null
          ? (offer.type == 'PERCENT'
              ? (offer.value / 100).toString()
              : (offer.value / 100).toString())
          : '10',
    );
    final maxDiscCtrl = TextEditingController(
      text: offer != null ? (offer.maxDisc / 100).toString() : '200',
    );
    final minAmtCtrl = TextEditingController(
      text: offer != null ? (offer.minAmt / 100).toString() : '0',
    );
    final limitCtrl = TextEditingController(
      text: offer != null ? offer.limit.toString() : '1000',
    );
    final perUserCtrl = TextEditingController(
      text: offer != null ? offer.perUser.toString() : '1',
    );
    String funder = offer?.funder ?? 'PLATFORM';
    String whoCanUse =
        offer?.newOnly == true ? 'new' : (offer?.scope == 'Women travellers' ? 'women' : 'all');
    final scope = offer?.scope ?? 'All';
    final termsCtrl = TextEditingController(
      text: offer?.terms.join('\n') ??
          'Valid on bus bookings made in the Abra Travels app.\nOne coupon per booking. Cannot be combined.',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit ${offer.code}' : 'New offer'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeCtrl,
                        enabled: !isEdit,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Code *',
                          hintText: '4 to 16 capital letters and numbers',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description (shown in the app) *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'PERCENT', child: Text('Percentage')),
                          DropdownMenuItem(
                              value: 'FLAT', child: Text('Flat amount (₹)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => type = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: valCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: type == 'PERCENT'
                              ? 'Value (percentage) *'
                              : 'Value (₹ flat) *',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxDiscCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Maximum discount (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: minAmtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimum booking (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: limitCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total usage limit (0 = no limit)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: perUserCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Uses per customer',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: funder,
                        decoration: const InputDecoration(
                          labelText: 'Funded by',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'PLATFORM', child: Text('Abra Travels')),
                          DropdownMenuItem(
                              value: 'OPERATOR', child: Text('Operator')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => funder = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: whoCanUse,
                        decoration: const InputDecoration(
                          labelText: 'Who can use it',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('Everyone')),
                          DropdownMenuItem(
                              value: 'new',
                              child: Text('New customers only')),
                          DropdownMenuItem(
                              value: 'women',
                              child: Text('Women travellers')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => whoCanUse = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: termsCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Terms & conditions (one per line)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final code = codeCtrl.text.trim().toUpperCase();
                    final desc = descCtrl.text.trim();
                    if (code.isEmpty || desc.isEmpty) return;

                    final val = double.tryParse(valCtrl.text.trim()) ?? 0;
                    final maxD = int.tryParse(maxDiscCtrl.text.trim()) ?? 0;
                    final minA = int.tryParse(minAmtCtrl.text.trim()) ?? 0;
                    final limit = int.tryParse(limitCtrl.text.trim()) ?? 0;
                    final perU = int.tryParse(perUserCtrl.text.trim()) ?? 1;

                    final newOffer = OfferRecord(
                      id: offer?.id ?? 'OF${DateTime.now().millisecondsSinceEpoch}',
                      code: code,
                      desc: desc,
                      type: type,
                      value: (val * 100).toInt(),
                      maxDisc: maxD * 100,
                      minAmt: minA * 100,
                      status: offer?.status ?? 'ACTIVE',
                      funder: funder,
                      perUser: perU,
                      limit: limit,
                      used: offer?.used ?? 0,
                      from: offer?.from ?? DateTime.now(),
                      to: offer?.to ??
                          DateTime.now().add(const Duration(days: 30)),
                      scope: whoCanUse == 'women'
                          ? 'Women travellers'
                          : scope,
                      newOnly: whoCanUse == 'new',
                      terms: termsCtrl.text
                          .split('\n')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList(),
                    );

                    ref
                        .read(marketingStoreProvider.notifier)
                        .saveOffer(newOffer);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Offer $code saved')),
                    );
                  },
                  child: const Text('Save offer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
