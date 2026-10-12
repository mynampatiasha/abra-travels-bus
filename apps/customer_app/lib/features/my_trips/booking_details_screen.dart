import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/format/dates.dart';
import '../../core/format/rupees.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/sticky_action_bar.dart';
import '../../core/ui/tonal_button.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../booking/repositories/booking_repository.dart';
import '../discovery/controllers/travel_dates.dart';
import '../discovery/widgets/discovery_text.dart';
import 'controllers/trips_controller.dart';
import 'models/trip_models.dart';
import 'widgets/booking_card.dart';
import 'widgets/trip_timeline.dart';

/// One booking: its journey, a timeline, the e-ticket and what can be done
/// (track the bus, cancel seats, get help).
class BookingDetailsScreen extends ConsumerWidget {
  const BookingDetailsScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(bookingProvider(bookingId));
    final booking = value.value;
    final now = ref.read(bookingClockProvider)();
    final tracking = booking != null && canTrack(booking, now);
    final upcoming = booking?.status == BookingStatus.confirmed;

    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.tripDetailsTitle),
        subtitle: booking == null
            ? null
            : l10n.text(CustomerStrings.ticketBarSubtitle, <String, Object?>{
                'pnr': booking.ticket.pnr,
              }),
      ),
      bottomNavigationBar: !upcoming
          ? null
          : StickyActionBar(
              subtitle: tracking
                  ? null
                  : l10n.text(CustomerStrings.tdTrackLater),
              actionLabel: l10n.text(CustomerStrings.tdTrackBus),
              actionIcon: Icons.directions_bus_rounded,
              onAction: tracking
                  ? () => context.push(AppRoutes.myTripTrack(bookingId))
                  : null,
            ),
      body: AsyncValueView<Booking>(
        value: value,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (context, booking) => _Details(booking: booking, now: now),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.booking, required this.now});

  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final ticket = booking.ticket;
    final upcoming = booking.status == BookingStatus.confirmed;
    final done = booking.status == BookingStatus.completed;
    final onBrand = textTheme.bodySmall?.copyWith(color: AbraColors.white);
    final time = textTheme.headlineSmall?.copyWith(
      color: AbraColors.white,
      fontWeight: FontWeight.w800,
    );

    String dateOf(DateTime instant) => formatShortDate(
      l10n,
      TravelDates.asLocalDate(TravelDates.wallClock(instant, ticket.timezone)),
    );

    final reachBy = ticket.boarding.time.subtract(const Duration(minutes: 15));
    final steps = <TimelineStep>[
      TimelineStep(
        title: l10n.text(CustomerStrings.tdBooked),
        subtitle: l10n.text(CustomerStrings.tdBookedLine, <String, Object?>{
          'date': dateOf(booking.bookedAt),
          'time': text.time(booking.bookedAt, ticket.timezone),
          'amount': formatRupees(
            l10n,
            ticket.paidPaise,
            currencyCode: ticket.currency,
          ),
        }),
        state: TimelineState.done,
      ),
      TimelineStep(
        title: l10n.text(CustomerStrings.tdTicketIssued),
        subtitle: l10n.text(CustomerStrings.tdTicketIssuedLine),
        state: TimelineState.done,
      ),
      TimelineStep(
        title: l10n.text(CustomerStrings.tdBoarding, <String, Object?>{
          'point': ticket.boarding.name,
        }),
        subtitle: l10n.text(CustomerStrings.tdBoardingLine, <String, Object?>{
          'date': dateOf(ticket.boarding.time),
          'time': text.time(ticket.boarding.time, ticket.timezone),
          'reach': text.time(reachBy, ticket.timezone),
        }),
        state: done ? TimelineState.done : TimelineState.current,
      ),
      TimelineStep(
        title: l10n.text(CustomerStrings.tdArrival, <String, Object?>{
          'point': ticket.dropping.name,
        }),
        subtitle: l10n.text(CustomerStrings.tdArrivalLine, <String, Object?>{
          'date': dateOf(ticket.arrivalAt),
          'time': text.time(ticket.arrivalAt, ticket.timezone),
        }),
        state: done ? TimelineState.done : TimelineState.upcoming,
      ),
    ];

    final cancelButton = AbraButton(
      label: l10n.text(CustomerStrings.tdCancelSeats),
      variant: AbraButtonVariant.secondary,
      expand: true,
      onPressed: booking.activeSeatIds.isEmpty
          ? null
          : () => context.push(AppRoutes.myTripCancel(booking.id)),
    );
    final helpButton = AbraButton(
      label: l10n.text(CustomerStrings.tdGetHelp),
      icon: Icons.help_outline_rounded,
      variant: AbraButtonVariant.secondary,
      expand: true,
      onPressed: () => context.go(AppRoutes.support),
    );
    final passengers = booking.activePassengers;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: AbraResponsive.pagePadding(context),
          children: <Widget>[
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AbraGradients.brand,
                borderRadius: AbraRadius.large,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AbraSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AbraSpacing.md,
                      children: <Widget>[
                        Text(
                          ticket.operatorName,
                          style: textTheme.titleMedium?.copyWith(
                            color: AbraColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        BookingStatusBadge(booking: booking),
                      ],
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                text.time(ticket.departureAt, ticket.timezone),
                                style: time,
                              ),
                              Text(
                                '${ticket.originName} • '
                                '${dateOf(ticket.departureAt)}',
                                style: onBrand,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                text.time(ticket.arrivalAt, ticket.timezone),
                                style: time,
                              ),
                              Text(
                                '${ticket.destinationName} • '
                                '${dateOf(ticket.arrivalAt)}',
                                textAlign: TextAlign.end,
                                style: onBrand,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AbraSpacing.md),
            AbraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.text(CustomerStrings.tdTimeline),
                      style: textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  VerticalTimeline(
                    steps: steps,
                    stateLabels: <TimelineState, String>{
                      TimelineState.done: l10n.text(
                        CustomerStrings.timelineDone,
                      ),
                      TimelineState.current: l10n.text(
                        CustomerStrings.timelineNow,
                      ),
                      TimelineState.upcoming: l10n.text(
                        CustomerStrings.timelineNext,
                      ),
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.md),
            AbraCard(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AbraSpacing.md,
                runSpacing: AbraSpacing.sm,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.text(CustomerStrings.tdEticket),
                          style: textTheme.titleSmall,
                        ),
                        Text(
                          l10n.text(
                            CustomerStrings.tdEticketLine,
                            <String, Object?>{
                              'seats': l10n.text(
                                CustomerStrings.tripsCardSeats,
                                <String, Object?>{
                                  'count': passengers.length,
                                  'seats': passengers
                                      .map((p) => p.seatId)
                                      .join(', '),
                                },
                              ),
                              'names': passengers
                                  .map((p) => p.name)
                                  .where((n) => n.isNotEmpty)
                                  .join(', '),
                            },
                          ),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TonalButton(
                    label: l10n.text(CustomerStrings.ticketViewTicket),
                    onPressed: () => context.push(AppRoutes.ticket(booking.id)),
                  ),
                ],
              ),
            ),
            if (booking.refund != null) ...<Widget>[
              const SizedBox(height: AbraSpacing.sm),
              TextButton(
                onPressed: () =>
                    context.push(AppRoutes.myTripRefund(booking.id)),
                child: Text(
                  l10n.text(CustomerStrings.tdRefundLink, <String, Object?>{
                    'seats': booking.refund!.cancelledSeatIds.join(', '),
                  }),
                ),
              ),
            ],
            const SizedBox(height: AbraSpacing.md),
            if (CustomerLayout.shouldStack(context))
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (upcoming) ...<Widget>[
                    cancelButton,
                    const SizedBox(height: AbraSpacing.sm),
                  ],
                  helpButton,
                ],
              )
            else
              Row(
                children: <Widget>[
                  if (upcoming) ...<Widget>[
                    Expanded(child: cancelButton),
                    const SizedBox(width: AbraSpacing.md),
                  ],
                  Expanded(child: helpButton),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
