import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class CancelSlab {
  CancelSlab({
    required this.id,
    required this.hours,
    required this.pct,
  });

  final String id;
  int hours;
  int pct;
}

class OperatorBankRecord {
  OperatorBankRecord({
    required this.id,
    required this.name,
    required this.mode, // AUTO, MANUAL
    required this.accountNumber,
    required this.ifsc,
    required this.status, // VERIFIED, PENDING, FAILED
  });

  final String id;
  final String name;
  String mode;
  final String accountNumber;
  final String ifsc;
  String status;
}

class AdminPayoutPage extends ConsumerStatefulWidget {
  const AdminPayoutPage({super.key});

  @override
  ConsumerState<AdminPayoutPage> createState() => _AdminPayoutPageState();
}

class _AdminPayoutPageState extends ConsumerState<AdminPayoutPage> {
  // Payout settings
  String _defaultMode = 'AUTO';
  final TextEditingController _cycleDaysCtrl = TextEditingController(text: '7');
  final TextEditingController _minPayoutCtrl = TextEditingController(text: '1000');
  final TextEditingController _holdDaysCtrl = TextEditingController(text: '2');
  bool _razorpayRouteEnabled = true;

  // Customer fees and coupons
  final TextEditingController _gstCtrl = TextEditingController(text: '5');
  final TextEditingController _convenienceFeeCtrl =
      TextEditingController(text: '49');
  String _couponFunding = 'PLATFORM';

  // Slabs
  final List<CancelSlab> _slabs = [
    CancelSlab(id: 'CS1', hours: 24, pct: 90),
    CancelSlab(id: 'CS2', hours: 12, pct: 75),
    CancelSlab(id: 'CS3', hours: 6, pct: 50),
    CancelSlab(id: 'CS4', hours: 2, pct: 25),
  ];

  // Operator payout records
  final List<OperatorBankRecord> _operators = [
    OperatorBankRecord(
      id: 'OP1',
      name: 'Kaveri Express',
      mode: 'AUTO',
      accountNumber: '••••••••4829',
      ifsc: 'HDFC0001234',
      status: 'VERIFIED',
    ),
    OperatorBankRecord(
      id: 'OP2',
      name: 'Godavari Lines',
      mode: 'AUTO',
      accountNumber: '••••••••9841',
      ifsc: 'SBIN0004321',
      status: 'VERIFIED',
    ),
    OperatorBankRecord(
      id: 'OP3',
      name: 'Deccan Voyager',
      mode: 'MANUAL',
      accountNumber: '••••••••1102',
      ifsc: 'ICIC0005678',
      status: 'PENDING',
    ),
    OperatorBankRecord(
      id: 'OP4',
      name: 'Charminar Tours',
      mode: 'AUTO',
      accountNumber: '••••••••3399',
      ifsc: 'UTIB0009988',
      status: 'VERIFIED',
    ),
    OperatorBankRecord(
      id: 'OP5',
      name: 'Southern Star Travels',
      mode: 'MANUAL',
      accountNumber: '••••••••7721',
      ifsc: 'KKBK0001122',
      status: 'FAILED',
    ),
  ];

  String _operatorFilter = 'ALL';

