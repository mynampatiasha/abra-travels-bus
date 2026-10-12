import 'package:meta/meta.dart';

import '../../booking/models/ticket_models.dart';

enum BookingStatus { confirmed, completed, cancelled }

/// How far a refund has got.
enum RefundStage { requested, processing, refunded }

/// The money coming back for cancelled seats.
@immutable
final class RefundInfo {
  const RefundInfo({
    required this.amountPaise,
    required this.methodLabel,
    required this.requestedAt,
    required this.stage,
    required this.cancelledSeatIds,
    required this.processingExpectedBy,
    required this.refundExpectedBy,
    this.processingAt,
    this.refundedAt,
    this.utr,
  });

  final int amountPaise;

  /// Where the money goes ("UPI sagar@okhdfc"), as the backend words it.
  final String methodLabel;
  final DateTime requestedAt;
  final RefundStage stage;
  final List<String> cancelledSeatIds;
  final DateTime processingExpectedBy;
  final DateTime refundExpectedBy;
  final DateTime? processingAt;
  final DateTime? refundedAt;

  /// The bank's reference, known once the refund is made.
  final String? utr;
}

/// One booking of the signed-in customer, as My trips lists it.
@immutable
final class Booking {
  const Booking({
    required this.ticket,
    required this.status,
    required this.bookedAt,
    required this.seatFarePaise,
    this.refund,
    this.cancelledSeatIds = const <String>[],
  });

  final Ticket ticket;
  final BookingStatus status;
  final DateTime bookedAt;

  /// Fare paid for each seat (without the convenience fee), by seat id.
  final Map<String, int> seatFarePaise;
  final RefundInfo? refund;
  final List<String> cancelledSeatIds;

  String get id => ticket.bookingId;

  /// The passengers whose seats are still booked.
  List<TicketPassenger> get activePassengers => ticket.passengers
      .where((p) => !cancelledSeatIds.contains(p.seatId))
      .toList();

  List<String> get activeSeatIds =>
      activePassengers.map((p) => p.seatId).toList();

  int get activeFarePaise =>
      activeSeatIds.fold<int>(0, (sum, id) => sum + (seatFarePaise[id] ?? 0));
}

/// What cancelling some seats would give back.
@immutable
final class CancellationQuote {
  const CancellationQuote({
    required this.farePaise,
    required this.chargePaise,
    required this.refundPaise,
    required this.refundPercent,
    required this.hoursBeforeDeparture,
  });

  final int farePaise;
  final int chargePaise;
  final int refundPaise;
  final int refundPercent;

  /// Whole hours left before departure when the quote was made.
  final int hoursBeforeDeparture;
}
