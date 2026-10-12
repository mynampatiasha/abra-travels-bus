import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../discovery/controllers/trip_search_controller.dart';
import '../../discovery/controllers/trip_selection_controller.dart';
import '../../discovery/models/discovery_models.dart';
import '../models/seat_models.dart';
import '../repositories/seat_repository.dart';
import 'seat_selection_rules.dart';

/// The seats of a trip. Loaded when the seat screen opens; the layout of the
/// trip's bus is passed along for the mock repository.
final seatMapProvider = FutureProvider.autoDispose.family<SeatMap, String>((
  ref,
  tripId,
) async {
  final trip = await ref.watch(tripDetailProvider(tripId).future);
  return ref
      .watch(seatRepositoryProvider)
      .seatMap(
        tripId,
        layoutHint: SeatLayoutKind.fromBerthType(trip.bus.berthType),
      );
});

/// Taps a seat of [tripId]: the chosen seats are kept in the trip selection
/// (so they survive sign-in) and the outcome says what to tell the customer.
SeatToggleOutcome toggleSeat(WidgetRef ref, String tripId, Seat seat) {
  final selector = ref.read(tripSelectionProvider(tripId).notifier);
  final result = SeatSelectionRules.toggle(
    ref.read(tripSelectionProvider(tripId)).seatIds,
    seat,
  );
  if (result.outcome == SeatToggleOutcome.selected ||
      result.outcome == SeatToggleOutcome.deselected) {
    selector.setSeats(result.seatIds);
  }
  return result.outcome;
}

/// Chooses the first boarding and the last dropping point of [trip] when
/// nothing is chosen yet, so a customer who comes straight to the seats
/// (a link, a restart) still has a complete choice.
void applyTripDefaults(WidgetRef ref, TripDetail trip) {
  final selection = ref.read(tripSelectionProvider(trip.id));
  if (selection.boardingPointId != null && selection.droppingPointId != null) {
    return;
  }
  ref
      .read(tripSelectionProvider(trip.id).notifier)
      .applyDefaults(
        boardingPointId: trip.boardingPoints.firstOrNull?.id,
        droppingPointId: trip.droppingPoints.lastOrNull?.id,
      );
}
