import 'package:meta/meta.dart';

/// No position for longer than this and the bus is shown as "signal lost".
const staleAfter = Duration(minutes: 3);

/// Where the bus is, as the backend last knew it
/// (`GET /bookings/:id/tracking`).
@immutable
final class TrackingSnapshot {
  const TrackingSnapshot({
    required this.busNumber,
    required this.busTypeName,
    required this.operatorName,
    required this.driverName,
    required this.stopName,
    required this.etaMinutes,
    required this.lastPingAt,
    required this.busProgress,
    required this.stopProgress,
    required this.isDelayed,
    this.distanceKm,
    this.driverPhone,
    this.operatorPhone,
    this.lastKnownPlace,
  });

  final String busNumber;
  final String busTypeName;
  final String operatorName;
  final String driverName;
  final String? driverPhone;
  final String? operatorPhone;

  /// The customer's boarding point, the stop the ETA is for.
  final String stopName;
  final int etaMinutes;
  final double? distanceKm;

  /// When the bus last reported its position.
  final DateTime lastPingAt;

  /// How far along the route the bus is and where the customer's stop is,
  /// both from 0 (start) to 1 (end). The map draws these.
  final double busProgress;
  final double stopProgress;
  final bool isDelayed;

  /// A name for the last known position ("Yelahanka"), when there is one.
  final String? lastKnownPlace;

  /// No position for [staleAfter] or more at [now].
  bool isStale(DateTime now) => now.difference(lastPingAt) >= staleAfter;
}

/// A person to alert in an emergency.
@immutable
final class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
  });

  final String id;
  final String name;
  final String phone;
  final String relation;
}

/// An SOS that was sent (`POST /safety/sos`).
@immutable
final class SosAlert {
  const SosAlert({
    required this.id,
    required this.sentAt,
    required this.contactsNotified,
  });

  final String id;
  final DateTime sentAt;
  final int contactsNotified;
}

/// A person who can follow the trip through the share link.
@immutable
final class SharePerson {
  const SharePerson({required this.name, this.viewedAt});

  final String name;

  /// Null until they open the link.
  final DateTime? viewedAt;
}

/// The share link of a trip and who has it (`/bookings/:id/share`).
@immutable
final class ShareState {
  const ShareState({
    required this.isActive,
    this.url,
    this.people = const <SharePerson>[],
    this.endsAt,
  });

  const ShareState.off() : this(isActive: false);

  final bool isActive;
  final String? url;
  final List<SharePerson> people;

  /// The link stops working then (an hour after arrival).
  final DateTime? endsAt;
}
