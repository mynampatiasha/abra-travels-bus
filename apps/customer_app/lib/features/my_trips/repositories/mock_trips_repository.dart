import '../../booking/models/ticket_models.dart';
import '../../booking/repositories/mock_booking_repository.dart';
import '../../booking/repositories/mock_ticket_repository.dart';
import '../controllers/cancellation_calculator.dart';
import '../models/trip_models.dart';
import 'trips_repository.dart';

/// Sample bookings for My trips: two upcoming, two completed, plus every
/// booking made in this run of the app (from [MockTicketStore]). Cancelling
/// seats is remembered while the app runs, and a refund moves on by itself:
/// processing at once, refunded after [refundDelay].
class MockTripsRepository implements TripsRepository {
  MockTripsRepository({
    required this.tickets,
    DateTime Function()? now,
    this.delay = const Duration(milliseconds: 500),
    this.refundDelay = const Duration(minutes: 2),
  }) : _now = now ?? DateTime.now;

  final MockTicketStore tickets;
  final DateTime Function() _now;
  final Duration delay;
  final Duration refundDelay;

  /// Cancelled seats and the refund started for them, by booking id.
  final Map<String, _Cancellation> _cancellations = <String, _Cancellation>{};

  static const _convenienceFeePaise = 4900;

  @override
  Future<List<Booking>> bookings() async {
    await Future<void>.delayed(delay);
    final all = <Booking>[..._made(), ..._samples()];
    all.sort((a, b) => b.ticket.departureAt.compareTo(a.ticket.departureAt));
    return all;
  }

  @override
  Future<Booking> booking(String bookingId) async {
    await Future<void>.delayed(delay);
    final all = <Booking>[..._made(), ..._samples()];
    final found = all.where((b) => b.id == bookingId).firstOrNull;
    if (found == null) throw StateError('No such booking');
    return found;
  }

  @override
  Future<CancellationQuote> quote(
    String bookingId,
    List<String> seatIds,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final booking = _find(bookingId);
    return _quoteFor(booking, seatIds);
  }

  @override
  Future<Booking> cancel(
    String bookingId,
    List<String> seatIds, {
    required String reason,
  }) async {
    await Future<void>.delayed(delay);
    final booking = _find(bookingId);
    final quote = _quoteFor(booking, seatIds);
    final previous = _cancellations[bookingId];
    _cancellations[bookingId] = _Cancellation(
      seatIds: <String>[...?previous?.seatIds, ...seatIds],
      refundPaise: (previous?.refundPaise ?? 0) + quote.refundPaise,
      requestedAt: _now(),
    );
    return _find(bookingId);
  }

  Booking _find(String bookingId) {
    final all = <Booking>[..._made(), ..._samples()];
    final found = all.where((b) => b.id == bookingId).firstOrNull;
    if (found == null) throw StateError('No such booking');
    return found;
  }

  CancellationQuote _quoteFor(Booking booking, List<String> seatIds) {
    final fare = seatIds.fold<int>(
      0,
      (sum, id) => sum + (booking.seatFarePaise[id] ?? 0),
    );
    return CancellationCalculator.quote(
      rules: MockBookingRepository.defaultPolicy,
      departure: booking.ticket.departureAt,
      now: _now(),
      farePaise: fare,
    );
  }

  /// The bookings made in this run of the app.
  Iterable<Booking> _made() => tickets.all.map(
    (ticket) => _build(
      ticket,
      bookedAt: tickets.createdAtOf(ticket.bookingId) ?? _now(),
      // The ticket keeps the total; the fare of a seat is its share without
      // the convenience fee and the 5% GST (an estimate for the mock).
      fares: _share(ticket),
    ),
  );

  Map<String, int> _share(Ticket ticket) {
    final seats = ticket.seatIds;
    if (seats.isEmpty) return const <String, int>{};
    final base = ((ticket.paidPaise - _convenienceFeePaise) * 100) ~/ 105;
    final each = base ~/ seats.length;
    return <String, int>{for (final id in seats) id: each};
  }

  Booking _build(
    Ticket ticket, {
    required DateTime bookedAt,
    required Map<String, int> fares,
    BookingStatus? fixedStatus,
  }) {
    final cancellation = _cancellations[ticket.bookingId];
    final cancelled = cancellation?.seatIds ?? const <String>[];
    final allCancelled =
        ticket.seatIds.isNotEmpty && ticket.seatIds.every(cancelled.contains);
    final status = allCancelled
        ? BookingStatus.cancelled
        : fixedStatus ??
              (ticket.departureAt.isBefore(_now())
                  ? BookingStatus.completed
                  : BookingStatus.confirmed);
    return Booking(
      ticket: ticket,
      status: status,
      bookedAt: bookedAt,
      seatFarePaise: fares,
      cancelledSeatIds: cancelled,
      refund: cancellation == null ? null : _refund(cancellation),
    );
  }

