import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

/// "₹850" for 85000 paise (whole rupees; paise only when there are some).
String money(int paise) {
  final whole = paise ~/ 100;
  final rest = paise % 100;
  final digits = whole.toString();
  final grouped = digits.length <= 3
      ? digits
      : '${digits.substring(0, digits.length - 3).replaceAllMapped(RegExp(r'(\d)(?=(\d\d)+$)'), (m) => '${m[1]},')},${digits.substring(digits.length - 3)}';
  return rest == 0 ? '₹$grouped' : '₹$grouped.${rest.toString().padLeft(2, '0')}';
}

/// `29 Oct 2026, 9:30 pm` in the viewer's time, or a dash.
String dayTime(String? iso) {
  final time = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (time == null) return '-';
  const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day} ${months[time.month - 1]} ${time.year}, $hour12:$minute ${time.hour < 12 ? 'am' : 'pm'}';
}

String readable(String code) {
  if (code.isEmpty) return '-';
  final text = code.replaceAll(RegExp(r'[_-]+'), ' ').toLowerCase();
  return text[0].toUpperCase() + text.substring(1);
}

/// One booking of this company, as the list shows it.
@immutable
class ClientBooking {
  const ClientBooking({
    required this.id,
    required this.pnr,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.route,
    required this.departureAt,
    required this.seats,
    required this.amountPaise,
  });

  final String id;
  final String pnr;
  final String status;
  final String customerName;
  final String customerPhone;
  final String route;
  final String? departureAt;
  final String seats;
  final int amountPaise;

