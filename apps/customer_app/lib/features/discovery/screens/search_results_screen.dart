import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/async_value_view.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../controllers/travel_dates.dart';
import '../controllers/trip_search_controller.dart';
import '../models/discovery_models.dart';
import '../widgets/discovery_text.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/trip_card.dart';

/// What `/search/results` was opened with.
@immutable
class SearchResultsArguments {
  const SearchResultsArguments({
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.date,
  });

  /// Reads the location. Null when something is missing or malformed (an
  /// edited or outdated link).
  static SearchResultsArguments? tryParse(Uri location) {
    final query = location.queryParameters;
    final fromId = query['origin'];
    final toId = query['destination'];
    final date = TravelDates.tryParse(query['date']);
    final id = RegExp(r'^[0-9a-fA-F]{24}$');
    if (fromId == null ||
        toId == null ||
        date == null ||
        !id.hasMatch(fromId) ||
        !id.hasMatch(toId) ||
        fromId == toId) {
      return null;
    }
    return SearchResultsArguments(
      fromId: fromId,
      fromName: query['originName'] ?? '',
      toId: toId,
      toName: query['destinationName'] ?? '',
      date: date,
    );
  }

  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final DateTime date;

  TripSearchCriteria get criteria => TripSearchCriteria(
    fromCityId: fromId,
    toCityId: toId,
    date: TravelDates.format(date),
  );
}

