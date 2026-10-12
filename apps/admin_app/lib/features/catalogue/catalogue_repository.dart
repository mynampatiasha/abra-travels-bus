import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

/// One page of a catalogue list, as the backend returned it.
@immutable
class PageOf {
  const PageOf({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<JsonMap> items;
  final int page;
  final int pageSize;
  final int total;

  int get firstIndex => total == 0 ? 0 : (page - 1) * pageSize + 1;
  int get lastIndex => (page - 1) * pageSize + items.length;
  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;
}

/// A list request: which resource, which page, which filters. Value-equal,
/// so it can key a provider.
@immutable
class ResourceQuery {
  const ResourceQuery(
    this.path, {
    this.page = 1,
    this.pageSize = 20,
    this.filters = const <String, String>{},
  });

  /// Path below `/catalogue`, for example `cities`.
  final String path;
  final int page;
  final int pageSize;

  /// Query parameters the backend defines for this list. Empty values are
  /// not sent.
  final Map<String, String> filters;

  String get _signature =>
      '$path|$page|$pageSize|'
      '${(filters.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}=${e.value}').join('&')}';

  @override
  bool operator ==(Object other) =>
      other is ResourceQuery && other._signature == _signature;

  @override
  int get hashCode => _signature.hashCode;
}

final catalogueRepositoryProvider = Provider<CatalogueRepository>(
  (ref) => CatalogueRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// The catalogue management API (documentation/catalogue-management.md).
///
/// Every call carries the user's token; the backend decides by permission
/// and data scope what it returns and accepts. Nothing here filters by
/// operator: an operator's staff simply receive only their own records.
class CatalogueRepository {
  CatalogueRepository(this._client);

  final ApiClient _client;

  /// Catalogue paths are given below `/catalogue`; the onboarding and admin APIs are given in full.
  static String _fullPath(String path) =>
      path.startsWith('onboarding/') || path.startsWith('admin/')
      ? path
      : 'catalogue/$path';

  Future<PageOf> list(ResourceQuery query) async {
    final response = await _client.get(
      _fullPath(query.path),
      query: <String, Object?>{
        'page': query.page,
        'pageSize': query.pageSize,
        for (final entry in query.filters.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      },
    );
    final info = response.page;
    if (info == null) throw const AppException(ServerFailure());
    return PageOf(
      items: response.decodeList((json) => json),
      page: info.page,
      pageSize: info.pageSize,
      total: info.total,
    );
  }

  Future<JsonMap> get(String path) async =>
      (await _client.get(_fullPath(path))).decodeObject((json) => json);

  Future<JsonMap> post(String path, [JsonMap body = const {}]) async =>
      (await _client.post(
        _fullPath(path),
        body: body,
      )).decodeObject((json) => json);

  Future<JsonMap> put(String path, JsonMap body) async => (await _client.put(
    _fullPath(path),
    body: body,
  )).decodeObject((json) => json);

  Future<void> delete(String path) => _client.delete(_fullPath(path));
}

/// A page of a catalogue list.
final resourceListProvider = FutureProvider.autoDispose
    .family<PageOf, ResourceQuery>(
      (ref, query) => ref.watch(catalogueRepositoryProvider).list(query),
    );

/// The records offered in a selector (the first hundred the user may see,
/// by name). [path] may carry filters, for example `locations?active=true`.
final optionsProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, String>((ref, path) async {
      final uri = Uri.parse(path);
      final page = await ref
          .watch(catalogueRepositoryProvider)
          .list(
            ResourceQuery(
              uri.path,
              pageSize: 100,
              filters: uri.queryParameters,
            ),
          );
      return page.items;
    });
