import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking_models.dart';
import '../models/ticket_models.dart';
import 'mock_booking_repository.dart';
import 'mock_ticket_repository.dart';

/// Why seats could not be held.
class SeatsUnavailableException implements Exception {
  const SeatsUnavailableException();
}

/// Everything the booking steps ask the backend for. Screens depend on this
/// interface only; the backend replaces [MockBookingRepository] by providing
/// [ApiBookingRepository] in [bookingRepositoryProvider].
abstract interface class BookingRepository {
  /// Holds [seatIds] of [tripId] for the customer
  /// (`POST /trips/:tripId/seat-locks`, needs sign-in). Throws
  /// [SeatsUnavailableException] when one of them was taken meanwhile.
  Future<SeatLock> lockSeats({
    required String tripId,
    required List<String> seatIds,
    required String boardingPointId,
    required String droppingPointId,
  });

  /// Creates the booking for held seats (`POST /bookings`). The backend
  /// prices it; the app shows its own estimate meanwhile. Throws
  /// [SeatsUnavailableException] when the hold was lost.
  Future<BookingCreated> createBooking(BookingRequest request);

  /// Checks [code] for the trip and the base fare
  /// (`POST /coupons/validate`).
  Future<CouponResult> applyCoupon({
    required String tripId,
    required String code,
    required int basePaise,
  });

  /// Coupons worth suggesting for this trip (`GET /coupons?tripId=`).
  Future<List<String>> suggestedCoupons(String tripId);

  /// What cancelling at each time costs (`GET /trips/:tripId/policy`).
  Future<List<CancellationRule>> cancellationPolicy(String tripId);
}

/// Backend implementation. Not connected yet; see the README table.
class ApiBookingRepository implements BookingRepository {
  @override
  Future<SeatLock> lockSeats({
    required String tripId,
    required List<String> seatIds,
    required String boardingPointId,
    required String droppingPointId,
  }) => throw UnimplementedError('POST /trips/:tripId/seat-locks');

  @override
  Future<BookingCreated> createBooking(BookingRequest request) =>
      throw UnimplementedError('POST /bookings');

  @override
  Future<CouponResult> applyCoupon({
    required String tripId,
    required String code,
    required int basePaise,
  }) => throw UnimplementedError('POST /coupons/validate');

  @override
  Future<List<String>> suggestedCoupons(String tripId) =>
      throw UnimplementedError('GET /coupons');

  @override
  Future<List<CancellationRule>> cancellationPolicy(String tripId) =>
      throw UnimplementedError('GET /trips/:tripId/policy');
}

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => MockBookingRepository(store: ref.watch(mockTicketStoreProvider)),
);

/// The current time for the seat hold. Overridden in tests.
final bookingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
