import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tracking_models.dart';

/// Where the bus is. Screens depend on this interface only; the backend
/// replaces [MockTrackingRepository] by providing [ApiTrackingRepository].
abstract interface class TrackingRepository {
  /// The bus of [bookingId] now (`GET /bookings/:id/tracking`, needs
  /// sign-in). [retry] asks for a fresh position (the "Retry" of a lost
  /// signal); the backend ignores it, the mock uses it to come back live.
  Future<TrackingSnapshot> snapshot(String bookingId, {bool retry = false});
}

class ApiTrackingRepository implements TrackingRepository {
  @override
  Future<TrackingSnapshot> snapshot(String bookingId, {bool retry = false}) =>
      throw UnimplementedError('GET /bookings/:id/tracking');
}

/// Emergency contacts and the SOS. Needs sign-in.
abstract interface class SafetyRepository {
  /// `GET /me/emergency-contacts`.
  Future<List<EmergencyContact>> contacts();

  /// `POST /me/emergency-contacts`.
  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
    required String relation,
  });

  /// Sends the SOS: contacts, the safety team and, for the police, the
  /// control room are told with the live location (`POST /safety/sos`).
  Future<SosAlert> triggerSos(String bookingId);

  /// "I'm safe": ends the alert (`POST /safety/sos/:id/cancel`).
  Future<void> cancelSos(String alertId);
}

class ApiSafetyRepository implements SafetyRepository {
  @override
  Future<List<EmergencyContact>> contacts() =>
      throw UnimplementedError('GET /me/emergency-contacts');

  @override
  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
    required String relation,
  }) => throw UnimplementedError('POST /me/emergency-contacts');

  @override
  Future<SosAlert> triggerSos(String bookingId) =>
      throw UnimplementedError('POST /safety/sos');

  @override
  Future<void> cancelSos(String alertId) =>
      throw UnimplementedError('POST /safety/sos/:id/cancel');
}

/// The link that lets family follow a trip. Needs sign-in.
abstract interface class SharingRepository {
  /// `GET /bookings/:id/share`.
  Future<ShareState> state(String bookingId);

  /// Creates a link (`POST /bookings/:id/share`).
  Future<ShareState> start(String bookingId);

  /// Ends the link at once (`DELETE /bookings/:id/share`).
  Future<ShareState> stop(String bookingId);
}

class ApiSharingRepository implements SharingRepository {
  @override
  Future<ShareState> state(String bookingId) =>
      throw UnimplementedError('GET /bookings/:id/share');

  @override
  Future<ShareState> start(String bookingId) =>
      throw UnimplementedError('POST /bookings/:id/share');

  @override
  Future<ShareState> stop(String bookingId) =>
      throw UnimplementedError('DELETE /bookings/:id/share');
}

/// Not connected yet - built in Phase 5.
class NotConnectedTrackingRepository implements TrackingRepository {
  const NotConnectedTrackingRepository();

  @override
  Future<TrackingSnapshot> snapshot(String bookingId, {bool retry = false}) async =>
      throw StateError('Not connected yet - built in Phase 5');
}

/// Not connected yet - built in Phase 5.
class NotConnectedSafetyRepository implements SafetyRepository {
  const NotConnectedSafetyRepository();

  @override
  Future<List<EmergencyContact>> contacts() async => const <EmergencyContact>[];

  @override
  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
    required String relation,
  }) async =>
      throw StateError('Not connected yet - built in Phase 5');

  @override
  Future<SosAlert> triggerSos(String bookingId) async =>
      throw StateError('Not connected yet - built in Phase 5');

  @override
  Future<void> cancelSos(String alertId) async =>
      throw StateError('Not connected yet - built in Phase 5');
}

/// Not connected yet - built in Phase 5.
class NotConnectedSharingRepository implements SharingRepository {
  const NotConnectedSharingRepository();

  @override
  Future<ShareState> state(String bookingId) async => const ShareState.off();

  @override
  Future<ShareState> start(String bookingId) async =>
      throw StateError('Not connected yet - built in Phase 5');

  @override
  Future<ShareState> stop(String bookingId) async =>
      throw StateError('Not connected yet - built in Phase 5');
}

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => const NotConnectedTrackingRepository(),
);

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => const NotConnectedSafetyRepository(),
);

final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => const NotConnectedSharingRepository(),
);
