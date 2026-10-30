import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

/// One coupon of the platform, as `GET /admin/coupons` sends it.
@immutable
class CouponRecord {
  const CouponRecord({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.value,
    required this.maxDiscountPaise,
    required this.minBookingPaise,
    required this.usageLimit,
    required this.perCustomerLimit,
    required this.usedCount,
    required this.fundedBy,
    required this.newUsersOnly,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String id;
  final String code;
  final String title;
  final String description;

  /// `PERCENT` or `FLAT`.
  final String discountType;

  /// A percentage, or paise for a flat discount.
  final int value;
  final int? maxDiscountPaise;
  final int minBookingPaise;

  /// 0 means no limit.
  final int usageLimit;
  final int perCustomerLimit;
  final int usedCount;

  /// `ABRA` or `OPERATOR`.
  final String fundedBy;
  final bool newUsersOnly;
  final DateTime startsAt;
  final DateTime endsAt;

  /// `ACTIVE` or `PAUSED`.
  final String status;

  /// What the table shows: Paused, Expired, Scheduled or Active.
  String statusAt(DateTime now) {
    if (status == 'PAUSED') return 'Paused';
    if (!endsAt.isAfter(now)) return 'Expired';
    if (startsAt.isAfter(now)) return 'Scheduled';
    return 'Active';
  }

  String get discountText {
    final base = discountType == 'PERCENT' ? '$value%' : rupees(value);
    final cap = maxDiscountPaise;
    return cap != null && discountType == 'PERCENT' ? '$base up to ${rupees(cap)}' : base;
  }

  String get funderText => fundedBy == 'OPERATOR' ? 'Operator' : 'Platform';

  String get usageText => usageLimit == 0 ? '$usedCount / no limit' : '$usedCount / $usageLimit';
}

/// "₹850" for 85000 paise (whole rupees; paise only when there are some).
String rupees(int paise) {
  final whole = paise ~/ 100;
  final rest = paise % 100;
  return rest == 0 ? '₹$whole' : '₹$whole.${rest.toString().padLeft(2, '0')}';
}

CouponRecord couponFromJson(JsonMap json) => CouponRecord(
  id: '${json['id']}',
  code: '${json['code']}',
  title: '${json['title'] ?? ''}',
  description: '${json['description'] ?? ''}',
  discountType: '${json['discountType']}',
  value: (json['value'] as num?)?.toInt() ?? 0,
  maxDiscountPaise: (json['maxDiscountPaise'] as num?)?.toInt(),
  minBookingPaise: (json['minBookingPaise'] as num?)?.toInt() ?? 0,
  usageLimit: (json['usageLimit'] as num?)?.toInt() ?? 0,
  perCustomerLimit: (json['perCustomerLimit'] as num?)?.toInt() ?? 1,
  usedCount: (json['usedCount'] as num?)?.toInt() ?? 0,
  fundedBy: '${json['fundedBy'] ?? 'ABRA'}',
  newUsersOnly: json['newUsersOnly'] == true,
  startsAt: DateTime.parse('${json['startsAt']}'),
  endsAt: DateTime.parse('${json['endsAt']}'),
  status: '${json['status'] ?? 'ACTIVE'}',
);

/// The table after the search and the two filters. [status] is `ALL`,
/// `ACTIVE`, `EXPIRED`, `PAUSED` or `SCHEDULED`; [funder] is `ALL`,
/// `PLATFORM` or `OPERATOR`.
List<CouponRecord> filterCoupons(
  List<CouponRecord> all, {
  required String search,
  required String status,
  required String funder,
  required DateTime now,
}) {
  final needle = search.trim().toLowerCase();
  return <CouponRecord>[
    for (final c in all)
      if ((needle.isEmpty ||
              c.code.toLowerCase().contains(needle) ||
              c.title.toLowerCase().contains(needle) ||
              c.description.toLowerCase().contains(needle)) &&
          (status == 'ALL' || c.statusAt(now).toUpperCase() == status) &&
          (funder == 'ALL' || c.funderText.toUpperCase() == funder))
        c,
  ];
}

final adminCouponsProvider = FutureProvider.autoDispose<List<CouponRecord>>((ref) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  final response = await client.get('admin/coupons');
  return response.decodeList(couponFromJson);
});

/// The body of `POST /admin/coupons` from what the form holds. Money is typed
/// in rupees and sent in paise.
Map<String, Object?> couponBody({
  required String code,
  required String title,
  required String description,
  required String discountType,
  required double value,
  required double? maxDiscountRupees,
  required double minBookingRupees,
  required int usageLimit,
  required int perCustomerLimit,
  required String fundedBy,
  required bool newUsersOnly,
  required DateTime startsAt,
  required DateTime endsAt,
}) => <String, Object?>{
  'code': code.trim().toUpperCase(),
  'title': title.trim(),
  if (description.trim().isNotEmpty) 'description': description.trim(),
  'discountType': discountType,
  'value': discountType == 'PERCENT' ? value.round() : (value * 100).round(),
  if (maxDiscountRupees != null && maxDiscountRupees > 0 && discountType == 'PERCENT')
    'maxDiscountPaise': (maxDiscountRupees * 100).round(),
  'minBookingPaise': (minBookingRupees * 100).round(),
  'usageLimit': usageLimit,
  'perCustomerLimit': perCustomerLimit,
  'fundedBy': fundedBy,
  'newUsersOnly': newUsersOnly,
  'startsAt': startsAt.toUtc().toIso8601String(),
  'endsAt': endsAt.toUtc().toIso8601String(),
};

/// What is wrong with the form, in words, or null when it can be sent.
String? couponFormProblem({
  required String code,
  required String title,
  required String discountType,
  required double? value,
  required DateTime? startsAt,
  required DateTime? endsAt,
}) {
  if (!RegExp(r'^[A-Za-z0-9]{3,20}$').hasMatch(code.trim())) {
    return 'The code has 3 to 20 letters or digits.';
  }
  if (title.trim().length < 2) return 'Give the offer a title.';
  if (value == null || value <= 0) return 'Enter the discount.';
  if (discountType == 'PERCENT' && value > 100) return 'A percentage is up to 100.';
  if (startsAt == null || endsAt == null) return 'Enter the start and end dates (YYYY-MM-DD).';
  if (!endsAt.isAfter(startsAt)) return 'The end must be after the start.';
  return null;
}

/// Who used a coupon (`GET /admin/coupons/:id/usage`).
final adminCouponUsageProvider = FutureProvider.autoDispose.family<JsonMap, String>((ref, id) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  return (await client.get('admin/coupons/${Uri.encodeComponent(id)}/usage')).decodeObject((json) => json);
});

