import 'package:meta/meta.dart';

import '../../discovery/models/discovery_models.dart';
import 'booking_models.dart';

/// One traveller of a booking, as it is printed on the ticket.
@immutable
final class TicketPassenger {
  const TicketPassenger({required this.name, required this.seatId});

  final String name;
  final String seatId;
}

/// A boarding or dropping point as it is printed on the ticket.
@immutable
final class TicketPoint {
  const TicketPoint({
    required this.name,
    required this.time,
    this.address,
    this.landmark,
  });

  final String name;
  final DateTime time;
  final String? address;
  final String? landmark;
}

/// What the app sends to create a booking for held seats
/// (`POST /bookings`). The prices are not sent: the backend calculates them
/// from the seats and the coupon.
@immutable
final class BookingRequest {
  const BookingRequest({
    required this.tripId,
    required this.lockId,
    required this.seatIds,
    required this.passengers,
    required this.contact,
    required this.boardingPointId,
    required this.droppingPointId,
    this.gst = const GstEntry(),
    this.couponCode,
    this.tripHint,
    this.expectedAmountPaise = 0,
  });

  final String tripId;
  final String lockId;
  final List<String> seatIds;

  /// By seat id.
  final Map<String, PassengerEntry> passengers;
  final ContactEntry contact;
  final GstEntry gst;
  final String boardingPointId;
  final String droppingPointId;
  final String? couponCode;

  /// The amount the customer saw, so the backend can refuse a booking whose
  /// price changed.
  final int expectedAmountPaise;

  /// The trip as the app knows it. Only the mock uses it, to build a ticket
  /// for the trip the customer chose; the backend knows its own trips.
  final TripDetail? tripHint;
}

/// A booking that exists and waits for payment.
@immutable
final class BookingCreated {
  const BookingCreated({required this.bookingId, required this.amountPaise});

  final String bookingId;
  final int amountPaise;
}

/// A confirmed booking and everything its ticket shows.
@immutable
final class Ticket {
  const Ticket({
    required this.bookingId,
    required this.tripId,
    required this.pnr,
    required this.operatorName,
    required this.busTypeName,
    required this.originName,
    required this.destinationName,
    required this.travelDate,
    required this.timezone,
    required this.departureAt,
    required this.arrivalAt,
    required this.durationMinutes,
    required this.passengers,
    required this.boarding,
    required this.dropping,
    required this.paidPaise,
    required this.currency,
    required this.qrPayload,
    this.operatorPhone,
    this.contactEmail,
  });

  final String bookingId;
  final String tripId;

  /// The booking reference the customer quotes ("ABR7K2M9QX").
  final String pnr;
  final String operatorName;
  final String busTypeName;
  final String originName;
  final String destinationName;

  /// `YYYY-MM-DD` in [timezone].
  final String travelDate;
  final String timezone;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final int durationMinutes;
  final List<TicketPassenger> passengers;
  final TicketPoint boarding;
  final TicketPoint dropping;
  final int paidPaise;
  final String currency;

  /// What the conductor's scanner reads (signed by the backend).
  final String qrPayload;
  final String? operatorPhone;
  final String? contactEmail;

  List<String> get seatIds => passengers.map((p) => p.seatId).toList();
}
