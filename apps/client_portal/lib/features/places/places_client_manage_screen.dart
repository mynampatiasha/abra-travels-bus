import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';

// The client portal Places page (demo page `places`): Abra keeps one list of
// boarding and dropping points; an operator asks Abra to add one it needs
// (`client/place-requests`), follows its requests, and sees the places it can
// use (`catalogue/locations`, the shared ones and its own).

// ===== 1. MODELS =====

/// One page of a list, as the server sent it.
class PlacesPage {
  const PlacesPage(this.items, this.page, this.total, this.pageSize);

  final List<JsonMap> items;
  final int page;
  final int total;
  final int pageSize;

  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;
}

/// Which list, which page, which filters. Value-equal, so it keys a provider.
@immutable
class PlacesQuery {
  const PlacesQuery(this.path, {this.page = 1, this.filters = const {}});

  final String path;
  final int page;
  final Map<String, String> filters;

  String get _key =>
      '$path|$page|${(filters.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}=${e.value}').join('&')}';

  @override
  bool operator ==(Object other) => other is PlacesQuery && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

const requestStatusLabels = <String, String>{
  'PENDING': 'Pending',
  'APPROVED': 'Approved',
  'REJECTED': 'Rejected',
};

AbraStatusTone requestTone(Object? status) => switch (status) {
  'APPROVED' => AbraStatusTone.success,
  'REJECTED' => AbraStatusTone.danger,
  _ => AbraStatusTone.warning,
};

const placeUseLabels = <String, String>{
  'BOARDING': 'Boarding',
  'DROPPING': 'Dropping',
  'BOTH': 'Both',
};

/// "just now", "5 min ago", "3 h ago", "2 days ago".
String timeAgo(Object? iso, {DateTime? now}) {
  final at = DateTime.tryParse('${iso ?? ''}');
  if (at == null) return '';
  final minutes = (now ?? DateTime.now()).difference(at).inMinutes;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '$minutes min ago';
  if (minutes < 24 * 60) return '${minutes ~/ 60} h ago';
  return '${minutes ~/ (24 * 60)} days ago';
}

// ===== 2. STATE AND API =====

const _requestsPath = 'client/place-requests';
const _placesPath = 'catalogue/locations';
const _pageSize = 20;

final placesListProvider = FutureProvider.autoDispose
    .family<PlacesPage, PlacesQuery>((ref, query) async {
      final response = await ref
          .watch(appDependenciesProvider)
          .apiClient
          .get(
            query.path,
            query: <String, Object?>{
              'page': query.page,
              'pageSize': _pageSize,
              for (final entry in query.filters.entries)
                if (entry.value.isNotEmpty) entry.key: entry.value,
            },
          );
      final info = response.page;
      return PlacesPage(
        response.decodeList((json) => json),
        info?.page ?? query.page,
        info?.total ?? 0,
        info?.pageSize ?? _pageSize,
      );
    });

/// The active cities, for the City field and filter, and to name a place's city.
final placeCitiesProvider = FutureProvider.autoDispose<List<JsonMap>>(
  (ref) async =>
      (await ref
              .watch(appDependenciesProvider)
              .apiClient
              .get('$_requestsPath/cities'))
          .decodeList((json) => json),
);

// ===== 3. WIDGETS =====

/// A white card with a title and something on the right of it.
class PlacesCard extends StatelessWidget {
  const PlacesCard({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => AbraCard(
    child: Padding(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.sm,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: AbraSpacing.sm,
                runSpacing: AbraSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          child,
        ],
      ),
    ),
  );
}

/// Table or list: two views of the same rows (the demo's toggle).
class ViewToggle extends StatelessWidget {
  const ViewToggle({required this.asTable, required this.onChanged, super.key});

  final bool asTable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: const <ButtonSegment<bool>>[
      ButtonSegment<bool>(
        value: true,
        icon: Icon(Icons.table_rows_outlined, size: 18),
        tooltip: 'Table',
      ),
      ButtonSegment<bool>(
        value: false,
        icon: Icon(Icons.view_agenda_outlined, size: 18),
        tooltip: 'List',
      ),
    ],
    selected: <bool>{asTable},
    onSelectionChanged: (value) => onChanged(value.first),
  );
}

/// One column of a [PlacesTable].
class PlacesColumn {
  const PlacesColumn(this.label, this.cell);

  final String label;
  final Widget Function(JsonMap row) cell;
}

/// The rows of a list as a table (wide screens) or as cards (phones, or when
/// the person chose List). Tapping a row opens it.
class PlacesTable extends StatelessWidget {
  const PlacesTable({
    required this.columns,
    required this.rows,
    required this.asTable,
    this.onOpen,
    super.key,
  });

