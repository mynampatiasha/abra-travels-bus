import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Models and mock store for Operations: Seat Inventory and Live Tracking
/// matching prototypes/admin_demo_model.html.

class InventoryTripRecord {
  InventoryTripRecord({
    required this.id,
    required this.route,
    required this.operator,
    required this.operatorId,
    required this.depart,
    required this.status, // SCHEDULED, BOARDING, DELAYED, CANCELLED, ARRIVED, IN_TRANSIT
    required this.seats,
    required this.booked,
    required this.held,
    required this.blocked,
    required this.fare,
    required this.bus,
    required this.driver,
    required this.conductor,
    this.busType = 'AC Sleeper (2+1)',
    this.delayMinutes = 0,
    this.delayReason = '',
    this.cancelReason = '',
    Set<int>? bookedSeats,
    Set<int>? heldSeats,
    Set<int>? blockedSeats,
  }) {
    this.bookedSeats = bookedSeats ?? {for (var i = 1; i <= booked; i++) i};
    this.heldSeats = heldSeats ?? {for (var i = booked + 1; i <= booked + held; i++) i};
    this.blockedSeats = blockedSeats ?? {for (var i = booked + held + 1; i <= booked + held + blocked; i++) i};
  }

  final String id;
  final String route;
  final String operator;
  final String operatorId;
  final DateTime depart;
  String status;
  final int seats;
  int booked;
  int held;
  int blocked;
  final int fare;
  String bus;
  String driver;
  String conductor;
  String busType;
  int delayMinutes;
  String delayReason;
  String cancelReason;

  late Set<int> bookedSeats;
  late Set<int> heldSeats;
  late Set<int> blockedSeats;

  int get free => seats - booked - held - blocked;
  double get occupancy => seats > 0 ? booked / seats : 0.0;
  bool isLowOccupancy(DateTime now) {
    final diff = depart.difference(now);
    return occupancy < 0.25 && diff.inDays >= 0 && diff.inDays <= 2;
  }

  void toggleSeat(int seatNum) {
    if (bookedSeats.contains(seatNum) || heldSeats.contains(seatNum)) {
      return; // Cannot toggle booked or held seats
    }
    if (blockedSeats.contains(seatNum)) {
      blockedSeats.remove(seatNum);
      blocked = blockedSeats.length;
    } else {
      blockedSeats.add(seatNum);
      blocked = blockedSeats.length;
    }
  }
}

class LiveTrackingRecord {
  LiveTrackingRecord({
    required this.tripId,
    required this.route,
    required this.bus,
    required this.operator,
    required this.driver,
    required this.state, // LIVE, DELAYED, SIGNAL_LOST
    required this.ping,
    required this.speed,
    required this.progress,
    required this.eta,
    required this.x,
    required this.y,
    required this.pax,
    required this.checkedIn,
    required this.stops,
  });

  final String tripId;
  final String route;
  final String bus;
  final String operator;
  final String driver;
  String state;
  DateTime ping;
  int speed;
  int progress;
  DateTime eta;
  double x;
  double y;
  int pax;
  int checkedIn;
  final List<String> stops;

  bool get needsAttention {
    if (state == 'SIGNAL_LOST' || state == 'DELAYED') return true;
    final diff = DateTime.now().difference(ping).inMinutes;
    return diff > 5;
  }
}

class OperationsState {
  OperationsState({
    required this.inventoryTrips,
    required this.liveBuses,
    this.selectedLiveBusId,
  });

  final List<InventoryTripRecord> inventoryTrips;
  final List<LiveTrackingRecord> liveBuses;
  final String? selectedLiveBusId;

  OperationsState copyWith({
    List<InventoryTripRecord>? inventoryTrips,
    List<LiveTrackingRecord>? liveBuses,
    String? selectedLiveBusId,
    bool clearSelectedBus = false,
  }) {
    return OperationsState(
      inventoryTrips: inventoryTrips ?? this.inventoryTrips,
      liveBuses: liveBuses ?? this.liveBuses,
      selectedLiveBusId:
          clearSelectedBus ? null : (selectedLiveBusId ?? this.selectedLiveBusId),
    );
  }
}

class OperationsStoreNotifier extends Notifier<OperationsState> {
  @override
  OperationsState build() {
    return _seedInitialData();
  }

