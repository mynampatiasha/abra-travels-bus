import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../discovery/controllers/trip_search_controller.dart';
import '../../discovery/controllers/trip_selection_controller.dart';
import '../../discovery/models/discovery_models.dart';
import '../models/booking_models.dart';
import '../models/seat_models.dart';
import '../repositories/booking_repository.dart';
import 'seat_selection_controller.dart';
import 'seat_selection_rules.dart';

/// What every booking step needs to know: the trip, the seats that are
/// chosen and can still be bought, and the two points.
@immutable
class BookingContext {
  const BookingContext({
    required this.trip,
    required this.seats,
    required this.boarding,
    required this.dropping,
  });

  final TripDetail trip;
  final List<Seat> seats;
  final TripPoint? boarding;
  final TripPoint? dropping;

  List<String> get seatIds => seats.map((seat) => seat.id).toList();

  int get basePaise => SeatSelectionRules.totalPaise(seats);
}

final bookingContextProvider = FutureProvider.autoDispose
    .family<BookingContext, String>((ref, tripId) async {
      final trip = await ref.watch(tripDetailProvider(tripId).future);
      final map = await ref.watch(seatMapProvider(tripId).future);
      final selection = ref.watch(tripSelectionProvider(tripId));
      TripPoint? point(List<TripPoint> points, String? id) =>
          points.where((p) => p.id == id).firstOrNull;
      return BookingContext(
        trip: trip,
        seats: SeatSelectionRules.chosenSeats(map, selection.seatIds),
        boarding: point(trip.boardingPoints, selection.boardingPointId),
        dropping: point(trip.droppingPoints, selection.droppingPointId),
      );
    });

/// Coupons worth suggesting for the trip.
final couponSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>(
      (ref, tripId) =>
          ref.watch(bookingRepositoryProvider).suggestedCoupons(tripId),
    );

/// The cancellation policy of the trip.
final cancellationPolicyProvider = FutureProvider.autoDispose
    .family<List<CancellationRule>, String>(
      (ref, tripId) =>
          ref.watch(bookingRepositoryProvider).cancellationPolicy(tripId),
    );