  final List<PlacesColumn> columns;
  final List<JsonMap> rows;
  final bool asTable;
  final void Function(JsonMap row)? onOpen;

  @override
  Widget build(BuildContext context) {
    final isPhone = AbraBreakpoint.of(context) == AbraBreakpoint.phone;
    if (!asTable || isPhone) {
      return Column(
        children: <Widget>[
          for (final row in rows)
            InkWell(
              onTap: onOpen == null ? null : () => onOpen!(row),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AbraSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AbraColors.divider)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    columns.first.cell(row),
                    const SizedBox(height: AbraSpacing.xs),
                    Wrap(
                      spacing: AbraSpacing.lg,
                      runSpacing: AbraSpacing.xs,
                      children: <Widget>[
                        for (final column in columns.skip(1))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${column.label}: ',
                                style: const TextStyle(
                                  color: AbraColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              column.cell(row),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: const WidgetStatePropertyAll<Color>(
              AbraColors.navy,
            ),
            headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AbraColors.white,
              fontWeight: FontWeight.w700,
            ),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            columns: <DataColumn>[
              for (final column in columns)
                DataColumn(label: Text(column.label)),
            ],
            rows: <DataRow>[
              for (final row in rows)
                DataRow(
                  onSelectChanged: onOpen == null ? null : (_) => onOpen!(row),
                  cells: <DataCell>[
                    for (final column in columns) DataCell(column.cell(row)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A name with a smaller grey line under it.
Widget twoLines(Object? title, Object? subtitle) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    Text('${title ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
    if ('${subtitle ?? ''}'.isNotEmpty)
      Text(
        '$subtitle',
        style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
      ),
  ],
);

/// Previous and next page, with "1-20 of 45".
class PlacesPager extends StatelessWidget {
  const PlacesPager({required this.page, required this.onPage, super.key});

  final PlacesPage page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (page.total <= page.pageSize) return const SizedBox.shrink();
    final first = (page.page - 1) * page.pageSize + 1;
    final last = first + page.items.length - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text('$first-$last of ${page.total}'),
        IconButton(
          tooltip: 'Previous page',
          icon: const Icon(Icons.chevron_left),
          onPressed: page.hasPrevious ? () => onPage(page.page - 1) : null,
        ),
        IconButton(
          tooltip: 'Next page',
          icon: const Icon(Icons.chevron_right),
          onPressed: page.hasNext ? () => onPage(page.page + 1) : null,
        ),
      ],
    );
  }
}

/// Loading, failure, empty or the rows of one list.
class PlacesListBody extends ConsumerWidget {
  const PlacesListBody({
    required this.query,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.builder,
    required this.onPage,
    super.key,
  });

  final PlacesQuery query;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(List<JsonMap> rows) builder;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncValueView<PlacesPage>(
        value: ref.watch(placesListProvider(query)),
        onRetry: () => ref.invalidate(placesListProvider(query)),
        data: (context, page) => page.items.isEmpty
            ? AbraStateView(
                kind: AbraStateKind.empty,
                title: query.filters.isEmpty ? emptyTitle : 'Nothing matches',
                message: query.filters.isEmpty
                    ? emptyMessage
                    : 'Try another search or city.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  builder(page.items),
                  PlacesPager(page: page, onPage: onPage),
                ],
              ),
      );
}

/// The read-only window of a request or a place.
Future<void> showPlaceDetail(
  BuildContext context,
  String title,
  List<(String, String)> lines,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (label, value) in lines)
            if (value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '$label\n',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AbraColors.textSecondary,
                        ),
                      ),
                      TextSpan(text: value),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);

/// "Request a place": City, Place name, Address, Landmark. Returns true when
/// the request was sent.
class RequestPlaceDialog extends ConsumerStatefulWidget {
  const RequestPlaceDialog({super.key});

  @override
  ConsumerState<RequestPlaceDialog> createState() => _RequestPlaceDialogState();
}

class _RequestPlaceDialogState extends ConsumerState<RequestPlaceDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  String? _cityId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(appDependenciesProvider)
          .apiClient
          .post(
            _requestsPath,
            body: <String, Object?>{
              'cityId': _cityId,
              'name': _name.text.trim(),
              'address': _address.text.trim(),
              if (_landmark.text.trim().isNotEmpty)
                'landmark': _landmark.text.trim(),
            },
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureText(AbraLocalizations.of(context), error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(placeCitiesProvider);
    final isPhone = AbraBreakpoint.of(context) == AbraBreakpoint.phone;
    final cityItems = cities.value ?? const <JsonMap>[];
    _cityId ??= cityItems.firstOrNull?['id'] as String?;
    String? required(String? value, String label) =>
        (value ?? '').trim().length < 2 ? '$label is required' : null;

    final name = TextFormField(
      controller: _name,
      decoration: const InputDecoration(
        labelText: 'Place name *',
        hintText: 'Miyapur Metro Pickup',
      ),
      validator: (value) => required(value, 'Place name'),
    );
    final city = DropdownButtonFormField<String>(
      initialValue: _cityId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'City'),
      items: <DropdownMenuItem<String>>[
        for (final city in cityItems)
          DropdownMenuItem<String>(
            value: city['id'] as String?,
            child: Text('${city['name']}'),
          ),
      ],
      validator: (value) => value == null ? 'Choose a city' : null,
      onChanged: (value) => setState(() => _cityId = value),
    );

    return AlertDialog(
      title: const Text('Request a place'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (isPhone) ...<Widget>[
                  city,
                  const SizedBox(height: AbraSpacing.md),
                  name,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: city),
                      const SizedBox(width: AbraSpacing.md),
                      Expanded(child: name),
                    ],
                  ),
                const SizedBox(height: AbraSpacing.md),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Address *'),
                  validator: (value) => required(value, 'Address'),
                ),
                const SizedBox(height: AbraSpacing.md),
                TextFormField(
                  controller: _landmark,
                  decoration: const InputDecoration(labelText: 'Landmark'),
                ),
                const SizedBox(height: AbraSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AbraSpacing.md),
                  decoration: const BoxDecoration(
                    color: AbraColors.lightBlue,
                    borderRadius: AbraRadius.medium,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AbraColors.blueDark,
                      ),
                      SizedBox(width: AbraSpacing.sm),
                      Expanded(
                        child: Text(
                          'Abra checks it is not too close to an existing '
                          'point, then adds it for every operator.',
                          style: TextStyle(color: AbraColors.blueDark),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AbraSpacing.md),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AbraColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AbraButton(
          label: 'Send request',
          isLoading: _busy,
          onPressed: _busy || cities.value == null ? null : _send,
        ),
      ],
    );
  }
}

// ===== 4. THE SCREEN =====

/// Places: "Request a place", "Your requests" and "Places you can use".
class PlacesClientManageScreen extends ConsumerStatefulWidget {
  const PlacesClientManageScreen({super.key});

