import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../kyc/admin_kyc_configuration.dart' show kycExcelBytes;

enum _View { list, table }

enum _Sort { name, email, phone, status, registered, lastSignIn }

/// Remembered while the app runs, so the page opens in the view last used.
_View _lastView = _View.list;

/// Customer identity directory. Uses the existing scoped users API.
class AdminCustomersPage extends ConsumerStatefulWidget {
  const AdminCustomersPage({super.key});
  @override
  ConsumerState<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends ConsumerState<AdminCustomersPage> {
  static const _pageSize = 20;
  final _search = TextEditingController();
  final _tableScroll = ScrollController();
  Timer? _debounce;
  String _status = '';
  String _method = '';
  int _page = 1;
  int _total = 0;
  int _generation = 0;
  bool _busy = true;
  bool _exporting = false;
  String? _error;
  List<JsonMap> _customers = [];
  _View _view = _lastView;
  _Sort? _sort;
  bool _ascending = true;

  /// Total, active, invited, suspended + deactivated. Null while loading or if
  /// the count failed (shown as a dash; it never blocks the list).
  List<int?> _kpis = const [null, null, null, null];
  bool _kpiBusy = true;
  int _kpiGeneration = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      _load();
      _loadKpis();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  Map<String, Object?> _query(int page, int size) => {
    'userType': 'CUSTOMER',
    'page': page,
    'pageSize': size,
    if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    if (_status.isNotEmpty) 'status': _status,
    if (_method.isNotEmpty) 'loginMethod': _method,
  };

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(appDependenciesProvider)
          .apiClient
          .get('users', query: _query(_page, _pageSize));
      final customers = response.decodeList((json) => json);
      if (mounted && generation == _generation) {
        setState(() {
          _customers = customers;
          _total = response.page?.total ?? customers.length;
        });
      }
    } on Object catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _customers = [];
          _error = failureText(AbraLocalizations.of(context), e);
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  /// Counts for the cards: one small request per status, unaffected by the
  /// filters, using the same endpoint (page.total with pageSize 1).
  Future<void> _loadKpis() async {
    final generation = ++_kpiGeneration;
    setState(() => _kpiBusy = true);
    final api = ref.read(appDependenciesProvider).apiClient;
    Future<int?> count(String status) async {
      try {
        final response = await api.get(
          'users',
          query: {
            'userType': 'CUSTOMER',
            'page': 1,
            'pageSize': 1,
            if (status.isNotEmpty) 'status': status,
          },
        );
        return response.page?.total;
      } on Object {
        return null;
      }
    }

    final results = await Future.wait([
      count(''),
      count('ACTIVE'),
      count('INVITED'),
      count('SUSPENDED'),
      count('DEACTIVATED'),
    ]);
    if (!mounted || generation != _kpiGeneration) return;
    setState(() {
      _kpis = [
        results[0],
        results[1],
        results[2],
        results[3] == null || results[4] == null
            ? null
            : results[3]! + results[4]!,
      ];
      _kpiBusy = false;
    });
  }

  void _refresh() {
    unawaited(_load());
    unawaited(_loadKpis());
  }

  void _filter(VoidCallback change) {
    _debounce?.cancel();
    setState(() {
      change();
      _page = 1;
    });
    unawaited(_load());
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    unawaited(_load());
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    return parsed == null
        ? 'Not recorded'
        : MaterialLocalizations.of(context).formatMediumDate(parsed);
  }

