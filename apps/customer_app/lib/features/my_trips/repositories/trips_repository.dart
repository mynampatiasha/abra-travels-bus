import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/repositories/booking_repository.dart';
import '../../booking/repositories/mock_ticket_repository.dart';
import '../models/trip_models.dart';
import 'mock_trips_repository.dart';

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

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => MockTripsRepository(
    tickets: ref.watch(mockTicketStoreProvider),
    now: ref.read(bookingClockProvider),
  ),
);
