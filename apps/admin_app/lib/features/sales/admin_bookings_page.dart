import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import 'sales_api.dart';
import 'sales_widgets.dart';

const _bookingStatuses = <String>[
  'PAYMENT_PENDING',
  'CONFIRMED',
  'PARTIALLY_CANCELLED',
  'CANCELLED',
  'REFUND_PENDING',
  'REFUNDED',
  'COMPLETED',
  'FAILED',
  'EXPIRED',
];

/// Admin Bookings: every booking, filtered and paged, one booking in full, and the ticket
/// message sent again. The list and the file both come from the server.
class AdminBookingsPage extends ConsumerStatefulWidget {
  const AdminBookingsPage({this.initialBookingId, super.key});

  final String? initialBookingId;

  @override
  ConsumerState<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends ConsumerState<AdminBookingsPage> {
  final _search = TextEditingController();
  SalesQuery _query = const SalesQuery();
  String? _openId;

  @override
  void initState() {
    super.initState();
    _openId = widget.initialBookingId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(SalesQuery query) => setState(() => _query = query);

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(salesApiProvider).export('admin/bookings', _query);
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      downloadBytesFile('bookings-$stamp.csv', bytes, mimeType: 'text/csv');
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text('The file could not be made. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final openId = _openId;
    if (openId != null) {
      return _BookingDetailView(id: openId, onBack: () => setState(() => _openId = null));
    }
    final page = ref.watch(adminBookingsProvider(_query));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SalesHeader(
              section: 'Sales',
              title: 'Bookings',
              help: 'Every booking with who, where and how much. Open one to see the passengers and payments.',
              actions: <Widget>[
                OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download, size: 16), label: const Text('Export CSV')),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),
            SalesFilterBar(
              controller: _search,
              statuses: _bookingStatuses,
              status: _query.status,
              onSearch: (text) => _set(_query.copyWith(search: text, page: 1)),
              onStatus: (status) => _set(_query.copyWith(status: status, page: 1)),
              onClear: () {
                _search.clear();
                _set(const SalesQuery());
              },
            ),
            const SizedBox(height: AbraSpacing.lg),
            AsyncValueView<SalesPage<BookingRow>>(
              value: page,
              onRetry: () => ref.invalidate(adminBookingsProvider(_query)),
              data: (context, data) => data.items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AbraSpacing.xxl),
                      child: Center(child: Text('No bookings match these filters.', style: TextStyle(fontWeight: FontWeight.w700))),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SalesTableCard(
                          child: DataTable(
                            showCheckboxColumn: false,
                            columns: const <DataColumn>[
                              DataColumn(label: Text('PNR')),
                              DataColumn(label: Text('Passenger')),
                              DataColumn(label: Text('Route')),
                              DataColumn(label: Text('Operator')),
                              DataColumn(label: Text('Departure')),
                              DataColumn(label: Text('Seats')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Payment')),
                              DataColumn(label: Text('')),
                            ],
                            rows: <DataRow>[
                              for (final row in data.items)
                                DataRow(
                                  onSelectChanged: (_) => setState(() => _openId = row.id),
                                  cells: <DataCell>[
                                    DataCell(Text(row.pnr, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    DataCell(Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[Text(row.customerName), Text(row.customerPhone, style: const TextStyle(fontSize: 12))],
                                    )),
                                    DataCell(Text(row.route)),
                                    DataCell(Text(row.operatorName)),
                                    DataCell(Text(dayTime(row.departureAt))),
                                    DataCell(Text(row.seats)),
                                    DataCell(Text(money(row.amountPaise))),
                                    DataCell(StatusWord(row.status)),
                                    DataCell(StatusWord(row.paymentStatus)),
                                    DataCell(TextButton(onPressed: () => setState(() => _openId = row.id), child: const Text('View'))),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        SalesPager(
                          firstIndex: data.firstIndex,
                          lastIndex: data.lastIndex,
                          total: data.total,
                          hasPrevious: data.hasPrevious,
                          hasNext: data.hasNext,
                          onPrevious: () => _set(_query.copyWith(page: _query.page - 1)),
                          onNext: () => _set(_query.copyWith(page: _query.page + 1)),
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

class _BookingDetailView extends ConsumerWidget {
  const _BookingDetailView({required this.id, required this.onBack});

  final String id;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminBookingDetailProvider(id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Back to bookings')),
            ),
            AsyncValueView<BookingDetail>(
              value: detail,
              onRetry: () => ref.invalidate(adminBookingDetailProvider(id)),
              data: (context, d) => _DetailBody(detail: d),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final BookingDetail detail;

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[SizedBox(width: 160, child: Text(label, style: const TextStyle(color: AbraColors.textSecondary))), Expanded(child: Text(value))],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = detail.row;
    final paid = const <String>['CONFIRMED', 'PARTIALLY_CANCELLED', 'COMPLETED'].contains(row.status);
    Future<void> resend() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(salesApiProvider).resendTicket(row.id);
        messenger.showSnackBar(const SnackBar(content: Text('The ticket message is queued again.')));
      } on Object {
        messenger.showSnackBar(const SnackBar(content: Text('It could not be sent. Please try again.')));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(row.pnr, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(width: AbraSpacing.md),
            StatusWord(row.status),
            const Spacer(),
            FilledButton.icon(
              onPressed: paid ? resend : null,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Resend ticket'),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.lg),
        _line('Route', row.route),
        _line('Operator', row.operatorName),
        _line('Departure', dayTime(row.departureAt)),
        _line('Boarding', detail.boardingPoint.isEmpty ? '-' : detail.boardingPoint),
        _line('Dropping', detail.droppingPoint.isEmpty ? '-' : detail.droppingPoint),
        _line('Contact', '${row.customerPhone}  ${detail.email}'),
        const Divider(height: 32),
        const Text('Passengers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: AbraSpacing.sm),
        SalesTableCard(
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Seat')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Age')),
              DataColumn(label: Text('Gender')),
              DataColumn(label: Text('Fare')),
              DataColumn(label: Text('Status')),
            ],
            rows: <DataRow>[
              for (final p in detail.passengers)
                DataRow(cells: <DataCell>[
                  DataCell(Text('${p['seatId']}')),
                  DataCell(Text('${p['name']}')),
                  DataCell(Text('${p['age']}')),
                  DataCell(Text(readable('${p['gender']}'))),
                  DataCell(Text(money((p['farePaise'] as num?)?.toInt() ?? 0))),
                  DataCell(StatusWord('${p['status']}')),
                ]),
            ],
          ),
        ),
        const Divider(height: 32),
        const Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: AbraSpacing.sm),
        _line('Fare', money(detail.baseFarePaise)),
        _line('GST', money(detail.gstPaise)),
        _line('Platform fee', money(detail.feePaise)),
        _line(detail.couponCode == null ? 'Discount' : 'Discount (${detail.couponCode})', '-${money(detail.discountPaise)}'),
        _line('Total', money(row.amountPaise)),
        const Divider(height: 32),
        const Text('Payments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: AbraSpacing.sm),
        if (detail.payments.isEmpty)
          const Text('No payment was started.')
        else
          for (final p in detail.payments)
            _line(dayTime('${p['createdAt']}'), '${readable('${p['status']}')} · ${money((p['amountPaise'] as num?)?.toInt() ?? 0)} · ${readable('${p['gateway']}')}'
                '${((p['refundedPaise'] as num?)?.toInt() ?? 0) > 0 ? ' · ${money((p['refundedPaise'] as num).toInt())} sent back' : ''}'),
      ],
    );
  }
}
