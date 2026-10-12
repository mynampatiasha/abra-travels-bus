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

    // Large text: times and the line between them no longer fit side by
    // side, so they stack.
    final isLargeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    final seatsBadge = AbraStatusBadge(
      label: text.seats(trip),
      icon: trip.isSoldOut ? Icons.block : Icons.event_seat_outlined,
      tone: trip.isSoldOut
          ? AbraStatusTone.neutral
          : trip.availableSeats <= 5
          ? AbraStatusTone.warning
          : AbraStatusTone.success,
    );

    return AbraCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.zero,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AbraSpacing.lg,
                AbraSpacing.lg,
                AbraSpacing.lg,
                AbraSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AbraColors.lightBlue,
                      borderRadius: AbraRadius.medium,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AbraSpacing.sm),
                      child: Icon(
                        Icons.directions_bus_filled_rounded,
                        color: AbraColors.blueDark,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.md),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
              child: isLargeText
                  ? Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AbraSpacing.md,
                      children: <Widget>[
                        Text(departure, style: textTheme.titleLarge),
                        Text(
                          text.duration(trip.durationMinutes),
                          style: secondary,
                        ),
                        Text(arrival, style: textTheme.titleLarge),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(departure, style: textTheme.titleLarge),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AbraSpacing.md,
                            ),
                            child: AbraJourneyLine(
                              label: text.duration(trip.durationMinutes),
                            ),
                          ),
                        ),
                        Text(arrival, style: textTheme.titleLarge),
                      ],
                    ),
            ),
            if (later != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(later, style: secondary),
                ),
              ),
            const SizedBox(height: AbraSpacing.md),
            // Fare and seats on a tinted band: what the choice comes down to.
            ColoredBox(
              color: AbraColors.lightGray,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AbraSpacing.lg,
                  vertical: AbraSpacing.md,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AbraSpacing.md,
                  runSpacing: AbraSpacing.sm,
                  children: <Widget>[
                    seatsBadge,
                    Text(
                      text.fareFrom(trip),
                      style: textTheme.titleLarge?.copyWith(
                        color: AbraColors.blueDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
