import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'sales_mock_store.dart';

/// Admin Bookings screen matching prototypes/admin_demo_model.html.
class AdminBookingsPage extends ConsumerStatefulWidget {
  const AdminBookingsPage({this.initialBookingId, super.key});

  final String? initialBookingId;

  @override
  ConsumerState<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends ConsumerState<AdminBookingsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedMode = 'ALL';
  String _selectedOperator = 'ALL';

  int _currentPage = 0;
  static const int _pageSize = 10;
  String? _selectedBookingId;

  @override
  void initState() {
    super.initState();
    _selectedBookingId = widget.initialBookingId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedStatus = 'ALL';
      _selectedMode = 'ALL';
      _selectedOperator = 'ALL';
      _currentPage = 0;
    });
  }

  void _exportCsv(List<BookingRecord> items) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${items.length} bookings to bookings.csv'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openCancelModal(BookingRecord booking) {
    final hoursToDepart = booking.travelDate.difference(DateTime.now()).inHours;
    int calculatedPct;
    if (hoursToDepart >= 48) {
      calculatedPct = 100;
    } else if (hoursToDepart >= 24) {
      calculatedPct = 75;
    } else if (hoursToDepart >= 12) {
      calculatedPct = 50;
    } else if (hoursToDepart >= 4) {
      calculatedPct = 25;
    } else {
      calculatedPct = 0;
    }

    final reasonController = TextEditingController();
    int overridePct = calculatedPct;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final refundAmount = (booking.amount * overridePct / 100).round();

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF13222F) : AbraColors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            title: Text('Cancel booking ${booking.pnr}'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(AbraSpacing.md),
                      decoration: const BoxDecoration(
                        color: AbraColors.skyContainer,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Text(
                        'Departs in ~$hoursToDepart hours. By policy the standard refund is $calculatedPct% = ${formatRupees(refundAmount)}.',
                        style: const TextStyle(color: AbraColors.deepBlue, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    const Text('Refund percent (Admin override):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: AbraSpacing.xs),
                    DropdownButtonFormField<int>(
                      initialValue: overridePct,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 100, child: Text('100% full refund')),
                        DropdownMenuItem(value: 90, child: Text('90% refund')),
                        DropdownMenuItem(value: 75, child: Text('75% refund')),
                        DropdownMenuItem(value: 50, child: Text('50% refund')),
                        DropdownMenuItem(value: 25, child: Text('25% refund')),
                        DropdownMenuItem(value: 0, child: Text('0% no refund')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => overridePct = val);
                      },
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    const Text('Reason (required):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: AbraSpacing.xs),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Passenger medical emergency / trip cancel',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Keep booking'),
              ),
              FilledButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a cancellation reason')),
                    );
                    return;
                  }
                  ref.read(salesStoreProvider.notifier).cancelBooking(booking.id, reason, overridePct);
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Booking ${booking.pnr} cancelled. Refund of ${formatRupees(refundAmount)} initiated.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                child: const Text('Cancel & refund'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openNoteModal(BookingRecord booking) {
    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add staff note'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Internal note (only staff see this)...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = noteController.text.trim();
              if (text.isNotEmpty) {
                ref.read(salesStoreProvider.notifier).addBookingNote(booking.id, text);
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save note'),
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

    if (_selectedBookingId != null) {
      final selected = salesState.bookings.firstWhere(
        (b) => b.id == _selectedBookingId,
        orElse: () => salesState.bookings.first,
      );
      final payment = salesState.payments.firstWhere(
        (p) => p.bookingId == selected.id,
        orElse: () => salesState.payments.first,
      );
      final refund = salesState.refunds.where((r) => r.bookingId == selected.id).firstOrNull;

      return _BookingDetailView(
        booking: selected,
        payment: payment,
        refund: refund,
        onBack: () => setState(() => _selectedBookingId = null),
        onCancel: () => _openCancelModal(selected),
        onAddNote: () => _openNoteModal(selected),
        onResendTicket: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket sent to customer by WhatsApp and email'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    }

    final filtered = salesState.bookings.where((b) {
      if (_selectedStatus != 'ALL' && b.status != _selectedStatus) return false;
      if (_selectedMode != 'ALL' && b.mode != _selectedMode) return false;
      if (_selectedOperator != 'ALL' && b.operator != _selectedOperator) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = b.pnr.toLowerCase().contains(q) ||
            b.customer.toLowerCase().contains(q) ||
            b.phone.toLowerCase().contains(q) ||
            b.route.toLowerCase().contains(q) ||
            b.operator.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final startIndex = _currentPage * _pageSize;
    final pageItems = filtered.skip(startIndex).take(_pageSize).toList();

    final operatorNames = {'ALL', ...salesState.bookings.map((b) => b.operator)};

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
                Text('Bookings', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
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
                      'Bookings',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xxs),
                    Text(
                      'Search by PNR, passenger phone, name or route.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportCsv(filtered),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),

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
                  // Search Box
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search PNR, name, phone...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => setState(() {
                        _searchQuery = val.trim();
                        _currentPage = 0;
                      }),
                    ),
                  ),

                  // Status Filter
                  DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                      DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() { _selectedStatus = val; _currentPage = 0; });
                    },
                  ),

                  // Payment Mode Filter
                  DropdownButton<String>(
                    value: _selectedMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All modes')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'CARD', child: Text('Card')),
                      DropdownMenuItem(value: 'NETBANKING', child: Text('Netbanking')),
                      DropdownMenuItem(value: 'WALLET', child: Text('Wallet')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() { _selectedMode = val; _currentPage = 0; });
                    },
                  ),

                  // Operator Filter
                  DropdownButton<String>(
                    value: _selectedOperator,
                    underline: const SizedBox(),
                    items: operatorNames.map((op) => DropdownMenuItem(value: op, child: Text(op == 'ALL' ? 'All operators' : op))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() { _selectedOperator = val; _currentPage = 0; });
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

            // Data Table Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AbraSpacing.xxl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(Icons.confirmation_number_outlined, size: 48, color: AbraColors.textDisabled),
                          const SizedBox(height: AbraSpacing.md),
                          const Text('No bookings match your filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: AbraSpacing.xs),
                          TextButton(onPressed: _clearFilters, child: const Text('Clear filters')),
                        ],
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
                          DataColumn(label: Text('PNR', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Route', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Travel Date', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Seats', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Paid by', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                        ],
                        rows: pageItems.map((b) {
                          return DataRow(
                            onSelectChanged: (_) => setState(() => _selectedBookingId = b.id),
                            cells: <DataCell>[
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(b.pnr, style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.blue)),
                                    Text(b.id, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(b.customer, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(b.phone, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(b.route, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(b.operator, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(Text(formatDate(b.travelDate))),
                              DataCell(Text('${b.seatsN}')),
                              DataCell(Text(formatRupees(b.amount), style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text(b.mode)),
                              DataCell(_buildStatusChip(b.status)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: AbraSpacing.md),

            // Pagination Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${filtered.length} booking${filtered.length == 1 ? '' : 's'} found',
                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    ),
                    Text('Page ${_currentPage + 1} of $totalPages', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'CONFIRMED':
        bg = const Color(0xFFE1F4EA);
        fg = const Color(0xFF12663F);
        break;
      case 'COMPLETED':
        bg = const Color(0xFFDDF3FC);
        fg = const Color(0xFF0B4EA2);
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFDE8E8);
        fg = const Color(0xFFB91C1C);
        break;
      default:
        bg = const Color(0xFFE5EAEE);
        fg = const Color(0xFF183247);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(Radius.circular(99))),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

/// Detail view for a specific booking matching bkDetail() in demo.
class _BookingDetailView extends StatelessWidget {
  const _BookingDetailView({
    required this.booking,
    required this.payment,
    required this.refund,
    required this.onBack,
    required this.onCancel,
    required this.onAddNote,
    required this.onResendTicket,
  });

  final BookingRecord booking;
  final PaymentRecord payment;
  final RefundRecord? refund;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onAddNote;
  final VoidCallback onResendTicket;

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
                  label: const Text('Back to bookings'),
                ),
                const Spacer(),
                Text('Sales / Bookings / ${booking.pnr}', style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: AbraSpacing.sm),

            // Header with Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Booking ${booking.pnr}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: booking.status == 'CONFIRMED'
                            ? const Color(0xFFE1F4EA)
                            : (booking.status == 'CANCELLED' ? const Color(0xFFFDE8E8) : const Color(0xFFDDF3FC)),
                        borderRadius: const BorderRadius.all(Radius.circular(99)),
                      ),
                      child: Text(
                        booking.status,
                        style: TextStyle(
                          color: booking.status == 'CONFIRMED'
                              ? const Color(0xFF12663F)
                              : (booking.status == 'CANCELLED' ? const Color(0xFFB91C1C) : const Color(0xFF0B4EA2)),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: AbraSpacing.sm,
                  children: <Widget>[
                    if (booking.status == 'CONFIRMED')
                      FilledButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancel booking'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      ),
                    OutlinedButton.icon(
                      onPressed: onResendTicket,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Resend ticket'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onAddNote,
                      icon: const Icon(Icons.note_add_outlined, size: 16),
                      label: const Text('Add note'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.xl),

            // 2 Column layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Left Column
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Column(
                        children: <Widget>[
                          _buildCard(
                            isDark: isDark,
                            title: 'Trip and passengers',
                            items: [
                              ('Customer', booking.customer),
                              ('Phone', booking.phone),
                              ('Trip ID', booking.tripId),
                              ('Route', booking.route),
                              ('Operator', booking.operator),
                              ('Travel Date', formatDateTime(booking.travelDate)),
                              ('Seat numbers', booking.seatList),
                            ],
                          ),
                          const SizedBox(height: AbraSpacing.lg),
                          _buildCard(
                            isDark: isDark,
                            title: 'Payment',
                            items: [
                              ('Payment ID', payment.id),
                              ('Payment Mode', payment.mode),
                              ('Status', payment.status),
                              ('Gateway reference', payment.gw),
                              ('Settled with gateway', payment.settled ? 'Yes' : 'Pending cycle'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: AbraSpacing.lg),

                    // Right Column
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Column(
                        children: <Widget>[
                          _buildCard(
                            isDark: isDark,
                            title: 'Amount breakdown',
                            items: [
                              ('Operator fare', formatRupees(booking.amount - booking.commission)),
                              ('Abra commission', formatRupees(booking.commission)),
                              ('Base fare total', formatRupees(booking.amount)),
                              ('GST (5%)', formatRupees(booking.gst)),
                              ('Convenience fee', formatRupees(booking.fee)),
                              if (booking.discount > 0)
                                ('Discount (${booking.coupon})', '- ${formatRupees(booking.discount)}'),
                              ('Customer total paid', formatRupees(booking.amount + booking.gst + booking.fee - booking.discount)),
                            ],
                            boldLast: true,
                          ),
                          const SizedBox(height: AbraSpacing.lg),
                          _buildCard(
                            isDark: isDark,
                            title: 'Refund details',
                            items: refund == null
                                ? [('Refund', 'No refund requested')]
                                : [
                                    ('Refund ID', refund!.id),
                                    ('Refund Amount', '${formatRupees(refund!.amount)} (${refund!.pct}%)'),
                                    ('Status', refund!.status),
                                    ('UTR Reference', refund!.utr.isNotEmpty ? refund!.utr : 'Awaiting processing'),
                                    ('Paid by', refund!.bearer),
                                    ('Reason', refund!.reason),
                                  ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Timeline Card
            Container(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Booking timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: AbraSpacing.md),
                  _timelineItem('Seats held by customer', formatDateTime(booking.at), true, isDark),
                  _timelineItem('Payment received via ${booking.mode}', formatDateTime(booking.at.add(const Duration(minutes: 2))), true, isDark),
                  _timelineItem('Ticket issued with PNR ${booking.pnr}', formatDateTime(booking.at.add(const Duration(minutes: 2))), true, isDark),
                  if (booking.status == 'CANCELLED')
                    _timelineItem('Booking cancelled by staff', 'Refund initiated', false, isDark, isError: true),
                  for (final note in booking.notes)
                    _timelineItem('Internal Note: $note', 'Logged in audit trail', false, isDark, isNote: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required String title,
    required List<(String, String)> items,
    bool boldLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13222F) : AbraColors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: isDark ? const Color(0xFF2A3E50) : AbraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: AbraSpacing.md),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(items[i].$1, style: TextStyle(color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary, fontSize: 13)),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontWeight: (boldLast && i == items.length - 1) ? FontWeight.w800 : FontWeight.w600,
                      fontSize: (boldLast && i == items.length - 1) ? 15 : 13,
                      color: (boldLast && i == items.length - 1) ? AbraColors.blue : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineItem(String title, String subtitle, bool isDone, bool isDark, {bool isError = false, bool isNote = false}) {
    Color dotColor = AbraColors.blue;
    if (isError) dotColor = const Color(0xFFEF4444);
    if (isNote) dotColor = const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
