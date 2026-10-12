import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/async_value_view.dart';
import '../../../core/browser_files.dart';
import '../../../core/csv.dart';
import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../../../routing/admin_routes.dart';
import '../catalogue_repository.dart';
import 'import_dialog.dart';

/// A column of a management table.
class ColumnSpec {
  const ColumnSpec(
    this.labelKey,
    this.cell, {
    this.isNumeric = false,
    this.text,
    this.exportOnly = false,
  });

  /// Not shown in the table, only written to the export (with [text]).
  final bool exportOnly;

  /// What the column holds as plain text, for the export. A column without it is left out of
  /// the export.
  final String Function(JsonMap record)? text;

  final String labelKey;
  final Widget Function(BuildContext context, JsonMap record) cell;
  final bool isNumeric;
}

/// A filter above a management table. [param] is the query parameter the
/// backend defines; filtering is always done by the backend.
sealed class FilterSpec {
  const FilterSpec(this.param, this.labelKey);

  final String param;
  final String labelKey;
}

/// Free text, sent after a pause in typing.
class SearchFilter extends FilterSpec {
  const SearchFilter(super.param, super.labelKey);
}

/// A date range: [param] is the query parameter for the first day, [toParam] for the last.
class DateRangeFilter extends FilterSpec {
  const DateRangeFilter(super.param, super.labelKey, {required this.toParam});

  final String toParam;
}

/// A summary card above the table: how many records match [filters]. Tapping it shows them.
class StatSpec {
  const StatSpec(this.labelKey, this.filters, this.icon, this.color);

  final String labelKey;
  final Map<String, String> filters;
  final IconData icon;
  final Color color;
}

/// One of fixed values; [options] maps each value to its label key.
class ChoiceFilter extends FilterSpec {
  const ChoiceFilter(super.param, super.labelKey, this.options);

  final Map<String, String> options;
}

/// A record from another catalogue list.
class RefFilter extends FilterSpec {
  const RefFilter(super.param, super.labelKey, this.optionsPath, this.labelOf);

  final String optionsPath;
  final String Function(JsonMap record) labelOf;
}

/// Something that can be done to one row. [run] returns true when the list
/// should be loaded again.
class RowAction {
  const RowAction(this.labelKey, this.icon, this.run);

  final String labelKey;
  final IconData icon;
  final Future<bool> Function(BuildContext context, JsonMap record) run;
}

/// The standard management list: filters, a table, pagination, an "Add"
/// button and row actions. What is offered depends on what the page passes
/// in, which the page decides from the user's permissions; the data is
/// whatever the backend returns for this user.
class ResourcePage extends ConsumerStatefulWidget {
  const ResourcePage({
    required this.path,
    required this.columns,
    this.filters = const <FilterSpec>[],
    this.onCreate,
    this.rowActions,
    this.stats = const <StatSpec>[],
    this.exportName,
    this.importSpec,
    this.createLabelKey = AdminStrings.listCreate,
    super.key,
  });

  /// The message key of the create button ("Add" unless a page uses the demo's
  /// own word, such as "New banner").
  final String createLabelKey;

  /// Summary cards above the toolbar.
  final List<StatSpec> stats;

  /// File name (without date) of the export; null hides the Export button.
  final String? exportName;

  /// How to import rows from a CSV file; null hides the Import button.
  final ImportSpec? importSpec;

  /// Path below `/catalogue` (or the full `onboarding/...` path).
  final String path;
  final List<ColumnSpec> columns;
  final List<FilterSpec> filters;

  /// Opens the create form; null when the user may not create. Returns true
  /// when something was created.
  final Future<bool> Function(BuildContext context)? onCreate;

  /// The actions for a row; may depend on the record (a draft can be
  /// published, a cancelled trip cannot).
  final List<RowAction> Function(JsonMap record)? rowActions;

