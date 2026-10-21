import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal models and provider for admin_trips_page until Phase 2 supply session connects it.
/// Contains no sample data.

class BookingRecord {
  BookingRecord({
    required this.id,
    required this.pnr,
    required this.customerId,
    required this.customer,
    required this.phone,
    required this.tripId,
    required this.route,
    required this.operator,
    required this.operatorId,
    required this.travelDate,
    required this.seatList,
    required this.seatsN,
    required this.amount,
    required this.commission,
    required this.gst,
    required this.fee,
    required this.discount,
    required this.status,
    required this.mode,
    required this.at,
    this.coupon = '',
    List<String>? notes,
  }) : notes = notes ?? <String>[];

  final String id;
  final String pnr;
  final String customerId;
  final String customer;
  final String phone;
  final String tripId;
  final String route;
  final String operator;
  final String operatorId;
  final DateTime travelDate;
  final String seatList;
  final int seatsN;
  final int amount;
  final int commission;
  final int gst;
  final int fee;
  final int discount;
  String status;
  final String mode;
  final DateTime at;
  final String coupon;
  final List<String> notes;
}

class SalesState {
  const SalesState({
    this.bookings = const <BookingRecord>[],
  });

  final List<BookingRecord> bookings;
}

class SalesStoreNotifier extends Notifier<SalesState> {
  @override
  SalesState build() => const SalesState();
}

final salesStoreProvider = NotifierProvider<SalesStoreNotifier, SalesState>(
  SalesStoreNotifier.new,
);
