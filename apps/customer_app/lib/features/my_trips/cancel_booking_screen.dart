import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/format/rupees.dart';
import '../../core/ui/adaptive_sheet.dart';
import '../../core/ui/chips.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/responsive.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../booking/controllers/booking_context.dart';
import '../booking/models/booking_models.dart';
import '../booking/models/ticket_models.dart';
import '../discovery/widgets/discovery_text.dart';
import 'controllers/cancellation_calculator.dart';
import 'controllers/trips_controller.dart';
import 'models/trip_models.dart';
import 'repositories/trips_repository.dart';

/// Cancelling seats: which seats, what comes back, why, and a confirmation
/// before anything happens. "Cancel" stays off until a seat and a reason are
/// chosen.
class CancelBookingScreen extends ConsumerStatefulWidget {
  const CancelBookingScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<CancelBookingScreen> createState() =>
      _CancelBookingScreenState();
}

class _CancelBookingScreenState extends ConsumerState<CancelBookingScreen> {
  Set<String>? _chosen;
  String? _reason;
  bool _busy = false;

  static const _reasons = <(String id, String key)>[
    ('plans', CustomerStrings.cancelReasonPlans),
    ('mistake', CustomerStrings.cancelReasonMistake),
    ('better', CustomerStrings.cancelReasonBetter),
    ('medical', CustomerStrings.cancelReasonMedical),
    ('other', CustomerStrings.cancelReasonOther),
  ];

