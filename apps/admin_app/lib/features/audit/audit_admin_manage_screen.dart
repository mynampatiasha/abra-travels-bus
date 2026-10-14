import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
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
import '../../l10n/admin_strings.dart';
import '../../routing/admin_routes.dart';

// The admin "Audit log" page (demo page `audit`): every sensitive action, who
// did it and when. Search, Person, Type, Action and dates narrow it; a row
// opens the entry; the list can be downloaded. Nothing here edits or deletes.

// ===== 1. MODELS =====

/// One row of the trail, as `GET /audit-logs` returns it.
@immutable
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actionLabel,
    required this.sensitive,
    required this.actorName,
    required this.actorRoleLabel,
    required this.targetLabel,
    required this.ip,
    required this.reason,
    required this.before,
    required this.after,
  });

  factory AuditEntry.fromJson(JsonMap json) => AuditEntry(
    id: '${json['id']}',
    at: DateTime.tryParse('${json['at']}')?.toLocal() ?? DateTime(1970),
    actionLabel: '${json['actionLabel'] ?? json['action'] ?? ''}',
    sensitive: json['sensitive'] == true,
    actorName: '${json['actorName'] ?? ''}',
    actorRoleLabel: '${json['actorRoleLabel'] ?? ''}',
    targetLabel: '${json['targetLabel'] ?? ''}',
    ip: json['ip'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    before: _mapOf(json['before']),
    after: _mapOf(json['after']),
  );

  final String id;
  final DateTime at;

  /// What was done, in words ("Changed role access").
  final String actionLabel;
  final bool sensitive;
  final String actorName;
  final String actorRoleLabel;
  final String targetLabel;
  final String ip;
  final String reason;
  final JsonMap before;
  final JsonMap after;

  static JsonMap _mapOf(Object? value) =>
      value is Map ? value.cast<String, Object?>() : const <String, Object?>{};
}

/// One page of the trail.
@immutable
class AuditPage {
  const AuditPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<AuditEntry> items;
  final int page;
  final int pageSize;
  final int total;

  int get firstIndex => total == 0 ? 0 : (page - 1) * pageSize + 1;
  int get lastIndex => (page - 1) * pageSize + items.length;
  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;
}

/// The choices of the Person and Action filters (`GET /audit-logs/filters`).
@immutable
class AuditFilterChoices {
  const AuditFilterChoices({required this.people, required this.actions});

  const AuditFilterChoices.empty()
    : people = const <String, String>{},
      actions = const <String, String>{};

  factory AuditFilterChoices.fromJson(JsonMap json) => AuditFilterChoices(
    people: <String, String>{
      for (final person in (json['people'] as List<Object?>? ?? const []))
        if (person is Map) '${person['id']}': '${person['name']}',
    },
    actions: <String, String>{
      for (final action in (json['actions'] as List<Object?>? ?? const []))
        if (action is Map) '${action['key']}': '${action['label']}',
    },
  );

  /// Person id to name.
  final Map<String, String> people;

  /// Action key to words.
  final Map<String, String> actions;
}

/// What the person chose: value-equal, so it keys a provider.
@immutable
class AuditQuery {
  const AuditQuery({
    this.search = '',
    this.personId = '',
    this.sensitiveOnly = false,
    this.action = '',
    this.from = '',
    this.to = '',
    this.newestFirst = true,
    this.page = 1,
  });

  final String search;
  final String personId;
  final bool sensitiveOnly;
  final String action;
  final String from;
  final String to;
  final bool newestFirst;
  final int page;

  /// The demo shows 15 rows a page.
  static const int pageSize = 15;

  bool get isFiltered =>
      search.isNotEmpty ||
      personId.isNotEmpty ||
      sensitiveOnly ||
      action.isNotEmpty ||
      from.isNotEmpty ||
      to.isNotEmpty;

  AuditQuery copyWith({
    String? search,
    String? personId,
    bool? sensitiveOnly,
    String? action,
    String? from,
    String? to,
    bool? newestFirst,
    int? page,
  }) => AuditQuery(
    search: search ?? this.search,
    personId: personId ?? this.personId,
    sensitiveOnly: sensitiveOnly ?? this.sensitiveOnly,
    action: action ?? this.action,
    from: from ?? this.from,
    to: to ?? this.to,
    newestFirst: newestFirst ?? this.newestFirst,
    page: page ?? this.page,
  );

