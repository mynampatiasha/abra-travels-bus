import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ticket_models.dart';

/// Where a confirmed booking and its ticket come from. Screens depend on
/// this interface only; the backend replaces [MockTicketRepository] by
/// providing [ApiTicketRepository].
abstract interface class TicketRepository {
  /// The ticket of [bookingId] (`GET /bookings/:id/ticket`, needs sign-in).
  Future<Ticket> ticket(String bookingId);
}

/// Backend implementation. Not connected yet; see the README table.
class ApiTicketRepository implements TicketRepository {
  @override
  Future<Ticket> ticket(String bookingId) =>
      throw UnimplementedError('GET /bookings/:id/ticket');
}

/// Not connected yet - built in Phase 3.
class NotConnectedTicketRepository implements TicketRepository {
  const NotConnectedTicketRepository();

  @override
  Future<Ticket> ticket(String bookingId) async =>
      throw StateError('Not connected yet - built in Phase 3');
}

final ticketRepositoryProvider = Provider<TicketRepository>(
  (ref) => const NotConnectedTicketRepository(),
);
