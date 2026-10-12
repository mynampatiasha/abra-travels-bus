import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/rupees.dart';
import '../../../core/ui/chips.dart';
import '../../../core/ui/route_label.dart';
import '../../../core/ui/tonal_button.dart';
import '../../../l10n/customer_strings.dart';
import '../../discovery/controllers/travel_dates.dart';
import '../../discovery/models/discovery_models.dart';
import '../../discovery/widgets/discovery_text.dart';
import '../models/booking_models.dart';

/// The trip on the brand gradient: route, operator, date and times.
class ReviewTripHeader extends StatelessWidget {
  const ReviewTripHeader({required this.trip, super.key});

  final TripDetail trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.tryParse(trip.travelDate);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AbraGradients.brand,
        borderRadius: AbraRadius.large,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RouteLabel(
              from: trip.origin.name,
              to: trip.destination.name,
              style: textTheme.titleLarge?.copyWith(color: AbraColors.white),
            ),
            const SizedBox(height: AbraSpacing.xs),
            Text(
              l10n.text(CustomerStrings.reviewRouteLine, <String, Object?>{
                'operator': trip.operator.name,
                'date': date == null
                    ? trip.travelDate
                    : formatShortDate(l10n, TravelDates.asLocalDate(date)),
                'departure': text.time(trip.departureAt, trip.timezone),
                'arrival': text.time(trip.arrivalAt, trip.timezone),
              }),
              style: textTheme.bodySmall?.copyWith(
                color: AbraColors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Names and seats, one row each.
class ReviewPassengersCard extends StatelessWidget {
  const ReviewPassengersCard({required this.rows, super.key});

  /// (name, seat id) in seat order.
  final List<(String name, String seatId)> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.text(CustomerStrings.reviewPassengers),
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          for (final (name, seat) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(name)),
                  const SizedBox(width: AbraSpacing.md),
                  Text(
                    seat,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the customer gets on and off.
class ReviewPointsCard extends StatelessWidget {
  const ReviewPointsCard({
    required this.trip,
    required this.boarding,
    required this.dropping,
    super.key,
  });

  final TripDetail trip;
  final TripPoint? boarding;
  final TripPoint? dropping;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    Widget row(TripPoint? point, String labelKey) => point == null
        ? const SizedBox.shrink()
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.place_outlined, size: AbraSizes.icon),
              const SizedBox(width: AbraSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(point.name, style: textTheme.titleSmall),
                    Text(
                      l10n.text(labelKey, <String, Object?>{
                        'time': text.time(point.time, trip.timezone),
                      }),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          row(boarding, CustomerStrings.reviewBoarding),
          const SizedBox(height: AbraSpacing.md),
          row(dropping, CustomerStrings.reviewDropping),
        ],
      ),
    );
  }
}

/// The coupon box: a field with "Apply", the codes worth trying, the applied
/// state with "Remove", and the "not valid" state.
class CouponCard extends StatefulWidget {
  const CouponCard({
    required this.coupon,
    required this.suggestions,
    required this.isChecking,
    required this.onApply,
    required this.onRemove,
    this.currencyCode = 'INR',
    super.key,
  });

  final CouponState coupon;
  final List<String> suggestions;
  final bool isChecking;
  final ValueChanged<String> onApply;
  final VoidCallback onRemove;
  final String currencyCode;

  @override
  State<CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<CouponCard> {
  late final TextEditingController _code = TextEditingController(
    text: widget.coupon.code,
  );

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final coupon = widget.coupon;
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.text(CustomerStrings.couponTitle),
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          if (coupon.isApplied)
            Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AbraColors.tealDark,
                ),
                const SizedBox(width: AbraSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.text(CustomerStrings.couponApplied, <String, Object?>{
                      'code': coupon.code,
                      'amount': formatRupees(
                        l10n,
                        coupon.discountPaise,
                        currencyCode: widget.currencyCode,
                      ),
                    }),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AbraColors.tealDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _code.clear();
                    widget.onRemove();
                  },
                  child: Text(l10n.text(CustomerStrings.couponRemove)),
                ),
              ],
            )
          else ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.text(CustomerStrings.couponCodeLabel),
                      errorText: coupon.status == CouponStatus.invalid
                          ? l10n.text(CustomerStrings.couponInvalid)
                          : null,
                    ),
                    onSubmitted: widget.onApply,
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(top: AbraSpacing.xs),
                  child: TonalButton(
                    label: l10n.text(CustomerStrings.couponApply),
                    isLoading: widget.isChecking,
                    onPressed: () => widget.onApply(_code.text),
                  ),
                ),
              ],
            ),
            if (coupon.status != CouponStatus.invalid &&
                widget.suggestions.isNotEmpty) ...<Widget>[
              const SizedBox(height: AbraSpacing.sm),
              Wrap(
                spacing: AbraSpacing.sm,
                runSpacing: AbraSpacing.sm,
                children: <Widget>[
                  for (final code in widget.suggestions)
                    SelectChip(
                      label: code,
                      selected: false,
                      onSelected: (_) {
                        _code.text = code;
                        widget.onApply(code);
                      },
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The cancellation policy as an accordion.
class CancellationPolicyCard extends StatelessWidget {
  const CancellationPolicyCard({required this.rules, super.key});

  final List<CancellationRule> rules;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    String window(CancellationRule rule) {
      final from = rule.fromHoursBefore;
      if (from == null) {
        return l10n.text(CustomerStrings.cancelPolicyBefore, <String, Object?>{
          'hours': rule.toHoursBefore,
        });
      }
      if (rule.toHoursBefore == 0) {
        return l10n.text(CustomerStrings.cancelPolicyUnder, <String, Object?>{
          'hours': from,
        });
      }
      return l10n.text(CustomerStrings.cancelPolicyBetween, <String, Object?>{
        'from': rule.toHoursBefore,
        'to': from,
      });
    }

    return AbraCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
          childrenPadding: const EdgeInsets.fromLTRB(
            AbraSpacing.lg,
            0,
            AbraSpacing.lg,
            AbraSpacing.md,
          ),
          title: Text(
            l10n.text(CustomerStrings.cancelPolicyTitle),
            style: textTheme.titleSmall,
          ),
          children: <Widget>[
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AbraSpacing.xs + 2,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(window(rule))),
                    const SizedBox(width: AbraSpacing.md),
                    Text(
                      rule.refundPercent == 0
                          ? l10n.text(CustomerStrings.cancelPolicyNoRefund)
                          : l10n.text(
                              CustomerStrings.cancelPolicyRefund,
                              <String, Object?>{'percent': rule.refundPercent},
                            ),
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "I agree to the Terms and the cancellation policy", as a checkbox row.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return CheckboxListTile(
      value: value,
      onChanged: (checked) => onChanged(checked ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.text(CustomerStrings.termsAgree)),
    );
  }
}