  /// The filters as query parameters (the same words for the list and the
  /// download). Empty ones are not sent.
  Map<String, String> filters() => <String, String>{
    if (search.isNotEmpty) 'search': search,
    if (personId.isNotEmpty) 'personId': personId,
    if (sensitiveOnly) 'type': 'sensitive',
    if (action.isNotEmpty) 'action': action,
    if (from.isNotEmpty) 'from': from,
    if (to.isNotEmpty) 'to': to,
    'sort': newestFirst ? 'newest' : 'oldest',
  };

  @override
  bool operator ==(Object other) =>
      other is AuditQuery &&
      other.search == search &&
      other.personId == personId &&
      other.sensitiveOnly == sensitiveOnly &&
      other.action == action &&
      other.from == from &&
      other.to == to &&
      other.newestFirst == newestFirst &&
      other.page == page;

  @override
  int get hashCode => Object.hash(
    search,
    personId,
    sensitiveOnly,
    action,
    from,
    to,
    newestFirst,
    page,
  );
}

// ===== 2. STATE AND API =====

/// The audit log API: the list, the filter choices and the download.
class AuditLogApi {
  AuditLogApi(this._client);

  final ApiClient _client;

  Future<AuditPage> list(AuditQuery query) async {
    final response = await _client.get(
      'audit-logs',
      query: <String, Object?>{
        ...query.filters(),
        'page': query.page,
        'pageSize': AuditQuery.pageSize,
      },
    );
    final info = response.page;
    if (info == null) throw const AppException(ServerFailure());
    return AuditPage(
      items: response.decodeList(AuditEntry.fromJson),
      page: info.page,
      pageSize: info.pageSize,
      total: info.total,
    );
  }

  Future<AuditFilterChoices> filters() async => (await _client.get(
    'audit-logs/filters',
  )).decodeObject(AuditFilterChoices.fromJson);

  /// The file the server makes from the same filters (`csv` or `xlsx`).
  Future<Uint8List> download(
    AuditQuery query,
    String format,
  ) => _client.getBytes(
    'audit-logs/export?${Uri(queryParameters: <String, String>{...query.filters(), 'format': format}).query}',
  );
}

final auditLogApiProvider = Provider<AuditLogApi>(
  (ref) => AuditLogApi(ref.watch(appDependenciesProvider).apiClient),
);

final auditListProvider = FutureProvider.autoDispose
    .family<AuditPage, AuditQuery>(
      (ref, query) => ref.watch(auditLogApiProvider).list(query),
    );

final auditFilterChoicesProvider =
    FutureProvider.autoDispose<AuditFilterChoices>(
      (ref) => ref.watch(auditLogApiProvider).filters(),
    );

// ===== 3. WIDGETS =====

/// The Audit log page.
class AuditAdminManageScreen extends ConsumerStatefulWidget {
  const AuditAdminManageScreen({super.key});

  @override
  ConsumerState<AuditAdminManageScreen> createState() =>
      _AuditAdminManageScreenState();
}

