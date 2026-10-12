import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ticket_models.dart';
import 'ticket_repository.dart';

/// Bookings made in this run of the app, so that the ticket screens show
/// what the customer actually booked. Mock only: the backend keeps the real
/// ones.
class MockTicketStore {
  final Map<String, Ticket> _tickets = <String, Ticket>{};
  final Map<String, DateTime> _createdAt = <String, DateTime>{};
  int _counter = 0;

  Ticket? find(String bookingId) => _tickets[bookingId];

  /// Every booking made in this run, newest first.
  List<Ticket> get all => _tickets.values.toList().reversed.toList();

  DateTime? createdAtOf(String bookingId) => _createdAt[bookingId];

  /// Makes a booking for [request] and keeps its ticket.
  BookingCreated create(BookingRequest request) {
    _counter++;
    final bookingId = 'mock-booking-$_counter';
    final random = Random(bookingId.hashCode ^ request.lockId.hashCode);
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final pnr =
        'ABR${List<String>.generate(7, (_) => letters[random.nextInt(letters.length)]).join()}';
    final trip = request.tripHint;
    if (trip == null) throw StateError('The mock needs the trip');
    TicketPoint point(String id, bool boarding) {
      final points = boarding ? trip.boardingPoints : trip.droppingPoints;
      final found = points.where((p) => p.id == id).firstOrNull ?? points.first;
      return TicketPoint(
        name: found.name,
        time: found.time,
        address: found.address,
        landmark: found.landmark,
      );
    }

    _createdAt[bookingId] = DateTime.now();
    _tickets[bookingId] = Ticket(
      bookingId: bookingId,
      tripId: request.tripId,
      pnr: pnr,
      operatorName: trip.operator.name,
      busTypeName: trip.bus.typeName,
      originName: trip.origin.name,
      destinationName: trip.destination.name,
      travelDate: trip.travelDate,
      timezone: trip.timezone,
      departureAt: trip.departureAt,
      arrivalAt: trip.arrivalAt,
      durationMinutes: trip.durationMinutes,
      passengers: <TicketPassenger>[
        for (final seat in request.seatIds)
          TicketPassenger(
            name: (request.passengers[seat]?.name ?? '').trim(),
            seatId: seat,
          ),
      ],
      boarding: point(request.boardingPointId, true),
      dropping: point(request.droppingPointId, false),
      paidPaise: request.expectedAmountPaise,
      currency: trip.currency,
      qrPayload: 'ABRA:$pnr:$bookingId',
      operatorPhone:
          trip.boardingPoints.firstOrNull?.contactPhone ?? '+91 80 4000 1234',
      contactEmail: request.contact.email.trim().isEmpty
          ? null
          : request.contact.email.trim(),
    );
    return BookingCreated(
      bookingId: bookingId,
      amountPaise: request.expectedAmountPaise,
    );
  }
}

final mockTicketStoreProvider = Provider<MockTicketStore>(
  (ref) => MockTicketStore(),
);

class MockTicketRepository implements TicketRepository {
  const MockTicketRepository(
    this.store, {
    this.delay = const Duration(milliseconds: 500),
  });

  final MockTicketStore store;
  final Duration delay;

  @override
  Future<Ticket> ticket(String bookingId) async {
    await Future<void>.delayed(delay);
    final ticket = store.find(bookingId);
    if (ticket == null) throw StateError('No such booking');
    return ticket;
  }
}
