import 'package:admin_app/features/marketing/admin_coupons_api.dart';
import 'package:flutter_test/flutter_test.dart';

CouponRecord coupon({
  String code = 'SAVE10',
  String title = 'Ten percent',
  String type = 'PERCENT',
  int value = 10,
  String fundedBy = 'ABRA',
  String status = 'ACTIVE',
  DateTime? startsAt,
  DateTime? endsAt,
}) => CouponRecord(
  id: code,
  code: code,
  title: title,
  description: '',
  discountType: type,
  value: value,
  maxDiscountPaise: null,
  minBookingPaise: 0,
  usageLimit: 0,
  perCustomerLimit: 1,
  usedCount: 3,
  fundedBy: fundedBy,
  newUsersOnly: false,
  startsAt: startsAt ?? DateTime(2026, 1, 1),
  endsAt: endsAt ?? DateTime(2026, 12, 31),
  status: status,
);

void main() {
  final now = DateTime(2026, 10, 29);

  group('the status the table shows', () {
    test('paused beats everything, then expired, scheduled and active', () {
      expect(coupon(status: 'PAUSED').statusAt(now), 'Paused');
      expect(coupon(endsAt: DateTime(2026, 10, 1)).statusAt(now), 'Expired');
      expect(coupon(startsAt: DateTime(2026, 11, 1)).statusAt(now), 'Scheduled');
      expect(coupon().statusAt(now), 'Active');
    });
  });

  group('the discount and usage text', () {
    test('percent with a cap, flat in rupees, and the usage count', () {
      expect(coupon().discountText, '10%');
      expect(coupon(type: 'FLAT', value: 5000).discountText, '₹50');
      expect(coupon(type: 'FLAT', value: 5050).discountText, '₹50.50');
      expect(coupon().usageText, '3 / no limit');
      expect(coupon(fundedBy: 'OPERATOR').funderText, 'Operator');
    });
  });

  group('the search and the filters', () {
    final all = <CouponRecord>[
      coupon(code: 'WELCOME', title: 'First ride'),
      coupon(code: 'PAUSEME', status: 'PAUSED', fundedBy: 'OPERATOR'),
      coupon(code: 'OLD', endsAt: DateTime(2026, 9, 1)),
    ];
    List<String> codes(String search, String status, String funder) =>
        filterCoupons(all, search: search, status: status, funder: funder, now: now)
            .map((c) => c.code)
            .toList();

    test('search looks in the code and the title', () {
      expect(codes('welc', 'ALL', 'ALL'), <String>['WELCOME']);
      expect(codes('first', 'ALL', 'ALL'), <String>['WELCOME']);
      expect(codes('', 'ALL', 'ALL'), hasLength(3));
    });

    test('status and funder narrow the list', () {
      expect(codes('', 'PAUSED', 'ALL'), <String>['PAUSEME']);
      expect(codes('', 'EXPIRED', 'ALL'), <String>['OLD']);
      expect(codes('', 'ACTIVE', 'ALL'), <String>['WELCOME']);
      expect(codes('', 'ALL', 'OPERATOR'), <String>['PAUSEME']);
    });
  });

  group('the form', () {
    test('says what is wrong in words', () {
      final ok = DateTime(2026, 11, 1);
      String? problem({String code = 'SAVE10', String title = 'Ten', double? value = 10, String type = 'PERCENT', DateTime? s, DateTime? e}) =>
          couponFormProblem(code: code, title: title, discountType: type, value: value, startsAt: s ?? ok, endsAt: e ?? ok.add(const Duration(days: 9)));
      expect(problem(), isNull);
      expect(problem(code: 'a b'), contains('3 to 20'));
      expect(problem(title: ' '), contains('title'));
      expect(problem(value: null), contains('discount'));
      expect(problem(value: 150), contains('100'));
      expect(problem(value: 150, type: 'FLAT'), isNull);
      expect(problem(e: DateTime(2026, 10, 1)), contains('after'));
      expect(couponFormProblem(code: 'SAVE10', title: 'x1', discountType: 'FLAT', value: 5, startsAt: null, endsAt: null), contains('dates'));
    });

    test('sends rupees as paise and a percentage as it is', () {
      final percent = couponBody(
        code: ' save10 ',
        title: 'Ten',
        description: '',
        discountType: 'PERCENT',
        value: 10,
        maxDiscountRupees: 100,
        minBookingRupees: 500,
        usageLimit: 0,
        perCustomerLimit: 1,
        fundedBy: 'ABRA',
        newUsersOnly: false,
        startsAt: DateTime.utc(2026, 11, 1),
        endsAt: DateTime.utc(2026, 11, 30),
      );
      expect(percent['code'], 'SAVE10');
      expect(percent['value'], 10);
      expect(percent['maxDiscountPaise'], 10000);
      expect(percent['minBookingPaise'], 50000);
      expect(percent.containsKey('description'), isFalse);
      final flat = couponBody(
        code: 'FLAT50',
        title: 'Fifty off',
        description: 'x',
        discountType: 'FLAT',
        value: 50,
        maxDiscountRupees: 100,
        minBookingRupees: 0,
        usageLimit: 5,
        perCustomerLimit: 2,
        fundedBy: 'OPERATOR',
        newUsersOnly: true,
        startsAt: DateTime.utc(2026, 11, 1),
        endsAt: DateTime.utc(2026, 11, 30),
      );
      expect(flat['value'], 5000);
      expect(flat.containsKey('maxDiscountPaise'), isFalse);
      expect(flat['fundedBy'], 'OPERATOR');
    });
  });
}
