import 'package:customer_app/features/booking/models/booking_models.dart';
import 'package:customer_app/features/booking/models/seat_models.dart';
import 'package:customer_app/features/booking/models/ticket_models.dart';
import 'package:customer_app/features/booking/repositories/booking_repository.dart';
import 'package:customer_app/features/booking/repositories/seat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the seat map from the backend', () {
    test('reads the places, the status and the price of each seat', () {
      final map = seatMapFromJson(<String, Object?>{
        'berthType': 'SLEEPER',
        'aisleAfterColumn': 1,
        'seats': <Object?>[
          <String, Object?>{'id': '1', 'deck': 'LOWER', 'row': 0, 'column': 0, 'status': 'AVAILABLE', 'farePaise': 85000},
          <String, Object?>{'id': '2', 'deck': 'LOWER', 'row': 0, 'column': 1, 'status': 'BOOKED', 'farePaise': 85000},
          <String, Object?>{'id': '16', 'deck': 'UPPER', 'row': 0, 'column': 2, 'status': 'BLOCKED', 'farePaise': 90000},
        ],
      });
      expect(map.kind, SeatLayoutKind.sleeper);
      expect(map.hasDecks, isTrue);
      expect(map.aisleAfterColumn, 1);
      expect(map.seats, hasLength(3));
      expect(map.byId('1')!.status, SeatStatus.available);
      expect(map.byId('1')!.isSelectable, isTrue);
      expect(map.byId('2')!.status, SeatStatus.booked);
      expect(map.byId('2')!.isSelectable, isFalse);
      expect(map.byId('16')!.deck, SeatDeck.upper);
      expect(map.byId('16')!.status, SeatStatus.blocked);
      expect(map.byId('16')!.farePaise, 90000);
      expect(map.onDeck(SeatDeck.lower), hasLength(2));
    });

    test('a seater bus is drawn as seats on one deck', () {
      final map = seatMapFromJson(<String, Object?>{
        'berthType': 'SEATER',
        'seats': <Object?>[
          <String, Object?>{'id': '1', 'deck': 'LOWER', 'row': 0, 'column': 3, 'status': 'LADIES_ONLY', 'farePaise': 500},
        ],
      });
      expect(map.kind, SeatLayoutKind.seater);
      expect(map.aisleAfterColumn, 1);
      expect(map.byId('1')!.status, SeatStatus.ladiesOnly);
      expect(map.columnCount, 4);
    });

    test('a trip without seats gives an empty map, not a failure', () {
      final map = seatMapFromJson(<String, Object?>{'berthType': 'SEATER'});
      expect(map.seats, isEmpty);
    });
  });

  group('the seat hold from the backend', () {
    test('reads the hold id and the time it runs out', () {
      final lock = seatLockFromJson(<String, Object?>{
        'lockId': 'abc-123',
        'expiresAt': '2026-10-26T10:10:00.000Z',
      });
      expect(lock.lockId, 'abc-123');
      expect(lock.expiresAt.toUtc(), DateTime.utc(2026, 10, 26, 10, 10));
    });
  });

  group('the booking sent to the backend', () {
    test('sends the hold, one passenger per seat and the contact, no prices', () {
      final body = bookingBody(
        const BookingRequest(
          tripId: 't1',
          lockId: 'lock-1',
          seatIds: <String>['1', '2'],
          passengers: <String, PassengerEntry>{
            '1': PassengerEntry(name: ' Asha Rao ', age: '31', gender: Gender.female),
            '2': PassengerEntry(name: 'Ravi Rao', age: '34', gender: Gender.male),
          },
          contact: ContactEntry(mobile: '9876543210', email: 'asha@example.com'),
          boardingPointId: 'b',
          droppingPointId: 'd',
          expectedAmountPaise: 170000,
        ),
      );
      expect(body['lockId'], 'lock-1');
      final passengers = body['passengers']! as List<Object?>;
      expect(passengers, hasLength(2));
      expect((passengers.first! as Map<String, Object?>)['name'], 'Asha Rao');
      expect((passengers.first! as Map<String, Object?>)['age'], 31);
      expect((passengers.first! as Map<String, Object?>)['gender'], 'FEMALE');
      expect((passengers.last! as Map<String, Object?>)['gender'], 'MALE');
      expect(body['expectedAmountPaise'], 170000);
      expect(body.containsKey('gst'), isFalse);
    });

    test('reads the booking id and the amount to pay', () {
      final created = bookingCreatedFromJson(<String, Object?>{
        'bookingId': 'bk1',
        'amountPaise': 175000,
      });
      expect(created.bookingId, 'bk1');
      expect(created.amountPaise, 175000);
    });
  });

  group('coupons from the backend', () {
    test('a good code carries the discount, a refused one does not', () {
      final good = couponResultFromJson(<String, Object?>{
        'code': 'SAVE10',
        'valid': true,
        'discountPaise': 8500,
      });
      expect(good.isValid, isTrue);
      expect(good.discountPaise, 8500);
      final bad = couponResultFromJson(<String, Object?>{
        'code': 'OLD',
        'valid': false,
        'discountPaise': 0,
        'reason': 'This code is not active right now.',
      });
      expect(bad.isValid, isFalse);
      expect(bad.discountPaise, 0);
    });

    test('a listed coupon gives its code', () {
      expect(couponCodeFromJson(<String, Object?>{'code': 'SAVE10'}), 'SAVE10');
    });
  });
}
