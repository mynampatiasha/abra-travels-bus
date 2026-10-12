import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ticket_models.dart';
import 'mock_ticket_repository.dart';

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

final ticketRepositoryProvider = Provider<TicketRepository>(
  (ref) => MockTicketRepository(ref.watch(mockTicketStoreProvider)),
);
