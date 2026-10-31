import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/format/rupees.dart';
import '../../core/ui/gradient_header.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../discovery/controllers/trip_selection_controller.dart';
import 'controllers/booking_context.dart';
import 'controllers/booking_draft_controller.dart';
import 'controllers/fare_calculator.dart';
import 'controllers/payment_controller.dart';
import 'controllers/seat_hold_controller.dart';
import 'controllers/ticket_actions.dart';
import 'models/payment_models.dart';
import 'models/ticket_models.dart';
import 'repositories/booking_repository.dart';
import 'widgets/booking_step_loader.dart';
import 'widgets/booking_step_scaffold.dart';
import 'widgets/fare_widgets.dart';
import 'widgets/hold_widgets.dart';
import 'widgets/payment_states.dart';
import 'widgets/payment_widgets.dart';

/// Payment: the four ways to pay, one open at a time, then "processing",
/// and, when it goes wrong, "payment failed" with a way on. The seats stay
/// held meanwhile; when the hold runs out the customer is told the seats
/// were released.
class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    return BookingStepLoader(
      tripId: tripId,
      title: l10n.text(CustomerStrings.payTitle),
      builder: (context, booking) =>
          _PaymentFlow(tripId: tripId, booking: booking),
    );
  }
}

class _PaymentFlow extends ConsumerWidget {
  const _PaymentFlow({required this.tripId, required this.booking});

  final String tripId;
  final BookingContext booking;

  int _totalPaise(WidgetRef ref) => FareCalculator.compute(
    basePaise: booking.basePaise,
    discountPaise: ref.read(couponDiscountProvider(tripId)),
  ).totalPaise;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final amount = _totalPaise(ref);
    final draft = ref.read(bookingDraftProvider(tripId));
    final selection = ref.read(tripSelectionProvider(tripId));
    final hold = ref.read(seatHoldProvider(tripId));
    if (hold == null) return;
    final result = await ref
        .read(paymentProvider(tripId).notifier)
        .pay(
          request: BookingRequest(
            tripId: tripId,
            lockId: hold.lockId,
            seatIds: booking.seatIds,
            passengers: draft.passengers,
            contact: draft.contact,
            gst: draft.gst,
            boardingPointId: selection.boardingPointId ?? '',
            droppingPointId: selection.droppingPointId ?? '',
            couponCode: draft.coupon.isApplied ? draft.coupon.code : null,
            tripHint: booking.trip,
            expectedAmountPaise: amount,
          ),
          amountPaise: amount,
          now: ref.read(bookingClockProvider)(),
        );
    if (!context.mounted || result == null) return;
    switch (result.outcome) {
      case PaymentOutcome.success:
        ref.read(seatHoldProvider(tripId).notifier).release();
        context.go(AppRoutes.bookingConfirmed(result.bookingId ?? ''));
      case PaymentOutcome.timeout:
        context.go(AppRoutes.tripHoldExpired(tripId));
      case PaymentOutcome.failed:
        break;
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final amount = _totalPaise(ref);
    final draft = ref.read(bookingDraftProvider(tripId));
    final selection = ref.read(tripSelectionProvider(tripId));
    final hold = ref.read(seatHoldProvider(tripId));
    if (hold == null) return;
    try {
      final link = await ref
          .read(paymentProvider(tripId).notifier)
          .shareLink(
            request: BookingRequest(
              tripId: tripId,
              lockId: hold.lockId,
              seatIds: booking.seatIds,
              passengers: draft.passengers,
              contact: draft.contact,
              gst: draft.gst,
              boardingPointId: selection.boardingPointId ?? '',
              droppingPointId: selection.droppingPointId ?? '',
              couponCode: draft.coupon.isApplied ? draft.coupon.code : null,
              tripHint: booking.trip,
              expectedAmountPaise: amount,
            ),
          );
      final total = formatRupees(l10n, amount, currencyCode: booking.trip.currency);
      await ref.read(shareTextProvider)(
        l10n.text(CustomerStrings.payShareMessage, <String, Object?>{'amount': total, 'link': link}),
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.text(CustomerStrings.payShareFailed))));
    }
  }

  void _backToReview(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.tripReview(tripId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final state = ref.watch(paymentProvider(tripId));
    final notifier = ref.read(paymentProvider(tripId).notifier);
    final currency = booking.trip.currency;
    final amount = formatRupees(
      l10n,
      FareCalculator.compute(
        basePaise: booking.basePaise,
        discountPaise: ref.watch(couponDiscountProvider(tripId)),
      ).totalPaise,
      currencyCode: currency,
    );

    if (state.phase == PaymentPhase.processing) {
      // Nothing to press and no way out until the answer comes.
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: GradientAppBar(
            title: l10n.text(CustomerStrings.payProcessingBarTitle),
            subtitle: l10n.text(CustomerStrings.payProcessingBarSubtitle),
            automaticallyImplyLeading: false,
          ),
          body: PaymentStatePage(child: PaymentProcessingCard(amount: amount)),
        ),
      );
    }

    if (state.phase == PaymentPhase.failed) {
      return Scaffold(
        appBar: GradientAppBar(
          title: l10n.text(CustomerStrings.payFailedBarTitle),
          subtitle: l10n.text(CustomerStrings.payFailedBarSubtitle),
          actions: <Widget>[HoldChip(tripId: tripId)],
        ),
        body: PaymentStatePage(
          child: PaymentFailedCard(
            failureCode: state.failureCode,
            reference: state.reference,
            onRetry: () => _pay(context, ref),
            onChangeMethod: notifier.changeMethod,
            onBack: () => _backToReview(context),
          ),
        ),
      );
    }

    void pay() => _pay(context, ref);
    final payLabel = l10n.text(CustomerStrings.payAction, <String, Object?>{
      'amount': amount,
    });
    final left = ref.watch(holdSecondsProvider(tripId)).value ?? 0;

    return BookingStepScaffold(
      tripId: tripId,
      title: l10n.text(CustomerStrings.payTitle),
      subtitle: l10n.text(CustomerStrings.paySubtitle, <String, Object?>{
        'amount': amount,
      }),
      barTotal: amount,
      barCaption: l10n.text(CustomerStrings.payHoldCaption, <String, Object?>{
        'time': formatHold(left),
      }),
      actionLabel: payLabel,
      onAction: pay,
      sideSummary: TotalActionCard(
        caption: l10n.text(CustomerStrings.payHoldCaption, <String, Object?>{
          'time': formatHold(left),
        }),
        total: amount,
        actionLabel: payLabel,
        onAction: pay,
      ),
      children: <Widget>[
        HoldBanner(tripId: tripId, messageKey: CustomerStrings.holdBannerShort),
        PaymentChooseNextCard(text: l10n.text(CustomerStrings.payChooseNext)),
        const SecureNote(),
        const SizedBox(height: AbraSpacing.md),
        OutlinedButton.icon(
          onPressed: () => _share(context, ref),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: Text(l10n.text(CustomerStrings.payShareAction)),
        ),
      ],
    );
  }
}
