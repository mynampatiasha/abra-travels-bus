import 'package:customer_app/features/booking/models/seat_models.dart';
import 'package:customer_app/features/booking/repositories/seat_repository.dart';

/// Test seat repository providing standard sleeper and seater test seat layouts.
class FakeSeatRepository implements SeatRepository {
  const FakeSeatRepository();

  @override
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint}) async {
    final kind = layoutHint ?? SeatLayoutKind.sleeper;
    return kind == SeatLayoutKind.sleeper ? _sleeper() : _seater();
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
              status: SeatStatus.available,
              farePaise: deck == SeatDeck.lower ? 115000 : 105000,
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
            status: SeatStatus.available,
            farePaise: 89900,
          ),
    ];
    return SeatMap(kind: SeatLayoutKind.seater, seats: seats);
  }
}
