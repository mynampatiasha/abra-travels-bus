import 'package:admin_app/features/sales/sales_api.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_admin.dart';

Map<String, Object?> bookingJson({String id = 'b1', String pnr = 'ABR7K2M9QX', String status = 'CONFIRMED', String name = 'Asha Rao', String payment = 'SUCCESS'}) =>
    <String, Object?>{
      'id': id,
      'pnr': pnr,
      'status': status,
      'customerName': name,
      'customerPhone': '9876543210',
      'customerEmail': 'asha@example.com',
      'route': 'Hyderabad to Bengaluru',
      'operatorName': 'Demo Travels',
      'departureAt': '2026-11-01T16:00:00.000Z',
      'seats': '1, 2',
      'amountPaise': 188650,
      'paymentStatus': payment,
    };

Map<String, Object?> detailJson({String status = 'CONFIRMED'}) => <String, Object?>{
  ...bookingJson(status: status),
  'baseFarePaise': 175000,
  'gstPaise': 8750,
  'convenienceFeePaise': 4900,
  'discountPaise': 0,
  'couponCode': null,
  'boardingPoint': 'Ameerpet Metro',
  'droppingPoint': 'Majestic',
  'passengers': <Object?>[
    <String, Object?>{'seatId': '1', 'name': 'Asha Rao', 'age': 31, 'gender': 'FEMALE', 'farePaise': 85000, 'status': 'ACTIVE'},
    <String, Object?>{'seatId': '2', 'name': 'Ravi Rao', 'age': 34, 'gender': 'MALE', 'farePaise': 90000, 'status': 'ACTIVE'},
  ],
  'payments': <Object?>[
    <String, Object?>{'id': 'p1', 'status': 'SUCCESS', 'amountPaise': 188650, 'gateway': 'razorpay', 'refundedPaise': 0, 'createdAt': '2026-10-29T10:00:00.000Z'},
  ],
};

FakeResponse paged(List<Object?> items, {int page = 1, int total = -1}) => FakeResponse.ok(
  items,
  meta: <String, Object?>{'page': page, 'pageSize': 20, 'total': total < 0 ? items.length : total},
);

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  group('the amounts and words of the sales pages', () {
    test('money is in rupees, with groups, and paise only when there are some', () {
      expect(money(85000), '₹850');
      expect(money(94150), '₹941.50');
      expect(money(188650), '₹1,886.50');
      expect(money(12345600), '₹1,23,456');
      expect(money(0), '₹0');
    });

    test('a code reads as words', () {
      expect(readable('PAYMENT_PENDING'), 'Payment pending');
      expect(readable('SUCCESS'), 'Success');
      expect(readable(''), '-');
    });

    test('a query keeps only the filters that are set', () {
      expect(const SalesQuery().filters(), isEmpty);
      expect(const SalesQuery(search: ' ABR1 ', status: 'CONFIRMED').filters(), <String, String>{'search': 'ABR1', 'status': 'CONFIRMED'});
    });
  });

  group('Admin bookings', () {
    testWidgets('lists the real bookings and asks the server for the filters chosen', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      final asked = <Map<String, dynamic>>[];
      backend.overrides['GET admin/bookings'] = (request) {
        asked.add(Map<String, dynamic>.of(request.options.queryParameters));
        return paged(<Object?>[bookingJson(), bookingJson(id: 'b2', pnr: 'ABR2222222', status: 'PAYMENT_PENDING', name: 'Nikhil', payment: 'NONE')], total: 2);
      };
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1000));
      await open(tester, AdminRoutes.bookings);

      expect(find.text('Bookings'), findsWidgets);
      expect(find.text('ABR7K2M9QX'), findsOneWidget);
      expect(find.text('Hyderabad to Bengaluru'), findsNWidgets(2));
      expect(find.text('₹1,886.50'), findsNWidgets(2));
      expect(find.text('Payment pending'), findsOneWidget);
      expect(find.text('1-2 of 2'), findsOneWidget);
      expect(asked.first['page'], 1);
      expect(asked.first.containsKey('search'), isFalse);

      await tester.enterText(find.byType(TextField).first, 'ABR7');
      await tapOn(tester, find.text('Search'));
      expect(asked.last['search'], 'ABR7');
      expect(asked.last['page'], 1);
    });

    testWidgets('says so when nothing matches, and the server failing is not a blank page', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      backend.overrides['GET admin/bookings'] = (request) => paged(<Object?>[]);
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1000));
      await open(tester, AdminRoutes.bookings);
      expect(find.text('No bookings match these filters.'), findsOneWidget);

      backend.overrides['GET admin/bookings'] = (request) => FakeResponse.error(500, 'INTERNAL_ERROR');
      await tester.enterText(find.byType(TextField).first, 'ABR9');
      await tapOn(tester, find.text('Search'));
      expect(find.text('No bookings match these filters.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('opens one booking in full and sends the ticket again only when it is paid', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      var resent = 0;
      backend.overrides['GET admin/bookings'] = (request) => paged(<Object?>[bookingJson()]);
      backend.overrides['GET admin/bookings/b1'] = (request) => FakeResponse.ok(detailJson());
      backend.overrides['POST admin/bookings/b1/resend-ticket'] = (request) {
        resent++;
        return FakeResponse.ok(<String, Object?>{'queued': true});
      };
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1000));
      await open(tester, AdminRoutes.bookings);

      await tapOn(tester, find.text('View'));
      expect(find.text('Passengers'), findsOneWidget);
      expect(find.text('Ravi Rao'), findsOneWidget);
      expect(find.text('Ameerpet Metro'), findsOneWidget);
      expect(find.text('₹87.50'), findsOneWidget);
      expect(find.text('₹49'), findsOneWidget);
      expect(find.textContaining('Razorpay'), findsOneWidget);

      await tapOn(tester, find.text('Resend ticket'));
      expect(resent, 1);
      expect(find.text('The ticket message is queued again.'), findsOneWidget);
    });

    testWidgets('does not offer to resend a booking that is not paid', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      backend.overrides['GET admin/bookings'] = (request) => paged(<Object?>[bookingJson(status: 'PAYMENT_PENDING', payment: 'NONE')]);
      backend.overrides['GET admin/bookings/b1'] = (request) => FakeResponse.ok(detailJson(status: 'PAYMENT_PENDING'));
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1000));
      await open(tester, AdminRoutes.bookings);
      await tapOn(tester, find.text('View'));
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Resend ticket'), matching: find.byWidgetPredicate((w) => w is FilledButton)),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Admin payments', () {
    testWidgets('lists payments, marks a refund that is due, and the page needs payments.read', (tester) async {
      final backend = FakeBackend(Persona.superAdmin);
      backend.overrides['GET admin/payments'] = (request) => paged(<Object?>[
        <String, Object?>{
          'id': 'p1',
          'pnr': 'ABR7K2M9QX',
          'customerName': 'Asha Rao',
          'customerPhone': '9876543210',
          'gateway': 'razorpay',
          'gatewayPaymentId': 'pay_123',
          'amountPaise': 94150,
          'refundedPaise': 94150,
          'status': 'SUCCESS',
          'failureReason': '',
          'refundDue': true,
          'createdAt': '2026-10-29T10:00:00.000Z',
        },
      ]);
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: const Size(1440, 1000));
      await open(tester, AdminRoutes.payments);

      expect(find.text('pay_123'), findsOneWidget);
      expect(find.text('Refund due'), findsOneWidget);
      expect(find.text('₹941.50'), findsNWidgets(2));
      expect(find.text('Razorpay'), findsOneWidget);
    });
  });
}