  static OperationsState _seedInitialData() {
    final now = DateTime.now();

    final inventoryTrips = <InventoryTripRecord>[
      InventoryTripRecord(
        id: 'TRP-3001',
        route: 'Hyderabad to Bengaluru',
        operator: 'Kaveri Express',
        operatorId: 'OP1',
        depart: now.add(const Duration(hours: 4)),
        status: 'SCHEDULED',
        seats: 36,
        booked: 28,
        held: 2,
        blocked: 1,
        fare: 120000,
        bus: 'TS09 UB 4521',
        driver: 'Ramesh K',
        conductor: 'Mahesh',
      ),
      InventoryTripRecord(
        id: 'TRP-3002',
        route: 'Bengaluru to Hyderabad',
        operator: 'Godavari Lines',
        operatorId: 'OP2',
        depart: now.add(const Duration(hours: 6)),
        status: 'SCHEDULED',
        seats: 40,
        booked: 34,
        held: 3,
        blocked: 0,
        fare: 110000,
        bus: 'KA01 AB 9021',
        driver: 'Sunil Y',
        conductor: 'Kiran',
      ),
      InventoryTripRecord(
        id: 'TRP-3003',
        route: 'Hyderabad to Vijayawada',
        operator: 'Deccan Voyager',
        operatorId: 'OP3',
        depart: now.add(const Duration(hours: 2)),
        status: 'BOARDING',
        seats: 32,
        booked: 29,
        held: 1,
        blocked: 1,
        fare: 85000,
        bus: 'TS07 CD 3311',
        driver: 'Anwar S',
        conductor: 'Joseph',
      ),
      InventoryTripRecord(
        id: 'TRP-3004',
        route: 'Chennai to Coimbatore',
        operator: 'Nilgiri Travels',
        operatorId: 'OP5',
        depart: now.add(const Duration(hours: 14)),
        status: 'SCHEDULED',
        seats: 38,
        booked: 7, // < 25% occupancy -> Low occupancy alert
        held: 2,
        blocked: 0,
        fare: 95000,
        bus: 'TN38 TX 8812',
        driver: 'Prakash M',
        conductor: 'Salim',
      ),
      InventoryTripRecord(
        id: 'TRP-3005',
        route: 'Visakhapatnam to Hyderabad',
        operator: 'Araku Express',
        operatorId: 'OP12',
        depart: now.add(const Duration(hours: 18)),
        status: 'SCHEDULED',
        seats: 42,
        booked: 9, // < 25% occupancy -> Low occupancy alert
        held: 0,
        blocked: 2,
        fare: 135000,
        bus: 'AP16 EF 7744',
        driver: 'Naveen B',
        conductor: 'Raju',
      ),
      InventoryTripRecord(
        id: 'TRP-3006',
        route: 'Bengaluru to Chennai',
        operator: 'Coromandel Coaches',
        operatorId: 'OP11',
        depart: now.add(const Duration(hours: 8)),
        status: 'SCHEDULED',
        seats: 36,
        booked: 33,
        held: 2,
        blocked: 0,
        fare: 75000,
        bus: 'KA04 GH 6100',
        driver: 'Karthik S',
        conductor: 'Murugan',
      ),
      InventoryTripRecord(
        id: 'TRP-3007',
        route: 'Kochi to Bengaluru',
        operator: 'Malabar Lines',
        operatorId: 'OP10',
        depart: now.add(const Duration(hours: 22)),
        status: 'SCHEDULED',
        seats: 36,
        booked: 21,
        held: 4,
        blocked: 1,
        fare: 140000,
        bus: 'KL07 JK 2299',
        driver: 'Thomas Mathew',
        conductor: 'Biju',
      ),
      InventoryTripRecord(
        id: 'TRP-3008',
        route: 'Hyderabad to Tirupati',
        operator: 'Krishna Wheels',
        operatorId: 'OP14',
        depart: now.add(const Duration(hours: 28)),
        status: 'SCHEDULED',
        seats: 40,
        booked: 6, // Low occupancy
        held: 1,
        blocked: 0,
        fare: 90000,
        bus: 'AP39 LM 4501',
        driver: 'Venkat Rao',
        conductor: 'Srinu',
      ),
    ];

    final liveBuses = <LiveTrackingRecord>[
      LiveTrackingRecord(
        tripId: 'TRP-3001',
        route: 'Hyderabad to Bengaluru',
        bus: 'TS09 UB 4521',
        operator: 'Kaveri Express',
        driver: 'Ramesh K',
        state: 'LIVE',
        ping: now.subtract(const Duration(seconds: 40)),
        speed: 68,
        progress: 45,
        eta: now.add(const Duration(hours: 4, minutes: 15)),
        x: 42.0,
        y: 48.0,
        pax: 28,
        checkedIn: 26,
        stops: const [
          'MGBS Hyderabad',
          'Jadcherla Bypass',
          'Kurnool Checkpost',
          'Anantapur Flyover',
          'Majestic Bengaluru',
        ],
      ),
      LiveTrackingRecord(
        tripId: 'TRP-3002',
        route: 'Bengaluru to Hyderabad',
        bus: 'KA01 AB 9021',
        operator: 'Godavari Lines',
        driver: 'Sunil Y',
        state: 'LIVE',
        ping: now.subtract(const Duration(minutes: 1, seconds: 20)),
        speed: 72,
        progress: 62,
        eta: now.add(const Duration(hours: 3)),
        x: 60.0,
        y: 40.0,
        pax: 34,
        checkedIn: 32,
        stops: const [
          'Kempegowda Stand',
          'Chikkaballapur',
          'Gooty Bypass',
          'Shamshabad Airport',
          'Ameerpet Metro',
        ],
      ),
      LiveTrackingRecord(
        tripId: 'TRP-3003',
        route: 'Hyderabad to Vijayawada',
        bus: 'TS07 CD 3311',
        operator: 'Deccan Voyager',
        driver: 'Anwar S',
        state: 'DELAYED',
        ping: now.subtract(const Duration(minutes: 2)),
        speed: 38,
        progress: 25,
        eta: now.add(const Duration(hours: 5, minutes: 30)),
        x: 35.0,
        y: 66.0,
        pax: 29,
        checkedIn: 29,
        stops: const [
          'LB Nagar Ring Road',
          'Choutuppal',
          'Suryapet Hotel Seven',
          'Nandigama Toll',
          'Benz Circle Vijayawada',
        ],
      ),
      LiveTrackingRecord(
        tripId: 'TRP-3006',
        route: 'Bengaluru to Chennai',
        bus: 'KA04 GH 6100',
        operator: 'Coromandel Coaches',
        driver: 'Karthik S',
        state: 'SIGNAL_LOST',
        ping: now.subtract(const Duration(minutes: 14)),
        speed: 0,
        progress: 70,
        eta: now.add(const Duration(hours: 2, minutes: 10)),
        x: 70.0,
        y: 62.0,
        pax: 33,
        checkedIn: 30,
        stops: const [
          'Electronic City Toll',
          'Hosur Bus Stand',
          'Krishnagiri Bypass',
          'Vellore Bypass',
          'Koyambedu CMBT',
        ],
      ),
      LiveTrackingRecord(
        tripId: 'TRP-3007',
        route: 'Kochi to Bengaluru',
        bus: 'KL07 JK 2299',
        operator: 'Malabar Lines',
        driver: 'Thomas Mathew',
        state: 'LIVE',
        ping: now.subtract(const Duration(seconds: 25)),
        speed: 64,
        progress: 35,
        eta: now.add(const Duration(hours: 6)),
        x: 50.0,
        y: 22.0,
        pax: 21,
        checkedIn: 19,
        stops: const [
          'Vyttila Mobility Hub',
          'Thrissur Round',
          'Palakkad KSRTC',
          'Coimbatore Bypass',
          'Electronic City Phase 1',
        ],
      ),
      LiveTrackingRecord(
        tripId: 'TRP-3008',
        route: 'Hyderabad to Tirupati',
        bus: 'AP39 LM 4501',
        operator: 'Krishna Wheels',
        driver: 'Venkat Rao',
        state: 'LIVE',
        ping: now.subtract(const Duration(minutes: 1)),
        speed: 59,
        progress: 80,
        eta: now.add(const Duration(hours: 1, minutes: 40)),
        x: 26.0,
        y: 52.0,
        pax: 24,
        checkedIn: 22,
        stops: const [
          'Aramghar Junction',
          'Kurnool City Stand',
          'Nandyal Bypass',
          'Kadapa Seven Roads',
          'Tirupati Central Stand',
        ],
      ),
    ];

    return OperationsState(
      inventoryTrips: inventoryTrips,
      liveBuses: liveBuses,
      selectedLiveBusId: 'TRP-3001',
    );
  }