class _AuditAdminManageScreenState
    extends ConsumerState<AuditAdminManageScreen> {
  AuditQuery _query = const AuditQuery();
  bool _tableView = true;
  Timer? _searchPause;

  /// The filter fields keep their own text; a new key gives them a fresh start.
  int _filterEpoch = 0;

  @override
  void dispose() {
    _searchPause?.cancel();
    super.dispose();
  }

  void _change(AuditQuery Function(AuditQuery) update) =>
      setState(() => _query = update(_query));

  void _clear() => setState(() {
    _query = AuditQuery(newestFirst: _query.newestFirst);
    _filterEpoch += 1;
  });

  void _reload() {
    ref
      ..invalidate(auditListProvider)
      ..invalidate(auditFilterChoicesProvider);
  }

  Future<void> _download(String format) async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.text(AdminStrings.listExporting))),
    );
    try {
      final bytes = await ref
          .read(auditLogApiProvider)
          .download(_query, format);
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      downloadBytesFile(
        'audit-log-$stamp.$format',
        bytes,
        mimeType: format == 'csv'
            ? 'text/csv'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.text(AdminStrings.listExportReady))),
        );
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final list = ref.watch(auditListProvider(_query));
    final page = list.value;
    final showFailure = list.hasError && !list.isLoading;
    final isCompact = AbraBreakpoint.of(context) == AbraBreakpoint.phone;
    final useTable = _tableView && !isCompact;

    final Widget content;
    if (showFailure) {
      content = AbraFailureView(
        failure: failureOf(list.error!),
        onRetry: _reload,
        onSignIn: () => context.go(AdminRoutes.signIn),
      );
    } else if (page == null) {
      content = const AbraLoadingView();
    } else if (page.items.isEmpty) {
      content = AbraStateView(
        kind: AbraStateKind.empty,
        title: l10n.text(
          _query.isFiltered
              ? AdminStrings.listEmptyFilteredTitle
              : AdminStrings.auditEmptyTitle,
        ),
        message: l10n.text(
          _query.isFiltered
              ? AdminStrings.listEmptyFiltered
              : AdminStrings.auditEmptyMessage,
        ),
        actionLabel: _query.isFiltered
            ? l10n.text(AdminStrings.listClearFilters)
            : null,
        onAction: _query.isFiltered ? _clear : null,
      );
    } else if (useTable) {
      content = _AuditTable(
        entries: page.items,
        newestFirst: _query.newestFirst,
        onSort: () =>
            _change((q) => q.copyWith(newestFirst: !q.newestFirst, page: 1)),
        onOpen: (entry) => showAuditEntryDialog(context, entry),
      );
    } else {
      content = _AuditCards(
        entries: page.items,
        onOpen: (entry) => showAuditEntryDialog(context, entry),
      );
    }

    return Padding(
      padding: EdgeInsets.all(isCompact ? AbraSpacing.md : AbraSpacing.xl),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AbraColors.white,
          borderRadius: AbraRadius.large,
          border: Border.fromBorderSide(BorderSide(color: AbraColors.divider)),
          boxShadow: AbraShadows.soft,
        ),
        child: ClipRRect(
          borderRadius: AbraRadius.large,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AbraSpacing.lg),
                child: Wrap(
                  spacing: AbraSpacing.md,
                  runSpacing: AbraSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: <Widget>[
                    _Filters(
                      key: ValueKey<int>(_filterEpoch),
                      query: _query,
                      isCompact: isCompact,
                      onSearch: (text) {
                        _searchPause?.cancel();
                        _searchPause = Timer(
                          const Duration(milliseconds: 350),
                          () => mounted
                              ? _change(
                                  (q) =>
                                      q.copyWith(search: text.trim(), page: 1),
                                )
                              : null,
                        );
                      },
                      onChange: _change,
                      onClear: _clear,
                    ),
                    Wrap(
                      spacing: AbraSpacing.sm,
                      runSpacing: AbraSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (!isCompact)
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: <ButtonSegment<bool>>[
                              ButtonSegment<bool>(
                                value: true,
                                icon: const Icon(Icons.table_rows_outlined),
                                tooltip: l10n.text(AdminStrings.auditViewTable),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                icon: const Icon(Icons.view_agenda_outlined),
                                tooltip: l10n.text(AdminStrings.auditViewList),
                              ),
                            ],
                            selected: <bool>{_tableView},
                            onSelectionChanged: (value) =>
                                setState(() => _tableView = value.first),
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: l10n.text(AdminStrings.listRefresh),
                          onPressed: _reload,
                        ),
                        if (access.can(PermissionKeys.auditExport))
                          PopupMenuButton<String>(
                            tooltip: '',
                            onSelected: _download,
                            itemBuilder: (context) => <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'csv',
                                child: Text(
                                  l10n.text(AdminStrings.listExportCsv),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'xlsx',
                                child: Text(
                                  l10n.text(AdminStrings.listExportExcel),
                                ),
                              ),
                            ],
                            child: IgnorePointer(
                              child: AbraButton(
                                label: l10n.text(AdminStrings.listExport),
                                icon: Icons.file_download_outlined,
                                variant: AbraButtonVariant.secondary,
                                onPressed: () {},
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 2,
                child: list.isLoading && page != null
                    ? Semantics(
                        label: l10n.text(AdminStrings.listUpdating),
                        child: const LinearProgressIndicator(minHeight: 2),
                      )
                    : const ColoredBox(color: AbraColors.divider),
              ),
              Expanded(child: content),
              if (page != null && page.total > 0) ...<Widget>[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AbraSpacing.lg,
                    vertical: AbraSpacing.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.text(AdminStrings.listRange, <String, Object?>{
                              'from': l10n.formatters.number(page.firstIndex),
                              'to': l10n.formatters.number(page.lastIndex),
                              'total': l10n.formatters.number(page.total),
                            }),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: l10n.text(AdminStrings.listPrevious),
                        onPressed: page.hasPrevious
                            ? () => _change((q) => q.copyWith(page: q.page - 1))
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: l10n.text(AdminStrings.listNext),
                        onPressed: page.hasNext
                            ? () => _change((q) => q.copyWith(page: q.page + 1))
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Search, Person, Type, Action, the two dates and Clear.
class _Filters extends ConsumerWidget {
  const _Filters({
    required this.query,
    required this.isCompact,
    required this.onSearch,
    required this.onChange,
    required this.onClear,
    super.key,
  });

  final AuditQuery query;
  final bool isCompact;
  final ValueChanged<String> onSearch;
  final void Function(AuditQuery Function(AuditQuery)) onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final choices =
        ref.watch(auditFilterChoicesProvider).value ??
        const AuditFilterChoices.empty();
    final all = l10n.text(AdminStrings.listAll);

    Widget dropdown(
      String label,
      String value,
      Map<String, String> items,
      ValueChanged<String> onPicked,
    ) => SizedBox(
      width: isCompact ? double.infinity : 200,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: '', child: Text(all)),
          for (final entry in items.entries)
            DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (picked) => onPicked(picked ?? ''),
      ),
    );

    return Wrap(
      spacing: AbraSpacing.md,
      runSpacing: AbraSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: isCompact ? double.infinity : 240,
          child: TextField(
            decoration: InputDecoration(
              labelText: l10n.text(AdminStrings.auditSearch),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onSearch,
          ),
        ),
        dropdown(
          l10n.text(AdminStrings.auditFilterPerson),
          query.personId,
          choices.people,
          (value) => onChange((q) => q.copyWith(personId: value, page: 1)),
        ),
        dropdown(
          l10n.text(AdminStrings.auditFilterType),
          query.sensitiveOnly ? 'sensitive' : '',
          <String, String>{
            'sensitive': l10n.text(AdminStrings.auditTypeSensitive),
          },
          (value) => onChange(
            (q) => q.copyWith(sensitiveOnly: value == 'sensitive', page: 1),
          ),
        ),
        dropdown(
          l10n.text(AdminStrings.auditFilterAction),
          query.action,
          choices.actions,
          (value) => onChange((q) => q.copyWith(action: value, page: 1)),
        ),
        _DateField(
          label: l10n.text(AdminStrings.listDateFrom),
          value: query.from,
          onPicked: (day) => onChange((q) => q.copyWith(from: day, page: 1)),
        ),
        _DateField(
          label: l10n.text(AdminStrings.listDateTo),
          value: query.to,
          onPicked: (day) => onChange((q) => q.copyWith(to: day, page: 1)),
        ),
        if (query.isFiltered)
          AbraButton(
            label: l10n.text(AdminStrings.listClearFilters),
            icon: Icons.filter_alt_off_outlined,
            variant: AbraButtonVariant.text,
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// A day picked from a calendar, as `YYYY-MM-DD`; the cross clears it.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final String value;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 168,
    child: InkWell(
      borderRadius: AbraRadius.medium,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? now,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 1),
        );
        if (picked != null) onPicked(picked.toIso8601String().substring(0, 10));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: value.isEmpty
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onPicked(''),
                ),
        ),
        child: Text(value),
      ),
    ),
  );
}

