import 'package:customer_app/features/booking/models/ticket_models.dart';
import 'package:customer_app/features/my_trips/models/trip_models.dart';
import 'package:customer_app/features/my_trips/repositories/trips_repository.dart';

/// Test fake providing sample bookings for tests (test-only, in test/support).
class FakeTripsRepository implements TripsRepository {
  FakeTripsRepository({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, List<String>> _cancellations = <String, List<String>>{};

  List<Booking> _buildBookings() {
    final now = _clock();
    DateTime at(Duration from) => DateTime.fromMillisecondsSinceEpoch(
      (now.add(from).millisecondsSinceEpoch ~/ 3600000) * 3600000,
      isUtc: true,
    );

    Ticket ticket({
      required String id,
      required String pnr,
      required String operator,
      required String bus,
      required String from,
      required String to,
      required Duration departsIn,
      required int minutes,
      required List<TicketPassenger> passengers,
      required String boarding,
      required int paidPaise,
    }) {
      final departure = at(departsIn);
      return Ticket(
        bookingId: id,
        tripId: 'test-$id',
        pnr: pnr,
        operatorName: operator,
        busTypeName: bus,
        originName: from,
        destinationName: to,
        travelDate:
            '${departure.year.toString().padLeft(4, '0')}-'
            '${departure.month.toString().padLeft(2, '0')}-'
            '${departure.day.toString().padLeft(2, '0')}',
        timezone: 'Asia/Kolkata',
        departureAt: departure,
        arrivalAt: departure.add(Duration(minutes: minutes)),
        durationMinutes: minutes,
        passengers: passengers,
        boarding: TicketPoint(
          name: boarding,
          time: departure,
          address: 'Main Road, $from',
        ),
        dropping: TicketPoint(
          name: '$to Bus Station',
          time: departure.add(Duration(minutes: minutes)),
        ),
        paidPaise: paidPaise,
        currency: 'INR',
        qrPayload: 'ABRA:$pnr:$id',
        operatorPhone: '+91 80 4000 1234',
        contactEmail: 'passenger@example.com',
      );
    }

    Booking makeBooking(
      Ticket t, {
      required DateTime bookedAt,
      required Map<String, int> fares,
      BookingStatus? fixedStatus,
    }) {
      final cancelled = _cancellations[t.bookingId] ?? const <String>[];
      final allCancelled =
          t.seatIds.isNotEmpty && t.seatIds.every(cancelled.contains);
      final status = allCancelled
          ? BookingStatus.cancelled
          : fixedStatus ??
              (t.departureAt.isBefore(now)
                  ? BookingStatus.completed
                  : BookingStatus.confirmed);
      return Booking(
        ticket: t,
        status: status,
        bookedAt: bookedAt,
        seatFarePaise: fares,
        cancelledSeatIds: cancelled,
      );
    }

    return <Booking>[
      // 3 upcoming bookings
      makeBooking(
        ticket(
          id: 'bk-1',
          pnr: 'ABR100001',
          operator: 'Express Lines',
          bus: 'Volvo AC Sleeper',
          from: 'Bengaluru',
          to: 'Hyderabad',
          departsIn: const Duration(hours: 18),
          minutes: 525,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Traveler One', seatId: 'L6'),
            TicketPassenger(name: 'Traveler Two', seatId: 'L7'),
          ],
          boarding: 'Hebbal',
          paidPaise: 234900,
        ),
        bookedAt: now.subtract(const Duration(days: 2)),
        fares: const <String, int>{'L6': 115000, 'L7': 115000},
      ),
      makeBooking(
        ticket(
          id: 'bk-2',
          pnr: 'ABR100002',
          operator: 'Express Lines',
          bus: 'Volvo AC Sleeper',
          from: 'Bengaluru',
          to: 'Hyderabad',
          departsIn: const Duration(minutes: 75),
          minutes: 525,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Traveler One', seatId: 'U3'),
          ],
          boarding: 'Hebbal',
          paidPaise: 117400,
        ),
        bookedAt: now.subtract(const Duration(days: 3)),
        fares: const <String, int>{'U3': 105000},
      ),
      makeBooking(
        ticket(
          id: 'bk-3',
          pnr: 'ABR100003',
          operator: 'City Express',
          bus: 'AC Seater',
          from: 'Chennai',
          to: 'Coimbatore',
          departsIn: const Duration(days: 6),
          minutes: 435,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Traveler One', seatId: '12A'),
          ],
          boarding: 'Central',
          paidPaise: 89900,
        ),
        bookedAt: now.subtract(const Duration(days: 1)),
        fares: const <String, int>{'12A': 79000},
      ),
      // 2 completed bookings
      makeBooking(
        ticket(
          id: 'bk-4',
          pnr: 'ABR100004',
          operator: 'Highway Express',
          bus: 'AC Seater',
          from: 'Mumbai',
          to: 'Pune',
          departsIn: const Duration(days: -14),
          minutes: 210,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Traveler One', seatId: '8C'),
          ],
          boarding: 'Dadar',
          paidPaise: 62000,
        ),
        bookedAt: now.subtract(const Duration(days: 20)),
        fares: const <String, int>{'8C': 55000},
        fixedStatus: BookingStatus.completed,
      ),
      makeBooking(
        ticket(
          id: 'bk-5',
          pnr: 'ABR100005',
          operator: 'Star Travels',
          bus: 'Volvo AC Sleeper',
          from: 'Hyderabad',
          to: 'Vijayawada',
          departsIn: const Duration(days: -26),
          minutes: 330,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Traveler One', seatId: 'U4'),
          ],
          boarding: 'Central',
          paidPaise: 78000,
        ),
        bookedAt: now.subtract(const Duration(days: 30)),
        fares: const <String, int>{'U4': 70000},
        fixedStatus: BookingStatus.completed,
      ),
    ];
  }

  @override
  Future<List<Booking>> bookings() async => _buildBookings();

  @override
  Future<Booking> booking(String bookingId) async {
    final list = _buildBookings();
    return list.firstWhere(
      (b) => b.id == bookingId,
      orElse: () => list.first,
    );
  }

  @override
  Future<CancellationQuote> quote(
    String bookingId,
    List<String> seatIds,
  ) async {
    return const CancellationQuote(
      farePaise: 115000,
      chargePaise: 15000,
      refundPaise: 100000,
      refundPercent: 87,
      hoursBeforeDeparture: 18,
    );
  }

  @override
  Future<Booking> cancel(
    String bookingId,
    List<String> seatIds, {
    required String reason,
  }) async {
    _cancellations[bookingId] = seatIds;
    return booking(bookingId);
  }
}
