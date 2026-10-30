import 'package:admin_app/core/browser_files_stub.dart' as downloads;
import 'package:admin_app/features/marketing/admin_coupons_api.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_admin.dart';

Map<String, Object?> couponJson({String id = 'c1', String code = 'WELCOME100', int used = 0, String status = 'ACTIVE'}) => <String, Object?>{
  'id': id,
  'code': code,
  'title': 'Welcome offer',
  'description': 'For your trip',
  'discountType': 'FLAT',
  'value': 10000,
  'maxDiscountPaise': null,
  'minBookingPaise': 50000,
  'usageLimit': 0,
  'perCustomerLimit': 1,
  'usedCount': used,
  'fundedBy': 'ABRA',
  'newUsersOnly': false,
  'startsAt': '2026-10-01T00:00:00.000Z',
  'endsAt': '2026-12-31T00:00:00.000Z',
  'status': status,
};

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

FakeBackend withCoupons() {
  final backend = FakeBackend(Persona.superAdmin);
  backend.overrides['GET admin/coupons'] = (_) => FakeResponse.ok(<Object?>[
    couponJson(),
    couponJson(id: 'c2', code: 'USEDONE', used: 3),
  ]);
  return backend;
}

void main() {
  group('the body of a change', () {
    final before = CouponRecord(
      id: 'c1',
      code: 'WELCOME100',
      title: 'Welcome offer',
      description: 'For your trip',
      discountType: 'FLAT',
      value: 10000,
      maxDiscountPaise: null,
      minBookingPaise: 50000,
      usageLimit: 0,
      perCustomerLimit: 1,
      usedCount: 0,
      fundedBy: 'ABRA',
      newUsersOnly: false,
      startsAt: DateTime.utc(2026, 10, 1),
      endsAt: DateTime.utc(2026, 12, 31),
      status: 'ACTIVE',
    );

    Map<String, Object?> body({String title = 'Welcome offer', double? value = 100, int usage = 0, int per = 1, String funder = 'ABRA', bool first = false, double? min = 500, DateTime? ends}) =>
        couponChangeBody(
          before: before,
          title: title,
          description: 'For your trip',
          value: value,
          usageLimit: usage,
          perCustomerLimit: per,
          fundedBy: funder,
          newUsersOnly: first,
          minBookingRupees: min,
          endsAt: ends ?? DateTime.utc(2026, 12, 31),
        );

    test('sends nothing when nothing changed', () {
      expect(body(), isEmpty);
    });

    test('sends only what changed, with money in paise', () {
      expect(body(title: 'New words', value: 150, min: 800, usage: 20), <String, Object?>{
        'title': 'New words',
        'value': 15000,
        'minBookingPaise': 80000,
        'usageLimit': 20,
      });
      expect(body(per: 2, funder: 'OPERATOR', first: true), <String, Object?>{
        'perCustomerLimit': 2,
        'fundedBy': 'OPERATOR',
        'newUsersOnly': true,
      });
      expect(body(ends: DateTime.utc(2027, 1, 31))['endsAt'], '2027-01-31T00:00:00.000Z');
    });
  });

  group('the Offers page', () {
    testWidgets('shows each coupon with Edit and Usage, and Delete only for one nobody used', (tester) async {
      final app = TestAdmin.signedIn(withCoupons());
      await app.pump(tester, size: const Size(1600, 1000));
      await open(tester, AdminRoutes.offers);

      expect(find.text('WELCOME100'), findsOneWidget);
      expect(find.text('USEDONE'), findsOneWidget);
      expect(find.text('Edit'), findsNWidgets(2));
      expect(find.text('Usage'), findsNWidgets(2));
      final deletes = tester.widgetList<TextButton>(find.widgetWithText(TextButton, 'Delete')).toList();
      expect(deletes, hasLength(2));
      expect(deletes[0].onPressed, isNotNull);
      expect(deletes[1].onPressed, isNull);
    });

    testWidgets('saves a change as a patch with only the changed fields', (tester) async {
      final backend = withCoupons();
      Object? sent;
      backend.overrides['PATCH admin/coupons/c1'] = (request) {
        sent = request.body;
        return FakeResponse.ok(couponJson());
      };
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1600, 1000));
      await open(tester, AdminRoutes.offers);

      await tapOn(tester, find.text('Edit').first);
      expect(find.text('Change WELCOME100'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Welcome offer'), 'Fresh title');
      await tapOn(tester, find.text('Save changes'));
      expect(sent, <String, Object?>{'title': 'Fresh title'});
    });

    testWidgets('says why when the server refuses a change to a used coupon', (tester) async {
      final backend = withCoupons();
      backend.overrides['PATCH admin/coupons/c2'] = (_) => FakeResponse.error(409, 'RESOURCE_IN_USE');
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1600, 1000));
      await open(tester, AdminRoutes.offers);

      await tapOn(tester, find.text('Edit').last);
      await tester.enterText(find.widgetWithText(TextField, 'Welcome offer'), 'Other');
      await tapOn(tester, find.text('Save changes'));
      expect(find.textContaining('cannot change'), findsWidgets);
    });

    testWidgets('shows who used a coupon', (tester) async {
      final backend = withCoupons();
      backend.overrides['GET admin/coupons/c2/usage'] = (_) => FakeResponse.ok(<String, Object?>{
        'code': 'USEDONE',
        'usedCount': 3,
        'reserved': 1,
        'redeemed': 2,
        'released': 0,
        'discountGivenPaise': 20000,
        'items': <Object?>[
          <String, Object?>{'bookingId': 'b1', 'pnr': 'ABR7K2M9QX', 'customerName': 'Asha Rao', 'customerPhone': '9876543210', 'discountPaise': 10000, 'status': 'REDEEMED', 'at': null},
        ],
      });
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1600, 1000));
      await open(tester, AdminRoutes.offers);

      await tapOn(tester, find.text('Usage').last);
      expect(find.text('Who used USEDONE'), findsOneWidget);
      expect(find.textContaining('Used 3 times: 2 paid, 1 waiting for payment'), findsOneWidget);
      expect(find.text('ABR7K2M9QX  Asha Rao'), findsOneWidget);
    });

    testWidgets('deletes after asking, and downloads the list from the server', (tester) async {
      final backend = withCoupons();
      var deleted = false;
      backend.overrides['DELETE admin/coupons/c1'] = (_) {
        deleted = true;
        return FakeResponse.ok(<String, Object?>{'deleted': true});
      };
      backend.overrides['GET admin/coupons/export?format=csv'] = (_) => const FakeResponse(200, 'csv bytes');
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1600, 1000));
      await open(tester, AdminRoutes.offers);

      await tapOn(tester, find.text('Delete').first);
      expect(find.text('Delete WELCOME100?'), findsOneWidget);
      await tapOn(tester, find.text('Keep it'));
      expect(deleted, isFalse);
      await tapOn(tester, find.text('Delete').first);
      await tapOn(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(deleted, isTrue);
      expect(find.text('WELCOME100 is deleted.'), findsOneWidget);

      downloads.lastDownloadName = null;
      await tapOn(tester, find.text('Export CSV'));
      expect(downloads.lastDownloadName, startsWith('coupons-'));
    });
  });
}
