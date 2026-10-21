import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/seat_models.dart';

/// Where the seats of a trip come from. Screens depend on this interface only.
abstract interface class SeatRepository {
  /// The layout, availability and fares of every seat of [tripId].
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint});
}

/// Backend: `GET /trips/:tripId/seats` (public, no token). Not connected yet.
class ApiSeatRepository implements SeatRepository {
  @override
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint}) =>
      throw UnimplementedError('GET /trips/:tripId/seats is not connected');
}

/// Not connected yet - built in Phase 3.
class NotConnectedSeatRepository implements SeatRepository {
  const NotConnectedSeatRepository();

  @override
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint}) async =>
      SeatMap(
        kind: layoutHint ?? SeatLayoutKind.seater,
        seats: const <Seat>[],
      );
}

final seatRepositoryProvider = Provider<SeatRepository>(
  (ref) => const NotConnectedSeatRepository(),
);