  @override
  void dispose() {
    _cycleDaysCtrl.dispose();
    _minPayoutCtrl.dispose();
    _holdDaysCtrl.dispose();
    _gstCtrl.dispose();
    _convenienceFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOps = _operators.where((o) {
      if (_operatorFilter != 'ALL' && o.mode != _operatorFilter) return false;
      return true;
    }).toList();

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
                      'Payout modes and fees',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How operators are paid, and what customers pay on top.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Row: Payout settings & Customer fees
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildPayoutSettingsCard(),
                    ),
                    SizedBox(
                      width: isWide ? 20 : 0,
                      height: isWide ? 0 : 20,
                    ),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildCustomerFeesCard(),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Cancellation Refund Slabs Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cancellation refund slabs',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AbraColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Default. Hours before departure to refund percent. Operators may configure custom slabs.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: _openAddSlabModal,
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('Add slab'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AbraColors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Cancel at least')),
                          DataColumn(label: Text('Refund percent')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _slabs.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${s.hours} hours before')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${s.pct}%',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _slabs.remove(s));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Refund slab removed'),
                                      ),
                                    );
                                  },
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
            ),
            const SizedBox(height: 24),

            // Operator Payout Modes and Bank Accounts Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Operator payout modes and bank accounts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AbraColors.navy,
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: DropdownButtonFormField<String>(
                            initialValue: _operatorFilter,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: 'Mode',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'ALL', child: Text('All modes')),
                              DropdownMenuItem(
                                  value: 'AUTO', child: Text('Automatic')),
                              DropdownMenuItem(
                                  value: 'MANUAL', child: Text('Manual')),
                            ],
                            onChanged: (v) =>
                                setState(() => _operatorFilter = v ?? 'ALL'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(Colors.grey.shade100),
                          columns: const [
                            DataColumn(label: Text('Operator')),
                            DataColumn(label: Text('Mode')),
                            DataColumn(label: Text('Bank account')),
                            DataColumn(label: Text('Verification')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filteredOps.map((o) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    o.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: o.mode == 'AUTO'
                                          ? Colors.blue.shade50
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      o.mode == 'AUTO' ? 'Automatic' : 'Manual',
                                      style: TextStyle(
                                        color: o.mode == 'AUTO'
                                            ? AbraColors.blue
                                            : Colors.grey.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text('${o.accountNumber} • ${o.ifsc}'),
                                ),
                                DataCell(_buildVerificationBadge(o.status)),
                                DataCell(
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _changeOperatorMode(context, o),
                                        child: const Text('Change mode'),
                                      ),
                                      if (o.status != 'VERIFIED')
                                        TextButton(
                                          onPressed: () =>
                                              _verifyBankAccount(context, o),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.green.shade700,
                                          ),
                                          child: const Text('Verify ₹1 drop'),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutSettingsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payout settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AbraColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _defaultMode,
              decoration: const InputDecoration(
                labelText: 'Default mode for new operators',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'AUTO',
                  child: Text('Automatic (Razorpay Route)'),
                ),
                DropdownMenuItem(
                  value: 'MANUAL',
                  child: Text('Manual settlement'),
                ),
              ],
              onChanged: (v) => setState(() => _defaultMode = v ?? 'AUTO'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cycleDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Settlement cycle (days)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minPayoutCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum payout (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _holdDaysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hold days after trip',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Razorpay Route enabled',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Splits customer payments directly to operator virtual accounts',
                style: TextStyle(fontSize: 11),
              ),
              value: _razorpayRouteEnabled,
              activeThumbColor: AbraColors.blue,
              onChanged: (v) => setState(() => _razorpayRouteEnabled = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerFeesCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer fees and coupons',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AbraColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gstCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'GST on fare (%)',
                helperText: 'Standard passenger road transport GST',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _convenienceFeeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Platform convenience fee (₹)',
                helperText: 'Charged per confirmed booking',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _couponFunding,
              decoration: const InputDecoration(
                labelText: 'Who funds coupon discounts',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PLATFORM',
                  child: Text('Abra Travels (Platform)'),
                ),
                DropdownMenuItem(
                  value: 'OPERATOR',
                  child: Text('The Operator'),
                ),
                DropdownMenuItem(
                  value: 'SPLIT',
                  child: Text('Shared 50/50'),
                ),
              ],
              onChanged: (v) => setState(() => _couponFunding = v ?? 'PLATFORM'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() {
    final gst = double.tryParse(_gstCtrl.text.trim()) ?? -1;
    final cycle = int.tryParse(_cycleDaysCtrl.text.trim()) ?? -1;

    if (gst < 0 || gst > 28) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GST must be between 0% and 28%')),
      );
      return;
    }
    if (cycle < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement cycle must be 1 day or more')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved. Applies to new bookings and settlements.'),
      ),
    );
  }

  void _openAddSlabModal() {
    final hoursCtrl = TextEditingController();
    final pctCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add refund slab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hoursCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hours before departure',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pctCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Refund percent (%)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final h = int.tryParse(hoursCtrl.text.trim());
              final p = int.tryParse(pctCtrl.text.trim());
              if (h == null || p == null) return;

              if (_slabs.any((s) => s.hours == h)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('A slab for these hours already exists'),
                  ),
                );
                return;
              }

              setState(() {
                _slabs.add(
                  CancelSlab(
                    id: 'CS-${DateTime.now().millisecondsSinceEpoch % 1000}',
                    hours: h,
                    pct: p.clamp(0, 100),
                  ),
                );
                _slabs.sort((a, b) => b.hours.compareTo(a.hours));
              });

              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AbraColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _changeOperatorMode(BuildContext context, OperatorBankRecord o) {
    String current = o.mode;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMdlState) => AlertDialog(
          title: Text('Change mode for ${o.name}'),
          content: DropdownButtonFormField<String>(
            initialValue: current,
            decoration: const InputDecoration(
              labelText: 'Payout Mode',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'AUTO',
                child: Text('Automatic (Razorpay Route)'),
              ),
              DropdownMenuItem(
                value: 'MANUAL',
                child: Text('Manual settlement'),
              ),
            ],
            onChanged: (v) => setMdlState(() => current = v ?? 'AUTO'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => o.mode = current);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${o.name} mode changed to ${current == "AUTO" ? "Automatic" : "Manual"}',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _verifyBankAccount(BuildContext context, OperatorBankRecord o) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Sending ₹1 to verify account...')),
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      setState(() => o.status = 'VERIFIED');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Bank account verified for ${o.name} (Beneficiary match 100%)',
            ),
          ),
        );
      }
    });
  }

  Widget _buildVerificationBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'VERIFIED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'PENDING':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'FAILED':
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
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
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
