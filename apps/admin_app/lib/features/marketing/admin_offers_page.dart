import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/browser_files.dart';
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
                Expanded(child: Column(
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
                )),
                OutlinedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                ),
                const SizedBox(width: AbraSpacing.sm),
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
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (status != 'Expired')
              TextButton(
                onPressed: () => _setStatus(c, paused ? 'ACTIVE' : 'PAUSED'),
                child: Text(paused ? 'Resume' : 'Pause'),
              ),
            TextButton(onPressed: () => _edit(c), child: const Text('Edit')),
            TextButton(onPressed: () => _usage(c), child: const Text('Usage')),
            TextButton(
              onPressed: c.usedCount > 0 ? null : () => _delete(c),
              child: const Text('Delete'),
            ),
          ],
        )),
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

  Future<void> _edit(CouponRecord c) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _EditOfferDialog(coupon: c));
    if (changed == true) ref.invalidate(adminCouponsProvider);
  }

  Future<void> _usage(CouponRecord c) => showDialog<void>(context: context, builder: (_) => _UsageDialog(coupon: c));

  Future<void> _delete(CouponRecord c) async {
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${c.code}?'),
        content: const Text('Nobody has used it. It will be gone for good. To stop it for a while, pause it instead.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(appDependenciesProvider).apiClient.delete('admin/coupons/${c.id}');
      ref.invalidate(adminCouponsProvider);
      messenger.showSnackBar(SnackBar(content: Text('${c.code} is deleted.')));
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text('It could not be deleted. A coupon that was used can only be paused.')));
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final query = <String, String>{
        if (_search.trim().isNotEmpty) 'search': _search.trim(),
        if (_selectedStatus == 'ACTIVE' || _selectedStatus == 'PAUSED') 'status': _selectedStatus,
        if (_selectedFunder == 'PLATFORM') 'funder': 'ABRA',
        if (_selectedFunder == 'OPERATOR') 'funder': 'OPERATOR',
        'format': 'csv',
      };
      final bytes = await ref.read(appDependenciesProvider).apiClient.getBytes('admin/coupons/export?${Uri(queryParameters: query).query}');
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      downloadBytesFile('coupons-$stamp.csv', bytes, mimeType: 'text/csv');
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text('The file could not be made. Please try again.')));
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

/// Change a coupon: the words, the limits, who pays and the end date. The code and the kind never
/// change, and the amount only until the first use (the server says so).
class _EditOfferDialog extends ConsumerStatefulWidget {
  const _EditOfferDialog({required this.coupon});

  final CouponRecord coupon;

  @override
  ConsumerState<_EditOfferDialog> createState() => _EditOfferDialogState();
}

class _EditOfferDialogState extends ConsumerState<_EditOfferDialog> {
  late final _title = TextEditingController(text: widget.coupon.title);
  late final _description = TextEditingController(text: widget.coupon.description);
  late final _value = TextEditingController(
    text: widget.coupon.discountType == 'PERCENT' ? '${widget.coupon.value}' : '${widget.coupon.value / 100}',
  );
  late final _min = TextEditingController(text: '${widget.coupon.minBookingPaise / 100}');
  late final _usage = TextEditingController(text: '${widget.coupon.usageLimit}');
  late final _perCustomer = TextEditingController(text: '${widget.coupon.perCustomerLimit}');
  late final _ends = TextEditingController(text: widget.coupon.endsAt.toLocal().toIso8601String().substring(0, 10));
  late String _funder = widget.coupon.fundedBy;
  late bool _newUsersOnly = widget.coupon.newUsersOnly;
  bool _saving = false;
  String? _problem;

