import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/format/rupees.dart';
import '../../core/ui/gradient_header.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../discovery/controllers/trip_search_controller.dart';
import '../discovery/controllers/trip_selection_controller.dart';
import 'controllers/booking_context.dart';
import 'controllers/booking_draft_controller.dart';
import 'controllers/booking_validation.dart';
import 'controllers/fare_calculator.dart';
import 'controllers/seat_hold_controller.dart';
import 'models/booking_models.dart';
import 'repositories/booking_repository.dart';
import 'widgets/booking_step_loader.dart';
import 'widgets/booking_step_scaffold.dart';
import 'widgets/fare_widgets.dart';
import 'widgets/hold_widgets.dart';
import 'widgets/passenger_forms.dart';
import 'widgets/review_cards.dart';

/// Step 1 of 2 after the points: who travels in each seat, and how to reach
/// them.
class PassengerDetailsScreen extends ConsumerWidget {
  const PassengerDetailsScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    return BookingStepLoader(
      tripId: tripId,
      title: l10n.text(CustomerStrings.passengerTitle),
      builder: (context, booking) =>
          _PassengerForm(tripId: tripId, booking: booking),
    );
  }
}

class _PassengerForm extends ConsumerWidget {
  const _PassengerForm({required this.tripId, required this.booking});

  final String tripId;
  final BookingContext booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final draft = ref.watch(bookingDraftProvider(tripId));
    final notifier = ref.read(bookingDraftProvider(tripId).notifier);
    final auth = ref.watch(authStateProvider);
    final profile = auth is AuthSignedIn ? auth.user : null;
    final seats = booking.seats;
    final errors = BookingValidation.check(
      seats: seats,
      passengers: draft.passengers,
      contact: draft.contact,
      gst: draft.gst,
    );
    final show = draft.showErrors;
    final fare = FareCalculator.compute(
      basePaise: booking.basePaise,
      discountPaise: draft.coupon.discountPaise,
    );
    final currency = booking.trip.currency;

    void next() {
      if (errors.hasAny) {
        notifier.showErrors();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: _toastDuration,
              content: Text(l10n.text(CustomerStrings.passengerFixFields)),
            ),
          );
        return;
      }
      // A message from this step must not float over the next one.
      ScaffoldMessenger.of(context).clearSnackBars();
      context.push(AppRoutes.tripReview(tripId));
    }

    final continueLabel = l10n.text(CustomerStrings.passengerContinue);
    return BookingStepScaffold(
      tripId: tripId,
      title: l10n.text(CustomerStrings.passengerTitle),
      subtitle: l10n.text(
        CustomerStrings.seatSelectedSummary,
        <String, Object?>{
          'count': seats.length,
          'seats': seats.map((s) => s.id).join(', '),
        },
      ),
      barTotal: formatRupees(l10n, fare.totalPaise, currencyCode: currency),
      barCaption: l10n.text(CustomerStrings.seatTotal),
      actionLabel: continueLabel,
      onAction: next,
      // No countdown on this step, but the hold is still watched.
      showHold: false,
      sideSummary: TotalActionCard(
        caption: l10n.text(CustomerStrings.seatTotal),
        total: formatRupees(l10n, fare.totalPaise, currencyCode: currency),
        actionLabel: continueLabel,
        onAction: next,
      ),
      children: <Widget>[
        SwitchCard(
          title: l10n.text(CustomerStrings.passengerUseProfile),
          hint: l10n.text(CustomerStrings.passengerUseProfileHint),
          value: draft.usesProfile,
          onChanged: (enabled) => notifier.useProfile(
            enabled: enabled,
            profile: profile,
            firstSeatId: seats.first.id,
          ),
        ),
        for (var i = 0; i < seats.length; i++)
          PassengerCard(
            key: ValueKey<String>('${seats[i].id}-${draft.fillVersion}'),
            number: i + 1,
            seat: seats[i],
            entry: draft.passengerFor(seats[i].id),
            errors: errors.forSeat(seats[i].id),
            showErrors: show,
            onChanged: (entry) => notifier.setPassenger(seats[i].id, entry),
          ),
        ContactCard(
          key: ValueKey<int>(draft.fillVersion),
          contact: draft.contact,
          showMobileError: show && errors.mobile,
          showEmailError: show && errors.email,
          onChanged: notifier.setContact,
        ),
        SwitchCard(
          title: l10n.text(CustomerStrings.gstTitle),
          hint: l10n.text(CustomerStrings.gstHint),
          value: draft.gst.enabled,
          onChanged: (enabled) =>
              notifier.setGst(draft.gst.copyWith(enabled: enabled)),
          child: GstFields(
            gst: draft.gst,
            showGstinError: show && errors.gstin,
            showCompanyError: show && errors.company,
            onChanged: notifier.setGst,
          ),
        ),
      ],
    );
  }
}

