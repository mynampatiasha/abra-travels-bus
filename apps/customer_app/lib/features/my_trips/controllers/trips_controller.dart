import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/repositories/booking_repository.dart';
import '../models/trip_models.dart';
import '../repositories/trips_repository.dart';

/// The three lists of My trips.
enum TripListKind { upcoming, completed, cancelled }

/// Which list is open. Kept so that "Back to My trips" after a cancellation
/// can open the Cancelled list.
final tripListKindProvider =
    NotifierProvider<TripListKindController, TripListKind>(
      TripListKindController.new,
    );

class TripListKindController extends Notifier<TripListKind> {
  @override
  TripListKind build() => TripListKind.upcoming;

  void select(TripListKind kind) => state = kind;
}

/// Every booking of the customer.
final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>(
  (ref) => ref.watch(tripsRepositoryProvider).bookings(),
);

/// One booking. While its refund is on the way it reloads every minute.
final bookingProvider = FutureProvider.autoDispose.family<Booking, String>((
  ref,
  bookingId,
) async {
  final booking = await ref.watch(tripsRepositoryProvider).booking(bookingId);
  final refund = booking.refund;
  if (refund != null && refund.stage != RefundStage.refunded) {
    final timer = Timer(const Duration(seconds: 60), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return booking;
});

/// The bookings that belong in [kind]. Upcoming and completed lists hold
/// bookings that still have seats; the cancelled list holds fully cancelled
/// bookings.
List<Booking> bookingsOfKind(List<Booking> all, TripListKind kind) {
  final matching = all.where((booking) {
    switch (kind) {
      case TripListKind.upcoming:
        return booking.status == BookingStatus.confirmed;
      case TripListKind.completed:
        return booking.status == BookingStatus.completed;
      case TripListKind.cancelled:
        return booking.status == BookingStatus.cancelled;
    }
  }).toList();
  // The next trip first; past and cancelled trips newest first.
  matching.sort(
    (a, b) => kind == TripListKind.upcoming
        ? a.ticket.departureAt.compareTo(b.ticket.departureAt)
        : b.ticket.departureAt.compareTo(a.ticket.departureAt),
  );
  return matching;
}

/// Tracking opens this long before departure.
const trackingOpensBefore = Duration(hours: 2);

bool canTrack(Booking booking, DateTime now) {
  if (booking.status != BookingStatus.confirmed) return false;
  final opens = booking.ticket.departureAt.subtract(trackingOpensBefore);
  return !now.isBefore(opens);
}

/// The quote for cancelling [seatIds] of [bookingId]. Reloads when the
/// chosen seats change.
typedef QuoteKey = ({String bookingId, String seats});

final cancellationQuoteProvider = FutureProvider.autoDispose
    .family<CancellationQuote, QuoteKey>(
      (ref, key) => ref
          .watch(tripsRepositoryProvider)
          .quote(
            key.bookingId,
            key.seats.split(',').where((s) => s.isNotEmpty).toList(),
          ),
    );

/// The clock of the trip screens.
DateTime Function() clockFor(Ref ref) => ref.read(bookingClockProvider);