  Future<void> _confirm(Booking booking, CancellationQuote quote) async {
    final l10n = AbraLocalizations.of(context);
    final seats = booking.activeSeatIds
        .where((id) => _chosen!.contains(id))
        .toList();
    final text = DiscoveryText(l10n);
    final confirmed = await showAdaptiveSheet<bool>(
      context,
      builder: (context) => _ConfirmSheet(
        seats: seats,
        route: text.route(
          booking.ticket.originName,
          booking.ticket.destinationName,
        ),
        refund: formatRupees(
          l10n,
          quote.refundPaise,
          currencyCode: booking.ticket.currency,
        ),
        hasRefund: quote.refundPaise > 0,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(tripsRepositoryProvider)
          .cancel(booking.id, seats, reason: _reason ?? '');
      ref
        ..invalidate(myBookingsProvider)
        ..invalidate(bookingProvider(booking.id));
      if (!mounted) return;
      final remaining = booking.activeSeatIds.length - seats.length;
      if (remaining == 0) {
        ref.read(tripListKindProvider.notifier).select(TripListKind.cancelled);
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      context.pushReplacement(AppRoutes.myTripRefund(booking.id));
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(l10n.text(CustomerStrings.cancelFailed)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(bookingProvider(widget.bookingId));
    final booking = value.value;
    final text = DiscoveryText(l10n);

    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.cancelTitle),
        subtitle: booking == null
            ? null
            : text.route(
                booking.ticket.originName,
                booking.ticket.destinationName,
              ),
      ),
      body: AsyncValueView<Booking>(
        value: value,
        onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
        data: (context, booking) {
          _chosen ??= booking.activeSeatIds.toSet();
          final chosen = booking.activeSeatIds
              .where((id) => _chosen!.contains(id))
              .toList();
          final quote = ref.watch(
            cancellationQuoteProvider((
              bookingId: booking.id,
              seats: chosen.join(','),
            )),
          );
          final rules = ref
              .watch(cancellationPolicyProvider(booking.ticket.tripId))
              .value;
          return _Form(
            booking: booking,
            chosen: chosen,
            quote: quote.value,
            quoteLoading: quote.isLoading && chosen.isNotEmpty,
            rules: rules,
            reason: _reason,
            busy: _busy,
            onToggle: (id) => setState(() {
              final set = _chosen!;
              set.contains(id) ? set.remove(id) : set.add(id);
            }),
            onReason: (id) => setState(() => _reason = id),
            onCancel: quote.value == null
                ? null
                : () => _confirm(booking, quote.value!),
          );
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.booking,
    required this.chosen,
    required this.quote,
    required this.quoteLoading,
    required this.rules,
    required this.reason,
    required this.busy,
    required this.onToggle,
    required this.onReason,
    required this.onCancel,
  });

  final Booking booking;
  final List<String> chosen;
  final CancellationQuote? quote;
  final bool quoteLoading;
  final List<CancellationRule>? rules;
  final String? reason;
  final bool busy;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onReason;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final currency = booking.ticket.currency;
    String money(int paise) =>
        formatRupees(l10n, paise, currencyCode: currency);

    final canCancel =
        chosen.isNotEmpty && reason != null && quote != null && !busy;

    String? tier;
    final q = quote;
    if (q != null && rules != null) {
      final rule = CancellationCalculator.ruleFor(
        rules!,
        q.hoursBeforeDeparture,
      );
      if (rule != null) {
        final params = <String, Object?>{'percent': rule.refundPercent};
        tier = rule.fromHoursBefore == null
            ? l10n.text(CustomerStrings.cancelTierBefore, <String, Object?>{
                ...params,
                'hours': rule.toHoursBefore,
              })
            : rule.toHoursBefore == 0
            ? l10n.text(CustomerStrings.cancelTierUnder, <String, Object?>{
                ...params,
                'hours': rule.fromHoursBefore,
              })
            : l10n.text(CustomerStrings.cancelTierBetween, <String, Object?>{
                ...params,
                'from': rule.toHoursBefore,
                'to': rule.fromHoursBefore,
              });
      }
    }

    final refundAmount = q == null ? 0 : q.refundPaise;

    return Column(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: AbraResponsive.pagePadding(context),
                children: <Widget>[
                  AbraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.text(CustomerStrings.cancelSelectSeats),
                            style: textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: AbraSpacing.xs),
                        for (final passenger in booking.activePassengers)
                          _SeatRow(
                            passenger: passenger,
                            fare: money(
                              booking.seatFarePaise[passenger.seatId] ?? 0,
                            ),
                            selected: chosen.contains(passenger.seatId),
                            onTap: () => onToggle(passenger.seatId),
                          ),
                      ],
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
                            l10n.text(CustomerStrings.cancelEstimate),
                            style: textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: AbraSpacing.sm),
                        if (tier != null)
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              color: AbraColors.lightBlue,
                              borderRadius: AbraRadius.medium,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AbraSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: AbraColors.deepBlue,
                                  ),
                                  const SizedBox(width: AbraSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      tier,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: AbraColors.deepBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: AbraSpacing.sm),
                        if (chosen.isEmpty)
                          Text(
                            l10n.text(CustomerStrings.cancelPickSeat),
                            style: textTheme.bodyMedium,
                          )
                        else if (quoteLoading || q == null)
                          const AbraSkeletonGroup(
                            child: Column(
                              children: <Widget>[
                                AbraSkeleton(height: 16),
                                SizedBox(height: AbraSpacing.md),
                                AbraSkeleton(height: 16),
                                SizedBox(height: AbraSpacing.md),
                                AbraSkeleton(height: 20),
                              ],
                            ),
                          )
                        else ...<Widget>[
                          _Line(
                            l10n.text(
                              CustomerStrings.cancelFarePaid,
                              <String, Object?>{'count': chosen.length},
                            ),
                            money(q.farePaise),
                          ),
                          const Divider(height: 1),
                          _Line(
                            l10n.text(
                              CustomerStrings.cancelCharge,
                              <String, Object?>{
                                'percent': 100 - q.refundPercent,
                              },
                            ),
                            '−${money(q.chargePaise)}',
                          ),
                          const Divider(height: 1),
                          _Line(
                            l10n.text(CustomerStrings.cancelRefundAmount),
                            money(q.refundPaise),
                            strong: true,
                            color: AbraColors.tealDark,
                          ),
                          const SizedBox(height: AbraSpacing.sm),
                          Text(
                            l10n.text(CustomerStrings.cancelRefundNote),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ],
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
                            l10n.text(CustomerStrings.cancelReasonTitle),
                            style: textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: AbraSpacing.sm),
                        Wrap(
                          spacing: AbraSpacing.sm,
                          runSpacing: AbraSpacing.sm,
                          children: <Widget>[
                            for (final (id, key)
                                in _CancelBookingScreenState._reasons)
                              SelectChip(
                                label: l10n.text(key),
                                selected: reason == id,
                                onSelected: (_) => onReason(id),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _CancelBar(
          refund: money(refundAmount),
          label: l10n.text(CustomerStrings.cancelAction, <String, Object?>{
            'count': chosen.length,
          }),
          busy: busy,
          onPressed: canCancel ? onCancel : null,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.amount, {this.strong = false, this.color});

  final String label;
  final String amount;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = strong ? textTheme.titleMedium : textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: strong
                  ? textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
                  : style,
            ),
          ),
          const SizedBox(width: AbraSpacing.md),
          Text(
            amount,
            style: style?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A passenger with a check box: the seat, the name and the fare. The whole
/// row is the tap target.
class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.passenger,
    required this.fare,
    required this.selected,
    required this.onTap,
  });

  final TicketPassenger passenger;
  final String fare;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: false,
      label:
          '${passenger.name}, '
          '${l10n.text(CustomerStrings.ticketSeat, <String, Object?>{'seat': passenger.seatId})}, $fare',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: AbraRadius.medium,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: selected ? AbraColors.blue : null,
                  border: Border.all(
                    color: selected ? AbraColors.blue : const Color(0xFF9FB3C3),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AbraColors.white,
                      )
                    : null,
              ),
              const SizedBox(width: AbraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      passenger.name.isEmpty ? '-' : passenger.name,
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      l10n.text(CustomerStrings.ticketSeat, <String, Object?>{
                        'seat': passenger.seatId,
                      }),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                fare,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar of the cancel screen: the refund on the left and a red "Cancel"
/// on the right, which stays off until a seat and a reason are chosen.
class _CancelBar extends StatelessWidget {
  const _CancelBar({
    required this.refund,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String refund;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final gutter = AbraResponsive.gutter(context);
    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.text(CustomerStrings.cancelBarRefund),
          style: textTheme.bodySmall,
        ),
        Text(refund, style: textTheme.titleLarge),
      ],
    );
    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AbraColors.danger,
        foregroundColor: AbraColors.white,
        minimumSize: const Size(
          AbraSizes.minTouchTarget,
          AbraSizes.buttonHeight,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AbraRadius.medium),
      ),
      onPressed: onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: AbraSizes.iconSmall + 4,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AbraColors.white,
              ),
            )
          : Text(label, textAlign: TextAlign.center),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.white,
        boxShadow: AbraShadows.raised,
      ),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                AbraSpacing.md,
                gutter,
                AbraSpacing.md,
              ),
              child: CustomerLayout.shouldStack(context)
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        summary,
                        const SizedBox(height: AbraSpacing.sm),
                        button,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        summary,
                        const SizedBox(width: AbraSpacing.lg),
                        Expanded(child: button),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The confirmation before seats are cancelled. "Keep booking" is first and
