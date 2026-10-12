import '../models/booking_models.dart';
import '../models/ticket_models.dart';
import 'booking_repository.dart';
import 'mock_ticket_repository.dart';

/// Sample answers for the booking steps: a ten-minute hold, the coupon
/// `ABRA100` (₹100 off), and a three-step cancellation policy.
class MockBookingRepository implements BookingRepository {
  MockBookingRepository({
    required this.store,
    this.delay = const Duration(milliseconds: 400),
    this.holdDuration = const Duration(minutes: 10),
    this.lockFails = false,
  });

  /// Where created bookings are kept, for the ticket screens to read.
  final MockTicketStore store;

  final Duration delay;
  final Duration holdDuration;

  /// Makes every hold fail, to see the "seats taken" path.
  final bool lockFails;

  @override
  Future<SeatLock> lockSeats({
    required String tripId,
    required List<String> seatIds,
    required String boardingPointId,
    required String droppingPointId,
  }) async {
    await Future<void>.delayed(delay);
    if (lockFails) throw const SeatsUnavailableException();
    return SeatLock(
      lockId: 'mock-lock-${seatIds.join('-')}',
      expiresAt: DateTime.now().add(holdDuration),
    );
  }

  @override
  Future<BookingCreated> createBooking(BookingRequest request) async {
    await Future<void>.delayed(delay);
    if (lockFails) throw const SeatsUnavailableException();
    return store.create(request);
  }

  @override
  Future<CouponResult> applyCoupon({
    required String tripId,
    required String code,
    required int basePaise,
  }) async {
    await Future<void>.delayed(delay);
    final normalised = code.trim().toUpperCase();
    return normalised == 'ABRA100'
        ? CouponResult.valid(code: normalised, discountPaise: 10000)
        : CouponResult.invalid(normalised);
  }

  @override
  Future<List<String>> suggestedCoupons(String tripId) async => const <String>[
    'ABRA100',
    'WEEKEND5',
  ];

  /// 90% refund from 24 hours before departure, 50% from 12 to 24 hours,
  /// nothing under 12 hours.
  static const List<CancellationRule> defaultPolicy = <CancellationRule>[
    CancellationRule(
      fromHoursBefore: null,
      toHoursBefore: 24,
      refundPercent: 90,
    ),
    CancellationRule(fromHoursBefore: 24, toHoursBefore: 12, refundPercent: 50),
    CancellationRule(fromHoursBefore: 12, toHoursBefore: 0, refundPercent: 0),
  ];

  @override
  Future<List<CancellationRule>> cancellationPolicy(String tripId) async =>
      defaultPolicy;
}