  RefundInfo _refund(_Cancellation cancellation) {
    final now = _now();
    final elapsed = now.difference(cancellation.requestedAt);
    final stage = elapsed >= refundDelay
        ? RefundStage.refunded
        : elapsed < const Duration(seconds: 3)
        ? RefundStage.requested
        : RefundStage.processing;
    final requested = cancellation.requestedAt;
    return RefundInfo(
      amountPaise: cancellation.refundPaise,
      methodLabel: 'UPI sagar@okhdfc',
      requestedAt: requested,
      stage: stage,
      cancelledSeatIds: cancellation.seatIds,
      processingAt: stage == RefundStage.requested
          ? null
          : requested.add(const Duration(seconds: 3)),
      refundedAt: stage == RefundStage.refunded
          ? requested.add(refundDelay)
          : null,
      utr: stage == RefundStage.refunded ? '4829 1056 7731' : null,
      processingExpectedBy: requested.add(const Duration(days: 3)),
      refundExpectedBy: requested.add(const Duration(days: 5)),
    );
  }

  List<Booking> _samples() {
    final now = _now();
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
        tripId: 'sample-$id',
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
        contactEmail: 'sagar.k@example.com',
      );
    }

    return <Booking>[
      _build(
        ticket(
          id: 'sample-b1',
          pnr: 'ABR7K2M9QX',
          operator: 'VRL Travels',
          bus: 'Volvo Multi-Axle A/C Sleeper (2+1)',
          from: 'Bengaluru',
          to: 'Hyderabad',
          departsIn: const Duration(hours: 18),
          minutes: 525,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Sagar Kumar', seatId: 'L6'),
            TicketPassenger(name: 'Ananya Rao', seatId: 'L7'),
          ],
          boarding: 'Hebbal Flyover',
          paidPaise: 234900,
        ),
        bookedAt: now.subtract(const Duration(days: 2)),
        fares: const <String, int>{'L6': 115000, 'L7': 115000},
      ),
      // A bus about to leave, so that tracking can be opened.
      _build(
        ticket(
          id: 'sample-b3',
          pnr: 'ABR8W6R2ZD',
          operator: 'VRL Travels',
          bus: 'Volvo A/C Sleeper (2+1)',
          from: 'Bengaluru',
          to: 'Hyderabad',
          departsIn: const Duration(minutes: 75),
          minutes: 525,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Sagar Kumar', seatId: 'U3'),
          ],
          boarding: 'Hebbal Flyover',
          paidPaise: 117400,
        ),
        bookedAt: now.subtract(const Duration(days: 3)),
        fares: const <String, int>{'U3': 105000},
      ),
      _build(
        ticket(
          id: 'sample-b2',
          pnr: 'ABR3N8TQ4W',
          operator: 'SRS Travels',
          bus: 'A/C Seater (2+2)',
          from: 'Chennai',
          to: 'Coimbatore',
          departsIn: const Duration(days: 6),
          minutes: 435,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Sagar Kumar', seatId: '12A'),
          ],
          boarding: 'Koyambedu',
          paidPaise: 89900,
        ),
        bookedAt: now.subtract(const Duration(days: 1)),
        fares: const <String, int>{'12A': 79000},
      ),
      _build(
        ticket(
          id: 'sample-c1',
          pnr: 'ABR5H2D7KM',
          operator: 'Neeta Bus',
          bus: 'A/C Seater (2+2)',
          from: 'Mumbai',
          to: 'Pune',
          departsIn: const Duration(days: -14),
          minutes: 210,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Sagar Kumar', seatId: '8C'),
          ],
          boarding: 'Dadar',
          paidPaise: 62000,
        ),
        bookedAt: now.subtract(const Duration(days: 20)),
        fares: const <String, int>{'8C': 55000},
        fixedStatus: BookingStatus.completed,
      ),
      _build(
        ticket(
          id: 'sample-c2',
          pnr: 'ABR9P4X2LT',
          operator: 'Orange Travels',
          bus: 'Volvo A/C Sleeper (2+1)',
          from: 'Hyderabad',
          to: 'Vijayawada',
          departsIn: const Duration(days: -26),
          minutes: 330,
          passengers: const <TicketPassenger>[
            TicketPassenger(name: 'Sagar Kumar', seatId: 'U4'),
          ],
          boarding: 'Ameerpet',
          paidPaise: 78000,
        ),
        bookedAt: now.subtract(const Duration(days: 30)),
        fares: const <String, int>{'U4': 70000},
        fixedStatus: BookingStatus.completed,
      ),
    ];
  }
}

class _Cancellation {
  const _Cancellation({
    required this.seatIds,
    required this.refundPaise,
    required this.requestedAt,
  });

  final List<String> seatIds;
  final int refundPaise;
  final DateTime requestedAt;
}
