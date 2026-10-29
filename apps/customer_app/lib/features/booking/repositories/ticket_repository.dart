import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../../app/providers.dart';
import '../models/ticket_models.dart';

/// Where a confirmed booking and its ticket come from. Screens depend on
/// this interface only; the backend replaces [MockTicketRepository] by
/// providing [ApiTicketRepository].
abstract interface class TicketRepository {
  /// The ticket of [bookingId] (`GET /bookings/:id/ticket`, needs sign-in).
  Future<Ticket> ticket(String bookingId);
}

/// Backend: `GET /bookings/:id/ticket` (owner only, after payment).
class ApiTicketRepository implements TicketRepository {
  ApiTicketRepository(this._client);

  final ApiClient _client;

  @override
  Future<Ticket> ticket(String bookingId) async {
    final response = await _client.get(
      'bookings/${Uri.encodeComponent(bookingId)}/ticket',
    );
    return response.decodeObject(ticketFromJson);
  }
}

/// The ticket as the backend sends it.
Ticket ticketFromJson(JsonMap json) => Ticket(
  bookingId: '${json['bookingId']}',
  tripId: '${json['tripId']}',
  pnr: '${json['pnr']}',
  operatorName: '${json['operatorName'] ?? ''}',
  busTypeName: '${json['busTypeName'] ?? ''}',
  originName: '${json['originName'] ?? ''}',
  destinationName: '${json['destinationName'] ?? ''}',
  travelDate: '${json['travelDate'] ?? ''}',
  timezone: '${json['timezone'] ?? 'Asia/Kolkata'}',
  departureAt: DateTime.parse('${json['departureAt']}'),
  arrivalAt: DateTime.parse('${json['arrivalAt']}'),
  durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
  passengers: <TicketPassenger>[
    if (json['passengers'] is List)
      for (final item in json['passengers'] as List<Object?>)
        if (item is Map)
          TicketPassenger(
            name: '${item['name']}',
            seatId: '${item['seatId']}',
          ),
  ],
  boarding: _ticketPointFromJson(json['boarding']),
  dropping: _ticketPointFromJson(json['dropping']),
  paidPaise: (json['paidPaise'] as num?)?.toInt() ?? 0,
  currency: '${json['currency'] ?? 'INR'}',
  qrPayload: '${json['qrPayload']}',
  operatorPhone: json['operatorPhone'] as String?,
  contactEmail: json['contactEmail'] as String?,
);

TicketPoint _ticketPointFromJson(Object? raw) {
  final json = raw is Map ? asJsonMap(raw) : const <String, Object?>{};
  return TicketPoint(
    name: '${json['name'] ?? ''}',
    time: DateTime.tryParse('${json['time']}') ?? DateTime.now(),
    address: json['address'] as String?,
    landmark: json['landmark'] as String?,
  );
}

/// Not connected yet - built in Phase 3.
class NotConnectedTicketRepository implements TicketRepository {
  const NotConnectedTicketRepository();

  @override
  Future<Ticket> ticket(String bookingId) async =>
      throw StateError('Not connected yet - built in Phase 3');
}

final ticketRepositoryProvider = Provider<TicketRepository>(
  (ref) => ApiTicketRepository(ref.watch(appDependenciesProvider).apiClient),
);
