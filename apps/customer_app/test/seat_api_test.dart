import 'package:customer_app/features/booking/models/seat_models.dart';
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
}
