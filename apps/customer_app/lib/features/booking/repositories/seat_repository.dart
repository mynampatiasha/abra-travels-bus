import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../../app/providers.dart';
import '../models/seat_models.dart';

/// Where the seats of a trip come from. Screens depend on this interface only.
abstract interface class SeatRepository {
  /// The layout, availability and fares of every seat of [tripId].
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint});
}

/// Backend: `GET /trips/:tripId/seats` (public, no token). A hold that has
/// run out shows its seat as free; a seat held or sold to someone else is
/// `BOOKED`.
class ApiSeatRepository implements SeatRepository {
  ApiSeatRepository(this._client);

  final ApiClient _client;

  @override
  Future<SeatMap> seatMap(String tripId, {SeatLayoutKind? layoutHint}) async {
    final response = await _client.get(
      'trips/${Uri.encodeComponent(tripId)}/seats',
      authenticated: false,
    );
    return response.decodeObject(seatMapFromJson);
  }
}

/// The seat map as the backend sends it.
SeatMap seatMapFromJson(JsonMap json) {
  final raw = json['seats'];
  return SeatMap(
    kind: SeatLayoutKind.fromBerthType('${json['berthType'] ?? ''}'),
    aisleAfterColumn: (json['aisleAfterColumn'] as num?)?.toInt() ?? 1,
    seats: <Seat>[
      if (raw is List)
        for (final item in raw)
          if (item is Map) _seatFromJson(asJsonMap(item)),
    ],
  );
}

Seat _seatFromJson(JsonMap json) => Seat(
  id: '${json['id']}',
  deck: json['deck'] == 'UPPER' ? SeatDeck.upper : SeatDeck.lower,
  row: (json['row'] as num?)?.toInt() ?? 0,
  column: (json['column'] as num?)?.toInt() ?? 0,
  status: switch ('${json['status']}') {
    'AVAILABLE' => SeatStatus.available,
    'LADIES_ONLY' => SeatStatus.ladiesOnly,
    'BLOCKED' => SeatStatus.blocked,
    _ => SeatStatus.booked,
  },
  farePaise: (json['farePaise'] as num?)?.toInt() ?? 0,
);

final seatRepositoryProvider = Provider<SeatRepository>(
  (ref) => ApiSeatRepository(ref.watch(appDependenciesProvider).apiClient),
);
