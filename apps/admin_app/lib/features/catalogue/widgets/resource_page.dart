import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/async_value_view.dart';
import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';

/// A column of a management table.
class ColumnSpec {
  const ColumnSpec(this.labelKey, this.cell, {this.isNumeric = false});

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
    super.key,
  });

  /// Path below `/catalogue`.
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

  void _reload() => ref.invalidate(resourceListProvider(_query));

  Future<void> _run(Future<bool> Function() action) async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await action()) {
        _reload();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.text(AdminStrings.formSaved))),
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
    Widget dropdown(Map<String, String> items) => SizedBox(
      width: 220,
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
      SearchFilter() => SizedBox(
        width: 260,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final list = ref.watch(resourceListProvider(_query));
    final page = list.value;

    return Padding(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final filter in widget.filters) _filter(filter),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.text(AdminStrings.listRefresh),
                onPressed: _reload,
              ),
              if (widget.onCreate != null)
                AbraButton(
                  label: l10n.text(AdminStrings.listCreate),
                  icon: Icons.add,
                  variant: AbraButtonVariant.primary,
                  onPressed: () => _run(() => widget.onCreate!(context)),
                ),
            ],
          ),
          const SizedBox(height: AbraSpacing.lg),
          Expanded(
            child: AbraCard(
              padding: EdgeInsetsDirectional.zero,
              child: AsyncValueView<PageOf>(
                value: list,
                onRetry: _reload,
                data: (context, page) => page.items.isEmpty
                    ? AbraStateView(
                        kind: AbraStateKind.empty,
                        title: l10n.text(AdminStrings.listEmptyTitle),
                        message: _filters.isEmpty
                            ? null
                            : l10n.text(AdminStrings.listEmptyFiltered),
                      )
                    : _table(page),
              ),
            ),
          ),
          if (page != null && page.total > 0)
            Padding(
              padding: const EdgeInsets.only(top: AbraSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.text(AdminStrings.listRange, <String, Object?>{
                        'from': l10n.formatters.number(page.firstIndex),
                        'to': l10n.formatters.number(page.lastIndex),
                        'total': l10n.formatters.number(page.total),
                      }),
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
      ),
    );
  }

  Widget _table(PageOf page) {
    final l10n = AbraLocalizations.of(context);
    final hasActions = widget.rowActions != null;
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: <DataColumn>[
            for (final column in widget.columns)
              DataColumn(
                label: Text(l10n.text(column.labelKey)),
                numeric: column.isNumeric,
              ),
            if (hasActions)
              DataColumn(label: Text(l10n.text(AdminStrings.listActions))),
          ],
          rows: <DataRow>[
            for (final record in page.items)
              DataRow(
                cells: <DataCell>[
                  for (final column in widget.columns)
                    DataCell(column.cell(context, record)),
                  if (hasActions)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final action in widget.rowActions!(record))
                            IconButton(
                              icon: Icon(action.icon),
                              tooltip: l10n.text(action.labelKey),
                              onPressed: () =>
                                  _run(() => action.run(context, record)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
