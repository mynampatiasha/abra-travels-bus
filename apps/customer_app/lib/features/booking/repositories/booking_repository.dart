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

/// Backend implementation: the seat hold, the booking, coupons and the
/// cancellation policy all call their endpoints.
class ApiBookingRepository implements BookingRepository {
  ApiBookingRepository(this._client);

  final ApiClient _client;

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
  Future<BookingCreated> createBooking(BookingRequest request) async {
    try {
      final response = await _client.post(
        'bookings',
        body: bookingBody(request),
      );
      return response.decodeObject(bookingCreatedFromJson);
    } on AppException catch (error) {
      final failure = error.failure;
      if (failure is ApiFailure && failure.code == 'SEAT_LOCK_EXPIRED') {
        throw const SeatsUnavailableException();
      }
      rethrow;
    }
  }

  @override
  Future<CouponResult> applyCoupon({
    required String tripId,
    required String code,
    required int basePaise,
  }) async {
    final response = await _client.post(
      'coupons/validate',
      body: <String, Object?>{
        'tripId': tripId,
        'code': code,
        'basePaise': basePaise,
      },
    );
    return response.decodeObject(couponResultFromJson);
  }

  @override
  Future<List<String>> suggestedCoupons(String tripId) async {
    final response = await _client.get(
      'coupons',
      query: <String, Object?>{'tripId': tripId},
    );
    return response.decodeList(couponCodeFromJson);
  }

  @override
  Future<List<CancellationRule>> cancellationPolicy(String tripId) async {
    final response = await _client.get(
      'trips/${Uri.encodeComponent(tripId)}/policy',
      authenticated: false,
    );
    return response.decodeList(cancellationRuleFromJson);
  }
}

/// One refund window as the backend sends it (from the admin refund slabs).
CancellationRule cancellationRuleFromJson(JsonMap json) => CancellationRule(
  fromHoursBefore: (json['fromHoursBefore'] as num?)?.toInt(),
  toHoursBefore: (json['toHoursBefore'] as num?)?.toInt() ?? 0,
  refundPercent: (json['refundPercent'] as num?)?.toInt() ?? 0,
);

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

/// `POST /bookings`: the hold, one passenger per seat and the contact. The
/// prices are not sent; the backend reads them from the seats.
Map<String, Object?> bookingBody(BookingRequest request) {
  final gst = request.gst;
  final coupon = request.couponCode;
  return <String, Object?>{
    'lockId': request.lockId,
    'passengers': <Map<String, Object?>>[
      for (final seatId in request.seatIds)
        <String, Object?>{
          'seatId': seatId,
          'name': (request.passengers[seatId]?.name ?? '').trim(),
          'age': int.tryParse(request.passengers[seatId]?.age ?? '') ?? 0,
          'gender': switch (request.passengers[seatId]?.gender) {
            Gender.female => 'FEMALE',
            Gender.other => 'OTHER',
            _ => 'MALE',
          },
        },
    ],
    'contact': <String, Object?>{
      'mobile': request.contact.mobile.trim(),
      'email': request.contact.email.trim(),
    },
    if (gst.enabled)
      'gst': <String, Object?>{
        'gstin': gst.gstin.trim(),
        'company': gst.company.trim(),
      },
    if (coupon != null && coupon.isNotEmpty) 'couponCode': coupon,
    if (request.expectedAmountPaise > 0)
      'expectedAmountPaise': request.expectedAmountPaise,
  };
}

/// The booking as the backend sends it: its id and the amount to pay.
BookingCreated bookingCreatedFromJson(JsonMap json) => BookingCreated(
  bookingId: '${json['bookingId']}',
  amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
);

/// The answer to "is this code good for this booking?".
CouponResult couponResultFromJson(JsonMap json) => json['valid'] == true
    ? CouponResult.valid(
        code: '${json['code']}',
        discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
      )
    : CouponResult.invalid('${json['code']}');

/// A code on offer, from the coupon list.
String couponCodeFromJson(JsonMap json) => '${json['code']}';
