import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/format/rupees.dart';
import '../../core/ui/chips.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/state_views.dart';
import '../../core/ui/sticky_action_bar.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../authentication/gate/require_sign_in.dart';
import '../authentication/gate/sign_in_intent.dart';
import '../discovery/controllers/trip_search_controller.dart';
import '../discovery/controllers/trip_selection_controller.dart';
import '../discovery/models/discovery_models.dart';
import '../discovery/widgets/discovery_text.dart';
import 'controllers/seat_selection_controller.dart';
import 'controllers/seat_selection_rules.dart';
import 'models/seat_models.dart';
import 'widgets/seat_grid.dart';
import 'widgets/seat_legend.dart';
import 'widgets/trip_summary_card.dart';

/// Seat selection. Open to guests: they can look at every seat and choose
/// some. Signing in is asked for only on "Continue", and the customer comes
/// back to this screen with the seats still chosen.
class SeatSelectionScreen extends ConsumerStatefulWidget {
  const SeatSelectionScreen({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<SeatSelectionScreen> createState() =>
      _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends ConsumerState<SeatSelectionScreen> {
  SeatDeck _deck = SeatDeck.lower;

  String get _tripId => widget.tripId;

  void _onSeatTap(Seat seat) {
    final outcome = toggleSeat(ref, _tripId, seat);
    if (outcome == SeatToggleOutcome.limitReached) {
      _toast(
        AbraLocalizations.of(context).text(
          CustomerStrings.seatLimitReached,
          <String, Object?>{'max': SeatSelectionRules.maxSeats},
        ),
      );
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(duration: _toastDuration, content: Text(message)));

  Future<void> _continue(List<Seat> chosen) async {
    if (chosen.isEmpty) return;
    final wasSignedIn = ref.read(authStateProvider) is AuthSignedIn;
    final selection = ref.read(tripSelectionProvider(_tripId));
    final signedIn = await requireSignIn(
      context,
      SignInIntent(
        returnLocation: AppRoutes.tripSeats(_tripId),
        kind: SignInIntentKind.selectSeats,
        selection: <String, Object?>{'tripId': _tripId, ...selection.toJson()},
      ),
    );
    if (!mounted || !signedIn) return;
    if (wasSignedIn) {
      ScaffoldMessenger.of(context).clearSnackBars();
      await context.push(AppRoutes.tripPoints(_tripId));
    } else {
      // Back on this screen with the same seats: the customer taps
      // "Continue" again.
      _toast(
        AbraLocalizations.of(context).text(CustomerStrings.seatLoggedInKept),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.trip(_tripId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final tripValue = ref.watch(tripDetailProvider(_tripId));
    final mapValue = ref.watch(seatMapProvider(_tripId));
    final chosenIds = ref.watch(
      tripSelectionProvider(_tripId).select((s) => s.seatIds),
    );
    final trip = tripValue.value;
    final map = mapValue.value;
    final chosen = map == null
        ? const <Seat>[]
        : SeatSelectionRules.chosenSeats(map, chosenIds);
    final total = formatRupees(
      l10n,
      SeatSelectionRules.totalPaise(chosen),
      currencyCode: trip?.currency ?? 'INR',
    );
    final summary = chosen.isEmpty
        ? l10n.text(CustomerStrings.seatNoneSelected)
        : l10n.text(CustomerStrings.seatSelectedSummary, <String, Object?>{
            'count': chosen.length,
            'seats': chosen.map((s) => s.id).join(', '),
          });
    // A short screen (a phone on its side) keeps the bar at the bottom, so
    // "Continue" is always in reach.
    final sideSummary =
        CustomerLayout.hasSideSummary(context) &&
        !CustomerLayout.isShort(context);
    final canContinue = chosen.isNotEmpty;

    if (trip != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => applyTripDefaults(ref, trip),
      );
    }

    final body = AsyncValueView<TripDetail>(
      value: tripValue,
      onRetry: () => ref.invalidate(tripDetailProvider(_tripId)),
      data: (context, trip) => trip.isSoldOut
          ? MessageStateView(
              icon: Icons.event_seat_outlined,
              title: l10n.text(CustomerStrings.seatSoldOutTitle),
              message: l10n.text(CustomerStrings.seatSoldOutMessage),
            )
          : _SeatBody(
              trip: trip,
              mapValue: mapValue,
              chosen: chosen,
              chosenIds: chosenIds,
              deck: _deck,
              onDeck: (deck) => setState(() => _deck = deck),
              onSeatTap: _onSeatTap,
              onRetry: () => ref.invalidate(seatMapProvider(_tripId)),
              sideSummary: sideSummary
                  ? _SummaryCard(
                      summary: summary,
                      total: total,
                      onContinue: canContinue ? () => _continue(chosen) : null,
                    )
                  : null,
            ),
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (canContinue) _continue(chosen);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: GradientAppBar(
            title: l10n.text(CustomerStrings.seatSelectTitle),
            subtitle: trip == null
                ? null
                : text.route(trip.origin.name, trip.destination.name),
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: l10n.text(CustomerStrings.seatClose),
              onPressed: _close,
            ),
          ),
          bottomNavigationBar: sideSummary || trip == null || trip.isSoldOut
              ? null
              : StickyActionBar(
                  title: total,
                  subtitle: summary,
                  captionFirst: true,
                  actionLabel: l10n.text(CustomerStrings.seatContinue),
                  onAction: canContinue ? () => _continue(chosen) : null,
                ),
          body: body,
        ),
      ),
    );
  }
}

/// The scrolling content: trip card, deck tabs, legend and the seat map,
/// with the summary card beside it on wider screens.
class _SeatBody extends StatelessWidget {
  const _SeatBody({
    required this.trip,
    required this.mapValue,
    required this.chosen,
    required this.chosenIds,
    required this.deck,
    required this.onDeck,
    required this.onSeatTap,
    required this.onRetry,
    required this.sideSummary,
  });

  final TripDetail trip;
  final AsyncValue<SeatMap> mapValue;
  final List<Seat> chosen;
  final List<String> chosenIds;
  final SeatDeck deck;
  final ValueChanged<SeatDeck> onDeck;
  final ValueChanged<Seat> onSeatTap;
  final VoidCallback onRetry;
  final Widget? sideSummary;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final map = mapValue.value;
    final isSleeper = map == null
        ? SeatLayoutKind.fromBerthType(trip.bus.berthType) ==
              SeatLayoutKind.sleeper
        : map.hasDecks;

    final content = <Widget>[
      TripSummaryCard(trip: trip),
      if (isSleeper) _DeckTabs(deck: deck, onChanged: onDeck),
      AbraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SeatLegend(),
            const SizedBox(height: AbraSpacing.sm),
            Text(
              l10n.text(CustomerStrings.seatChosenCount, <String, Object?>{
                'max': SeatSelectionRules.maxSeats,
                'count': chosen.length,
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      AbraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _DeckHeader(showDeck: isSleeper, deck: deck),
            const SizedBox(height: AbraSpacing.sm),
            if (mapValue.isLoading && map == null)
              SeatGridSkeleton(berths: isSleeper)
            else
              AsyncValueView<SeatMap>(
                value: mapValue,
                onRetry: onRetry,
                data: (context, map) => SeatGrid(
                  map: map,
                  deck: map.hasDecks ? deck : SeatDeck.lower,
                  chosenIds: chosenIds,
                  currencyCode: trip.currency,
                  onSeatTap: onSeatTap,
                ),
              ),
          ],
        ),
      ),
    ];

    final gutter = AbraResponsive.gutter(context);
    final list = ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: sideSummary == null ? gutter : 0,
        vertical: AbraSpacing.lg,
      ),
      itemCount: content.length,
      separatorBuilder: (_, _) => const SizedBox(height: AbraSpacing.md),
      itemBuilder: (_, index) => content[index],
    );

    if (sideSummary == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: CustomerLayout.listMaxWidth,
          ),
          child: list,
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AbraSizes.maxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: list),
              const SizedBox(width: AbraSpacing.xl),
              SizedBox(
                width: _summaryWidth(context),
                // Scrolls on its own when the screen is short (a landscape
                // phone with large text).
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: AbraSpacing.lg),
                  child: sideSummary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The summary column: a third of the width, between 240 and 320, so that
/// the seat map keeps enough room next to it on a small tablet.
double _summaryWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * 0.3).clamp(240.0, 320.0);