  static ClientBooking fromJson(JsonMap json) => ClientBooking(
    id: '${json['id']}',
    pnr: '${json['pnr']}',
    status: '${json['status']}',
    customerName: '${json['customerName'] ?? ''}',
    customerPhone: '${json['customerPhone'] ?? ''}',
    route: '${json['route'] ?? ''}',
    departureAt: json['departureAt'] as String?,
    seats: '${json['seats'] ?? ''}',
    amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class ClientBookingSummary {
  const ClientBookingSummary({required this.total, required this.confirmed, required this.cancelled, required this.confirmedAmountPaise});

  final int total;
  final int confirmed;
  final int cancelled;
  final int confirmedAmountPaise;

  static ClientBookingSummary fromJson(JsonMap json) => ClientBookingSummary(
    total: (json['total'] as num?)?.toInt() ?? 0,
    confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
    cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    confirmedAmountPaise: (json['confirmedAmountPaise'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class BookingsQuery {
  const BookingsQuery({this.search = '', this.status = '', this.page = 1});

  static const pageSize = 20;
  final String search;
  final String status;
  final int page;

  BookingsQuery copyWith({String? search, String? status, int? page}) =>
      BookingsQuery(search: search ?? this.search, status: status ?? this.status, page: page ?? this.page);

  @override
  bool operator ==(Object other) => other is BookingsQuery && other.search == search && other.status == status && other.page == page;

  @override
  int get hashCode => Object.hash(search, status, page);
}

@immutable
class ClientBookingsPage {
  const ClientBookingsPage({required this.items, required this.page, required this.pageSize, required this.total});

  final List<ClientBooking> items;
  final int page;
  final int pageSize;
  final int total;

  int get firstIndex => total == 0 ? 0 : (page - 1) * pageSize + 1;
  int get lastIndex => (page - 1) * pageSize + items.length;
}

final clientBookingsProvider = FutureProvider.autoDispose.family<ClientBookingsPage, BookingsQuery>((ref, query) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  final response = await client.get(
    'client/bookings',
    query: <String, Object?>{
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      if (query.status.isNotEmpty) 'status': query.status,
      'page': query.page,
      'pageSize': BookingsQuery.pageSize,
    },
  );
  final info = response.page;
  if (info == null) throw const AppException(ServerFailure());
  return ClientBookingsPage(items: response.decodeList(ClientBooking.fromJson), page: info.page, pageSize: info.pageSize, total: info.total);
});

final clientBookingSummaryProvider = FutureProvider.autoDispose<ClientBookingSummary>((ref) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  return (await client.get('client/bookings/summary')).decodeObject(ClientBookingSummary.fromJson);
});

final clientBookingDetailProvider = FutureProvider.autoDispose.family<JsonMap, String>((ref, id) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  return (await client.get('client/bookings/${Uri.encodeComponent(id)}')).decodeObject((json) => json);
});

const _statuses = <String>['CONFIRMED', 'PARTIALLY_CANCELLED', 'COMPLETED', 'CANCELLED', 'REFUND_PENDING', 'REFUNDED'];

/// The bookings on this company's trips, from the server. Filters and pages are asked of the server.
class ClientBookingsScreen extends ConsumerStatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  ConsumerState<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends ConsumerState<ClientBookingsScreen> {
  final _search = TextEditingController();
  BookingsQuery _query = const BookingsQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(BookingsQuery query) => setState(() => _query = query);

  Future<void> _open(String id) => showDialog<void>(
    context: context,
    builder: (_) => _BookingDialog(id: id),
  );

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(clientBookingSummaryProvider);
    final page = ref.watch(clientBookingsProvider(_query));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PortalSectionTitle(
            title: 'Bookings',
            subtitle: 'Bookings on your trips from the Abra customer app.',
            breadcrumbs: <String>['Sales', 'Bookings'],
          ),
          const SizedBox(height: AbraSpacing.lg),
          summary.when(
            loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
            data: (s) => Wrap(
              spacing: AbraSpacing.md,
              runSpacing: AbraSpacing.md,
              children: <Widget>[
                SizedBox(width: 240, child: PortalKpiCard(icon: Icons.confirmation_number_outlined, value: '${s.total}', label: 'Bookings')),
                SizedBox(width: 240, child: PortalKpiCard(icon: Icons.check_circle_outline, value: '${s.confirmed}', label: 'Confirmed', iconColor: AbraColors.teal)),
                SizedBox(width: 240, child: PortalKpiCard(icon: Icons.cancel_outlined, value: '${s.cancelled}', label: 'Cancelled', iconColor: AbraColors.danger)),
                SizedBox(width: 240, child: PortalKpiCard(icon: Icons.payments_outlined, value: money(s.confirmedAmountPaise), label: 'Paid by customers', iconColor: AbraColors.deepBlue)),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  onSubmitted: (text) => _set(_query.copyWith(search: text, page: 1)),
                  decoration: InputDecoration(
                    hintText: 'Search PNR, name, phone',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _query.status,
                underline: const SizedBox(),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(value: '', child: Text('All statuses')),
                  for (final s in _statuses) DropdownMenuItem<String>(value: s, child: Text(readable(s))),
                ],
                onChanged: (value) => _set(_query.copyWith(status: value ?? '', page: 1)),
              ),
              FilledButton.tonal(onPressed: () => _set(_query.copyWith(search: _search.text, page: 1)), child: const Text('Search')),
              TextButton.icon(
                onPressed: () {
                  _search.clear();
                  _set(const BookingsQuery());
                },
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.lg),
          AsyncValueView<ClientBookingsPage>(
            value: page,
            onRetry: () => ref.invalidate(clientBookingsProvider(_query)),
            data: (context, data) => data.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AbraSpacing.xxl),
                    child: Center(child: Text('No bookings yet.', style: TextStyle(fontWeight: FontWeight.w700))),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          showCheckboxColumn: false,
                          columns: const <DataColumn>[
                            DataColumn(label: Text('PNR')),
                            DataColumn(label: Text('Passenger')),
                            DataColumn(label: Text('Route')),
                            DataColumn(label: Text('Departure')),
                            DataColumn(label: Text('Seats')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('')),
                          ],
                          rows: <DataRow>[
                            for (final b in data.items)
                              DataRow(
                                onSelectChanged: (_) => _open(b.id),
                                cells: <DataCell>[
                                  DataCell(Text(b.pnr, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  DataCell(Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[Text(b.customerName), Text(b.customerPhone, style: const TextStyle(fontSize: 12))],
                                  )),
                                  DataCell(Text(b.route)),
                                  DataCell(Text(dayTime(b.departureAt))),
                                  DataCell(Text(b.seats)),
                                  DataCell(Text(money(b.amountPaise))),
                                  DataCell(PortalStatusChip(status: b.status, label: readable(b.status))),
                                  DataCell(TextButton(onPressed: () => _open(b.id), child: const Text('View'))),
                                ],
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Text('${data.firstIndex}-${data.lastIndex} of ${data.total}'),
                          IconButton(
                            onPressed: data.page > 1 ? () => _set(_query.copyWith(page: _query.page - 1)) : null,
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Previous',
                          ),
                          IconButton(
                            onPressed: data.page * data.pageSize < data.total ? () => _set(_query.copyWith(page: _query.page + 1)) : null,
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Next',
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingDialog extends ConsumerWidget {
  const _BookingDialog({required this.id});

  final String id;

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AbraColors.textSecondary))), Expanded(child: Text(value))],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(clientBookingDetailProvider(id));
    return AlertDialog(
      title: const Text('Booking'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: AsyncValueView<JsonMap>(
            value: detail,
            onRetry: () => ref.invalidate(clientBookingDetailProvider(id)),
            data: (context, d) {
              final passengers = <JsonMap>[
                if (d['passengers'] is List)
                  for (final p in d['passengers'] as List<Object?>)
                    if (p is Map) asJsonMap(p),
              ];
              int paise(String key) => (d[key] as num?)?.toInt() ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _line('PNR', '${d['pnr']}'),
                  _line('Status', readable('${d['status']}')),
                  _line('Route', '${d['route'] ?? ''}'),
                  _line('Departure', dayTime(d['departureAt'] as String?)),
                  _line('Boarding', '${d['boardingPoint'] ?? '-'}'),
                  _line('Dropping', '${d['droppingPoint'] ?? '-'}'),
                  _line('Contact', '${d['customerPhone'] ?? ''}  ${d['customerEmail'] ?? ''}'),
                  const Divider(height: 24),
                  const Text('Passengers', style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final p in passengers)
                    _line('Seat ${p['seatId']}', '${p['name']}, ${p['age']}, ${readable('${p['gender']}')}  ${readable('${p['status']}')}'),
                  const Divider(height: 24),
                  _line('Fare', money(paise('baseFarePaise'))),
                  _line('GST', money(paise('gstPaise'))),
                  _line('Platform fee', money(paise('convenienceFeePaise'))),
                  _line('Discount', '-${money(paise('discountPaise'))}'),
                  _line('Total paid', money(paise('amountPaise'))),
                ],
              );
            },
          ),
        ),
      ),
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