  List<String> _methodsOf(JsonMap c) => [
    for (final m in c['loginMethods'] as List? ?? const []) '$m',
  ];
  String _methods(JsonMap c) => _methodsOf(c).join(', ');
  String _value(Object? value) =>
      value == null || '$value'.isEmpty ? 'Not provided' : '$value';
  String _initials(Object? name) {
    final parts = '${name ?? ''}'
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  String _statusLabel(Object? status) {
    final text = '${status ?? ''}';
    return text.isEmpty
        ? 'Unknown'
        : text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  AbraStatusTone _tone(Object? status) => switch ('$status') {
    'ACTIVE' => AbraStatusTone.success,
    'INVITED' => AbraStatusTone.warning,
    'SUSPENDED' => AbraStatusTone.danger,
    _ => AbraStatusTone.neutral,
  };

  /// The backend returns newest first and has no sort option, so sorting by a
  /// column orders the rows of the page being shown.
  List<JsonMap> get _shown {
    final sort = _sort;
    if (sort == null) return _customers;
    String key(JsonMap c) => switch (sort) {
      _Sort.name => '${c['name'] ?? ''}'.toLowerCase(),
      _Sort.email => '${c['email'] ?? ''}'.toLowerCase(),
      _Sort.phone => '${c['phone'] ?? ''}',
      _Sort.status => '${c['status'] ?? ''}',
      _Sort.registered => '${c['createdAt'] ?? ''}',
      _Sort.lastSignIn => '${c['lastLoginAt'] ?? ''}',
    };
    final sorted = [..._customers]..sort((a, b) => key(a).compareTo(key(b)));
    return _ascending ? sorted : sorted.reversed.toList();
  }

  Future<void> _export(bool excel) async {
    setState(() => _exporting = true);
    try {
      final query = _query(1, 100);
      final all = <JsonMap>[];
      var total = 0;
      var page = 1;
      do {
        final response = await ref
            .read(appDependenciesProvider)
            .apiClient
            .get('users', query: {...query, 'page': page});
        final rows = response.decodeList((json) => json);
        all.addAll(rows);
        total = response.page?.total ?? all.length;
        if (rows.isEmpty) break;
        page++;
      } while (all.length < total);
      final rows = <List<String>>[
        [
          'Name',
          'Email',
          'Phone',
          'Status',
          'Login methods',
          'Registered',
          'Last sign-in',
        ],
        for (final c in all)
          [
            for (final key in ['name', 'email', 'phone', 'status'])
              '${c[key] ?? ''}',
            _methods(c),
            '${c['createdAt'] ?? ''}',
            '${c['lastLoginAt'] ?? ''}',
          ],
      ];
      if (!mounted) return;
      if (excel) {
        downloadBytesFile(
          'abra-customers.xlsx',
          kycExcelBytes(rows, sheetName: 'Customers'),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        downloadTextFile(
          'abra-customers.csv',
          const ListToCsvConverter().convert(
            rows
                .map(
                  (r) => r
                      .map((v) => RegExp(r'^[=+@\-]').hasMatch(v) ? "'$v" : v)
                      .toList(),
                )
                .toList(),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureText(AbraLocalizations.of(context), e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---------------------------------------------------------------- details

  Widget _detailsBody(BuildContext context, JsonMap c) {
    final theme = Theme.of(context);
    final entries = <String, Widget>{
      'Email': SelectableText(_value(c['email'])),
      'Phone': SelectableText(_value(c['phone'])),
      'Account status': Align(
        alignment: AlignmentDirectional.centerStart,
        child: AbraStatusBadge(
          label: _statusLabel(c['status']),
          tone: _tone(c['status']),
        ),
      ),
      'Login methods': SelectableText(
        _methods(c).isEmpty ? 'Not recorded' : _methods(c),
      ),
      'Registered': SelectableText(_date(c['createdAt'])),
      'Last sign-in': SelectableText(_date(c['lastLoginAt'])),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Avatar(initials: _initials(c['name'])),
            const SizedBox(width: AbraSpacing.md),
            Expanded(
              child: Text(_value(c['name']), style: theme.textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.lg),
        for (final e in entries.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AbraSpacing.xs),
                e.value,
              ],
            ),
          ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AbraColors.lightBlue,
            borderRadius: AbraRadius.medium,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: AbraSizes.iconSmall + 4,
                  color: AbraColors.deepBlue,
                ),
                const SizedBox(width: AbraSpacing.sm),
                Expanded(
                  child: Text(
                    'Login methods show the ways registered for this account. They are not a history of every login.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AbraColors.deepBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AbraSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  void _details(JsonMap c) {
    if (AbraBreakpoint.of(context).isTabletOrWider) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AbraSpacing.xl),
              child: _detailsBody(context, c),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AbraSpacing.lg,
              0,
              AbraSpacing.lg,
              AbraSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: _detailsBody(context, c),
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------- pieces

  Widget _kpiCard(String label, int? value) => AbraCard(
    semanticLabel: '$label: ${value ?? 'not available'}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
        ),
        const SizedBox(height: AbraSpacing.xs),
        if (_kpiBusy && value == null)
          const AbraSkeleton(width: 56, height: 28)
        else
          Text(
            value == null ? '-' : '$value',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
      ],
    ),
  );

  Widget _kpiRow(int columns) {
    const labels = [
      'Total customers',
      'Active',
      'Invited',
      'Suspended / deactivated',
    ];
    return _Grid(
      columns: columns,
      children: [for (var i = 0; i < 4; i++) _kpiCard(labels[i], _kpis[i])],
    );
  }

  Widget _searchField() => TextField(
    controller: _search,
    decoration: const InputDecoration(
      labelText: 'Search name, email or phone',
      prefixIcon: Icon(Icons.search_rounded),
    ),
    onChanged: (_) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => _filter(() {}),
      );
    },
  );

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    isExpanded: true,
    key: ValueKey('$label:$value'),
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final e in items.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) => onChanged(v ?? ''),
  );

  Widget _statusField() => _dropdown(
    label: 'Account status',
    value: _status,
    items: const {
      '': 'All statuses',
      'ACTIVE': 'Active',
      'INVITED': 'Invited',
      'SUSPENDED': 'Suspended',
      'DEACTIVATED': 'Deactivated',
    },
    onChanged: (v) => _filter(() => _status = v),
  );

  Widget _methodField() => _dropdown(
    label: 'Login method',
    value: _method,
    items: const {
      '': 'All login methods',
      'google': 'Google',
      'apple': 'Apple',
      'whatsapp': 'WhatsApp OTP',
      'password': 'Password',
    },
    onChanged: (v) => _filter(() => _method = v),
  );

  Widget _actions() => Wrap(
    spacing: AbraSpacing.sm,
    runSpacing: AbraSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SegmentedButton<_View>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, AbraSizes.minTouchTarget),
        ),
        segments: const [
          ButtonSegment(
            value: _View.list,
            icon: Icon(Icons.view_agenda_outlined),
            label: Text('List'),
          ),
          ButtonSegment(
            value: _View.table,
            icon: Icon(Icons.table_rows_outlined),
            label: Text('Table'),
          ),
        ],
        selected: {_view},
        onSelectionChanged: (s) => setState(() => _view = _lastView = s.first),
      ),
      TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AbraSizes.minTouchTarget),
        ),
        onPressed: () => _filter(() {
          _search.clear();
          _status = '';
          _method = '';
        }),
        child: const Text('Clear filters'),
      ),
      PopupMenuButton<bool>(
        enabled: !_exporting,
        tooltip: 'Export filtered customers',
        onSelected: _export,
        itemBuilder: (_) => const [
          PopupMenuItem(value: true, child: Text('Export Excel')),
          PopupMenuItem(value: false, child: Text('Export CSV')),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AbraSizes.minTouchTarget,
            minWidth: AbraSizes.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_rounded,
                  color: _exporting ? AbraColors.textDisabled : null,
                ),
                const SizedBox(width: AbraSpacing.sm),
                const Text('Export'),
              ],
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Refresh',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );

  Widget _filterPanel(AbraBreakpoint bp, double width) {
    final Widget content;
    if (bp == AbraBreakpoint.desktop && width >= 1080) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: _searchField()),
          const SizedBox(width: AbraSpacing.md),
          Expanded(flex: 2, child: _statusField()),
          const SizedBox(width: AbraSpacing.md),
          Expanded(flex: 2, child: _methodField()),
          const SizedBox(width: AbraSpacing.md),
          _actions(),
        ],
      );
    } else if (bp.isTabletOrWider) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchField(),
          const SizedBox(height: AbraSpacing.md),
          Row(
            children: [
              Expanded(child: _statusField()),
              const SizedBox(width: AbraSpacing.md),
              Expanded(child: _methodField()),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          Align(alignment: AlignmentDirectional.centerEnd, child: _actions()),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchField(),
          const SizedBox(height: AbraSpacing.md),
          _statusField(),
          const SizedBox(height: AbraSpacing.md),
          _methodField(),
          const SizedBox(height: AbraSpacing.md),
          _actions(),
        ],
      );
    }
    return AbraCard(child: content);
  }

  Widget _customerCard(JsonMap c) {
    final theme = Theme.of(context);
    return AbraCard(
      onTap: () => _details(c),
      semanticLabel:
          '${_value(c['name'])}, ${_statusLabel(c['status'])}. Opens details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(initials: _initials(c['name'])),
              const SizedBox(width: AbraSpacing.md),
              Expanded(
                child: Text(
                  _value(c['name']),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          _IconText(Icons.mail_outline_rounded, _value(c['email'])),
          const SizedBox(height: AbraSpacing.xs),
          _IconText(Icons.phone_outlined, _value(c['phone'])),
          const SizedBox(height: AbraSpacing.md),
          Wrap(
            spacing: AbraSpacing.sm,
            runSpacing: AbraSpacing.sm,
            children: [
              AbraStatusBadge(
                label: _statusLabel(c['status']),
                tone: _tone(c['status']),
              ),
              for (final m in _methodsOf(c))
                AbraStatusBadge(label: m, tone: AbraStatusTone.info),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          Text(
            'Registered ${_date(c['createdAt'])} · Last sign-in ${_date(c['lastLoginAt'])}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listView(int columns) => _Grid(
    columns: columns,
    children: [for (final c in _shown) _customerCard(c)],
  );

  Widget _tableView() {
    final theme = Theme.of(context);
    void sortBy(_Sort s, bool ascending) => setState(() {
      _sort = s;
      _ascending = ascending;
    });
    DataColumn column(String label, _Sort s) => DataColumn(
      label: Text(label),
      onSort: (_, ascending) => sortBy(s, ascending),
    );
    final sortIndex = _sort == null
        ? null
        : switch (_sort!) {
            _Sort.name => 0,
            _Sort.email => 1,
            _Sort.phone => 2,
            _Sort.status => 3,
            _Sort.registered => 5,
            _Sort.lastSignIn => 6,
          };
    return AbraCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => Scrollbar(
          controller: _tableScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _tableScroll,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth > 980
                    ? constraints.maxWidth
                    : 980,
              ),
              child: DataTable(
                showCheckboxColumn: false,
                sortColumnIndex: sortIndex,
                sortAscending: _ascending,
                headingRowColor: const WidgetStatePropertyAll(
                  AbraColors.lightBlue,
                ),
                headingTextStyle: theme.textTheme.labelMedium?.copyWith(
                  color: AbraColors.textSecondary,
                ),
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columns: [
                  column('Name', _Sort.name),
                  column('Email', _Sort.email),
                  column('Phone', _Sort.phone),
                  column('Status', _Sort.status),
                  const DataColumn(label: Text('Login methods')),
                  column('Registered', _Sort.registered),
                  column('Last sign-in', _Sort.lastSignIn),
                ],
                rows: [
                  for (final c in _shown)
                    DataRow(
                      onSelectChanged: (_) => _details(c),
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Avatar(initials: _initials(c['name']), size: 32),
                              const SizedBox(width: AbraSpacing.sm),
                              Text(
                                _value(c['name']),
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(_value(c['email']))),
                        DataCell(Text(_value(c['phone']))),
                        DataCell(
                          AbraStatusBadge(
                            label: _statusLabel(c['status']),
                            tone: _tone(c['status']),
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: AbraSpacing.xs,
                            runSpacing: AbraSpacing.xs,
                            children: [
                              for (final m in _methodsOf(c))
                                AbraStatusBadge(
                                  label: m,
                                  tone: AbraStatusTone.info,
                                ),
                            ],
                          ),
                        ),
                        DataCell(Text(_date(c['createdAt']))),
                        DataCell(Text(_date(c['lastLoginAt']))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletons(int columns) {
    if (_view == _View.table) {
      return AbraCard(
        child: Column(
          children: [
            for (var i = 0; i < 7; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AbraSpacing.sm),
                child: AbraSkeleton(height: 18),
              ),
          ],
        ),
      );
    }
    return _Grid(
      columns: columns,
      children: [
        for (var i = 0; i < 6; i++)
          const AbraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AbraSkeleton(width: 160, height: 18),
                SizedBox(height: AbraSpacing.md),
                AbraSkeleton(height: 14),
                SizedBox(height: AbraSpacing.sm),
                AbraSkeleton(width: 120, height: 14),
                SizedBox(height: AbraSpacing.md),
                AbraSkeleton(width: 80, height: 24, radius: AbraRadius.pill),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pager() {
    final pages = (_total / _pageSize).ceil().clamp(1, 1 << 30);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: !_busy && _page > 1 ? () => _goToPage(_page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text('Page $_page of $pages'),
        IconButton(
          tooltip: 'Next page',
          onPressed: !_busy && _page * _pageSize < _total
              ? () => _goToPage(_page + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _results(int columns) {
    if (_error != null) {
      return AbraStateView(
        kind: AbraStateKind.error,
        title: 'Couldn’t load customers',
        message: _error,
        actionLabel: 'Retry',
        onAction: _load,
      ).withHeight(320);
    }
    if (_busy) return _skeletons(columns);
    if (_customers.isEmpty) {
      return AbraStateView(
        kind: AbraStateKind.empty,
        title: 'No customers match these filters',
        message: 'Try a different name, email or phone, or clear the filters.',
        actionLabel: 'Clear filters',
        onAction: () => _filter(() {
          _search.clear();
          _status = '';
          _method = '';
        }),
      ).withHeight(320);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _view == _View.table ? _tableView() : _listView(columns),
        const SizedBox(height: AbraSpacing.lg),
        _pager(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bp = AbraBreakpoint.fromWidth(constraints.maxWidth);
        final gutter = AbraResponsive.gutterFor(bp);
        final columns = bp == AbraBreakpoint.desktop
            ? 3
            : bp.isTabletOrWider
            ? 2
            : 1;
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: AbraSpacing.xl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AbraSizes.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Customer accounts',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.sm),
                    Text(
                      'Find registered customers and see their contact details and login methods.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AbraColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.lg),
                    _kpiRow(bp.isTabletOrWider ? 4 : 2),
                    const SizedBox(height: AbraSpacing.lg),
                    _filterPanel(bp, constraints.maxWidth),
                    const SizedBox(height: AbraSpacing.lg),
                    if (_busy || _exporting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AbraSpacing.md),
                        child: LinearProgressIndicator(),
                      ),
                    Row(
                      children: [
                        Text(
                          _busy ? 'Loading…' : '$_total customers',
                          style: theme.textTheme.titleSmall,
                        ),
                        if (_view == _View.table && _sort != null) ...[
                          const SizedBox(width: AbraSpacing.md),
                          Flexible(
                            child: Text(
                              'Sorted within this page',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AbraColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    _results(columns),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

extension on Widget {
  Widget withHeight(double height) => SizedBox(height: height, child: this);
}

/// Equal-width columns; the cards of one row share the height of the tallest.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = AbraSpacing.md;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < children.length; start += columns) ...[
          if (start > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: start + i < children.length
                        ? children[start + i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.size = 40});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AbraColors.skyContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AbraColors.deepBlue,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _IconText extends StatelessWidget {
  const _IconText(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: AbraSizes.iconSmall + 2,
        color: AbraColors.textSecondary,
      ),
      const SizedBox(width: AbraSpacing.sm),
      Expanded(child: Text(text)),
    ],
  );
}
