import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/seat_models.dart';
import 'mock_seat_repository.dart';

/// Where the seats of a trip come from. Screens depend on this interface
/// only; the backend replaces [MockSeatRepository] by providing
/// [ApiSeatRepository] in [seatRepositoryProvider].
abstract interface class SeatRepository {
  /// The layout, availability and fares of every seat of [tripId].
  ///
  /// [layoutHint] is the layout of the trip's bus. Only the mock uses it, to
  /// draw the layout of the bus the customer opened; the backend knows it.
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint});
}

/// Backend: `GET /trips/:tripId/seats` (public, no token). Not connected
/// yet; see the README table of repositories.
class ApiSeatRepository implements SeatRepository {
  @override
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint}) =>
      throw UnimplementedError('GET /trips/:tripId/seats is not connected');
}

final seatRepositoryProvider = Provider<SeatRepository>(
  (ref) => const MockSeatRepository(),
);