/// The last look before paying: trip, passengers, points, coupon, fare,
/// cancellation policy and the terms. The seat hold keeps counting down.
class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<BookingReviewScreen> createState() =>
      _BookingReviewScreenState();
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen> {
  bool _checkingCoupon = false;

  String get _tripId => widget.tripId;

  Future<void> _applyCoupon(BookingContext booking, String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || _checkingCoupon) return;
    final notifier = ref.read(bookingDraftProvider(_tripId).notifier);
    setState(() => _checkingCoupon = true);
    try {
      final result = await ref
          .read(bookingRepositoryProvider)
          .applyCoupon(
            tripId: _tripId,
            code: trimmed,
            basePaise: booking.basePaise,
          );
      notifier.setCoupon(
        result.isValid
            ? CouponState(
                status: CouponStatus.applied,
                code: result.code,
                discountPaise: result.discountPaise,
              )
            : CouponState(status: CouponStatus.invalid, code: result.code),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: _toastDuration,
          content: Text(
            AbraLocalizations.of(context).text(AbraStrings.stateErrorMessage),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return BookingStepLoader(
      tripId: _tripId,
      title: l10n.text(CustomerStrings.reviewTitle),
      builder: _buildReview,
    );
  }

  Widget _buildReview(BuildContext context, BookingContext booking) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final draft = ref.watch(bookingDraftProvider(_tripId));
    final notifier = ref.read(bookingDraftProvider(_tripId).notifier);
    final suggestions =
        ref.watch(couponSuggestionsProvider(_tripId)).value ?? const <String>[];
    final rules = ref.watch(cancellationPolicyProvider(_tripId)).value;
    final fare = FareCalculator.compute(
      basePaise: booking.basePaise,
      discountPaise: draft.coupon.discountPaise,
    );
    final currency = booking.trip.currency;
    final seats = booking.seats;
    final proceedLabel = l10n.text(CustomerStrings.reviewProceed);
    final VoidCallback? proceed = draft.termsAccepted
        ? () => context.push(AppRoutes.tripPayment(_tripId))
        : null;

    return BookingStepScaffold(
      tripId: _tripId,
      title: l10n.text(CustomerStrings.reviewTitle),
      subtitle: l10n.text(CustomerStrings.reviewSubtitle),
      barTotal: formatRupees(l10n, fare.totalPaise, currencyCode: currency),
      barCaption: l10n.text(CustomerStrings.seatTotal),
      actionLabel: proceedLabel,
      onAction: proceed,
      sideSummary: TotalActionCard(
        caption: l10n.text(CustomerStrings.seatTotal),
        total: formatRupees(l10n, fare.totalPaise, currencyCode: currency),
        actionLabel: proceedLabel,
        onAction: proceed,
      ),
      children: <Widget>[
        HoldBanner(tripId: _tripId),
        ReviewTripHeader(trip: booking.trip),
        ReviewPassengersCard(
          rows: <(String, String)>[
            for (var i = 0; i < seats.length; i++)
              (
                draft.passengerFor(seats[i].id).name.trim().isEmpty
                    ? l10n.text(
                        CustomerStrings.passengerCardTitle,
                        <String, Object?>{'number': i + 1},
                      )
                    : draft.passengerFor(seats[i].id).name.trim(),
                seats[i].id,
              ),
          ],
        ),
        ReviewPointsCard(
          trip: booking.trip,
          boarding: booking.boarding,
          dropping: booking.dropping,
        ),
        CouponCard(
          key: ValueKey<CouponStatus>(draft.coupon.status),
          coupon: draft.coupon,
          suggestions: suggestions,
          isChecking: _checkingCoupon,
          currencyCode: currency,
          onApply: (code) => _applyCoupon(booking, code),
          onRemove: () => notifier.setCoupon(const CouponState()),
        ),
        AbraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.text(CustomerStrings.fareTitle),
                  style: textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              FareTable(
                fare: fare,
                seatCount: seats.length,
                currencyCode: currency,
              ),
            ],
          ),
        ),
        if (rules != null) CancellationPolicyCard(rules: rules),
        TermsCheckbox(
          value: draft.termsAccepted,
          onChanged: notifier.setTermsAccepted,
        ),
      ],
    );
  }
}

/// Shown when the seat hold ran out before payment: nothing was charged and
/// the seats were let go. Reached from every booking step through
/// [HoldTicker].
class HoldExpiredScreen extends ConsumerWidget {
  const HoldExpiredScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final seatIds = ref.watch(
      tripSelectionProvider(tripId).select((s) => s.seatIds),
    );
    final trip = ref.watch(tripDetailProvider(tripId)).value;
    // The hold is over: let go of it so the booking steps do not use it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(seatHoldProvider(tripId).notifier).release(),
    );

    void backToResults() {
      if (trip == null) {
        context.go(AppRoutes.home);
        return;
      }
      context.go(
        AppRoutes.searchResultsFor(
          fromId: trip.origin.id,
          fromName: trip.origin.name,
          toId: trip.destination.id,
          toName: trip.destination.name,
          date: trip.travelDate,
        ),
      );
    }

    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.holdExpiredBarTitle),
      ),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: AbraCard(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _amber,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AbraSpacing.lg),
                        child: Icon(
                          Icons.schedule_rounded,
                          size: 44,
                          color: AbraColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.text(CustomerStrings.holdExpiredTitle),
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  Text(
                    seatIds.isEmpty
                        ? l10n.text(CustomerStrings.holdExpiredMessageGeneric)
                        : l10n.text(
                            CustomerStrings.holdExpiredMessage,
                            <String, Object?>{'seats': seatIds.join(', ')},
                          ),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.lg),
                  AbraButton(
                    label: l10n.text(CustomerStrings.holdExpiredAgain),
                    variant: AbraButtonVariant.primary,
                    expand: true,
                    onPressed: () => context.go(AppRoutes.tripSeats(tripId)),
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  AbraButton(
                    label: l10n.text(CustomerStrings.holdExpiredBack),
                    variant: AbraButtonVariant.text,
                    expand: true,
                    onPressed: backToResults,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The warning colour of the design (few seats left, pending).
  static const Color _amber = Color(0xFFF59E0B);
}

/// How long a message stays on screen: short, so it never keeps covering the
/// form (the prototype's toast also lasts two seconds).
const Duration _toastDuration = Duration(seconds: 2);
