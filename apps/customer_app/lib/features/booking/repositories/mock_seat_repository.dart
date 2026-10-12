import '../models/seat_models.dart';
import 'seat_repository.dart';

/// Sample seats in the layouts of the approved design: a sleeper with 18
/// berths per deck (2+1) and a seater with 40 seats (2+2).
class MockSeatRepository implements SeatRepository {
  const MockSeatRepository({
    this.delay = const Duration(milliseconds: 600),
    this.sleeperLowerPaise = 115000,
    this.sleeperUpperPaise = 105000,
    this.seaterPaise = 89900,
  });

  final Duration delay;
  final int sleeperLowerPaise;
  final int sleeperUpperPaise;
  final int seaterPaise;

  static const _sleeperBooked = <String>{
    'L2', 'L5', 'L9', 'L12', 'L14', 'U1', 'U6', 'U7', //
  };
  static const _seaterBooked = <String>{
    '1A', '2D', '3B', '5A', '5B', '7C', '9D', '10A', //
  };
  static const _sleeperLadies = <String>{'L3', 'L4', 'L11', 'U10', 'U11'};
  static const _seaterLadies = <String>{'2A', '2B'};
  static const _sleeperBlocked = <String>{'L18', 'U16'};
  static const _seaterBlocked = <String>{'10D'};

  @override
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint}) async {
    await Future<void>.delayed(delay);
    // Without a hint, the layout follows the trip id so that both layouts
    // appear while only sample data exists.
    final kind =
        layoutHint ??
        (tripId.codeUnits.fold<int>(0, (a, b) => a + b).isEven
            ? SeatLayoutKind.sleeper
            : SeatLayoutKind.seater);
    return kind == SeatLayoutKind.sleeper ? _sleeper() : _seater();
  }

  SeatStatus _status(
    String id,
    Set<String> booked,
    Set<String> ladies,
    Set<String> blocked,
  ) {
    if (blocked.contains(id)) return SeatStatus.blocked;
    if (booked.contains(id)) return SeatStatus.booked;
    if (ladies.contains(id)) return SeatStatus.ladiesOnly;
    return SeatStatus.available;
  }

  SeatMap _sleeper() {
    final seats = <Seat>[];
    for (final deck in SeatDeck.values) {
      final prefix = deck == SeatDeck.lower ? 'L' : 'U';
      for (var row = 0; row < 6; row++) {
        for (var column = 0; column < 3; column++) {
          final id = '$prefix${row * 3 + column + 1}';
          seats.add(
            Seat(
              id: id,
              deck: deck,
              row: row,
              column: column,
              status: _status(
                id,
                _sleeperBooked,
                _sleeperLadies,
                _sleeperBlocked,
              ),
              farePaise: deck == SeatDeck.lower
                  ? sleeperLowerPaise
                  : sleeperUpperPaise,
            ),
          );
        }
      }
    }
    return SeatMap(kind: SeatLayoutKind.sleeper, seats: seats);
  }

  SeatMap _seater() {
    const letters = <String>['A', 'B', 'C', 'D'];
    final seats = <Seat>[
      for (var row = 0; row < 10; row++)
        for (var column = 0; column < 4; column++)
          Seat(
            id: '${row + 1}${letters[column]}',
            deck: SeatDeck.lower,
            row: row,
            column: column,
            status: _status(
              '${row + 1}${letters[column]}',
              _seaterBooked,
              _seaterLadies,
              _seaterBlocked,
            ),
            farePaise: seaterPaise,
          ),
    ];
    return SeatMap(kind: SeatLayoutKind.seater, seats: seats);
  }
}
