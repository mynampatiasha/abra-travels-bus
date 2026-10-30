import 'package:client_portal/features/bookings/client_bookings_screen.dart';
import 'package:client_portal/routing/portal_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';

import 'support/test_portal.dart';

Map<String, Object?> bookingJson({String id = 'b1', String pnr = 'ABR7K2M9QX', String status = 'CONFIRMED', String name = 'Asha Rao'}) =>
    <String, Object?>{
      'id': id,
      'pnr': pnr,
      'status': status,
      'customerName': name,
      'customerPhone': '9876543210',
      'customerEmail': 'asha@example.com',
      'route': 'Hyderabad to Bengaluru',
      'departureAt': '2026-11-01T16:00:00.000Z',
      'seats': '1, 2',
      'amountPaise': 188650,
    };

FakeResponse paged(List<Object?> items, {int total = -1}) => FakeResponse.ok(
  items,
  meta: <String, Object?>{'page': 1, 'pageSize': 20, 'total': total < 0 ? items.length : total},
);

FakeBackend withBookings({List<Object?>? items}) {
  final backend = FakeBackend(Persona.owner);
  backend.overrides['GET client/bookings/summary'] = (_) => FakeResponse.ok(<String, Object?>{
    'total': 3,
    'confirmed': 2,
    'cancelled': 1,
    'confirmedAmountPaise': 377300,
  });
  backend.overrides['GET client/bookings'] = (_) => paged(items ?? <Object?>[bookingJson(), bookingJson(id: 'b2', pnr: 'ABR2222222', status: 'CANCELLED', name: 'Nikhil')]);
  backend.overrides['GET client/bookings/b1'] = (_) => FakeResponse.ok(<String, Object?>{
    ...bookingJson(),
    'baseFarePaise': 175000,
    'gstPaise': 8750,
    'convenienceFeePaise': 4900,
    'discountPaise': 0,
    'boardingPoint': 'Ameerpet Metro',
    'droppingPoint': 'Majestic',
    'passengers': <Object?>[
      <String, Object?>{'seatId': '1', 'name': 'Asha Rao', 'age': 31, 'gender': 'FEMALE', 'status': 'ACTIVE'},
    ],
  });
  return backend;
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  test('money and words read the way the other pages do', () {
    expect(money(188650), '₹1,886.50');
    expect(money(85000), '₹850');
    expect(readable('REFUND_PENDING'), 'Refund pending');
    expect(dayTime(null), '-');
  });

  group('Client bookings', () {
    testWidgets('shows the numbers on top and this company bookings, all from the server', (tester) async {
      final app = TestPortal.signedIn(withBookings());
      await app.pump(tester);
      await open(tester, PortalRoutes.bookings);

      expect(find.text('Bookings'), findsWidgets);
      expect(find.text('Confirmed'), findsWidgets);
      expect(find.text('Paid by customers'), findsOneWidget);
      expect(find.text('₹3,773'), findsOneWidget);
      expect(find.text('ABR7K2M9QX'), findsOneWidget);
      expect(find.text('Nikhil'), findsOneWidget);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('1-2 of 2'), findsOneWidget);
      expect(find.textContaining('Not connected'), findsNothing);
    });

    testWidgets('says so when there are no bookings', (tester) async {
      final app = TestPortal.signedIn(withBookings(items: <Object?>[]));
      await app.pump(tester);
      await open(tester, PortalRoutes.bookings);
      expect(find.text('No bookings yet.'), findsOneWidget);
    });

    testWidgets('opens one booking with the passengers and the amount paid', (tester) async {
      final app = TestPortal.signedIn(withBookings());
      await app.pump(tester);
      await open(tester, PortalRoutes.bookings);

      await tapOn(tester, find.text('View').first);
      expect(find.text('Boarding'), findsOneWidget);
      expect(find.text('Ameerpet Metro'), findsOneWidget);
      expect(find.textContaining('Asha Rao, 31'), findsOneWidget);
      expect(find.text('₹1,886.50'), findsWidgets);
      expect(find.text('Total paid'), findsOneWidget);
    });
  });
}
