import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_models.dart';

/// The bookings of the signed-in customer. Screens depend on this interface
/// only; the backend replaces [MockTripsRepository] by providing
/// [ApiTripsRepository] in [tripsRepositoryProvider]. Every method needs a
/// signed-in customer.
abstract interface class TripsRepository {
  /// All bookings, newest first (`GET /bookings`).
  Future<List<Booking>> bookings();

  /// One booking (`GET /bookings/:id`).
  Future<Booking> booking(String bookingId);

  /// What cancelling [seatIds] would refund
  /// (`POST /bookings/:id/cancellations/quote`).
  Future<CancellationQuote> quote(String bookingId, List<String> seatIds);

  /// Cancels [seatIds] and starts the refund
  /// (`POST /bookings/:id/cancellations`). Returns the booking as it is now.
  Future<Booking> cancel(
    String bookingId,
    List<String> seatIds, {
    required String reason,
  });
}

/// Backend implementation. Not connected yet; see the README table.
class ApiTripsRepository implements TripsRepository {
  @override
  Future<List<Booking>> bookings() => throw UnimplementedError('GET /bookings');

  @override
  Future<Booking> booking(String bookingId) =>
      throw UnimplementedError('GET /bookings/:id');

  @override
  Future<CancellationQuote> quote(String bookingId, List<String> seatIds) =>
      throw UnimplementedError('POST /bookings/:id/cancellations/quote');

  @override
  Future<Booking> cancel(
    String bookingId,
    List<String> seatIds, {
    required String reason,
  }) => throw UnimplementedError('POST /bookings/:id/cancellations');
}

/// Not connected yet - built in Phase 4.
class NotConnectedTripsRepository implements TripsRepository {
  const NotConnectedTripsRepository();

  @override
  Future<List<Booking>> bookings() async => const <Booking>[];

  @override
  Future<Booking> booking(String bookingId) async =>
      throw StateError('Not connected yet - built in Phase 4');

  @override
  Future<CancellationQuote> quote(String bookingId, List<String> seatIds) async =>
      throw StateError('Not connected yet - built in Phase 4');

  @override
  Future<Booking> cancel(
    String bookingId,
    List<String> seatIds, {
    required String reason,
  }) async =>
      throw StateError('Not connected yet - built in Phase 4');
}

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => const NotConnectedTripsRepository(),
);
