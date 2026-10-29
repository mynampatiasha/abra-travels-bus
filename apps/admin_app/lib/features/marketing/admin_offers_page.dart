import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import 'admin_coupons_api.dart';

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
  String _search = '';

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
      _search = '';
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
                ElevatedButton.icon(
                  onPressed: _newOffer,
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
                  onChanged: (value) => setState(() => _search = value),
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
                  DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                  DropdownMenuItem(value: 'PAUSED', child: Text('Paused')),
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
            child: ref.watch(adminCouponsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('The offers could not be loaded.', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AbraSpacing.sm),
                    TextButton(
                      onPressed: () => ref.invalidate(adminCouponsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (all) {
                final now = DateTime.now();
                final rows = filterCoupons(
                  all,
                  search: _search,
                  status: _selectedStatus,
                  funder: _selectedFunder,
                  now: now,
                );
                if (rows.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_offer_outlined, size: 48, color: AbraColors.textDisabled),
                        const SizedBox(height: AbraSpacing.md),
                        Text(
                          all.isEmpty ? 'No offers yet. Press New offer.' : 'No offer matches these filters.',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: SingleChildScrollView(
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
                      rows: <DataRow>[for (final c in rows) _row(c, now)],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _day(DateTime d) => d.toLocal().toIso8601String().substring(0, 10);

  DataRow _row(CouponRecord c, DateTime now) {
    final status = c.statusAt(now);
    final paused = c.status == 'PAUSED';
    return DataRow(
      cells: <DataCell>[
        DataCell(Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.code, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(c.title, style: const TextStyle(fontSize: 12)),
          ],
        )),
        DataCell(Text(c.discountText)),
        DataCell(Text(<String>[
          c.minBookingPaise > 0 ? 'Min ${rupees(c.minBookingPaise)}' : 'All bookings',
          if (c.newUsersOnly) 'first booking',
          c.funderText,
        ].join(' · '))),
        DataCell(Text('${c.perCustomerLimit}')),
        DataCell(Text(c.usageText)),
        DataCell(Text('${_day(c.startsAt)} to ${_day(c.endsAt)}')),
        DataCell(Text(status, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(
          status == 'Expired'
              ? const Text('')
              : TextButton(
                  onPressed: () => _setStatus(c, paused ? 'ACTIVE' : 'PAUSED'),
                  child: Text(paused ? 'Resume' : 'Pause'),
                ),
        ),
      ],
    );
  }

  Future<void> _setStatus(CouponRecord c, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(appDependenciesProvider).apiClient.patch(
        'admin/coupons/${c.id}/status',
        body: <String, Object?>{'status': status},
      );
      ref.invalidate(adminCouponsProvider);
      messenger.showSnackBar(SnackBar(content: Text(status == 'PAUSED' ? '${c.code} is paused.' : '${c.code} is active again.')));
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text('The change could not be saved. Please try again.')));
    }
  }

  Future<void> _newOffer() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewOfferDialog(),
    );
    if (created == true) ref.invalidate(adminCouponsProvider);
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

/// The "New offer" form. Sends `POST /admin/coupons` and says what the server refused.
class _NewOfferDialog extends ConsumerStatefulWidget {
  const _NewOfferDialog();

  @override
  ConsumerState<_NewOfferDialog> createState() => _NewOfferDialogState();
}

class _NewOfferDialogState extends ConsumerState<_NewOfferDialog> {
  final _code = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _maxDiscount = TextEditingController();
  final _minBooking = TextEditingController(text: '0');
  final _usageLimit = TextEditingController(text: '0');
  final _perCustomer = TextEditingController(text: '1');
  final _starts = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _ends = TextEditingController();
  String _type = 'PERCENT';
  String _funder = 'ABRA';
  bool _newUsersOnly = false;
  bool _saving = false;
  String? _problem;

  @override
  void dispose() {
    for (final c in <TextEditingController>[_code, _title, _description, _value, _maxDiscount, _minBooking, _usageLimit, _perCustomer, _starts, _ends]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? _date(String text) => DateTime.tryParse(text.trim());

  Future<void> _save() async {
    final value = double.tryParse(_value.text.trim());
    final startsAt = _date(_starts.text);
    final endsRaw = _date(_ends.text);
    // The last day counts as a whole day
    final endsAt = endsRaw?.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    final problem = couponFormProblem(
      code: _code.text,
      title: _title.text,
      discountType: _type,
      value: value,
      startsAt: startsAt,
      endsAt: endsAt,
    );
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      await ref.read(appDependenciesProvider).apiClient.post(
        'admin/coupons',
        body: couponBody(
          code: _code.text,
          title: _title.text,
          description: _description.text,
          discountType: _type,
          value: value!,
          maxDiscountRupees: double.tryParse(_maxDiscount.text.trim()),
          minBookingRupees: double.tryParse(_minBooking.text.trim()) ?? 0,
          usageLimit: int.tryParse(_usageLimit.text.trim()) ?? 0,
          perCustomerLimit: int.tryParse(_perCustomer.text.trim()) ?? 1,
          fundedBy: _funder,
          newUsersOnly: _newUsersOnly,
          startsAt: startsAt!,
          endsAt: endsAt!,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      final text = '$error';
      setState(() {
        _saving = false;
        _problem = text.contains('ALREADY_REGISTERED') || text.contains('already used')
            ? 'This code is already used.'
            : 'The offer could not be saved. Please check the form and try again.';
      });
    }
  }

  Widget _field(String label, TextEditingController c, {String? hint, bool number = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New offer'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Code', _code, hint: 'WELCOME100'),
              _field('Title', _title),
              _field('Description (optional)', _description),
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Discount type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'PERCENT', child: Text('Percent')),
                        DropdownMenuItem(value: 'FLAT', child: Text('Flat amount')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'PERCENT'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _field(_type == 'PERCENT' ? 'Percent (1-100)' : 'Amount (Rs)', _value, number: true)),
              ]),
              if (_type == 'PERCENT') _field('Highest discount (Rs, optional)', _maxDiscount, number: true),
              _field('Lowest booking amount (Rs)', _minBooking, number: true),
              Row(children: [
                Expanded(child: _field('Total uses (0 = no limit)', _usageLimit, number: true)),
                const SizedBox(width: 12),
                Expanded(child: _field('Uses per customer', _perCustomer, number: true)),
              ]),
              Row(children: [
                Expanded(child: _field('Starts (YYYY-MM-DD)', _starts)),
                const SizedBox(width: 12),
                Expanded(child: _field('Ends (YYYY-MM-DD)', _ends)),
              ]),
              DropdownButtonFormField<String>(
                initialValue: _funder,
                decoration: const InputDecoration(labelText: 'Who pays the discount', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'ABRA', child: Text('Platform')),
                  DropdownMenuItem(value: 'OPERATOR', child: Text('Operator')),
                ],
                onChanged: (v) => setState(() => _funder = v ?? 'ABRA'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _newUsersOnly,
                onChanged: (v) => setState(() => _newUsersOnly = v ?? false),
                title: const Text('First booking only'),
              ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_problem!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save offer')),
      ],
    );
  }
}