  @override
  ConsumerState<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends ConsumerState<ResourcePage> {
  int _page = 1;
  final Map<String, String> _filters = <String, String>{};
  Timer? _searchPause;
  int _filterEpoch = 0;

  @override
  void dispose() {
    _searchPause?.cancel();
    super.dispose();
  }

  ResourceQuery get _query =>
      ResourceQuery(widget.path, page: _page, filters: Map.of(_filters));

  void _setFilter(String param, String? value) => setState(() {
    _page = 1;
    if (value == null || value.isEmpty) {
      _filters.remove(param);
    } else {
      _filters[param] = value;
    }
  });

  /// Loads the list again, with every other page and summary card: after a
  /// change any of their counts may be out of date.
  void _reload() => ref.invalidate(resourceListProvider);

  Future<void> _run(Future<bool> Function() action) async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await action()) {
        _reload();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle,
                  color: AbraColors.skyBlue,
                  size: 20,
                ),
                const SizedBox(width: AbraSpacing.sm),
                Expanded(child: Text(l10n.text(AdminStrings.formSaved))),
              ],
            ),
          ),
        );
      }
    } on Object catch (error) {
      // An action without a form of its own (enable, disable): the reason
      // from the backend is shown here.
      messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    }
  }

  Widget _filter(FilterSpec filter) {
    final l10n = AbraLocalizations.of(context);
    final label = l10n.text(filter.labelKey);
    final all = l10n.text(AdminStrings.listAll);
    final isCompact = AbraBreakpoint.of(context) == AbraBreakpoint.phone;
    Widget dropdown(Map<String, String> items) => SizedBox(
      width: isCompact ? double.infinity : 220,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(_filters[filter.param])
            ? _filters[filter.param]
            : '',
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
        onChanged: (value) => _setFilter(filter.param, value),
      ),
    );
    return switch (filter) {
      DateRangeFilter(:final toParam) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _dateField(l10n.text(AdminStrings.listDateFrom), filter.param),
          const SizedBox(width: AbraSpacing.sm),
          _dateField(l10n.text(AdminStrings.listDateTo), toParam),
        ],
      ),
      SearchFilter() => SizedBox(
        width: isCompact ? double.infinity : 260,
        child: TextField(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (text) {
            _searchPause?.cancel();
            _searchPause = Timer(
              const Duration(milliseconds: 350),
              () => mounted ? _setFilter(filter.param, text.trim()) : null,
            );
          },
        ),
      ),
      ChoiceFilter(:final options) => dropdown(<String, String>{
        for (final entry in options.entries) entry.key: l10n.text(entry.value),
      }),
      RefFilter(:final optionsPath, :final labelOf) =>
        ref
            .watch(optionsProvider(optionsPath))
            .maybeWhen(
              data: (records) => dropdown(<String, String>{
                for (final record in records)
                  record['id']! as String: labelOf(record),
              }),
              orElse: () => dropdown(const <String, String>{}),
            ),
    };
  }

  Widget _dateField(String label, String param) {
    final value = _filters[param];
    return SizedBox(
      width: 168,
      child: InkWell(
        borderRadius: AbraRadius.medium,
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(value ?? '') ?? now,
            firstDate: DateTime(2020),
            lastDate: DateTime(now.year + 5),
          );
          if (picked == null || !mounted) return;
          _setFilter(param, picked.toIso8601String().substring(0, 10));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _setFilter(param, null),
                  ),
          ),
          child: Text(value ?? ''),
        ),
      ),
    );
  }

  /// Everything the current filters show (not just this page), as a CSV download.
  Future<void> _export() async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final columns = widget.columns
        .where((column) => column.text != null)
        .toList();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.text(AdminStrings.listExporting))),
    );
    try {
      final repository = ref.read(catalogueRepositoryProvider);
      final rows = <List<Object?>>[];
      for (var page = 1; page <= 100; page++) {
        final result = await repository.list(
          ResourceQuery(
            widget.path,
            page: page,
            pageSize: 100,
            filters: Map.of(_filters),
          ),
        );
        for (final record in result.items) {
          rows.add(<Object?>[
            for (final column in columns) column.text!(record),
          ]);
        }
        if (!result.hasNext) break;
      }
      messenger.hideCurrentSnackBar();
      if (rows.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.text(AdminStrings.listExportEmpty))),
        );
        return;
      }
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      downloadTextFile(
        '${widget.exportName}_$stamp.csv',
        Csv.encode(<String>[
          for (final column in columns) l10n.text(column.labelKey),
        ], rows),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.text(AdminStrings.listExportDone, <String, Object?>{
              'count': rows.length,
            }),
          ),
        ),
      );
    } on Object catch (error) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    }
  }

  void _clearFilters() => setState(() {
    _page = 1;
    _filters.clear();
    // The filter fields keep their own text and selection; a new key gives
    // them a fresh start.
    _filterEpoch += 1;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final list = ref.watch(resourceListProvider(_query));
    final page = list.value;
    final showFailure = list.hasError && !list.isLoading;
    final isCompact = AbraBreakpoint.of(context) == AbraBreakpoint.phone;
    final shown = widget.columns.where((column) => !column.exportOnly).toList();
    final create = widget.onCreate == null
        ? null
        : () => _run(() => widget.onCreate!(context));

    final Widget content;
    if (showFailure) {
      content = AbraFailureView(
        failure: failureOf(list.error!),
        onRetry: _reload,
        onSignIn: () => context.go(AdminRoutes.signIn),
      );
    } else if (page == null) {
      content = _TableSkeleton(columns: shown.length);
    } else if (page.items.isEmpty) {
      final isFiltered = _filters.isNotEmpty;
      content = AbraStateView(
        kind: AbraStateKind.empty,
        title: l10n.text(
          isFiltered
              ? AdminStrings.listEmptyFilteredTitle
              : AdminStrings.listEmptyTitle,
        ),
        message: l10n.text(
          isFiltered
              ? AdminStrings.listEmptyFiltered
              : AdminStrings.listEmptyMessage,
        ),
        actionLabel: isFiltered
            ? l10n.text(AdminStrings.listClearFilters)
            : l10n.text(AdminStrings.listEmptyAction),
        onAction: isFiltered ? _clearFilters : create,
      );
    } else {
      content = _ResourceTable(
        columns: shown,
        records: page.items,
        actionsOf: widget.rowActions,
        onAction: (action, record) => _run(() => action.run(context, record)),
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
              if (widget.stats.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AbraSpacing.lg,
                    AbraSpacing.lg,
                    AbraSpacing.lg,
                    0,
                  ),
                  child: Wrap(
                    spacing: AbraSpacing.md,
                    runSpacing: AbraSpacing.md,
                    children: <Widget>[
                      for (final stat in widget.stats)
                        _StatCard(
                          spec: stat,
                          path: widget.path,
                          selected: stat.filters.entries.every(
                            (entry) => _filters[entry.key] == entry.value,
                          ),
                          onTap: () => setState(() {
                            _page = 1;
                            _filters
                              ..clear()
                              ..addAll(stat.filters);
                            _filterEpoch += 1;
                          }),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AbraSpacing.lg),
                child: Wrap(
                  spacing: AbraSpacing.md,
                  runSpacing: AbraSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: <Widget>[
                    Wrap(
                      spacing: AbraSpacing.md,
                      runSpacing: AbraSpacing.md,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        for (final filter in widget.filters)
                          KeyedSubtree(
                            key: ValueKey<String>(
                              '${filter.param}-$_filterEpoch',
                            ),
                            child: _filter(filter),
                          ),
                        if (_filters.isNotEmpty)
                          AbraButton(
                            label: l10n.text(AdminStrings.listClearFilters),
                            icon: Icons.filter_alt_off_outlined,
                            variant: AbraButtonVariant.text,
                            onPressed: _clearFilters,
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: AbraSpacing.sm,
                      runSpacing: AbraSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: l10n.text(AdminStrings.listRefresh),
                          onPressed: _reload,
                        ),
                        if (widget.importSpec != null) ...<Widget>[
                          AbraButton(
                            label: l10n.text(AdminStrings.listImport),
                            icon: Icons.file_upload_outlined,
                            variant: AbraButtonVariant.secondary,
                            onPressed: () async {
                              await showImportDialog(
                                context,
                                widget.importSpec!,
                              );
                              if (mounted) _reload();
                            },
                          ),
                        ],
                        if (widget.exportName != null) ...<Widget>[
                          AbraButton(
                            label: l10n.text(AdminStrings.listExport),
                            icon: Icons.file_download_outlined,
                            variant: AbraButtonVariant.secondary,
                            onPressed: _export,
                          ),
                        ],
                        if (create != null) ...<Widget>[
                          AbraButton(
                            label: l10n.text(widget.createLabelKey),
                            icon: Icons.add,
                            variant: AbraButtonVariant.primary,
                            onPressed: create,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Shows that a list already on screen is being loaded again.
              SizedBox(
                height: 2,
                child: list.isLoading && page != null
                    ? Semantics(
                        label: l10n.text(AdminStrings.listUpdating),
                        child: const LinearProgressIndicator(minHeight: 2),
                      )
                    : const ColoredBox(color: AbraColors.divider),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AbraMotion.isReduced(context)
                      ? Duration.zero
                      : AbraDurations.normal,
                  // Every state fills the area: rows start at the top, a
                  // message centres itself.
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: <Widget>[...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      showFailure
                          ? 'failure'
                          : page == null
                          ? 'loading'
                          : page.items.isEmpty
                          ? 'empty'
                          : 'rows',
                    ),
                    child: content,
                  ),
                ),
              ),
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
                            ? () => setState(() => _page -= 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: l10n.text(AdminStrings.listNext),
                        onPressed: page.hasNext
                            ? () => setState(() => _page += 1)
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

const double _headingHeight = 44;
const double _rowHeight = 56;

/// The records of one page.
///
/// Wide enough: a table whose data columns scroll sideways when they do not
/// fit, with the actions pinned at the trailing edge so they are always on
/// screen. Narrow (a phone): one block per record, actions underneath.
class _ResourceTable extends StatefulWidget {
  const _ResourceTable({
    required this.columns,
    required this.records,
    required this.actionsOf,
    required this.onAction,
  });

  final List<ColumnSpec> columns;
  final List<JsonMap> records;
  final List<RowAction> Function(JsonMap record)? actionsOf;
  final void Function(RowAction action, JsonMap record) onAction;

  @override
  State<_ResourceTable> createState() => _ResourceTableState();
}

class _ResourceTableState extends State<_ResourceTable> {
  static const double _compactBelow = 640;
  static const double _actionSize = 40;

  final ScrollController _horizontal = ScrollController();

  /// True when the data columns are wider than the room they have, so some
  /// of them are under the pinned actions until scrolled.
  bool _overflows = false;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  Widget _actions(JsonMap record) {
    final l10n = AbraLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final action in widget.actionsOf!(record))
          IconButton(
            icon: Icon(action.icon, size: 20),
            color: AbraColors.navySecondary,
            tooltip: l10n.text(action.labelKey),
            constraints: const BoxConstraints.tightFor(
              width: _actionSize,
              height: _actionSize,
            ),
            onPressed: () => widget.onAction(action, record),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < _compactBelow
        ? _blocks()
        : _table(constraints.maxWidth),
  );

  TextStyle? get _headingStyle =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AbraColors.white,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      );

  Widget _table(double width) {
    final l10n = AbraLocalizations.of(context);
    final hasActions = widget.actionsOf != null;
    final mostActions = hasActions
        ? widget.records
              .map((record) => widget.actionsOf!(record).length)
              .fold<int>(1, (most, count) => count > most ? count : most)
        : 0;
    // On touch platforms each button is padded to the minimum tap target.
    final actionSlot =
        Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded
        ? kMinInteractiveDimension
        : _actionSize;
    final actionsWidth = hasActions
        ? mostActions * actionSlot + AbraSpacing.lg * 2
        : 0.0;

    final data = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        final overflows = notification.metrics.maxScrollExtent > 0;
        if (overflows != _overflows) setState(() => _overflows = overflows);
        return false;
      },
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          // Room for the scrollbar under the last row.
          padding: EdgeInsets.only(bottom: _overflows ? AbraSpacing.lg : 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: width - actionsWidth),
            child: DataTable(
              headingRowHeight: _headingHeight,
              dataRowMinHeight: _rowHeight,
              dataRowMaxHeight: _rowHeight,
              horizontalMargin: AbraSpacing.lg,
              columnSpacing: AbraSpacing.xl,
              dividerThickness: 1,
              headingRowColor: const WidgetStatePropertyAll<Color>(
                AbraColors.navy,
              ),
              headingTextStyle: _headingStyle,
              dataTextStyle: Theme.of(context).textTheme.bodyMedium,
              columns: <DataColumn>[
                for (final column in widget.columns)
                  DataColumn(
                    label: Text(l10n.text(column.labelKey)),
                    numeric: column.isNumeric,
                    columnWidth: const IntrinsicColumnWidth(flex: 1),
                  ),
              ],
              rows: <DataRow>[
                for (final record in widget.records)
                  DataRow(
                    cells: <DataCell>[
                      for (final column in widget.columns)
                        DataCell(column.cell(context, record)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!hasActions) return SingleChildScrollView(child: data);

    const line = BorderSide(color: AbraColors.divider);
    final pinned = DecoratedBox(
      decoration: BoxDecoration(
        color: AbraColors.white,
        border: const BorderDirectional(start: line),
        // Says that columns continue underneath.
        boxShadow: _overflows
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1F071E3D),
                  blurRadius: 12,
                  offset: Offset(-4, 0),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: actionsWidth,
        child: Column(
          children: <Widget>[
            Container(
              height: _headingHeight,
              color: AbraColors.navy,
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
              child: Text(
                l10n.text(AdminStrings.listActions),
                style: _headingStyle,
              ),
            ),
            for (final record in widget.records)
              Container(
                height: _rowHeight,
                decoration: const BoxDecoration(border: Border(top: line)),
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.sm),
                child: _actions(record),
              ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: data),
          pinned,
        ],
      ),
    );
  }

  Widget _blocks() {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return ListView.separated(
      itemCount: widget.records.length,
      separatorBuilder: (context, _) => const Divider(),
      itemBuilder: (context, index) {
        final record = widget.records[index];
        return Padding(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle.merge(
                style: textTheme.titleMedium,
                child: widget.columns.first.cell(context, record),
              ),
              const SizedBox(height: AbraSpacing.sm),
              for (final column in widget.columns.skip(1))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 128,
                        child: Text(
                          l10n.text(column.labelKey),
                          style: textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: column.cell(context, record),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.actionsOf != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _actions(record),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The shape of the table while its first page loads.
class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) => AbraSkeletonGroup(
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              height: _headingHeight,
              child: ColoredBox(
                color: AbraColors.lightGray,
                child: SizedBox.expand(),
              ),
            ),
            for (var row = 0; row < 8; row++)
              Container(
                height: _rowHeight,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AbraColors.divider)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
                child: Row(
                  children: <Widget>[
                    for (var column = 0; column < columns.clamp(2, 6); column++)
                      Expanded(
                        flex: column == 0 ? 3 : 2,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FractionallySizedBox(
                            widthFactor: (row + column).isEven ? 0.7 : 0.5,
                            child: const AbraSkeleton(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A summary card: a number and what it counts. The number comes from the same list API, asking
/// for one record of those matching the card's filters and reading the total.
class _StatCard extends ConsumerWidget {
  const _StatCard({
    required this.spec,
    required this.path,
    required this.selected,
    required this.onTap,
  });

  final StatSpec spec;
  final String path;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final total = ref
        .watch(
          resourceListProvider(
            ResourceQuery(path, pageSize: 1, filters: spec.filters),
          ),
        )
        .value
        ?.total;
    return InkWell(
      borderRadius: AbraRadius.medium,
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(AbraSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AbraRadius.medium,
          gradient: LinearGradient(
            colors: <Color>[spec.color, spec.color.withValues(alpha: 0.78)],
          ),
          border: Border.all(
            color: selected ? AbraColors.navy : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(spec.icon, color: AbraColors.white, size: 28),
            const SizedBox(width: AbraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    total == null ? '-' : l10n.formatters.number(total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AbraColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.text(spec.labelKey),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AbraColors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
