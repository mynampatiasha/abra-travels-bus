
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

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
  final suffix = time.hour < 12 ? 'am' : 'pm';
  return '${time.day} ${months[time.month - 1]} ${time.year}, $hour12:$minute $suffix';
}

/// `PAYMENT_PENDING` as "Payment pending".
String readable(String code) {
  if (code.isEmpty) return '-';
  final text = code.replaceAll(RegExp(r'[_-]+'), ' ').toLowerCase();
  return text[0].toUpperCase() + text.substring(1);
}

@immutable
class BookingRow {
  const BookingRow({
    required this.id,
    required this.pnr,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.route,
    required this.operatorName,
    required this.departureAt,
    required this.seats,
    required this.amountPaise,
    required this.paymentStatus,
  });

  final String id;
  final String pnr;
  final String status;
  final String customerName;
  final String customerPhone;
  final String route;
  final String operatorName;
  final String? departureAt;
  final String seats;
  final int amountPaise;
  final String paymentStatus;

  static BookingRow fromJson(JsonMap json) => BookingRow(
    id: '${json['id']}',
    pnr: '${json['pnr']}',
    status: '${json['status']}',
    customerName: '${json['customerName'] ?? ''}',
    customerPhone: '${json['customerPhone'] ?? ''}',
    route: '${json['route'] ?? ''}',
    operatorName: '${json['operatorName'] ?? ''}',
    departureAt: json['departureAt'] as String?,
    seats: '${json['seats'] ?? ''}',
    amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
    paymentStatus: '${json['paymentStatus'] ?? 'NONE'}',
  );
}

@immutable
class BookingDetail {
  const BookingDetail({
    required this.row,
    required this.baseFarePaise,
    required this.gstPaise,
    required this.feePaise,
    required this.discountPaise,
    required this.couponCode,
    required this.boardingPoint,
    required this.droppingPoint,
    required this.email,
    required this.passengers,
    required this.payments,
  });

  final BookingRow row;
  final int baseFarePaise;
  final int gstPaise;
  final int feePaise;
  final int discountPaise;
  final String? couponCode;
  final String boardingPoint;
  final String droppingPoint;
  final String email;
  final List<JsonMap> passengers;
  final List<JsonMap> payments;

  static BookingDetail fromJson(JsonMap json) => BookingDetail(
    row: BookingRow.fromJson(json),
    baseFarePaise: (json['baseFarePaise'] as num?)?.toInt() ?? 0,
    gstPaise: (json['gstPaise'] as num?)?.toInt() ?? 0,
    feePaise: (json['convenienceFeePaise'] as num?)?.toInt() ?? 0,
    discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
    couponCode: json['couponCode'] as String?,
    boardingPoint: '${json['boardingPoint'] ?? ''}',
    droppingPoint: '${json['droppingPoint'] ?? ''}',
    email: '${json['customerEmail'] ?? ''}',
    passengers: _maps(json['passengers']),
    payments: _maps(json['payments']),
  );
}

@immutable
class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.pnr,
    required this.customerName,
    required this.customerPhone,
    required this.gateway,
    required this.gatewayPaymentId,
    required this.amountPaise,
    required this.refundedPaise,
    required this.status,
    required this.failureReason,
    required this.refundDue,
    required this.createdAt,
  });

  final String id;
  final String pnr;
  final String customerName;
  final String customerPhone;
  final String gateway;
  final String gatewayPaymentId;
  final int amountPaise;
  final int refundedPaise;
  final String status;
  final String failureReason;
  final bool refundDue;
  final String? createdAt;

  static PaymentRow fromJson(JsonMap json) => PaymentRow(
    id: '${json['id']}',
    pnr: '${json['pnr'] ?? ''}',
    customerName: '${json['customerName'] ?? ''}',
    customerPhone: '${json['customerPhone'] ?? ''}',
    gateway: '${json['gateway'] ?? ''}',
    gatewayPaymentId: '${json['gatewayPaymentId'] ?? ''}',
    amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
    refundedPaise: (json['refundedPaise'] as num?)?.toInt() ?? 0,
    status: '${json['status']}',
    failureReason: '${json['failureReason'] ?? ''}',
    refundDue: json['refundDue'] == true,
    createdAt: json['createdAt'] as String?,
  );
}

List<JsonMap> _maps(Object? raw) => <JsonMap>[
  if (raw is List)
    for (final item in raw)
      if (item is Map) asJsonMap(item),
];

/// One page of a list.
@immutable
class SalesPage<T> {
  const SalesPage({required this.items, required this.page, required this.pageSize, required this.total});

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  int get firstIndex => total == 0 ? 0 : (page - 1) * pageSize + 1;
  int get lastIndex => (page - 1) * pageSize + items.length;
  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;
}

/// What the Bookings page asks for: the filters and the page.
@immutable
class SalesQuery {
  const SalesQuery({this.search = '', this.status = '', this.page = 1});

  static const pageSize = 20;
  final String search;
  final String status;
  final int page;

  SalesQuery copyWith({String? search, String? status, int? page}) =>
      SalesQuery(search: search ?? this.search, status: status ?? this.status, page: page ?? this.page);

  Map<String, String> filters() => <String, String>{
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (status.isNotEmpty) 'status': status,
  };

  @override
  bool operator ==(Object other) => other is SalesQuery && other.search == search && other.status == status && other.page == page;

  @override
  int get hashCode => Object.hash(search, status, page);
}

/// The Bookings and Payments endpoints of the admin API.
class SalesApi {
  SalesApi(this._client);

  final ApiClient _client;

  Future<SalesPage<T>> _page<T>(String path, SalesQuery query, T Function(JsonMap) fromJson) async {
    final response = await _client.get(
      path,
      query: <String, Object?>{...query.filters(), 'page': query.page, 'pageSize': SalesQuery.pageSize},
    );
    final info = response.page;
    if (info == null) throw const AppException(ServerFailure());
    return SalesPage<T>(
      items: response.decodeList(fromJson),
      page: info.page,
      pageSize: info.pageSize,
      total: info.total,
    );
  }

  Future<SalesPage<BookingRow>> bookings(SalesQuery query) => _page('admin/bookings', query, BookingRow.fromJson);

  Future<BookingDetail> booking(String id) async =>
      (await _client.get('admin/bookings/${Uri.encodeComponent(id)}')).decodeObject(BookingDetail.fromJson);

  Future<void> resendTicket(String id) async {
    await _client.post('admin/bookings/${Uri.encodeComponent(id)}/resend-ticket');
  }

  Future<SalesPage<PaymentRow>> payments(SalesQuery query) => _page('admin/payments', query, PaymentRow.fromJson);

  /// The file the server makes from the same filters.
  Future<Uint8List> export(String path, SalesQuery query) =>
      _client.getBytes('$path/export?${Uri(queryParameters: <String, String>{...query.filters(), 'format': 'csv'}).query}');
}

final salesApiProvider = Provider<SalesApi>((ref) => SalesApi(ref.watch(appDependenciesProvider).apiClient));

final adminBookingsProvider = FutureProvider.autoDispose.family<SalesPage<BookingRow>, SalesQuery>(
  (ref, query) => ref.watch(salesApiProvider).bookings(query),
);

final adminBookingDetailProvider = FutureProvider.autoDispose.family<BookingDetail, String>(
  (ref, id) => ref.watch(salesApiProvider).booking(id),
);

final adminPaymentsProvider = FutureProvider.autoDispose.family<SalesPage<PaymentRow>, SalesQuery>(
  (ref, query) => ref.watch(salesApiProvider).payments(query),
);
