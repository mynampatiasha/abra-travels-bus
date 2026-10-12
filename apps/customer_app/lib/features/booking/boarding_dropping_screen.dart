import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/async_value_view.dart';
import '../../core/ui/chips.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/sticky_action_bar.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../discovery/controllers/trip_search_controller.dart';
import '../discovery/controllers/trip_selection_controller.dart';
import '../discovery/models/discovery_models.dart';
import '../discovery/widgets/discovery_text.dart';
import 'controllers/seat_hold_controller.dart';
import 'controllers/seat_selection_controller.dart';
import 'controllers/url_launcher_provider.dart';
import 'repositories/booking_repository.dart';

enum _PointKind { boarding, dropping }

/// Where to get on and off. Both points start with the choice made on the
/// trip page, so "Continue" is always possible. Phones show one list at a
/// time behind two tabs; wider screens show both side by side.
class BoardingDroppingScreen extends ConsumerStatefulWidget {
  const BoardingDroppingScreen({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<BoardingDroppingScreen> createState() =>
      _BoardingDroppingScreenState();
}

class _BoardingDroppingScreenState
    extends ConsumerState<BoardingDroppingScreen> {
  _PointKind _tab = _PointKind.boarding;

  String get _tripId => widget.tripId;

  Future<void> _openMap(TripPoint point) async {
    final query = <String>[
      point.name,
      if (point.address != null) point.address!,
      if (point.cityName != null) point.cityName!,
    ].join(', ');
    final opened = await ref.read(urlLauncherProvider)(mapSearchUri(query));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: _toastDuration,
            content: Text(
              AbraLocalizations.of(
                context,
              ).text(CustomerStrings.pointsMapFailed),
            ),
          ),
        );
    }
  }

  bool _holding = false;

  /// Holds the seats for ten minutes, then goes on to the passengers. If
  /// somebody else took one meanwhile, back to the seat map to choose again.
  Future<void> _continue() async {
    if (_holding) return;
    final selection = ref.read(tripSelectionProvider(_tripId));
    final boardingId = selection.boardingPointId;
    final droppingId = selection.droppingPointId;
    if (boardingId == null || droppingId == null || selection.seatIds.isEmpty) {
      context.go(AppRoutes.tripSeats(_tripId));
      return;
    }
    setState(() => _holding = true);
    try {
      final lock = await ref
          .read(bookingRepositoryProvider)
          .lockSeats(
            tripId: _tripId,
            seatIds: selection.seatIds,
            boardingPointId: boardingId,
            droppingPointId: droppingId,
          );
      if (!mounted) return;
      ref.read(seatHoldProvider(_tripId).notifier).start(lock);
      ScaffoldMessenger.of(context).clearSnackBars();
      await context.push(AppRoutes.tripPassengers(_tripId));
    } on SeatsUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: _toastDuration,
          content: Text(
            AbraLocalizations.of(
              context,
            ).text(CustomerStrings.seatsTakenMessage),
          ),
        ),
      );
      context.go(AppRoutes.tripSeats(_tripId));
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
      if (mounted) setState(() => _holding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final tripValue = ref.watch(tripDetailProvider(_tripId));
    final selection = ref.watch(tripSelectionProvider(_tripId));
    final selector = ref.read(tripSelectionProvider(_tripId).notifier);
    final trip = tripValue.value;

    if (trip != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => applyTripDefaults(ref, trip),
      );
    }
    final boarding = trip?.boardingPoints
        .where((p) => p.id == selection.boardingPointId)
        .firstOrNull;
    final dropping = trip?.droppingPoints
        .where((p) => p.id == selection.droppingPointId)
        .firstOrNull;
    final canContinue = boarding != null && dropping != null;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (canContinue) _continue();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: GradientAppBar(
            title: l10n.text(CustomerStrings.pointsTitle),
            subtitle: l10n.text(CustomerStrings.pointsSubtitle),
          ),
          bottomNavigationBar: trip == null
              ? null
              : StickyActionBar(
                  summaryText: <String>[
                    if (boarding != null)
                      l10n.text(
                        CustomerStrings.pointsSummaryBoarding,
                        <String, Object?>{
                          'name': boarding.name,
                          'time': text.time(boarding.time, trip.timezone),
                        },
                      ),
                    if (dropping != null)
                      l10n.text(
                        CustomerStrings.pointsSummaryDropping,
                        <String, Object?>{
                          'name': dropping.name,
                          'time': text.time(dropping.time, trip.timezone),
                        },
                      ),
                  ].join('\n'),
                  actionLabel: l10n.text(CustomerStrings.pointsContinue),
                  isLoading: _holding,
                  onAction: canContinue ? _continue : null,
                ),
          body: AsyncValueView<TripDetail>(
            value: tripValue,
            onRetry: () => ref.invalidate(tripDetailProvider(_tripId)),
            data: (context, trip) {
              Widget list(_PointKind kind) => _PointList(
                trip: trip,
                points: kind == _PointKind.boarding
                    ? trip.boardingPoints
                    : trip.droppingPoints,
                selectedId: kind == _PointKind.boarding
                    ? selection.boardingPointId
                    : selection.droppingPointId,
                onSelected: (id) => kind == _PointKind.boarding
                    ? selector.selectBoardingPoint(id)
                    : selector.selectDroppingPoint(id),
                onMap: _openMap,
              );

              if (CustomerLayout.hasSideSummary(context)) {
                return _SideBySide(
                  boarding: list(_PointKind.boarding),
                  dropping: list(_PointKind.dropping),
                );
              }
              return _Tabs(
                tab: _tab,
                onTab: (tab) => setState(() => _tab = tab),
                child: list(_tab),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.onTab, required this.child});

  final _PointKind tab;
  final ValueChanged<_PointKind> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final gutter = AbraResponsive.gutter(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AbraSpacing.lg,
        gutter,
        AbraSpacing.lg,
      ),
      children: <Widget>[
        Semantics(
          label: l10n.text(CustomerStrings.pointsTabs),
          child: SegmentTabs<_PointKind>(
            segments: <(_PointKind, String)>[
              (
                _PointKind.boarding,
                l10n.text(CustomerStrings.pointsBoardingTab),
              ),
              (
                _PointKind.dropping,
                l10n.text(CustomerStrings.pointsDroppingTab),
              ),
            ],
            selected: tab,
            onChanged: onTab,
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        child,
      ],
    );
  }
}

