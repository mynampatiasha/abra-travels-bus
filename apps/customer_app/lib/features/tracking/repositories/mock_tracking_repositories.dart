import '../../my_trips/repositories/trips_repository.dart';
import '../models/tracking_models.dart';
import 'tracking_repositories.dart';

/// A bus that is a few kilometres from the customer's stop. The position is
/// live for [liveFor] after the screen is opened; then the signal "is lost"
/// (a ping six minutes old, near Yelahanka) until the customer taps "Retry".
class MockTrackingRepository implements TrackingRepository {
  MockTrackingRepository({
    required DateTime Function() now,
    this.liveFor = const Duration(seconds: 40),
    this.delay = const Duration(milliseconds: 400),
  }) : _now = now;

  final DateTime Function() _now;
  final Duration liveFor;
  final Duration delay;
  final Map<String, DateTime> _openedAt = <String, DateTime>{};

  @override
  Future<TrackingSnapshot> snapshot(
    String bookingId, {
    bool retry = false,
  }) async {
    await Future<void>.delayed(delay);
    final now = _now();
    if (retry || !_openedAt.containsKey(bookingId)) {
      _openedAt[bookingId] = now;
    }
    final elapsed = now.difference(_openedAt[bookingId]!);
    final lost = elapsed >= liveFor;
    final minutes = (12 - elapsed.inMinutes).clamp(2, 12);
    return TrackingSnapshot(
      busNumber: 'KA 01 AB 4521',
      busTypeName: 'Volvo A/C Sleeper',
      operatorName: 'VRL Travels',
      driverName: 'Ramesh K',
      driverPhone: '+91 98450 00000',
      operatorPhone: '+91 80 4000 1234',
      stopName: 'Hebbal Flyover',
      etaMinutes: lost ? 25 : minutes,
      distanceKm: lost ? null : 4.2,
      lastPingAt: lost
          ? now.subtract(const Duration(minutes: 6))
          : now.subtract(Duration(seconds: elapsed.inSeconds % 10)),
      busProgress: lost ? 0.28 : 0.42,
      stopProgress: 0.58,
      isDelayed: lost,
      lastKnownPlace: lost ? 'Yelahanka' : null,
    );
  }
}

class MockSafetyRepository implements SafetyRepository {
  MockSafetyRepository({required DateTime Function() now}) : _now = now;

  final DateTime Function() _now;
  final List<EmergencyContact> _contacts = <EmergencyContact>[
    const EmergencyContact(
      id: 'c1',
      name: 'Priya Kumar',
      phone: '+91 98765 11111',
      relation: 'Sister',
    ),
    const EmergencyContact(
      id: 'c2',
      name: 'Rahul Menon',
      phone: '+91 98765 22222',
      relation: 'Friend',
    ),
  ];
  int _alerts = 0;

  @override
  Future<List<EmergencyContact>> contacts() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<EmergencyContact>.unmodifiable(_contacts);
  }

  @override
  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
    required String relation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final contact = EmergencyContact(
      id: 'c${_contacts.length + 1}',
      name: name,
      phone: phone,
      relation: relation,
    );
    _contacts.add(contact);
    return contact;
  }

  @override
  Future<SosAlert> triggerSos(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _alerts++;
    return SosAlert(
      id: 'sos-$_alerts',
      sentAt: _now(),
      contactsNotified: _contacts.length,
    );
  }

  @override
  Future<void> cancelSos(String alertId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

class MockSharingRepository implements SharingRepository {
  MockSharingRepository({required DateTime Function() now, required this.trips})
    : _now = now;

  final DateTime Function() _now;
  final TripsRepository trips;
  final Map<String, bool> _active = <String, bool>{};
  final Map<String, int> _links = <String, int>{};

  @override
  Future<ShareState> state(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // A trip that is about to leave starts with sharing on, as the
    // prototype shows.
    return _build(bookingId, _active[bookingId] ?? true);
  }

  @override
  Future<ShareState> start(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _active[bookingId] = true;
    _links[bookingId] = (_links[bookingId] ?? 0) + 1;
    return _build(bookingId, true, fresh: true);
  }

  @override
  Future<ShareState> stop(String bookingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _active[bookingId] = false;
    return _build(bookingId, false);
  }

  Future<ShareState> _build(
    String bookingId,
    bool active, {
    bool fresh = false,
  }) async {
    if (!active) return const ShareState.off();
    final booking = await trips.booking(bookingId);
    final code = bookingId.hashCode.abs().toRadixString(36).toUpperCase();
    final suffix = (_links[bookingId] ?? 0) == 0 ? '' : '${_links[bookingId]}';
    final now = _now();
    return ShareState(
      isActive: true,
      url: 'abra.in/t/${code.padRight(5, 'K').substring(0, 5)}$suffix',
      endsAt: booking.ticket.arrivalAt.add(const Duration(hours: 1)),
      people: fresh
          ? const <SharePerson>[]
          : <SharePerson>[
              SharePerson(
                name: 'Priya Kumar',
                viewedAt: now.subtract(const Duration(minutes: 2)),
              ),
              const SharePerson(name: 'Rahul Menon'),
            ],
    );
  }
}
