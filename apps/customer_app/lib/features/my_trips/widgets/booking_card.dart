import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/rupees.dart';
import '../../../core/ui/route_label.dart';
import '../../../l10n/customer_strings.dart';
import '../../discovery/controllers/travel_dates.dart';
import '../../discovery/widgets/discovery_text.dart';
import '../models/trip_models.dart';

/// The status of a booking as a coloured badge with words (never colour
/// alone): Confirmed (green), Completed (navy), Cancelled (red) and Refund
/// processing (amber).
class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({required this.booking, super.key});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final (String key, AbraStatusTone tone) = switch (booking.status) {
      BookingStatus.confirmed => (
        CustomerStrings.statusConfirmed,
        AbraStatusTone.success,
      ),
      BookingStatus.completed => (
        CustomerStrings.statusCompleted,
        AbraStatusTone.neutral,
      ),
      BookingStatus.cancelled =>
        booking.refund == null
            ? (CustomerStrings.statusCancelled, AbraStatusTone.danger)
            : booking.refund!.stage == RefundStage.refunded
            ? (CustomerStrings.statusRefunded, AbraStatusTone.success)
            : (CustomerStrings.statusRefundProcessing, AbraStatusTone.warning),
    };
    return AbraStatusBadge(label: l10n.text(key), tone: tone);
  }
}

/// One booking in a My trips list: date and status, route, times, seats and
/// the amount. The whole card opens the booking.
class BookingCard extends StatelessWidget {
  const BookingCard({
    required this.booking,
    required this.now,
    required this.onTap,
    super.key,
  });

  final Booking booking;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final ticket = booking.ticket;
    final date = DateTime.tryParse(ticket.travelDate);
    final isToday =
        date != null &&
        TravelDates.format(date) == TravelDates.format(TravelDates.today(now));
    final dateText = date == null
        ? ticket.travelDate
        : formatShortDate(l10n, TravelDates.asLocalDate(date));
    final seats = l10n.text(CustomerStrings.tripsCardSeats, <String, Object?>{
      'count': booking.ticket.passengers.length,
      'seats': booking.ticket.seatIds.join(', '),
    });
    final times = l10n.text(CustomerStrings.tripsCardTimes, <String, Object?>{
      'departure': text.time(ticket.departureAt, ticket.timezone),
      'arrival': text.time(ticket.arrivalAt, ticket.timezone),
      'operator': ticket.operatorName,
    });
    return AbraCard(
      onTap: onTap,
      semanticLabel:
          '$dateText, ${ticket.originName}, ${ticket.destinationName}, '
          '$times, $seats',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.xs,
            children: <Widget>[
              Text(
                isToday
                    ? '$dateText • ${l10n.text(CustomerStrings.tripsToday)}'
                    : dateText,
                style: textTheme.bodySmall,
              ),
              BookingStatusBadge(booking: booking),
            ],
          ),
          const SizedBox(height: AbraSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: RouteLabel(
                  from: ticket.originName,
                  to: ticket.destinationName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: AbraSizes.icon),
            ],
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text(times, style: textTheme.bodySmall),
          const SizedBox(height: AbraSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: Text(seats, style: textTheme.bodyMedium)),
              Text(
                formatRupees(
                  l10n,
                  ticket.paidPaise,
                  currencyCode: ticket.currency,
                ),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
