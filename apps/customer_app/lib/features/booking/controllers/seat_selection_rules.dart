import '../../discovery/controllers/trip_selection_controller.dart';
import '../models/seat_models.dart';

/// What happened when a seat was tapped.
enum SeatToggleOutcome {
  selected,
  deselected,

  /// Already [TripSelection.maxSeats] seats are chosen.
  limitReached,

  /// Booked or blocked: nothing changed.
  unavailable,
}

/// The result of [SeatSelectionRules.toggle]: the new choice and why.
class SeatToggleResult {
  const SeatToggleResult(this.seatIds, this.outcome);

  final List<String> seatIds;
  final SeatToggleOutcome outcome;
}

/// The rules of choosing seats, without any widget, so they can be tested
/// on their own: at most six seats, only seats that can be bought, and a
/// total that is the sum of the seat fares.
abstract final class SeatSelectionRules {
  static const maxSeats = TripSelection.maxSeats;

  /// Taps [seat] with [chosen] seats already chosen.
  static SeatToggleResult toggle(List<String> chosen, Seat seat) {
    if (chosen.contains(seat.id)) {
      return SeatToggleResult(
        List<String>.unmodifiable(chosen.where((id) => id != seat.id)),
        SeatToggleOutcome.deselected,
      );
    }
    if (!seat.isSelectable) {
      return SeatToggleResult(chosen, SeatToggleOutcome.unavailable);
    }
    if (chosen.length >= maxSeats) {
      return SeatToggleResult(chosen, SeatToggleOutcome.limitReached);
    }
    return SeatToggleResult(
      List<String>.unmodifiable(<String>[...chosen, seat.id]),
      SeatToggleOutcome.selected,
    );
  }

  /// The chosen seats that still exist and can be bought in [map], in the
  /// order they were chosen. Seats that were booked meanwhile drop out.
  static List<Seat> chosenSeats(SeatMap map, List<String> chosen) => <Seat>[
    for (final id in chosen)
      if (map.byId(id) case final Seat seat when seat.isSelectable) seat,
  ];

  /// Sum of the fares of [seats], in paise.
  static int totalPaise(Iterable<Seat> seats) =>
      seats.fold<int>(0, (sum, seat) => sum + seat.farePaise);
}
