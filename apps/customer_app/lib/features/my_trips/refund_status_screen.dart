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
import '../../core/ui/sticky_action_bar.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../booking/controllers/ticket_actions.dart';
import '../discovery/controllers/travel_dates.dart';
import '../discovery/widgets/discovery_text.dart';
import 'controllers/trips_controller.dart';
import 'models/trip_models.dart';
import 'widgets/trip_timeline.dart';

/// Where the refund of cancelled seats is: requested, processing, refunded,
/// and the bank's UTR once it is paid. Refreshes itself every minute while
/// the refund is on its way.
class RefundStatusScreen extends ConsumerWidget {
  const RefundStatusScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(bookingProvider(bookingId));
    final booking = value.value;
    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.refundTitle),
        subtitle: booking == null
            ? null
            : l10n.text(CustomerStrings.ticketBarSubtitle, <String, Object?>{
                'pnr': booking.ticket.pnr,
              }),
      ),
      bottomNavigationBar: StickyActionBar(
        actionLabel: l10n.text(CustomerStrings.refundBack),
        onAction: () => context.go(AppRoutes.myTrips),
      ),
      body: AsyncValueView<Booking>(
        value: value,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (context, booking) => booking.refund == null
            ? const SizedBox.shrink()
            : _Refund(booking: booking, refund: booking.refund!),
      ),
    );
  }
}

class _Refund extends ConsumerWidget {
  const _Refund({required this.booking, required this.refund});

  final Booking booking;
  final RefundInfo refund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final ticket = booking.ticket;
    final done = refund.stage == RefundStage.refunded;

    String dateOf(DateTime instant) => formatShortDate(
      l10n,
      TravelDates.asLocalDate(TravelDates.wallClock(instant, ticket.timezone)),
    );
    String timeOf(DateTime instant) => text.time(instant, ticket.timezone);

    final steps = <TimelineStep>[
      TimelineStep(
        title: l10n.text(CustomerStrings.refundRequested),
        subtitle: l10n
            .text(CustomerStrings.refundRequestedLine, <String, Object?>{
              'date': dateOf(refund.requestedAt),
              'time': timeOf(refund.requestedAt),
              'count': refund.cancelledSeatIds.length,
            }),
        state: TimelineState.done,
      ),
      TimelineStep(
        title: l10n.text(CustomerStrings.refundProcessing),
        subtitle: done
            ? l10n.text(CustomerStrings.refundProcessingDone, <String, Object?>{
                'date': dateOf(refund.processingAt ?? refund.requestedAt),
              })
            : l10n.text(CustomerStrings.refundProcessingLine, <String, Object?>{
                'date': dateOf(refund.processingExpectedBy),
              }),
        state: done ? TimelineState.done : TimelineState.current,
      ),
      TimelineStep(
        title: l10n.text(CustomerStrings.refundRefunded),
        subtitle: done
            ? l10n.text(CustomerStrings.refundRefundedLine, <String, Object?>{
                'date': dateOf(refund.refundedAt ?? refund.requestedAt),
                'time': timeOf(refund.refundedAt ?? refund.requestedAt),
              })
            : l10n.text(
                CustomerStrings.refundRefundedExpected,
                <String, Object?>{'date': dateOf(refund.refundExpectedBy)},
              ),
        state: done ? TimelineState.done : TimelineState.upcoming,
      ),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(bookingProvider(booking.id).future),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AbraResponsive.pagePadding(context),
            children: <Widget>[
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AbraGradients.brand,
                  borderRadius: AbraRadius.large,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AbraSpacing.lg),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.text(
                            done
                                ? CustomerStrings.refundDoneLabel
                                : CustomerStrings.refundAmountLabel,
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: AbraColors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          formatRupees(
                            l10n,
                            refund.amountPaise,
                            currencyCode: ticket.currency,
                          ),
                          style: textTheme.headlineMedium?.copyWith(
                            color: AbraColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.text(CustomerStrings.refundTo, <String, Object?>{
                            'method': refund.methodLabel,
                          }),
                          style: textTheme.bodySmall?.copyWith(
                            color: AbraColors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              AbraCard(
                child: VerticalTimeline(
                  steps: steps,
                  stateLabels: <TimelineState, String>{
                    TimelineState.done: l10n.text(CustomerStrings.timelineDone),
                    TimelineState.current: l10n.text(
                      CustomerStrings.timelineNow,
                    ),
                    TimelineState.upcoming: l10n.text(
                      CustomerStrings.timelineNext,
                    ),
                  },
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              AbraCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.text(CustomerStrings.refundUtr),
                            style: textTheme.bodySmall,
                          ),
                          Text(
                            done
                                ? (refund.utr ?? '-')
                                : l10n.text(CustomerStrings.refundUtrPending),
                            style: textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    if (done && refund.utr != null)
                      IconButton.filled(
                        tooltip: l10n.text(CustomerStrings.refundUtrCopy),
                        style: IconButton.styleFrom(
                          backgroundColor: AbraColors.lightBlue,
                          foregroundColor: AbraColors.blue,
                          minimumSize: const Size.square(
                            AbraSizes.minTouchTarget,
                          ),
                        ),
                        onPressed: () async {
                          await ref.read(copyTextProvider)(refund.utr!);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 2),
                                content: Text(
                                  l10n.text(CustomerStrings.refundUtrCopied),
                                ),
                              ),
                            );
                        },
                        icon: const Icon(Icons.content_copy_rounded),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.support),
                icon: const Icon(Icons.help_outline_rounded),
                label: Text(l10n.text(CustomerStrings.refundHelp)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