  @override
  ConsumerState<PlacesClientManageScreen> createState() =>
      _PlacesClientManageScreenState();
}

class _PlacesClientManageScreenState
    extends ConsumerState<PlacesClientManageScreen> {
  int _requestsPage = 1;
  int _placesPage = 1;
  bool _requestsAsTable = true;
  bool _placesAsTable = true;
  String _search = '';
  String? _cityId;
  Timer? _searchPause;

  @override
  void dispose() {
    _searchPause?.cancel();
    super.dispose();
  }

  PlacesQuery get _requestsQuery =>
      PlacesQuery(_requestsPath, page: _requestsPage);

  PlacesQuery get _placesQuery => PlacesQuery(
    _placesPath,
    page: _placesPage,
    filters: <String, String>{
      'active': 'true',
      if (_search.isNotEmpty) 'query': _search,
      if (_cityId != null) 'cityId': _cityId!,
    },
  );

  Future<void> _request() async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RequestPlaceDialog(),
    );
    if (sent != true || !mounted) return;
    setState(() => _requestsPage = 1);
    ref.invalidate(placesListProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Sent to Abra')));
  }

  Future<void> _export() async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(appDependenciesProvider)
          .apiClient
          .getBytes('$_requestsPath/export?format=csv');
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      downloadTextFile('place-requests-$stamp.csv', utf8.decode(bytes));
      messenger.showSnackBar(
        const SnackBar(content: Text('The file is ready.')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final access = ref.watch(accessProvider);
    final canRequest = access.can(PermissionKeys.routesCreate);
    final cities = ref.watch(placeCitiesProvider).value ?? const <JsonMap>[];
    final cityNames = <String, String>{
      for (final city in cities) '${city['id']}': '${city['name']}',
    };
    final isPhone = AbraBreakpoint.of(context) == AbraBreakpoint.phone;

    return ListView(
      padding: EdgeInsets.all(isPhone ? AbraSpacing.md : AbraSpacing.xl),
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AbraSpacing.md,
          runSpacing: AbraSpacing.md,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Network / Places',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                  Text('Places', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AbraSpacing.xs),
                  Text(
                    'Abra keeps one list of boarding and dropping points. '
                    'Ask Abra to add a place you need.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (canRequest)
              AbraButton(
                label: 'Request a place',
                icon: Icons.add,
                onPressed: _request,
              ),
          ],
        ),
        const SizedBox(height: AbraSpacing.lg),
        PlacesCard(
          title: 'Your requests',
          actions: <Widget>[
            AbraButton(
              label: 'Export CSV',
              icon: Icons.file_download_outlined,
              variant: AbraButtonVariant.secondary,
              onPressed: _export,
            ),
            ViewToggle(
              asTable: _requestsAsTable,
              onChanged: (value) => setState(() => _requestsAsTable = value),
            ),
          ],
          child: PlacesListBody(
            query: _requestsQuery,
            emptyTitle: 'No requests',
            emptyMessage:
                'Requests you send to Abra appear here with their status.',
            onPage: (page) => setState(() => _requestsPage = page),
            builder: (rows) => PlacesTable(
              asTable: _requestsAsTable,
              rows: rows,
              onOpen: (row) => showPlaceDetail(context, '${row['name']}', [
                ('City', '${row['cityName'] ?? ''}'),
                ('Place', '${row['name'] ?? ''}'),
                ('Address', '${row['address'] ?? ''}'),
                ('Landmark', '${row['landmark'] ?? ''}'),
                ('Requested', timeAgo(row['requestedAt'])),
                ('Status', requestStatusLabels['${row['status']}'] ?? ''),
                ('Reason', '${row['reason'] ?? ''}'),
              ]),
              columns: <PlacesColumn>[
                PlacesColumn(
                  'Place',
                  (row) => twoLines(row['name'], row['address']),
                ),
                PlacesColumn('City', (row) => Text('${row['cityName'] ?? ''}')),
                PlacesColumn(
                  'Requested',
                  (row) => Text(timeAgo(row['requestedAt'])),
                ),
                PlacesColumn(
                  'Status',
                  (row) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AbraStatusBadge(
                        label:
                            requestStatusLabels['${row['status']}'] ??
                            '${row['status']}',
                        tone: requestTone(row['status']),
                      ),
                      if (row['reason'] != null)
                        Text(
                          '${row['reason']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AbraColors.danger,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AbraSpacing.lg),
        PlacesCard(
          title: 'Places you can use',
          actions: <Widget>[
            SizedBox(
              width: isPhone ? double.infinity : 220,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (text) {
                  _searchPause?.cancel();
                  _searchPause = Timer(
                    const Duration(milliseconds: 350),
                    () => mounted
                        ? setState(() {
                            _search = text.trim();
                            _placesPage = 1;
                          })
                        : null,
                  );
                },
              ),
            ),
            SizedBox(
              width: isPhone ? double.infinity : 200,
              child: DropdownButtonFormField<String>(
                initialValue: _cityId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'City',
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(value: '', child: Text('All')),
                  for (final city in cities)
                    DropdownMenuItem<String>(
                      value: '${city['id']}',
                      child: Text('${city['name']}'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _cityId = (value ?? '').isEmpty ? null : value;
                  _placesPage = 1;
                }),
              ),
            ),
            ViewToggle(
              asTable: _placesAsTable,
              onChanged: (value) => setState(() => _placesAsTable = value),
            ),
          ],
          child: PlacesListBody(
            query: _placesQuery,
            emptyTitle: 'No places yet',
            emptyMessage: 'Ask Abra to add the places you need.',
            onPage: (page) => setState(() => _placesPage = page),
            builder: (rows) => PlacesTable(
              asTable: _placesAsTable,
              rows: rows,
              onOpen: (row) => showPlaceDetail(context, '${row['name']}', [
                ('City', cityNames['${row['cityId']}'] ?? ''),
                ('Address', '${row['address'] ?? ''}'),
                ('Landmark', '${row['landmark'] ?? ''}'),
                ('Used for', placeUseLabels['${row['usedFor']}'] ?? ''),
                ('Instructions', '${row['instructions'] ?? ''}'),
              ]),
              columns: <PlacesColumn>[
                PlacesColumn('Place', (row) => Text('${row['name'] ?? ''}')),
                PlacesColumn(
                  'City',
                  (row) => Text(cityNames['${row['cityId']}'] ?? '—'),
                ),
                PlacesColumn(
                  'Used for',
                  (row) => AbraStatusBadge(
                    label:
                        placeUseLabels['${row['usedFor']}'] ??
                        '${row['usedFor'] ?? ''}',
                    tone: AbraStatusTone.info,
                  ),
                ),
                PlacesColumn(
                  'Landmark',
                  (row) => Text('${row['landmark'] ?? ''}'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