/// The buses for a search, with day switching, filters and sorting.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({required this.arguments, super.key});

  final SearchResultsArguments? arguments;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  /// The day shown. Starts with the day of the link; changing it searches
  /// again without stacking a screen per day.
  late DateTime? _date = widget.arguments?.date;
  TripFilters _filters = TripFilters.none;
  TripSort _sort = TripSort.departureEarliest;

  Future<void> _openFilters(TripSearchCriteria criteria) async {
    final chosen = await showTripFilterSheet(
      context,
      criteria: criteria,
      current: _filters,
    );
    if (chosen != null && mounted) setState(() => _filters = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final arguments = widget.arguments;

    if (arguments == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.text(CustomerStrings.routeSearchResultsTitle)),
        ),
        body: AbraPageContainer(
          child: AbraStateView(
            kind: AbraStateKind.error,
            title: l10n.text(CustomerStrings.resultsInvalidTitle),
            message: l10n.text(CustomerStrings.resultsInvalidMessage),
            actionLabel: l10n.text(CustomerStrings.searchButton),
            onAction: () => context.go(AppRoutes.home),
          ),
        ),
      );
    }

    final date = _date ?? arguments.date;
    final criteria = TripSearchCriteria(
      fromCityId: arguments.fromId,
      toCityId: arguments.toId,
      date: TravelDates.format(date),
    );
    final request = TripSearchRequest(
      criteria: criteria,
      filters: _filters,
      sort: _sort,
    );
    final provider = tripSearchControllerProvider(request);
    final results = ref.watch(provider);
    final now = ref.read(discoveryClockProvider)();
    final previous = date.subtract(const Duration(days: 1));
    final next = date.add(const Duration(days: 1));
    final title = arguments.fromName.isEmpty || arguments.toName.isEmpty
        ? l10n.text(CustomerStrings.routeSearchResultsTitle)
        : text.route(arguments.fromName, arguments.toName);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: <Widget>[
          _DateBar(
            label: text.date(date),
            onPrevious: TravelDates.isSearchable(previous, now)
                ? () => setState(() => _date = previous)
                : null,
            onNext: TravelDates.isSearchable(next, now)
                ? () => setState(() => _date = next)
                : null,
          ),
          _ToolBar(
            count: results.value?.total,
            activeFilters: _filters.activeCount,
            sort: _sort,
            onFilter: () => _openFilters(criteria),
            onSort: (sort) => setState(() => _sort = sort),
          ),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<TripSearchState>(
              value: results,
              onRetry: () => ref.invalidate(provider),
              data: (context, state) => state.trips.isEmpty
                  ? AbraPageContainer(
                      child: AbraStateView(
                        kind: AbraStateKind.empty,
                        title: l10n.text(CustomerStrings.resultsEmptyTitle),
                        message: l10n.text(
                          _filters.isEmpty
                              ? CustomerStrings.resultsEmptyMessage
                              : CustomerStrings.resultsEmptyFilteredMessage,
                        ),
                        actionLabel: _filters.isEmpty
                            ? null
                            : l10n.text(CustomerStrings.resultsClearFilters),
                        onAction: _filters.isEmpty
                            ? null
                            : () => setState(() => _filters = TripFilters.none),
                      ),
                    )
                  : _TripList(
                      state: state,
                      onLoadMore: ref.read(provider.notifier).loadMore,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({required this.label, this.onPrevious, this.onNext});

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.sm),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.text(CustomerStrings.resultsPreviousDay),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.text(CustomerStrings.resultsNextDay),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({
    required this.count,
    required this.activeFilters,
    required this.sort,
    required this.onFilter,
    required this.onSort,
  });

  /// Null while the first page loads.
  final int? count;
  final int activeFilters;
  final TripSort sort;
  final VoidCallback onFilter;
  final ValueChanged<TripSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final filterLabel = l10n.text(CustomerStrings.resultsFilter);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AbraSpacing.lg,
        end: AbraSpacing.sm,
        bottom: AbraSpacing.xs,
      ),
      // Wraps when count, filter and sort do not fit on one line.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (count != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AbraSpacing.md),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.text(CustomerStrings.resultsCount, <String, Object?>{
                    'count': count,
                  }),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          TextButton.icon(
            icon: Badge(
              isLabelVisible: activeFilters > 0,
              label: Text(l10n.formatters.number(activeFilters)),
              child: const Icon(Icons.tune),
            ),
            label: Text(
              filterLabel,
              semanticsLabel: activeFilters == 0
                  ? filterLabel
                  : l10n.text(
                      CustomerStrings.resultsFilterActive,
                      <String, Object?>{'count': activeFilters},
                    ),
            ),
            onPressed: onFilter,
          ),
          PopupMenuButton<TripSort>(
            tooltip: l10n.text(CustomerStrings.resultsSort),
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (context) => <PopupMenuEntry<TripSort>>[
              for (final option in TripSort.values)
                CheckedPopupMenuItem<TripSort>(
                  value: option,
                  checked: option == sort,
                  child: Text(text.sort(option)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(AbraSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.sort, color: AbraColors.blueDark),
                  const SizedBox(width: AbraSpacing.xs),
                  Text(
                    l10n.text(CustomerStrings.resultsSort),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AbraColors.blueDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.state, required this.onLoadMore});

  final TripSearchState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final gutter = AbraResponsive.gutter(context);
    final hasFooter = state.hasMore || state.loadMoreFailure != null;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AbraSizes.maxFormWidth * 1.5,
        ),
        child: ListView.separated(
          padding: EdgeInsets.all(gutter),
          itemCount: state.trips.length + (hasFooter ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AbraSpacing.md),
          itemBuilder: (context, index) {
            if (index < state.trips.length) {
              final trip = state.trips[index];
              return TripCard(
                trip: trip,
                onTap: () => context.push(AppRoutes.trip(trip.id)),
              );
            }
            return Column(
              children: <Widget>[
                if (state.loadMoreFailure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.text(CustomerStrings.resultsLoadMoreFailed),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                AbraButton(
                  label: l10n.text(
                    state.loadMoreFailure != null
                        ? AbraStrings.commonRetry
                        : CustomerStrings.resultsLoadMore,
                  ),
                  variant: AbraButtonVariant.secondary,
                  isLoading: state.isLoadingMore,
                  onPressed: onLoadMore,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
