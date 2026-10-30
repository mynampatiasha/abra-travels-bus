import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../app/providers.dart';
import '../../core/async_value_view.dart' show failureOf;
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../commission/commission_admin_manage_screen.dart' show formatRupees;
import '../kyc/admin_kyc_configuration.dart' show kycExcelBytes;

enum _View { list, table }

enum _Sort { name, email, phone, status, bookings, spent, registered }

/// Remembered while the app runs, so the page opens in the view last used.
_View _lastView = _View.list;

/// Customers (`/admin/customers`): the list with search and filters, one customer with bookings and
/// devices, block and unblock, sign out of all devices, delete.
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
    'page': page,
    'pageSize': size,
    if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    if (_status.isNotEmpty) 'status': _status,
    if (_method.isNotEmpty) 'signInMethod': _method,
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
          .get('admin/customers', query: _query(_page, _pageSize));
      final customers = response.decodeList((json) => _shape(json));
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
          'admin/customers',
          query: {
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
      count('SUSPENDED'),
      count('DEACTIVATED'),
    ]);
    if (!mounted || generation != _kpiGeneration) return;
    setState(() {
      _kpis = [results[0], results[1], results[2], results[3]];
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

  static const _methodLabels = {
    'google': 'Google',
    'apple': 'Apple',
    'whatsapp': 'WhatsApp OTP',
    'password': 'Password',
  };

  /// A row as the screen reads it: the way the person signs in as words, and the join date.
  static JsonMap _shape(JsonMap c) => {
    ...c,
    'loginMethods': [
      if (c['signInMethod'] is String)
        _methodLabels[c['signInMethod']] ?? '${c['signInMethod']}',
    ],
    'createdAt': c['joinedAt'],
  };

  List<String> _methodsOf(JsonMap c) => [
    for (final m in c['loginMethods'] as List? ?? const []) '$m',
  ];
  int _count(Object? value) => value is num ? value.toInt() : 0;
  String _spent(JsonMap c) => formatRupees(_count(c['spentPaise']));
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
      _Sort.bookings => '${_count(c['bookings'])}'.padLeft(9, '0'),
      _Sort.spent => '${_count(c['spentPaise'])}'.padLeft(12, '0'),
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
            .get('admin/customers', query: {...query, 'page': page});
        final rows = response.decodeList((json) => _shape(json));
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
          'Signs in with',
          'Bookings',
          'Spent (Rs)',
          'Joined',
        ],
        for (final c in all)
          [
            for (final key in ['name', 'email', 'phone', 'status'])
              '${c[key] ?? ''}',
            _methods(c),
            '${_count(c['bookings'])}',
            '${_count(c['spentPaise']) / 100}',
            '${c['createdAt'] ?? ''}',
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

  void _details(JsonMap c) {
    final access = ref.read(accessProvider);
    Widget body(BuildContext context) => _CustomerDetail(
      id: '${c['id']}',
      canUpdate: access.can(PermissionKeys.customersUpdate),
      canDelete: access.can(PermissionKeys.customersAccountDelete),
      onChanged: _refresh,
    );
    if (AbraBreakpoint.of(context).isTabletOrWider) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AbraSpacing.xl),
              child: body(context),
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
            child: body(context),
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
      'Suspended',
      'Deactivated',
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
      'SUSPENDED': 'Suspended',
      'DEACTIVATED': 'Deactivated',
    },
    onChanged: (v) => _filter(() => _status = v),
  );

  Widget _methodField() => _dropdown(
    label: 'Signs in with',
    value: _method,
    items: const {
      '': 'All sign-in methods',
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
            '${_count(c['bookings'])} bookings · ${_spent(c)} spent · Joined ${_date(c['createdAt'])}',
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
            _Sort.bookings => 5,
            _Sort.spent => 6,
            _Sort.registered => 7,
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
                  const DataColumn(label: Text('Signs in with')),
                  column('Bookings', _Sort.bookings),
                  column('Spent', _Sort.spent),
                  column('Joined', _Sort.registered),
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
                        DataCell(Text('${_count(c['bookings'])}')),
                        DataCell(Text(_spent(c))),
                        DataCell(Text(_date(c['createdAt']))),
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

/// One customer: profile, bookings, the devices signed in, and the actions staff may take. The
/// server decides what is allowed; the buttons are only hidden for people without the permission.
class _CustomerDetail extends ConsumerStatefulWidget {
  const _CustomerDetail({
    required this.id,
    required this.canUpdate,
    required this.canDelete,
    required this.onChanged,
  });

  final String id;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onChanged;

  @override
  ConsumerState<_CustomerDetail> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends ConsumerState<_CustomerDetail> {
  JsonMap? _detail;
  String? _error;
  String? _notice;
  bool _busy = false;

  ApiClient get _api => ref.read(appDependenciesProvider).apiClient;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  /// A sentence the person can act on: the server's own words when it gave one.
  String _say(Object error) {
    final failure = failureOf(error);
    if (failure is ApiFailure && failure.message.isNotEmpty && failure.statusCode < 500) {
      return failure.message;
    }
    return failureText(AbraLocalizations.of(context), error);
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.get('admin/customers/${widget.id}');
      final data = response.data;
      if (mounted) setState(() => _detail = data is Map ? asJsonMap(data) : null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = _say(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs one action; shows the server's sentence when it is refused.
  Future<void> _act(
    Future<Object?> Function() call, {
    required String done,
    bool closes = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await call();
      widget.onChanged();
      if (!mounted) return;
      if (closes) {
        Navigator.pop(context);
        return;
      }
      setState(() => _notice = done);
      await _load();
    } on Object catch (e) {
      if (mounted) setState(() => _error = _say(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _block() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _BlockDialog(),
    );
    if (reason == null || !mounted) return;
    await _act(
      () => _api.post('admin/customers/${widget.id}/block', body: {'reason': reason}),
      done: 'Account blocked. The customer is signed out everywhere.',
    );
  }

  Future<void> _confirmThen(
    String title,
    String message,
    String label,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await action();
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    return parsed == null
        ? 'Not recorded'
        : MaterialLocalizations.of(context).formatMediumDate(parsed);
  }

  String _text(Object? value) => value == null || '$value'.isEmpty ? 'Not provided' : '$value';

  int _int(Object? value) => value is num ? value.toInt() : 0;

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: AbraSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AbraColors.textSecondary,
          ),
        ),
        const SizedBox(height: AbraSpacing.xs),
        value,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _detail;
    final status = '${c?['status'] ?? ''}';
    final blocked = c?['blocked'];
    final bookings = [
      for (final b in c?['recentBookings'] as List? ?? const [])
        if (b is Map) asJsonMap(b),
    ];
    final devices = [
      for (final d in c?['devices'] as List? ?? const [])
        if (d is Map) asJsonMap(d),
    ];
    final methodLabel = _AdminCustomersPageState._methodLabels['${c?['signInMethod']}'] ??
        _text(c?['signInMethod']);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c == null ? 'Customer' : _text(c['name']),
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.md),
        if (_busy && c == null) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.md),
            child: Text(_error!, style: const TextStyle(color: AbraColors.danger)),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.md),
            child: Text(_notice!, style: TextStyle(color: Colors.green.shade800)),
          ),
        if (c == null && _error != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ),
        if (c != null) ...[
          _row('Email', SelectableText(_text(c['email']))),
          _row('Phone', SelectableText(_text(c['phone']))),
          _row('Signs in with', Text(methodLabel)),
          _row(
            'Account status',
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AbraStatusBadge(
                label: status.isEmpty
                    ? 'Unknown'
                    : status[0] + status.substring(1).toLowerCase(),
                tone: switch (status) {
                  'ACTIVE' => AbraStatusTone.success,
                  'SUSPENDED' => AbraStatusTone.danger,
                  _ => AbraStatusTone.neutral,
                },
              ),
            ),
          ),
          if (blocked is Map)
            Container(
              margin: const EdgeInsets.only(bottom: AbraSpacing.md),
              padding: const EdgeInsets.all(AbraSpacing.md),
              decoration: const BoxDecoration(
                color: AbraColors.dangerContainer,
                borderRadius: AbraRadius.medium,
              ),
              child: Text(
                'Blocked on ${_date(blocked['at'])}: ${blocked['reason']}',
                style: const TextStyle(color: AbraColors.danger),
              ),
            ),
          _row('Joined', Text(_date(c['joinedAt']))),
          _row(
            'Bookings',
            Text('${_int(c['bookings'])} bookings, ${formatRupees(_int(c['spentPaise']))} spent'),
          ),
          _row(
            'Latest bookings',
            bookings.isEmpty
                ? const Text('No bookings yet')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final b in bookings)
                        Text(
                          '${b['pnr']}  |  ${'${b['status']}'.replaceAll('_', ' ').toLowerCase()}  |  ${formatRupees(_int(b['amountPaise']))}',
                        ),
                    ],
                  ),
          ),
          _row(
            'Signed in on',
            devices.isEmpty
                ? const Text('No device is signed in')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final d in devices)
                        Text(
                          '${_text(d['deviceName'] ?? d['clientType'])}, last used ${_date(d['lastUsedAt'])}',
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          Wrap(
            spacing: AbraSpacing.sm,
            runSpacing: AbraSpacing.sm,
            children: [
              if (widget.canUpdate && status == 'ACTIVE')
                OutlinedButton(
                  onPressed: _busy ? null : _block,
                  child: const Text('Block account'),
                ),
              if (widget.canUpdate && status == 'SUSPENDED')
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => _api.post('admin/customers/${widget.id}/unblock'),
                          done: 'Account unblocked.',
                        ),
                  child: const Text('Unblock'),
                ),
              if (widget.canUpdate)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _confirmThen(
                          'Sign out of all devices?',
                          'The customer is signed out everywhere and can sign in again.',
                          'Sign out all devices',
                          () => _act(
                            () => _api.post('admin/customers/${widget.id}/sessions/revoke'),
                            done: 'Signed out of all devices.',
                          ),
                        ),
                  child: const Text('Sign out all devices'),
                ),
              if (widget.canDelete)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AbraColors.danger),
                  onPressed: _busy
                      ? null
                      : () => _confirmThen(
                          'Delete this customer?',
                          'The account leaves every list and cannot sign in. You can bring it back later.',
                          'Delete',
                          () => _act(
                            () => _api.delete('admin/customers/${widget.id}'),
                            done: 'Customer deleted.',
                            closes: true,
                          ),
                        ),
                  child: const Text('Delete'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BlockDialog extends StatefulWidget {
  const _BlockDialog();

  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  final _reason = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Block account'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _reason,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Reason',
            helperText: 'Staff see this reason. The customer does not.',
            errorText: _problem,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _reason.text.trim();
            if (text.isEmpty) {
              setState(() => _problem = 'Write why this account is blocked');
              return;
            }
            Navigator.pop(context, text);
          },
          child: const Text('Block'),
        ),
      ],
    );
  }
}