  @override
  void dispose() {
    for (final c in <TextEditingController>[_title, _description, _value, _min, _usage, _perCustomer, _ends]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final endsRaw = DateTime.tryParse(_ends.text.trim());
    if (_title.text.trim().length < 2) {
      setState(() => _problem = 'Give the offer a title.');
      return;
    }
    if (endsRaw == null) {
      setState(() => _problem = 'Enter the end date as YYYY-MM-DD.');
      return;
    }
    final body = couponChangeBody(
      before: widget.coupon,
      title: _title.text,
      description: _description.text,
      value: double.tryParse(_value.text.trim()),
      usageLimit: int.tryParse(_usage.text.trim()) ?? widget.coupon.usageLimit,
      perCustomerLimit: int.tryParse(_perCustomer.text.trim()) ?? widget.coupon.perCustomerLimit,
      fundedBy: _funder,
      newUsersOnly: _newUsersOnly,
      minBookingRupees: double.tryParse(_min.text.trim()),
      // The day shown is only a day: when it was not touched, the end stays exactly as it is
      endsAt: _ends.text.trim() == widget.coupon.endsAt.toLocal().toIso8601String().substring(0, 10)
          ? widget.coupon.endsAt
          : endsRaw.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
    );
    if (body.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      await ref.read(appDependenciesProvider).apiClient.patch('admin/coupons/${widget.coupon.id}', body: body);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      final text = '$error';
      setState(() {
        _saving = false;
        _problem = text.contains('RESOURCE_IN_USE') || text.contains('has been used')
            ? 'This coupon has been used, so its amount cannot change. Make a new coupon instead.'
            : 'The change could not be saved. Please check the form and try again.';
      });
    }
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final used = widget.coupon.usedCount > 0;
    return AlertDialog(
      title: Text('Change ${widget.coupon.code}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _field('Title', _title),
              _field('Description (optional)', _description),
              Row(children: <Widget>[
                Expanded(
                  child: _field(widget.coupon.discountType == 'PERCENT' ? 'Percent (1-100)' : 'Amount (Rs)', _value, number: true),
                ),
                const SizedBox(width: 12),
                Expanded(child: _field('Lowest booking (Rs)', _min, number: true)),
              ]),
              if (used)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('This coupon was used, so its amount cannot change.', style: TextStyle(fontSize: 12)),
                ),
              Row(children: <Widget>[
                Expanded(child: _field('Total uses (0 = no limit)', _usage, number: true)),
                const SizedBox(width: 12),
                Expanded(child: _field('Uses per customer', _perCustomer, number: true)),
              ]),
              _field('Ends (YYYY-MM-DD)', _ends),
              DropdownButtonFormField<String>(
                initialValue: _funder,
                decoration: const InputDecoration(labelText: 'Who pays the discount', border: OutlineInputBorder()),
                items: const <DropdownMenuItem<String>>[
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
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save changes')),
      ],
    );
  }
}

/// Who used a coupon: each booking, the customer, what it took off and where that use stands.
class _UsageDialog extends ConsumerWidget {
  const _UsageDialog({required this.coupon});

  final CouponRecord coupon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(adminCouponUsageProvider(coupon.id));
    return AlertDialog(
      title: Text('Who used ${coupon.code}'),
      content: SizedBox(
        width: 560,
        child: usage.when(
          loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const Text('The usage could not be loaded.'),
          data: (u) {
            final items = <JsonMap>[
              if (u['items'] is List)
                for (final item in u['items'] as List<Object?>)
                  if (item is Map) asJsonMap(item),
            ];
            int n(String key) => (u[key] as num?)?.toInt() ?? 0;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Used ${n('usedCount')} times: ${n('redeemed')} paid, ${n('reserved')} waiting for payment, ${n('released')} given back. '
                    'Taken off so far: ${rupees(n('discountGivenPaise'))}.',
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Text('Nobody has used this coupon yet.')
                  else
                    for (final item in items)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${item['pnr']}  ${item['customerName']}'),
                        subtitle: Text('${item['customerPhone']}  ${item['status']}'),
                        trailing: Text(rupees((item['discountPaise'] as num?)?.toInt() ?? 0)),
                      ),
                ],
              ),
            );
          },
        ),
      ),
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