/// The words of the "Sensitive" mark.
class _SensitiveChip extends StatelessWidget {
  const _SensitiveChip();

  @override
  Widget build(BuildContext context) => AbraStatusBadge(
    label: AbraLocalizations.of(context).text(AdminStrings.auditSensitive),
    tone: AbraStatusTone.warning,
  );
}

/// Table view: When (sortable, newest first), Who, Action, Target, IP address.
class _AuditTable extends StatelessWidget {
  const _AuditTable({
    required this.entries,
    required this.newestFirst,
    required this.onSort,
    required this.onOpen,
  });

  final List<AuditEntry> entries;
  final bool newestFirst;
  final VoidCallback onSort;
  final ValueChanged<AuditEntry> onOpen;

  static const _widths = <int>[2, 2, 3, 3, 2];

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final heading = theme.textTheme.labelLarge?.copyWith(
      color: AbraColors.textSecondary,
      fontWeight: FontWeight.w800,
    );

    Widget cell(int index, Widget child) =>
        Expanded(flex: _widths[index], child: child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
          color: AbraColors.lightGray,
          child: Row(
            children: <Widget>[
              cell(
                0,
                Semantics(
                  button: true,
                  label: l10n.text(AdminStrings.auditSortWhen),
                  child: InkWell(
                    onTap: onSort,
                    child: Row(
                      children: <Widget>[
                        Text(
                          l10n.text(AdminStrings.auditColWhen),
                          style: heading,
                        ),
                        Icon(
                          newestFirst
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 16,
                          color: AbraColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              cell(
                1,
                Text(l10n.text(AdminStrings.auditColWho), style: heading),
              ),
              cell(
                2,
                Text(l10n.text(AdminStrings.auditColAction), style: heading),
              ),
              cell(
                3,
                Text(l10n.text(AdminStrings.auditColTarget), style: heading),
              ),
              cell(4, Text(l10n.text(AdminStrings.auditColIp), style: heading)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return InkWell(
                onTap: () => onOpen(entry),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AbraSpacing.lg,
                    vertical: AbraSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      cell(0, Text(l10n.formatters.dateTime(entry.at))),
                      cell(
                        1,
                        Text(
                          entry.actorName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      cell(
                        2,
                        Wrap(
                          spacing: AbraSpacing.sm,
                          runSpacing: AbraSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(entry.actionLabel),
                            if (entry.sensitive) const _SensitiveChip(),
                          ],
                        ),
                      ),
                      cell(
                        3,
                        Text(
                          entry.targetLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      cell(4, Text(entry.ip)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// List view (and the phone): one block per entry.
class _AuditCards extends StatelessWidget {
  const _AuditCards({required this.entries, required this.onOpen});

  final List<AuditEntry> entries;
  final ValueChanged<AuditEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AbraSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return AbraCard(
          semanticLabel: '${entry.actionLabel}. ${entry.actorName}',
          onTap: () => onOpen(entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AbraSpacing.sm,
                runSpacing: AbraSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    entry.actionLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.sensitive) const _SensitiveChip(),
                ],
              ),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                '${entry.actorName} · ${l10n.formatters.dateTime(entry.at)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.xxs),
              Text(
                [
                  entry.targetLabel,
                  if (entry.ip.isNotEmpty) entry.ip,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The "Audit entry" window: when, who, role, action, target, IP address and,
/// for a sensitive entry, what changed (before and after).
Future<void> showAuditEntryDialog(BuildContext context, AuditEntry entry) =>
    showDialog<void>(
      context: context,
      builder: (context) => _AuditEntryDialog(entry: entry),
    );

class _AuditEntryDialog extends StatelessWidget {
  const _AuditEntryDialog({required this.entry});

  final AuditEntry entry;

  static String _pretty(JsonMap values) =>
      values.isEmpty ? '' : const JsonEncoder.withIndent('  ').convert(values);

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    Widget block(String label, JsonMap values) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AbraSpacing.md),
        decoration: BoxDecoration(
          color: AbraColors.lightGray,
          borderRadius: AbraRadius.medium,
          border: Border.all(color: AbraColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
            const SizedBox(height: AbraSpacing.xs),
            SelectableText(
              _pretty(values).isEmpty
                  ? l10n.text(AdminStrings.auditNothingChanged)
                  : _pretty(values),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );

    return AlertDialog(
      title: Text(l10n.text(AdminStrings.auditEntryTitle)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              line(
                l10n.text(AdminStrings.auditColWhen),
                l10n.formatters.dateTime(entry.at),
              ),
              line(l10n.text(AdminStrings.auditColWho), entry.actorName),
              line(
                l10n.text(AdminStrings.auditFieldRole),
                entry.actorRoleLabel,
              ),
              line(l10n.text(AdminStrings.auditColAction), entry.actionLabel),
              line(l10n.text(AdminStrings.auditColTarget), entry.targetLabel),
              line(l10n.text(AdminStrings.auditColIp), entry.ip),
              if (entry.reason.isNotEmpty)
                line(l10n.text(AdminStrings.auditReason), entry.reason),
              if (entry.sensitive) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                Text(
                  l10n.text(AdminStrings.auditChange),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AbraSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    block(l10n.text(AdminStrings.auditBefore), entry.before),
                    const SizedBox(width: AbraSpacing.md),
                    block(l10n.text(AdminStrings.auditAfter), entry.after),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        AbraButton(
          label: l10n.text(AbraStrings.commonClose),
          variant: AbraButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
