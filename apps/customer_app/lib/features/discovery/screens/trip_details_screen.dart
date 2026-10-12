import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/async_value_view.dart';
import '../../../core/ui/gradient_header.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../controllers/trip_search_controller.dart';
import '../controllers/trip_selection_controller.dart';
import '../models/discovery_models.dart';
import '../widgets/discovery_text.dart';

/// One trip: bus, timings, fare, boarding and dropping points. Loaded from
/// the backend every time it opens. Open to guests; the boarding and
/// dropping points chosen here are kept through sign-in, which "Select
/// seats" asks for.
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
    final loaded = trip.value;
    final text = DiscoveryText(l10n);
    if (loaded != null) {
      final selection = ref.read(tripSelectionProvider(tripId));
      if (selection.boardingPointId == null ||
          selection.droppingPointId == null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref
              .read(tripSelectionProvider(tripId).notifier)
              .applyDefaults(
                boardingPointId: loaded.boardingPoints.firstOrNull?.id,
                droppingPointId: loaded.droppingPoints.lastOrNull?.id,
              ),
        );
      }
    }

    return Scaffold(
      appBar: GradientAppBar(
        title: loaded == null
            ? l10n.text(CustomerStrings.routeTripTitle)
            : text.route(loaded.origin.name, loaded.destination.name),
      ),
      bottomNavigationBar: loaded == null || failure != null
          ? null
          : StickyActionBar(
              title: text.fareFrom(loaded),
              subtitle: text.seats(loaded),
              actionLabel: l10n.text(CustomerStrings.tripSelectSeats),
              actionIcon: Icons.event_seat_outlined,
              // The seats are open to guests; signing in is asked for on
              // "Continue" there.
              onAction: loaded.isSoldOut
                  ? null
                  : () => context.push(AppRoutes.tripSeats(tripId)),
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

class _TripDetails extends ConsumerWidget {
  const _TripDetails({required this.trip});

  final TripDetail trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(tripSelectionProvider(trip.id));
    final selector = ref.read(tripSelectionProvider(trip.id).notifier);
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final later = text.arrivesLater(trip);
    final onBrand = textTheme.bodyMedium?.copyWith(color: AbraColors.white);
    final travelDate = DateTime.tryParse(trip.travelDate);

    return AbraPageContainer(
      maxWidth: AbraSizes.maxFormWidth * 1.5,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AbraSpacing.lg),
        children: <Widget>[
          // The journey on the brand colours: who runs it, when it leaves
          // and arrives.
          AbraEntrance(
            child: AbraBrandSurface(
              gradient: AbraGradients.brandDeep,
              borderRadius: AbraRadius.large,
              showMotif: false,
              child: Padding(
                padding: const EdgeInsets.all(AbraSpacing.lg),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: AbraColors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        trip.operator.name,
                        style: textTheme.titleLarge?.copyWith(
                          color: AbraColors.white,
                        ),
                      ),
                      Text(trip.bus.name, style: onBrand),
                      Text(
                        '${trip.bus.typeName} · '
                        '${text.airConditioning(isAc: trip.bus.isAc)}',
                        style: onBrand,
                      ),
                      if (trip.bus.registrationNumber != null)
                        Text(
                          l10n.text(
                            CustomerStrings.tripDetailsBusNumber,
                            <String, Object?>{
                              'number': trip.bus.registrationNumber,
                            },
                          ),
                          style: onBrand,
                        ),
                      const Divider(
                        height: AbraSpacing.xl,
                        color: AbraColors.navyDivider,
                      ),
                      if (travelDate != null)
                        Text(
                          text.date(travelDate),
                          style: textTheme.titleSmall?.copyWith(
                            color: AbraColors.white,
                          ),
                        ),
                      const SizedBox(height: AbraSpacing.sm),
                      MergeSemantics(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _TimeAndPlace(
                              time: text.time(trip.departureAt, trip.timezone),
                              place: trip.origin.name,
                              alignment: CrossAxisAlignment.start,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AbraSpacing.sm,
                                ),
                                child: AbraJourneyLine(
                                  label: text.duration(trip.durationMinutes),
                                  color: AbraColors.white,
                                  labelColor: AbraColors.white,
                                  iconBackground: AbraColors.navySecondary,
                                ),
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
                          l10n.text(
                            CustomerStrings.tripDetailsVia,
                            <String, Object?>{
                              'stops': trip.stops
                                  .map((stop) => stop.name)
                                  .join(', '),
                            },
                          ),
                          style: onBrand,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          AbraEntrance(
            index: 1,
            child: AbraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Wraps when fare and seats do not fit on one line.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AbraSpacing.md,
                    runSpacing: AbraSpacing.sm,
                    children: <Widget>[
                      Text(
                        text.fareFrom(trip),
                        style: textTheme.headlineSmall?.copyWith(
                          color: AbraColors.blueDark,
                        ),
                      ),
                      AbraStatusBadge(
                        label: text.seats(trip),
                        icon: trip.isSoldOut
                            ? Icons.block
                            : Icons.event_seat_outlined,
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
                    icon: Icons.check,
                  ),
              ],
            ),
          ],
          _SectionTitle(l10n.text(CustomerStrings.tripDetailsBoardingTitle)),
          _PointList(
            points: trip.boardingPoints,
            timezone: trip.timezone,
            text: text,
            selectedId: selection.boardingPointId,
            onSelect: selector.selectBoardingPoint,
          ),
          _SectionTitle(l10n.text(CustomerStrings.tripDetailsDroppingTitle)),
          _PointList(
            points: trip.droppingPoints,
            timezone: trip.timezone,
            text: text,
            selectedId: selection.droppingPointId,
            onSelect: selector.selectDroppingPoint,
          ),
          const SizedBox(height: AbraSpacing.xl),
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

/// A time with its city, on the brand header (white text).
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
    final align = alignment == CrossAxisAlignment.end
        ? TextAlign.end
        : TextAlign.start;
    return Flexible(
      flex: 2,
      child: Column(
        crossAxisAlignment: alignment,
        children: <Widget>[
          Text(
            time,
            textAlign: align,
            style: textTheme.titleLarge?.copyWith(color: AbraColors.white),
          ),
          Text(
            place,
            textAlign: align,
            style: textTheme.bodyMedium?.copyWith(color: AbraColors.white),
          ),
          if (note != null)
            Text(
              note!,
              textAlign: align,
              style: textTheme.bodySmall?.copyWith(color: AbraColors.white),
            ),
        ],
      ),
    );
  }
}

/// Boarding or dropping points as a timeline, in time order.
class _PointList extends StatelessWidget {
  const _PointList({
    required this.points,
    required this.timezone,
    required this.text,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TripPoint> points;
  final String timezone;
  final DiscoveryText text;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => AbraCard(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AbraSpacing.lg,
      vertical: AbraSpacing.sm,
    ),
    child: Column(
      children: <Widget>[
        for (final (index, point) in points.indexed)
          _PointTile(
            point: point,
            timezone: timezone,
            text: text,
            isFirst: index == 0,
            isLast: index == points.length - 1,
            isSelected: point.id == selectedId,
            onSelect: () => onSelect(point.id),
          ),
      ],
    ),
  );
}

class _PointTile extends StatelessWidget {
  const _PointTile({
    required this.point,
    required this.timezone,
    required this.text,
    required this.isFirst,
    required this.isLast,
    required this.isSelected,
    required this.onSelect,
  });

  final TripPoint point;
  final String timezone;
  final DiscoveryText text;
  final bool isFirst;
  final bool isLast;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = text.l10n;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: AbraColors.textSecondary,
    );
    const line = BorderSide(color: AbraColors.border, width: 2);
    // The whole row chooses the point; the stop on the timeline fills to
    // show the choice, and a check says it in words.
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: onSelect,
          borderRadius: AbraRadius.medium,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The timeline: a stop on a line that joins the points.
                ExcludeSemantics(
                  child: SizedBox(
                    width: AbraSpacing.xl,
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: AbraSpacing.md,
                          child: isFirst
                              ? null
                              : const VerticalDivider(
                                  width: 2,
                                  thickness: 2,
                                  color: AbraColors.border,
                                ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AbraColors.blue
                                : AbraColors.white,
                            shape: BoxShape.circle,
                            border: const Border.fromBorderSide(
                              BorderSide(color: AbraColors.blue, width: 3),
                            ),
                          ),
                          child: const SizedBox.square(dimension: 14),
                        ),
                        Expanded(
                          child: isLast
                              ? const SizedBox.shrink()
                              : const DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(left: line),
                                  ),
                                  child: SizedBox(width: 2),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AbraSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AbraSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          text.time(point.time, timezone),
                          style: textTheme.labelLarge?.copyWith(
                            color: AbraColors.blueDark,
                          ),
                        ),
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
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AbraSpacing.sm,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: AbraColors.blue,
                      semanticLabel: l10n.text(
                        CustomerStrings.tripPointSelected,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
