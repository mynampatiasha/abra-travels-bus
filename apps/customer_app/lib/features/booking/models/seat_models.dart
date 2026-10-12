import 'package:meta/meta.dart';

/// The two bus layouts the app draws.
enum SeatLayoutKind {
  /// Berths in a 2+1 layout, on a lower and an upper deck.
  sleeper,

  /// Seats in a 2+2 layout, on one deck.
  seater;

  /// The layout for the backend's `berthType`. Anything that is not a
  /// sleeper is drawn as seats.
  static SeatLayoutKind fromBerthType(String berthType) =>
      berthType.toUpperCase().contains('SLEEPER') ? sleeper : seater;
}

enum SeatDeck { lower, upper }

/// What can be done with a seat.
enum SeatStatus {
  available,

  /// Taken by another booking. Tapping it only explains that.
  booked,

  /// Only female passengers may travel in it.
  ladiesOnly,

  /// Not for sale (the operator keeps it). Cannot be tapped.
  blocked;

  bool get isSelectable => this == available || this == ladiesOnly;
}

/// One seat or berth of a bus.
@immutable
final class Seat {
  const Seat({
    required this.id,
    required this.deck,
    required this.row,
    required this.column,
    required this.status,
    required this.farePaise,
  });

  /// What the customer sees ("L6", "4B").
  final String id;
  final SeatDeck deck;

  /// Counted from the front of the bus.
  final int row;

  /// Counted from the left of the aisle's left side.
  final int column;
  final SeatStatus status;

  /// For display; the amount to pay is calculated by the backend.
  final int farePaise;

  bool get isSelectable => status.isSelectable;
}

/// The seats of one trip and where they are.
@immutable
final class SeatMap {
  const SeatMap({
    required this.kind,
    required this.seats,
    this.aisleAfterColumn = 1,
  });

  final SeatLayoutKind kind;
  final List<Seat> seats;

  /// The aisle runs between this column and the next.
  final int aisleAfterColumn;

  bool get hasDecks => kind == SeatLayoutKind.sleeper;

  List<Seat> onDeck(SeatDeck deck) =>
      seats.where((seat) => seat.deck == deck).toList(growable: false);

  Seat? byId(String id) {
    for (final seat in seats) {
      if (seat.id == id) return seat;
    }
    return null;
  }

  int get rowCount => seats.isEmpty
      ? 0
      : seats.map((s) => s.row).reduce((a, b) => a > b ? a : b) + 1;

  int get columnCount => seats.isEmpty
      ? 0
      : seats.map((s) => s.column).reduce((a, b) => a > b ? a : b) + 1;
}
