import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../l10n/customer_strings.dart';
import '../models/discovery_models.dart';
import 'discovery_text.dart';

/// One search result. Read as a single sentence by screen readers.
class TripCard extends StatelessWidget {
  const TripCard({required this.trip, required this.onTap, super.key});

  final TripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final departure = text.time(trip.departureAt, trip.timezone);
    final arrival = text.time(trip.arrivalAt, trip.timezone);
    final busType =
        '${trip.bus.typeName} · ${text.airConditioning(isAc: trip.bus.isAc)}';
    final later = text.arrivesLater(trip);
    final secondary = textTheme.bodySmall?.copyWith(
      color: AbraColors.textSecondary,
    );

    return AbraCard(
      onTap: onTap,
      semanticLabel: l10n
          .text(CustomerStrings.tripCardSemantics, <String, Object?>{
            'operator': trip.operator.name,
            'busType': busType,
            'departure': departure,
            'arrival': later == null ? arrival : '$arrival, $later',
            'fare': text.fareFrom(trip),
            'seats': text.seats(trip),
          }),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        trip.operator.name,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        busType,
                        style: secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Flexible(
                  child: Text(
                    text.fareFrom(trip),
                    textAlign: TextAlign.end,
                    style: textTheme.titleMedium?.copyWith(
                      color: AbraColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.md),
            // Wraps onto further lines when the times do not fit side by side
            // (narrow screen, large text).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AbraSpacing.md,
              children: <Widget>[
                Text(departure, style: textTheme.titleLarge),
                Text(text.duration(trip.durationMinutes), style: secondary),
                Text(arrival, style: textTheme.titleLarge),
              ],
            ),
            if (later != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(later, style: secondary),
              ),
            const SizedBox(height: AbraSpacing.md),
            AbraStatusBadge(
              label: text.seats(trip),
              tone: trip.isSoldOut
                  ? AbraStatusTone.neutral
                  : trip.availableSeats <= 5
                  ? AbraStatusTone.warning
                  : AbraStatusTone.success,
            ),
          ],
        ),
      ),
    );
  }
}
