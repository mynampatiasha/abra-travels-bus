import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/async_value_view.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../controllers/trip_search_controller.dart';
import '../models/discovery_models.dart';
import '../widgets/discovery_text.dart';

/// One trip: bus, timings, fare, boarding and dropping points. Loaded from
/// the backend every time it opens.
class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final provider = tripDetailProvider(tripId);
    final trip = ref.watch(provider);
    final error = trip.hasError && !trip.isLoading ? trip.error : null;
    final failure = error == null ? null : failureOf(error);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          trip.value == null
              ? l10n.text(CustomerStrings.routeTripTitle)
              : DiscoveryText(
                  l10n,
                ).route(trip.value!.origin.name, trip.value!.destination.name),
        ),
      ),
      // A trip that is gone (departed, cancelled, never existed) gets its own
      // explanation and a way back to searching, not a generic "not found".
      body: failure is ApiFailure && failure.isNotFound
          ? AbraPageContainer(
              child: AbraStateView(
                kind: AbraStateKind.notFound,
                title: l10n.text(CustomerStrings.tripUnavailableTitle),
                message: l10n.text(CustomerStrings.tripUnavailableMessage),
                actionLabel: l10n.text(CustomerStrings.searchButton),
                onAction: () => context.go(AppRoutes.home),
              ),
            )
          : AsyncValueView<TripDetail>(
              value: trip,
              onRetry: () => ref.invalidate(provider),
              data: (context, trip) => _TripDetails(trip: trip),
            ),
    );
  }
}

class _TripDetails extends StatelessWidget {
  const _TripDetails({required this.trip});

  final TripDetail trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AbraColors.textSecondary,
    );
    final later = text.arrivesLater(trip);
    final travelDate = DateTime.tryParse(trip.travelDate);

    return AbraPageContainer(
      maxWidth: AbraSizes.maxFormWidth * 1.5,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AbraSpacing.lg),
        children: <Widget>[
          AbraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(trip.operator.name, style: textTheme.titleLarge),
                Text(trip.bus.name, style: secondary),
                Text(
                  '${trip.bus.typeName} · '
                  '${text.airConditioning(isAc: trip.bus.isAc)}',
                  style: secondary,
                ),
                if (trip.bus.registrationNumber != null)
                  Text(
                    l10n.text(
                      CustomerStrings.tripDetailsBusNumber,
                      <String, Object?>{'number': trip.bus.registrationNumber},
                    ),
                    style: secondary,
                  ),
                const Divider(height: AbraSpacing.xl),
                if (travelDate != null)
                  Text(text.date(travelDate), style: textTheme.titleSmall),
                const SizedBox(height: AbraSpacing.sm),
                MergeSemantics(
                  child: Row(
                    children: <Widget>[
                      _TimeAndPlace(
                        time: text.time(trip.departureAt, trip.timezone),
                        place: trip.origin.name,
                        alignment: CrossAxisAlignment.start,
                      ),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text(
                              text.duration(trip.durationMinutes),
                              style: secondary,
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: AbraColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                      _TimeAndPlace(
                        time: text.time(trip.arrivalAt, trip.timezone),
                        place: trip.destination.name,
                        alignment: CrossAxisAlignment.end,
                        note: later,
                      ),
                    ],
                  ),
                ),
                if (trip.stops.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AbraSpacing.sm),
                  Text(
                    l10n.text(CustomerStrings.tripDetailsVia, <String, Object?>{
                      'stops': trip.stops.map((stop) => stop.name).join(', '),
                    }),
                    style: secondary,
                  ),
                ],
                const Divider(height: AbraSpacing.xl),
                // Wraps when fare and seats do not fit on one line.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AbraSpacing.md,
                  runSpacing: AbraSpacing.sm,
                  children: <Widget>[
                    Text(
                      text.fareFrom(trip),
                      style: textTheme.titleLarge?.copyWith(
                        color: AbraColors.navy,
                      ),
                    ),
                    AbraStatusBadge(
                      label: text.seats(trip),
                      tone: trip.isSoldOut
                          ? AbraStatusTone.neutral
                          : AbraStatusTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: AbraSpacing.xs),
                Text(
                  l10n.text(CustomerStrings.tripDetailsFareNote),
                  style: textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trip.bus.amenities.isNotEmpty) ...<Widget>[
            _SectionTitle(l10n.text(CustomerStrings.tripDetailsAmenitiesTitle)),
            Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.sm,
              children: <Widget>[
                for (final amenity in trip.bus.amenities)
                  AbraStatusBadge(
                    label: text.amenity(amenity),
                    tone: AbraStatusTone.info,
                  ),
              ],
            ),
          ],
          _SectionTitle(l10n.text(CustomerStrings.tripDetailsBoardingTitle)),
          for (final point in trip.boardingPoints)
            _PointTile(point: point, timezone: trip.timezone, text: text),
          _SectionTitle(l10n.text(CustomerStrings.tripDetailsDroppingTitle)),
          for (final point in trip.droppingPoints)
            _PointTile(point: point, timezone: trip.timezone, text: text),
          const SizedBox(height: AbraSpacing.xl),
          // Seat selection is the next milestone. Said plainly rather than
          // offered as a button that would do nothing.
          DecoratedBox(
            decoration: BoxDecoration(
              color: AbraStatusColors.from(context).info.container,
              borderRadius: AbraRadius.medium,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AbraSpacing.md),
              child: Text(
                l10n.text(CustomerStrings.tripDetailsBookingUnavailable),
                style: textTheme.bodyMedium?.copyWith(
                  color: AbraStatusColors.from(context).info.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AbraSpacing.xl, bottom: AbraSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _TimeAndPlace extends StatelessWidget {
  const _TimeAndPlace({
    required this.time,
    required this.place,
    required this.alignment,
    this.note,
  });

  final String time;
  final String place;
  final CrossAxisAlignment alignment;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AbraColors.textSecondary,
    );
    return Flexible(
      flex: 2,
      child: Column(
        crossAxisAlignment: alignment,
        children: <Widget>[
          Text(time, style: textTheme.titleLarge),
          Text(place, style: textTheme.bodyMedium),
          if (note != null) Text(note!, style: secondary),
        ],
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({
    required this.point,
    required this.timezone,
    required this.text,
  });

  final TripPoint point;
  final String timezone;
  final DiscoveryText text;

  @override
  Widget build(BuildContext context) {
    final l10n = text.l10n;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AbraColors.textSecondary,
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: AbraSpacing.xxxl + AbraSpacing.xl,
              child: Text(
                text.time(point.time, timezone),
                style: textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: AbraSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(point.name, style: textTheme.bodyLarge),
                  if (point.address != null)
                    Text(point.address!, style: secondary),
                  if (point.landmark != null)
                    Text(
                      l10n.text(
                        CustomerStrings.tripDetailsLandmark,
                        <String, Object?>{'landmark': point.landmark},
                      ),
                      style: secondary,
                    ),
                  if (point.instructions != null)
                    Text(point.instructions!, style: secondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
