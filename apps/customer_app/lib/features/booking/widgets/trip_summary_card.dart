import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/ui/route_label.dart';
import '../../discovery/controllers/travel_dates.dart';
import '../../discovery/models/discovery_models.dart';
import '../../discovery/widgets/discovery_text.dart';

/// The trip being booked, as a card at the top of every booking step: the
/// operator and bus, the route, and when it leaves.
class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({required this.trip, super.key});

  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.tryParse(trip.travelDate);
    final when = <String>[
      if (date != null) formatShortDate(l10n, TravelDates.asLocalDate(date)),
      text.time(trip.departureAt, trip.timezone),
    ].join(' • ');
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(trip.operator.name, style: textTheme.titleMedium),
          Text(trip.bus.typeName, style: textTheme.bodySmall),
          const SizedBox(height: AbraSpacing.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            children: <Widget>[
              RouteLabel(
                from: trip.origin.name,
                to: trip.destination.name,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(when, style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
