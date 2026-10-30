import 'package:customer_app/features/booking/models/booking_models.dart';
import 'package:customer_app/features/booking/models/payment_models.dart';
import 'package:customer_app/features/booking/models/seat_models.dart';
import 'package:customer_app/features/booking/models/ticket_models.dart';
import 'package:customer_app/features/booking/repositories/booking_repository.dart';
import 'package:customer_app/features/booking/repositories/payment_repository.dart';
import 'package:customer_app/features/booking/repositories/seat_repository.dart';
import 'package:customer_app/features/booking/repositories/ticket_repository.dart';
import 'package:customer_app/features/notifications/repositories/notifications_repositories.dart';
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

  group('the payment answer from the backend', () {
    test('a confirmed booking is a success', () {
      final result = paymentOutcomeOf(
        paymentResultFromJson(<String, Object?>{'status': 'SUCCESS', 'bookingStatus': 'CONFIRMED', 'refundDue': false}),
        bookingId: 'bk1',
        reference: 'order1',
      );
      expect(result.outcome, PaymentOutcome.success);
      expect(result.bookingId, 'bk1');
    });

    test('seats lost after paying are a timeout, a failed payment is a failure', () {
      final lost = paymentOutcomeOf(
        paymentResultFromJson(<String, Object?>{'status': 'SUCCESS', 'bookingStatus': 'EXPIRED', 'refundDue': true}),
        bookingId: 'bk1',
        reference: 'order1',
      );
      expect(lost.outcome, PaymentOutcome.timeout);
      final failed = paymentOutcomeOf(
        paymentResultFromJson(<String, Object?>{'status': 'FAILED', 'bookingStatus': 'FAILED', 'refundDue': false}),
        bookingId: 'bk1',
        reference: 'order1',
      );
      expect(failed.outcome, PaymentOutcome.failed);
      expect(failed.reference, 'order1');
    });

    test('reads the order to pay', () {
      final order = paymentOrderFromJson(<String, Object?>{'paymentId': 'p1', 'gatewayOrderId': 'o1', 'keyId': 'development'});
      expect(order.paymentId, 'p1');
      expect(order.keyId, 'development');
    });
  });

  group('the ticket from the backend', () {
    test('reads the trip, the passengers, the points and the QR text', () {
      final ticket = ticketFromJson(<String, Object?>{
        'bookingId': 'bk1',
        'tripId': 't1',
        'pnr': 'ABR7K2M9QX',
        'operatorName': 'Demo Travels',
        'busTypeName': 'AC Seater',
        'originName': 'Hyderabad',
        'destinationName': 'Bengaluru',
        'travelDate': '2026-10-29',
        'timezone': 'Asia/Kolkata',
        'departureAt': '2026-10-29T16:00:00.000Z',
        'arrivalAt': '2026-10-30T01:00:00.000Z',
        'durationMinutes': 540,
        'passengers': <Object?>[
          <String, Object?>{'name': 'Asha Rao', 'seatId': '1', 'age': 31, 'gender': 'FEMALE'},
          <String, Object?>{'name': 'Ravi Rao', 'seatId': '2', 'age': 32, 'gender': 'MALE'},
        ],
        'boarding': <String, Object?>{'name': 'Ameerpet Metro', 'time': '2026-10-29T16:00:00.000Z', 'address': 'Ameerpet'},
        'dropping': <String, Object?>{'name': 'Majestic', 'time': '2026-10-30T01:00:00.000Z'},
        'paidPaise': 170000,
        'currency': 'INR',
        'qrPayload': 'ABR1.bk1.ABR7K2M9QX.sig',
        'operatorPhone': '9000011111',
      });
      expect(ticket.pnr, 'ABR7K2M9QX');
      expect(ticket.seatIds, <String>['1', '2']);
      expect(ticket.boarding.name, 'Ameerpet Metro');
      expect(ticket.boarding.address, 'Ameerpet');
      expect(ticket.dropping.address, isNull);
      expect(ticket.paidPaise, 170000);
      expect(ticket.qrPayload, startsWith('ABR1.'));
      expect(ticket.operatorPhone, '9000011111');
      expect(ticket.departureAt.toUtc(), DateTime.utc(2026, 10, 29, 16));
    });
  });

  group('the offers from the backend', () {
    test('reads the code, the words, the last day and the conditions', () {
      final offer = offerFromJson(<String, Object?>{
        'code': 'SAVE10',
        'title': 'Ten percent',
        'description': '10% off up to Rs 100',
        'validTill': '2026-12-31T18:29:59.000Z',
        'terms': <Object?>['One use for each customer.', 'For your first booking only.'],
      });
      expect(offer.code, 'SAVE10');
      expect(offer.description, '10% off up to Rs 100');
      expect(offer.terms, hasLength(2));
      expect(offer.isValidOn(DateTime(2026, 10, 29)), isTrue);
      expect(offer.isValidOn(DateTime(2027, 2, 1)), isFalse);
    });
  });

  group('the cancellation policy from the backend', () {
    test('reads each refund window', () {
      final first = cancellationRuleFromJson(<String, Object?>{
        'fromHoursBefore': null,
        'toHoursBefore': 24,
        'refundPercent': 90,
      });
      expect(first.fromHoursBefore, isNull);
      expect(first.toHoursBefore, 24);
      expect(first.refundPercent, 90);
      final last = cancellationRuleFromJson(<String, Object?>{
        'fromHoursBefore': 12,
        'toHoursBefore': 0,
        'refundPercent': 0,
      });
      expect(last.fromHoursBefore, 12);
      expect(last.refundPercent, 0);
    });
  });
}