/// "Lower deck" / "Upper deck", as a two-part switch.
class _DeckTabs extends StatelessWidget {
  const _DeckTabs({required this.deck, required this.onChanged});

  final SeatDeck deck;
  final ValueChanged<SeatDeck> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return SegmentTabs<SeatDeck>(
      segments: <(SeatDeck, String)>[
        (SeatDeck.lower, l10n.text(CustomerStrings.seatDeckLower)),
        (SeatDeck.upper, l10n.text(CustomerStrings.seatDeckUpper)),
      ],
      selected: deck,
      onChanged: onChanged,
    );
  }
}

/// The line above the seats: which deck, and where the front of the bus is.
class _DeckHeader extends StatelessWidget {
  const _DeckHeader({required this.showDeck, required this.deck});

  final bool showDeck;
  final SeatDeck deck;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            showDeck
                ? l10n.text(
                    deck == SeatDeck.lower
                        ? CustomerStrings.seatDeckLower
                        : CustomerStrings.seatDeckUpper,
                  )
                : '',
            style: style,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.text(CustomerStrings.seatFront), style: style),
            const SizedBox(width: AbraSpacing.xs),
            const Icon(
              Icons.directions_bus_rounded,
              size: AbraSizes.icon,
              color: AbraColors.textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

/// The summary and price beside the seat map on wider screens: what is
/// chosen and the amount on the left, "Continue" on the right.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.total,
    required this.onContinue,
  });

  final String summary;
  final String total;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
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
              Text(summary, style: textTheme.bodySmall),
              Text(total, style: textTheme.titleLarge),
            ],
          ),
          AbraButton(
            label: l10n.text(CustomerStrings.seatContinue),
            variant: AbraButtonVariant.callToAction,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

/// How long a message stays on screen: short, so it never keeps covering the
/// form (the prototype's toast also lasts two seconds).
const Duration _toastDuration = Duration(seconds: 2);
