import 'dart:async';

/// Driver App In-Memory Data Store (dummy data removed, ready for backend integration)
class DriverMockDb {
  DriverMockDb._();
  static final DriverMockDb instance = DriverMockDb._();

  String currentDriver = '';

  final List<Map<String, dynamic>> operators = [];
  final List<Map<String, dynamic>> routes = [];

  List<Map<String, dynamic>> trips = [];
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> driverReports = [];
  List<Map<String, dynamic>> tripChecks = [];
  List<Map<String, dynamic>> sosEvents = [];

  Map<String, dynamic>? liveGps;
  Timer? _gpsTimer;

  void init() {
    // All dummy data removed. Ready to be populated by real backend API.
    trips = [];
    bookings = [];
    driverReports = [];
    tripChecks = [];
    sosEvents = [];
    liveGps = null;
  }

  Map<String, dynamic>? get currentTrip {
    try {
      return trips.firstWhere((t) =>
          t['driver'] == currentDriver &&
          ['BOARDING', 'IN_TRANSIT', 'DELAYED', 'SCHEDULED'].contains(t['status']));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get myProfile {
    if (currentDriver.isNotEmpty) {
      return {'name': currentDriver};
    }
    return null;
  }

  List<Map<String, dynamic>> get myTrips =>
      trips.where((t) => t['driver'] == currentDriver && t['status'] != 'CANCELLED').toList();

  List<Map<String, dynamic>> passengersOfTrip(String tripId) =>
      bookings.where((b) => b['tripId'] == tripId && b['status'] != 'CANCELLED').toList();

  Map<String, dynamic>? routeOfTrip(String routeId) {
    try {
      return routes.firstWhere((r) => r['id'] == routeId);
    } catch (_) {
      return null;
    }
  }

  void checkInPassenger(String tripId, String bookingId) {
    try {
      final trip = trips.firstWhere((t) => t['id'] == tripId);
      final checked = List<String>.from(trip['checkedIn'] as List? ?? []);
      if (!checked.contains(bookingId)) {
        checked.add(bookingId);
        trip['checkedIn'] = checked;
      }
    } catch (_) {}
  }

  void setTripStatus(String tripId, String status) {
    try {
      final trip = trips.firstWhere((t) => t['id'] == tripId);
      trip['status'] = status;
      if (status == 'IN_TRANSIT') {
        liveGps = {
          'tripId': tripId,
          'progress': 0,
          'speed': 0,
          'ping': DateTime.now().toIso8601String(),
          'state': 'LIVE',
        };
      } else if (status == 'ARRIVED') {
        liveGps = null;
        for (final b in bookings.where((x) => x['tripId'] == tripId)) {
          b['status'] = 'COMPLETED';
        }
      }
    } catch (_) {}
  }

  void reportDelay(String tripId, int minutes, String reason) {
    try {
      final trip = trips.firstWhere((t) => t['id'] == tripId);
      trip['status'] = 'DELAYED';
      trip['delay'] = minutes;
      trip['delayReason'] = reason;
      if (liveGps != null) {
        liveGps!['state'] = 'DELAYED';
      }
    } catch (_) {}
  }

  void sendSos({
    required String tripId,
    required String reason,
    String? note,
  }) {
    // Phase 5: To be connected to backend emergency SOS API.
  }

  void dispose() {
    _gpsTimer?.cancel();
  }
}
