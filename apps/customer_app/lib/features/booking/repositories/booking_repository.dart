import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../../app/providers.dart';
import '../models/booking_models.dart';
import '../models/ticket_models.dart';

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

  /// Lets go of a hold at once (`DELETE /seat-locks/:lockId`).
  Future<void> releaseSeats(String lockId);

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

/// Backend implementation. The seat hold is connected; the booking, coupons
/// and the cancellation policy are "Not connected yet - built in Phase 3"
/// and come from [rest] until their endpoints exist.
class ApiBookingRepository implements BookingRepository {
  ApiBookingRepository(
    this._client, {
    BookingRepository rest = const NotConnectedBookingRepository(),
  }) : _rest = rest;

  final ApiClient _client;
  final BookingRepository _rest;

  @override
  Future<SeatLock> lockSeats({
    required String tripId,
    required List<String> seatIds,
    required String boardingPointId,
    required String droppingPointId,
  }) async {
    try {
      final response = await _client.post(
        'trips/${Uri.encodeComponent(tripId)}/seat-locks',
        body: <String, Object?>{
          'seatIds': seatIds,
          'boardingPointId': boardingPointId,
          'droppingPointId': droppingPointId,
        },
      );
      return response.decodeObject(seatLockFromJson);
    } on AppException catch (error) {
      final failure = error.failure;
      if (failure is ApiFailure && failure.code == 'SEAT_NOT_AVAILABLE') {
        throw const SeatsUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<void> releaseSeats(String lockId) async {
    await _client.delete('seat-locks/${Uri.encodeComponent(lockId)}');
  }

  @override
  Future<BookingCreated> createBooking(BookingRequest request) =>
      _rest.createBooking(request);

  @override
  Future<CouponResult> applyCoupon({
    required String tripId,
    required String code,
    required int basePaise,
  }) => _rest.applyCoupon(tripId: tripId, code: code, basePaise: basePaise);

  @override
  Future<List<String>> suggestedCoupons(String tripId) =>
      _rest.suggestedCoupons(tripId);

  @override
  Future<List<CancellationRule>> cancellationPolicy(String tripId) =>
      _rest.cancellationPolicy(tripId);
}

/// The hold as the backend sends it: its id and when it runs out.
SeatLock seatLockFromJson(JsonMap json) => SeatLock(
  lockId: '${json['lockId']}',
  expiresAt: DateTime.parse('${json['expiresAt']}'),
);

/// Not connected yet - built in Phase 3.
class NotConnectedBookingRepository implements BookingRepository {
  const NotConnectedBookingRepository();

  @override
  Future<SeatLock> lockSeats({
    required String tripId,
    required List<String> seatIds,
    required String boardingPointId,
    required String droppingPointId,
  }) async =>
      throw const SeatsUnavailableException();

  @override
  Future<void> releaseSeats(String lockId) async {}

  @override
  Future<BookingCreated> createBooking(BookingRequest request) async =>
      throw StateError('Not connected yet - built in Phase 3');

  @override
  Future<CouponResult> applyCoupon({
    required String tripId,
    required String code,
    required int basePaise,
  }) async =>
      CouponResult.invalid(code);

  @override
  Future<List<String>> suggestedCoupons(String tripId) async =>
      const <String>[];

  @override
  Future<List<CancellationRule>> cancellationPolicy(String tripId) async =>
      const <CancellationRule>[];
}

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => ApiBookingRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// The current time for the seat hold. Overridden in tests.
final bookingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
