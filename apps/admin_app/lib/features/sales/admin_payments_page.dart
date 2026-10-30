import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import 'sales_api.dart';
import 'sales_widgets.dart';

const _paymentStatuses = <String>['CREATED', 'SUCCESS', 'FAILED'];

/// Admin Payments: what was paid for which booking, and what was sent back. Read only; the list
/// and the file come from the server.
class AdminPaymentsPage extends ConsumerStatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  ConsumerState<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends ConsumerState<AdminPaymentsPage> {
  final _search = TextEditingController();
  SalesQuery _query = const SalesQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(SalesQuery query) => setState(() => _query = query);

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(salesApiProvider).export('admin/payments', _query);
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      downloadBytesFile('payments-$stamp.csv', bytes, mimeType: 'text/csv');
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text('The file could not be made. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(adminPaymentsProvider(_query));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SalesHeader(
              section: 'Sales',
              title: 'Payments',
              help: 'Every payment with the booking it was for. "Refund due" means money was taken but the seats were lost.',
              actions: <Widget>[
                OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download, size: 16), label: const Text('Export CSV')),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),
            SalesFilterBar(
              controller: _search,
              statuses: _paymentStatuses,
              status: _query.status,
              onSearch: (text) => _set(_query.copyWith(search: text, page: 1)),
              onStatus: (status) => _set(_query.copyWith(status: status, page: 1)),
              onClear: () {
                _search.clear();
                _set(const SalesQuery());
              },
            ),
            const SizedBox(height: AbraSpacing.lg),
            AsyncValueView<SalesPage<PaymentRow>>(
              value: page,
              onRetry: () => ref.invalidate(adminPaymentsProvider(_query)),
              data: (context, data) => data.items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AbraSpacing.xxl),
                      child: Center(child: Text('No payments match these filters.', style: TextStyle(fontWeight: FontWeight.w700))),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SalesTableCard(
                          child: DataTable(
                            columns: const <DataColumn>[
                              DataColumn(label: Text('Started')),
                              DataColumn(label: Text('PNR')),
                              DataColumn(label: Text('Passenger')),
                              DataColumn(label: Text('Gateway')),
                              DataColumn(label: Text('Payment id')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Sent back')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Note')),
                            ],
                            rows: <DataRow>[
                              for (final row in data.items)
                                DataRow(cells: <DataCell>[
                                  DataCell(Text(dayTime(row.createdAt))),
                                  DataCell(Text(row.pnr, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  DataCell(Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[Text(row.customerName), Text(row.customerPhone, style: const TextStyle(fontSize: 12))],
                                  )),
                                  DataCell(Text(readable(row.gateway))),
                                  DataCell(Text(row.gatewayPaymentId.isEmpty ? '-' : row.gatewayPaymentId)),
                                  DataCell(Text(money(row.amountPaise))),
                                  DataCell(Text(row.refundedPaise == 0 ? '-' : money(row.refundedPaise))),
                                  DataCell(StatusWord(row.status)),
                                  DataCell(Text(
                                    row.refundDue ? 'Refund due' : readable(row.failureReason),
                                    style: TextStyle(color: row.refundDue ? AbraColors.orange : null, fontWeight: row.refundDue ? FontWeight.w700 : null),
                                  )),
                                ]),
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