/// The body of `PATCH /admin/coupons/:id`: only what the form changed, money in paise.
Map<String, Object?> couponChangeBody({
  required CouponRecord before,
  required String title,
  required String description,
  required double? value,
  required int usageLimit,
  required int perCustomerLimit,
  required String fundedBy,
  required bool newUsersOnly,
  required double? minBookingRupees,
  required DateTime endsAt,
}) {
  final newValue = value == null ? null : (before.discountType == 'PERCENT' ? value.round() : (value * 100).round());
  final minPaise = minBookingRupees == null ? null : (minBookingRupees * 100).round();
  return <String, Object?>{
    if (title.trim() != before.title) 'title': title.trim(),
    if (description.trim() != before.description && description.trim().isNotEmpty) 'description': description.trim(),
    if (newValue != null && newValue != before.value) 'value': newValue,
    if (usageLimit != before.usageLimit) 'usageLimit': usageLimit,
    if (perCustomerLimit != before.perCustomerLimit) 'perCustomerLimit': perCustomerLimit,
    if (fundedBy != before.fundedBy) 'fundedBy': fundedBy,
    if (newUsersOnly != before.newUsersOnly) 'newUsersOnly': newUsersOnly,
    if (minPaise != null && minPaise != before.minBookingPaise) 'minBookingPaise': minPaise,
    if (endsAt.toUtc() != before.endsAt.toUtc()) 'endsAt': endsAt.toUtc().toIso8601String(),
  };
}
