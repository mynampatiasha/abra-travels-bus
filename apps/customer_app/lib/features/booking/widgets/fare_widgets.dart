import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/format/rupees.dart';
import '../../../l10n/customer_strings.dart';
import '../models/booking_models.dart';

/// The fare breakup: base fare, GST, convenience fee, discount and the
/// total. Amounts are right-aligned and the labels wrap.
class FareTable extends StatelessWidget {
  const FareTable({
    required this.fare,
    required this.seatCount,
    this.currencyCode = 'INR',
    super.key,
  });

  final FareBreakup fare;
  final int seatCount;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    String money(int paise) =>
        formatRupees(l10n, paise, currencyCode: currencyCode);
    Widget line(
      String label,
      String amount, {
      Color? color,
      TextStyle? labelStyle,
      TextStyle? amountStyle,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: (labelStyle ?? textTheme.bodyMedium)?.copyWith(
                color: color,
              ),
            ),
          ),
          const SizedBox(width: AbraSpacing.md),
          Text(
            amount,
            style: (amountStyle ?? textTheme.bodyMedium)?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Column(
      children: <Widget>[
        line(
          l10n.text(CustomerStrings.fareBase, <String, Object?>{
            'count': seatCount,
          }),
          money(fare.basePaise),
        ),
        const Divider(height: 1),
        line(
          l10n.text(CustomerStrings.fareGst, <String, Object?>{'percent': 5}),
          money(fare.gstPaise),
        ),
        const Divider(height: 1),
        line(
          l10n.text(CustomerStrings.fareConvenienceFee),
          money(fare.convenienceFeePaise),
        ),
        const Divider(height: 1),
        line(
          l10n.text(CustomerStrings.fareDiscount),
          fare.discountPaise == 0 ? money(0) : '−${money(fare.discountPaise)}',
          color: AbraColors.tealDark,
        ),
        const Divider(height: 1),
        line(
          l10n.text(CustomerStrings.seatTotal),
          money(fare.totalPaise),
          labelStyle: textTheme.titleSmall,
          amountStyle: textTheme.titleMedium,
        ),
      ],
    );
  }
}

/// The total and the main action beside the form on wider screens: the
/// caption and the amount on the left, the action on the right. On phones
/// the same pair sits in the bar at the bottom.
class TotalActionCard extends StatelessWidget {
  const TotalActionCard({
    required this.caption,
    required this.total,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String caption;
  final String total;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AbraSpacing.lg,
        runSpacing: AbraSpacing.md,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(caption, style: textTheme.bodySmall),
              Text(total, style: textTheme.titleLarge),
            ],
          ),
          AbraButton(
            label: actionLabel,
            variant: AbraButtonVariant.callToAction,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
