import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_core/shared_core.dart';

import '../../../core/async_value_view.dart';
import '../models/discovery_models.dart';
import '../repositories/discovery_repository.dart';

/// Cities matching what the customer typed (popular cities for an empty
/// query). Kept only while the picker is open.
final citySuggestionsProvider = FutureProvider.autoDispose
    .family<List<City>, String>(
      (ref, query) => ref.watch(discoveryRepositoryProvider).cities(query),
    );

/// What a search can be filtered by.
final searchFilterOptionsProvider = FutureProvider.autoDispose
    .family<SearchFilterOptions, TripSearchCriteria>(
      (ref, criteria) =>
          ref.watch(discoveryRepositoryProvider).filterOptions(criteria),
    );

/// One trip. Always loaded from the backend when the screen opens, so a
/// trip that sold out or was cancelled since the search is shown as it is
/// now.
final tripDetailProvider = FutureProvider.autoDispose
    .family<TripDetail, String>(
      (ref, tripId) => ref.watch(discoveryRepositoryProvider).trip(tripId),
    );

/// The results of one search: the pages loaded so far.
@immutable
class TripSearchState {
  const TripSearchState({
    required this.trips,
    required this.total,
    required this.pagesLoaded,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<TripSummary> trips;

  /// Trips matching the search on the backend, over all pages.
  final int total;
  final int pagesLoaded;
  final bool isLoadingMore;

  /// Why the next page could not be loaded. The pages already shown stay.
  final AppFailure? loadMoreFailure;

  bool get hasMore => trips.length < total;

  TripSearchState copyWith({
    List<TripSummary>? trips,
    int? total,
    int? pagesLoaded,
    bool? isLoadingMore,
    AppFailure? Function()? loadMoreFailure,
  }) => TripSearchState(
    trips: trips ?? this.trips,
    total: total ?? this.total,
    pagesLoaded: pagesLoaded ?? this.pagesLoaded,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure == null
        ? this.loadMoreFailure
        : loadMoreFailure(),
  );
}

final tripSearchControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TripSearchController, TripSearchState, TripSearchRequest>(
      TripSearchController.new,
    );

/// Runs a search and loads further pages. Filtering and sorting happen on
/// the backend: a changed filter or order is a new request, never a
/// rearrangement of what is on screen, so availability is never stale by
/// construction. Results are not kept after the screen closes.
class TripSearchController extends AsyncNotifier<TripSearchState> {
  TripSearchController(this.request);

  final TripSearchRequest request;

  @override
  Future<TripSearchState> build() async {
    final page = await ref
        .watch(discoveryRepositoryProvider)
        .searchTrips(request);
    return TripSearchState(
      trips: page.trips,
      total: page.total,
      pagesLoaded: 1,
    );
  }

  /// Loads the next page, once: further calls while it loads do nothing.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: () => null),
    );
    try {
      final page = await ref
          .read(discoveryRepositoryProvider)
          .searchTrips(request, page: current.pagesLoaded + 1);
      if (!ref.mounted) return;
      final known = current.trips.map((trip) => trip.id).toSet();
      state = AsyncData(
        current.copyWith(
          // Inventory can change between pages; never show a trip twice.
          trips: <TripSummary>[
            ...current.trips,
            ...page.trips.where((trip) => !known.contains(trip.id)),
          ],
          total: page.total,
          pagesLoaded: current.pagesLoaded + 1,
          isLoadingMore: false,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          loadMoreFailure: () => failureOf(error),
        ),
      );
    }
  }
}
