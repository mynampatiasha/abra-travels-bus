import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';

import '../../../app/providers.dart';
import '../models/discovery_models.dart';

/// Number of trips requested per page of results.
const tripPageSize = 20;

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// The public discovery endpoints of the backend (documentation/
/// discovery.md). They need no sign-in, so no token is sent: a guest and a
/// signed-in customer see exactly the same. Every method throws
/// `AppException` on failure.
class DiscoveryRepository {
  DiscoveryRepository(this._client);

  final ApiClient _client;

  /// Cities whose name starts with [query], or the popular cities when
  /// [query] is empty.
  Future<List<City>> cities(String query) async {
    final trimmed = query.trim();
    final response = await _client.get(
      'cities',
      query: <String, Object?>{if (trimmed.isNotEmpty) 'query': trimmed},
      authenticated: false,
    );
    return response.decodeList(City.fromJson);
  }

  Future<TripPage> searchTrips(
    TripSearchRequest request, {
    int page = 1,
  }) async {
    final filters = request.filters;
    final response = await _client.get(
      'trips/search',
      query: <String, Object?>{
        ..._criteria(request.criteria),
        'sort': request.sort.wireValue,
        'page': page,
        'pageSize': tripPageSize,
        if (filters.departureWindows.isNotEmpty)
          'departureWindows': _list(filters.departureWindows),
        if (filters.busTypes.isNotEmpty) 'busTypes': _list(filters.busTypes),
        if (filters.operatorIds.isNotEmpty)
          'operatorIds': _list(filters.operatorIds),
        if (filters.amenities.isNotEmpty) 'amenities': _list(filters.amenities),
        if (filters.isAc != null) 'ac': filters.isAc.toString(),
        if (filters.maxFarePaise != null) 'maxFare': filters.maxFarePaise,
      },
      authenticated: false,
    );
    final info = response.page;
    if (info == null) {
      // The contract says search is paginated; anything else is a fault.
      throw const AppException(ServerFailure());
    }
    return TripPage(
      trips: response.decodeList(TripSummary.fromJson),
      page: info.page,
      total: info.total,
    );
  }

  /// What the unfiltered search for [criteria] can be filtered by.
  Future<SearchFilterOptions> filterOptions(TripSearchCriteria criteria) async {
    final response = await _client.get(
      'trips/search/filters',
      query: _criteria(criteria),
      authenticated: false,
    );
    return response.decodeObject(SearchFilterOptions.fromJson);
  }

  Future<TripDetail> trip(String tripId) async {
    final response = await _client.get(
      'trips/${Uri.encodeComponent(tripId)}',
      authenticated: false,
    );
    return response.decodeObject(TripDetail.fromJson);
  }

  Map<String, Object?> _criteria(TripSearchCriteria criteria) =>
      <String, Object?>{
        'from': criteria.fromCityId,
        'to': criteria.toCityId,
        'date': criteria.date,
      };

  String _list(Set<String> values) => (values.toList()..sort()).join(',');
}