class _SideBySide extends StatelessWidget {
  const _SideBySide({required this.boarding, required this.dropping});

  final Widget boarding;
  final Widget dropping;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final gutter = AbraResponsive.gutter(context);
    Widget column(String title, Widget list) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: textTheme.titleMedium),
          ),
          const SizedBox(height: AbraSpacing.md),
          list,
        ],
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AbraSizes.maxContentWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AbraSpacing.lg,
            gutter,
            AbraSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              column(
                l10n.text(CustomerStrings.pointsBoardingHeading),
                boarding,
              ),
              const SizedBox(width: AbraSpacing.xl),
              column(
                l10n.text(CustomerStrings.pointsDroppingHeading),
                dropping,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  const _PointList({
    required this.trip,
    required this.points,
    required this.selectedId,
    required this.onSelected,
    required this.onMap,
  });

  final TripDetail trip;
  final List<TripPoint> points;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<TripPoint> onMap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Column(
      children: <Widget>[
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.md),
            child: _PointCard(
              trip: trip,
              point: point,
              selected: point.id == selectedId,
              onSelected: () => onSelected(point.id),
              onMap: () => onMap(point),
            ),
          ),
      ],
    ),
  );
}

/// One point as a choice: time and name, address, landmark and a map link.
/// The selected point has a blue border and a check, not colour alone.
class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.trip,
    required this.point,
    required this.selected,
    required this.onSelected,
    required this.onMap,
  });

  final TripDetail trip;
  final TripPoint point;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final time = text.time(point.time, trip.timezone);
    const radius = AbraRadius.large;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$time ${point.name}',
      onTap: onSelected,
      child: Material(
        color: selected ? AbraColors.lightBlue : AbraColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AbraColors.blue : AbraColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AbraColors.blue : null,
                      border: Border.all(
                        color: selected
                            ? AbraColors.blue
                            : const Color(0xFF9FB3C3),
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
                ),
                const SizedBox(width: AbraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: time,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(text: '  '),
                            TextSpan(
                              text: point.name,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (point.address != null)
                        Text(point.address!, style: textTheme.bodySmall),
                      if (point.landmark != null)
                        Text(
                          l10n.text(
                            CustomerStrings.pointsLandmark,
                            <String, Object?>{'landmark': point.landmark},
                          ),
                          style: textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AbraSpacing.sm),
                Semantics(
                  label: l10n.text(
                    CustomerStrings.pointsMapSemantics,
                    <String, Object?>{'name': point.name},
                  ),
                  excludeSemantics: true,
                  button: true,
                  onTap: onMap,
                  child: TextButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.place_outlined, size: 16),
                    label: Text(l10n.text(CustomerStrings.pointsMap)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        AbraSizes.minTouchTarget,
                        AbraSizes.minTouchTarget,
                      ),
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

/// How long a message stays on screen: short, so it never keeps covering the
/// form (the prototype's toast also lasts two seconds).
const Duration _toastDuration = Duration(seconds: 2);
