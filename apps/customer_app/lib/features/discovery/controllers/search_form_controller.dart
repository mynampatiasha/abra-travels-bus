import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';

import '../../../app/providers.dart';
import '../models/discovery_models.dart';
import 'travel_dates.dart';

/// Why the search form cannot be submitted.
enum SearchFormProblem {
  originRequired,
  destinationRequired,
  sameCity,
  dateOutOfRange,
}

/// A route the customer searched before, kept on this device.
@immutable
class RecentSearch {
  const RecentSearch({required this.from, required this.to});

  final City from;
  final City to;

  bool isSameRoute(RecentSearch other) => other.from == from && other.to == to;
}

@immutable
class SearchFormState {
  const SearchFormState({
    required this.date,
    this.from,
    this.to,
    this.recent = const <RecentSearch>[],
    this.showProblems = false,
  });

  final City? from;
  final City? to;

  /// Travel date (date-only, India calendar).
  final DateTime date;
  final List<RecentSearch> recent;

  /// True once the customer tried to search, so problems are shown.
  final bool showProblems;

  SearchFormState copyWith({
    City? Function()? from,
    City? Function()? to,
    DateTime? date,
    List<RecentSearch>? recent,
    bool? showProblems,
  }) => SearchFormState(
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
    date: date ?? this.date,
    recent: recent ?? this.recent,
    showProblems: showProblems ?? this.showProblems,
  );
}

/// A search that is ready to run, with the names to show in its header.
@immutable
class SubmittedSearch {
  const SubmittedSearch({
    required this.from,
    required this.to,
    required this.date,
  });

  final City from;
  final City to;
  final DateTime date;

  TripSearchCriteria get criteria => TripSearchCriteria(
    fromCityId: from.id,
    toCityId: to.id,
    date: TravelDates.format(date),
  );
}

final searchFormControllerProvider =
    NotifierProvider<SearchFormController, SearchFormState>(
      SearchFormController.new,
    );

/// The search form on the home screen: origin, destination, travel date and
/// the routes searched recently. Validates before a search is run; the
/// backend validates again.
class SearchFormController extends Notifier<SearchFormState> {
  static const recentSearchesKey = 'abra.customer.recent_searches';
  static const maxRecentSearches = 5;

  PreferencesStore get _preferences =>
      ref.read(appDependenciesProvider).preferences;

  DateTime _now() => ref.read(discoveryClockProvider)();

  @override
  SearchFormState build() =>
      SearchFormState(date: TravelDates.today(_now()), recent: _readRecent());

  void setFrom(City city) => state = state.copyWith(from: () => city);

  void setTo(City city) => state = state.copyWith(to: () => city);

  void swap() {
    final from = state.from;
    state = state.copyWith(from: () => state.to, to: () => from);
  }

  void setDate(DateTime date) => state = state.copyWith(
    date: DateTime.utc(date.year, date.month, date.day),
  );

  void useRecent(RecentSearch search) =>
      state = state.copyWith(from: () => search.from, to: () => search.to);

  /// What stops the search, most important first. Empty when it can run.
  List<SearchFormProblem> get problems {
    final from = state.from;
    final to = state.to;
    return <SearchFormProblem>[
      if (from == null) SearchFormProblem.originRequired,
      if (to == null) SearchFormProblem.destinationRequired,
      if (from != null && to != null && from == to) SearchFormProblem.sameCity,
      if (!TravelDates.isSearchable(state.date, _now()))
        SearchFormProblem.dateOutOfRange,
    ];
  }

  /// The search to run, or null when the form is not valid (the problems
  /// are then shown). A valid search is remembered as a recent route.
  Future<SubmittedSearch?> submit() async {
    if (problems.isNotEmpty) {
      state = state.copyWith(showProblems: true);
      return null;
    }
    final search = SubmittedSearch(
      from: state.from!,
      to: state.to!,
      date: state.date,
    );
    await _remember(RecentSearch(from: search.from, to: search.to));
    return search;
  }

  Future<void> _remember(RecentSearch search) async {
    final recent = <RecentSearch>[
      search,
      ...state.recent.where((other) => !other.isSameRoute(search)),
    ].take(maxRecentSearches).toList();
    state = state.copyWith(recent: recent, showProblems: false);
    await _preferences.setString(
      recentSearchesKey,
      jsonEncode(<Object?>[
        for (final item in recent)
          <String, Object?>{'from': item.from.toJson(), 'to': item.to.toJson()},
      ]),
    );
  }

  /// Stored recent routes. Anything unreadable is ignored: it is only a
  /// convenience and must never stop the home screen from opening.
  List<RecentSearch> _readRecent() {
    final stored = _preferences.getString(recentSearchesKey);
    if (stored == null) return const <RecentSearch>[];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return const <RecentSearch>[];
      return <RecentSearch>[
        for (final item in decoded.whereType<Map<Object?, Object?>>())
          RecentSearch(
            from: City.fromJson(asJsonMap(item['from']! as Map)),
            to: City.fromJson(asJsonMap(item['to']! as Map)),
          ),
      ].take(maxRecentSearches).toList();
    } on Object {
      return const <RecentSearch>[];
    }
  }
}