/// the default; the red button must be chosen on purpose.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.seats,
    required this.route,
    required this.refund,
    required this.hasRefund,
  });

  final List<String> seats;
  final String route;
  final String refund;
  final bool hasRefund;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SheetScaffold(
      title: l10n.text(CustomerStrings.cancelSheetTitle, <String, Object?>{
        'count': seats.length,
      }),
      onClose: () => Navigator.of(context).pop(false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.text(CustomerStrings.cancelSheetBody, <String, Object?>{
              'seats': seats.join(', '),
              'route': route,
            }),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: AbraSpacing.md),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AbraColors.tealContainer,
              borderRadius: AbraRadius.medium,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AbraSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: AbraColors.tealDark,
                  ),
                  const SizedBox(width: AbraSpacing.sm),
                  Expanded(
                    child: Text(
                      hasRefund
                          ? l10n.text(
                              CustomerStrings.cancelSheetRefund,
                              <String, Object?>{'amount': refund},
                            )
                          : l10n.text(CustomerStrings.cancelSheetNoRefund),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AbraColors.tealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AbraButton(
            label: l10n.text(CustomerStrings.cancelKeep),
            variant: AbraButtonVariant.primary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: AbraSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AbraColors.danger,
              foregroundColor: AbraColors.white,
              minimumSize: const Size.fromHeight(AbraSizes.buttonHeight),
              shape: const RoundedRectangleBorder(
                borderRadius: AbraRadius.medium,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.text(CustomerStrings.cancelConfirm)),
          ),
        ],
      ),
    );
  }
}