  void releaseExpiredHolds() {
    final updated = state.inventoryTrips.map((t) {
      if (t.held > 0) {
        t.held = 0; // Release all expired holds
      }
      return t;
    }).toList();

    state = state.copyWith(inventoryTrips: updated);
  }

  void selectLiveBus(String? id) {
    state = state.copyWith(selectedLiveBusId: id);
  }

  void updateBusProgress(String tripId, int progress) {
    final updated = state.liveBuses.map((b) {
      if (b.tripId == tripId) {
        b.progress = progress;
      }
      return b;
    }).toList();

    state = state.copyWith(liveBuses: updated);
  }

  void addTrip(InventoryTripRecord trip) {
    state = state.copyWith(
      inventoryTrips: [trip, ...state.inventoryTrips],
    );
  }

  void delayTrip(String tripId, int minutes, String reason) {
    final updated = state.inventoryTrips.map((t) {
      if (t.id == tripId) {
        t.status = 'DELAYED';
        t.delayMinutes = minutes;
        t.delayReason = reason;
      }
      return t;
    }).toList();
    state = state.copyWith(inventoryTrips: updated);
  }

  void changeDriver(String tripId, String driver) {
    final updated = state.inventoryTrips.map((t) {
      if (t.id == tripId) {
        t.driver = driver;
      }
      return t;
    }).toList();
    state = state.copyWith(inventoryTrips: updated);
  }

  void cancelTrip(String tripId, String reason) {
    final updated = state.inventoryTrips.map((t) {
      if (t.id == tripId) {
        t.status = 'CANCELLED';
        t.cancelReason = reason;
      }
      return t;
    }).toList();
    state = state.copyWith(inventoryTrips: updated);
  }

  void toggleSeatBlock(String tripId, int seatNum) {
    final updated = state.inventoryTrips.map((t) {
      if (t.id == tripId) {
        t.toggleSeat(seatNum);
      }
      return t;
    }).toList();
    state = state.copyWith(inventoryTrips: updated);
  }
}

final operationsStoreProvider =
    NotifierProvider<OperationsStoreNotifier, OperationsState>(
  OperationsStoreNotifier.new,
);
