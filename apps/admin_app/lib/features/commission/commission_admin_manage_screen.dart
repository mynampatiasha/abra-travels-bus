// Commission page (admin app), page `commission` of the admin demo (#/commission).
//
// One file on purpose: the screen, its dialogs and every data call live here. The page title and
// the line under it come from the admin shell (navCommission, hintCommission).
//
// Money rules: values travel as whole numbers. PERCENT value = percent x 100 (1000 = 10%),
// FLAT value = paise per seat. The screen never works out a customer price itself:
// the Price calculator tab asks the server (POST /admin/commission/calculate).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import '../../l10n/admin_strings.dart';

/* ============================================================== helpers */

/// "10%" or "Rs 60 per seat".
String formatCommission(String mode, int value) {
  if (mode == 'PERCENT') return '${_trim2(value / 100)}%';
  return 'Rs ${_trim2(value / 100)} per seat';
}

/// Paise to "Rs 2,400" or "Rs 60.50" (Indian digit grouping).
String formatRupees(int paise) {
  final neg = paise < 0;
  final p = paise.abs();
  final rupees = p ~/ 100;
  final rem = p % 100;
  final body = rem == 0
      ? _group(rupees)
      : '${_group(rupees)}.${rem.toString().padLeft(2, '0')}';
  return '${neg ? '-' : ''}Rs $body';
}

String _group(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last';
}

String _trim2(double n) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  var s = n.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

/// What the person typed ("10", "12.5") to the stored whole number (x 100). Null if not a number.
int? parseValueX100(String text) {
  final d = double.tryParse(text.trim());
  if (d == null || d.isNaN || d.isInfinite) return null;
  return (d * 100).round();
}

/// Today's date in India as YYYY-MM-DD. Effective dates are India dates, like the server.
String todayIst() {
  final d = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return _iso(d);
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtDateTime(DateTime? d) {
  if (d == null) return '';
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final l = d.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${m[l.month - 1]} ${l.year}, $hh:$mm';
}

/// "Operator", "Route" or "Bus type", as the demo's pills read.
String scopeLabel(AbraLocalizations l10n, String scope) => switch (scope) {
  'OPERATOR' => l10n.text(AdminStrings.commScopeOperator),
  'ROUTE' => l10n.text(AdminStrings.commScopeRoute),
  'BUS_TYPE' => l10n.text(AdminStrings.commScopeBusType),
  _ => scope,
};

int _asInt(Object? v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
String _asStr(Object? v) => v == null ? '' : '$v';
Map<String, dynamic> _asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _asList(Object? v) => v is List ? v : <dynamic>[];

/* ================================================================ models */

class CommissionRule {
  CommissionRule({
    required this.id,
    required this.scope,
    required this.targetId,
    required this.targetName,
    required this.mode,
    required this.value,
    required this.effectiveFrom,
    required this.agreedNote,
    required this.version,
    required this.status,
    this.versions = const [],
  });

  final String id;
  final String scope;
  final String targetId;
  final String targetName;
  final String mode;
  final int value;
  final String effectiveFrom;
  final String agreedNote;
  final int version;
  final String status;
  final List<RuleVersionInfo> versions;

  bool get isActive => status == 'ACTIVE';

  factory CommissionRule.fromJson(Map<String, dynamic> j) => CommissionRule(
    id: _asStr(j['id']),
    scope: _asStr(j['scope']),
    targetId: _asStr(j['targetId']),
    targetName: _asStr(j['targetName']),
    mode: _asStr(j['mode']),
    value: _asInt(j['value']),
    effectiveFrom: _asStr(j['effectiveFrom']),
    agreedNote: _asStr(j['agreedNote']),
    version: _asInt(j['version']),
    status: _asStr(j['status']),
    versions: _asList(
      j['versions'],
    ).map((e) => RuleVersionInfo.fromJson(_asMap(e))).toList(),
  );
}

class RuleVersionInfo {
  RuleVersionInfo({
    required this.version,
    required this.mode,
    required this.value,
    required this.effectiveFrom,
    required this.agreedNote,
  });
  final int version;
  final String mode;
  final int value;
  final String effectiveFrom;
  final String agreedNote;

  factory RuleVersionInfo.fromJson(Map<String, dynamic> j) => RuleVersionInfo(
    version: _asInt(j['version']),
    mode: _asStr(j['mode']),
    value: _asInt(j['value']),
    effectiveFrom: _asStr(j['effectiveFrom']),
    agreedNote: _asStr(j['agreedNote']),
  );
}

class DefaultRule {
  DefaultRule({
    required this.mode,
    required this.value,
    required this.configured,
  });
  final String mode;
  final int value;

  /// False until someone saves a default: nothing is assumed meanwhile.
  final bool configured;
  bool get isFallback => !configured;
  factory DefaultRule.fromJson(Map<String, dynamic> j) {
    final mode = _asStr(j['mode']);
    return DefaultRule(
      mode: mode.isEmpty ? 'PERCENT' : mode,
      value: _asInt(j['value']),
      configured: j['configured'] == true,
    );
  }
}

class HistoryItem {
  HistoryItem({required this.label, required this.who, required this.when});

  /// "CR-1: Edited to v2", as the server words it.
  final String label;
  final String who;
  final DateTime? when;

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
    label: _asStr(j['label']),
    who: _asStr(j['who']),
    when: DateTime.tryParse(_asStr(j['at'])),
  );
}

class TargetOption {
  const TargetOption(this.id, this.name);
  final String id;
  final String name;
}

class CalcResult {
  CalcResult({
    required this.ruleId,
    required this.scope,
    required this.targetName,
    required this.mode,
    required this.value,
    required this.gstPct,
    required this.amounts,
  });
  final String ruleId;
  final String scope;
  final String targetName;
  final String mode;
  final int value;
  final num gstPct;
  final Map<String, int> amounts;

  factory CalcResult.fromJson(Map<String, dynamic> j) {
    final r = _asMap(j['rule']);
    final a = _asMap(j['amounts']);
    return CalcResult(
      ruleId: _asStr(r['ruleId']),
      scope: _asStr(r['scope']),
      targetName: _asStr(r['targetName']),
      mode: _asStr(r['mode']),
      value: _asInt(r['value']),
      gstPct: j['gstPct'] is num ? j['gstPct'] as num : 0,
      amounts: a.map((k, v) => MapEntry(k, _asInt(v))),
    );
  }
}

class RulesPage {
  RulesPage(this.items, this.total, this.page, this.pageSize);
  final List<CommissionRule> items;
  final int total;
  final int page;
  final int pageSize;
}

/// What went wrong, in words a person can act on; `field` names the input at fault when the server says so.
class CommissionApiError implements Exception {
  CommissionApiError(this.message, {this.field, this.status});
  final String message;
  final String? field;
  final int? status;
  @override
  String toString() => message;

  factory CommissionApiError.from(Object e) {
    final failure = failureOf(e);
    if (failure is ApiFailure) {
      final issues = failure.details['issues'];
      if (issues is List && issues.isNotEmpty && issues.first is Map) {
        final first = Map<String, dynamic>.from(issues.first as Map);
        final path = _asStr(first['path']);
        return CommissionApiError(
          _asStr(first['message']).isEmpty
              ? failure.message
              : _asStr(first['message']),
          field: path.isEmpty ? null : path.split('.').last,
          status: failure.statusCode,
        );
      }
      if (failure.isForbidden) {
        return CommissionApiError(
          'You do not have permission to do this.',
          status: failure.statusCode,
        );
      }
      return CommissionApiError(
        failure.message.isEmpty ? 'Something went wrong.' : failure.message,
        status: failure.statusCode,
      );
    }
    return CommissionApiError(
      'Could not reach the server. Check your connection and try again.',
    );
  }
}

/* ================================================================== api */

class CommissionApi {
  CommissionApi(this._client);
  final ApiClient _client;
  static const String _b = 'admin/commission';

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on CommissionApiError {
      rethrow;
    } on Object catch (e) {
      throw CommissionApiError.from(e);
    }
  }

  Map<String, Object?> _filters(String search, String scope, String status) => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (scope != 'ALL') 'scope': scope,
    if (status != 'ALL') 'status': status,
  };

  Future<RulesPage> listRules({
    String search = '',
    String scope = 'ALL',
    String status = 'ALL',
    String sort = 'id',
    bool descending = false,
    int page = 1,
    int pageSize = 10,
  }) => _run(() async {
    final res = await _client.get(
      '$_b/rules',
      query: {
        ..._filters(search, scope, status),
        'sort': sort,
        'dir': descending ? 'desc' : 'asc',
        'page': page,
        'pageSize': pageSize,
      },
    );
    final info = res.page;
    final items = res
        .decodeList((json) => json)
        .map((e) => CommissionRule.fromJson(_asMap(e)))
        .toList();
    return RulesPage(
      items,
      info?.total ?? items.length,
      info?.page ?? page,
      info?.pageSize ?? pageSize,
    );
  });

  Future<CommissionRule> getRule(String id) => _run(() async {
    final res = await _client.get('$_b/rules/$id');
    return CommissionRule.fromJson(_asMap(res.decodeObject((json) => json)));
  });

  Future<CommissionRule> createRule(Map<String, dynamic> body) => _run(
    () async {
      final res = await _client.post('$_b/rules', body: body);
      return CommissionRule.fromJson(_asMap(res.decodeObject((json) => json)));
    },
  );

  Future<CommissionRule> saveNewVersion(String id, Map<String, dynamic> body) =>
      _run(() async {
        final res = await _client.post('$_b/rules/$id/versions', body: body);
        return CommissionRule.fromJson(
          _asMap(res.decodeObject((json) => json)),
        );
      });

  Future<void> setActive(String id, bool active) => _run(() async {
    await _client.patch('$_b/rules/$id/active', body: {'active': active});
  });

  Future<void> deleteRule(String id) => _run(() async {
    await _client.delete('$_b/rules/$id');
  });

  /// Undo for a delete. Returns true if the rule came back switched off.
  Future<bool> restoreRule(String id) => _run(() async {
    final res = await _client.post('$_b/rules/$id/restore');
    return _asMap(res.decodeObject((json) => json))['restoredInactive'] == true;
  });

  Future<DefaultRule> getDefault() => _run(() async {
    final res = await _client.get('$_b/default');
    return DefaultRule.fromJson(_asMap(res.decodeObject((json) => json)));
  });

  Future<DefaultRule> saveDefault(String mode, int value) => _run(() async {
    await _client.put('$_b/default', body: {'mode': mode, 'value': value});
    return getDefault();
  });

  Future<CalcResult> calculate({
    required int farePerSeatPaise,
    required int seats,
    required String operatorId,
    String? routeId,
    String? busTypeId,
  }) => _run(() async {
    final res = await _client.post(
      '$_b/calculate',
      body: {
        'farePerSeatPaise': farePerSeatPaise,
        'seats': seats,
        'operatorId': operatorId,
        'routeId': ?routeId,
        'busTypeId': ?busTypeId,
      },
    );
    return CalcResult.fromJson(_asMap(res.decodeObject((json) => json)));
  });

  Future<(List<HistoryItem>, int)> history({int page = 1, int pageSize = 20}) =>
      _run(() async {
        final res = await _client.get(
          '$_b/history',
          query: {'page': page, 'pageSize': pageSize},
        );
        final items = res
            .decodeList((json) => json)
            .map((e) => HistoryItem.fromJson(_asMap(e)))
            .toList();
        return (items, res.page?.total ?? items.length);
      });

  /// CSV of the rows that match the filters (the server's own export, audited). Returns the file name and bytes.
  Future<(String, Uint8List)> exportCsv({
    String search = '',
    String scope = 'ALL',
    String status = 'ALL',
  }) => _run(() async {
    final query = Uri(
      queryParameters: {
        'format': 'csv',
        ..._filters(search, scope, status).map((k, v) => MapEntry(k, '$v')),
      },
    ).query;
    final bytes = await _client.getBytes('$_b/rules/export?$query');
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    return ('commission-rules-$stamp.csv', bytes);
  });

  /// Operators, routes or bus types to pick from (`GET /admin/commission/targets`).
  Future<List<TargetOption>> targets(String scope) => _run(() async {
    final res = await _client.get('$_b/targets', query: {'scope': scope});
    return res
        .decodeList((json) => json)
        .map((e) => _asMap(e))
        .where((m) => _asStr(m['id']).isNotEmpty)
        .map((m) => TargetOption(_asStr(m['id']), _asStr(m['name'])))
        .toList();
  });
}

/* ================================================================ screen */

/// The Rules table columns, in the demo's order, with the sort key the server takes.
const List<(String, String)> _ruleColumns = [
  ('id', AdminStrings.commColId),
  ('scope', AdminStrings.commAppliesTo),
  ('target', AdminStrings.commColTarget),
  ('commission', AdminStrings.commColCommission),
  ('from', AdminStrings.commColFrom),
  ('version', AdminStrings.commColVersion),
  ('status', AdminStrings.commStatus),
  ('note', AdminStrings.commColNote),
];

class CommissionAdminManageScreen extends ConsumerStatefulWidget {
  const CommissionAdminManageScreen({super.key});

  @override
  ConsumerState<CommissionAdminManageScreen> createState() =>
      _CommissionAdminManageScreenState();
}

class _CommissionAdminManageScreenState
    extends ConsumerState<CommissionAdminManageScreen>
    with SingleTickerProviderStateMixin {
  late final CommissionApi _api = CommissionApi(
    ref.read(appDependenciesProvider).apiClient,
  );
  late final TabController _tabs = TabController(length: 3, vsync: this);

  // What the person may do. The server checks again; this only hides buttons.
  bool get _canEdit =>
      ref.read(accessProvider).can(PermissionKeys.commissionsManage);
  bool get _canDelete =>
      ref.read(accessProvider).can(PermissionKeys.commissionsDelete);
  bool get _canExport =>
      ref.read(accessProvider).can(PermissionKeys.commissionsExport);

  // Rules tab state
  DefaultRule? _default;
  RulesPage? _page;
  bool _loading = true;
  String? _error;
  String _search = '';
  String _scope = 'ALL';
  String _status = 'ALL';
  String _sort = 'id';
  bool _descending = false;
  int _pageNo = 1;
  bool _tableView = true;
  String? _busyId;
  bool _exporting = false;
  Timer? _debounce;
  final TextEditingController _searchCtl = TextEditingController();

  // Targets cache (operators, routes, bus types)
  final Map<String, List<TargetOption>> _targets = {};

  // Calculator tab state
  final TextEditingController _fareCtl = TextEditingController(text: '1200');
  final TextEditingController _seatsCtl = TextEditingController(text: '2');
  String? _calcOperator;
  String? _calcRoute;
  String? _calcBusType;
  CalcResult? _calc;
  String? _calcError;
  bool _calcBusy = false;
  bool _calcReady = false;

  // History tab state
  List<HistoryItem> _history = [];
  int _historyTotal = 0;
  bool _historyLoading = false;
  bool _historyLoaded = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {});
      if (_tabs.index == 1) unawaited(_prepareCalculator());
      if (_tabs.index == 2 && !_historyLoaded) {
        unawaited(_loadHistory(reset: true));
      }
    });
    unawaited(_loadRules(withDefault: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _searchCtl.dispose();
    _fareCtl.dispose();
    _seatsCtl.dispose();
    super.dispose();
  }

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  void _toast(String msg, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          action: action,
          duration: Duration(seconds: action == null ? 3 : 8),
        ),
      );
  }

  /* ------------------------------------------------------------- loading */

  Future<void> _loadRules({bool withDefault = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _api.listRules(
          search: _search,
          scope: _scope,
          status: _status,
          sort: _sort,
          descending: _descending,
          page: _pageNo,
        ),
        if (withDefault) _api.getDefault(),
      ]);
      if (!mounted) return;
      setState(() {
        _page = results[0]! as RulesPage;
        if (withDefault) _default = results[1]! as DefaultRule;
        _loading = false;
      });
    } on CommissionApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadDefault() async {
    try {
      final d = await _api.getDefault();
      if (mounted) setState(() => _default = d);
    } on CommissionApiError catch (e) {
      _toast(e.message);
    }
  }

  Future<List<TargetOption>> _targetsFor(String scope) async {
    final cached = _targets[scope];
    if (cached != null) return cached;
    final list = await _api.targets(scope);
    _targets[scope] = list;
    return list;
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search = v;
      _pageNo = 1;
      unawaited(_loadRules());
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchCtl.clear();
    _search = '';
    _scope = 'ALL';
    _status = 'ALL';
    _pageNo = 1;
    unawaited(_loadRules());
  }

  /// A header pressed: sort by that column, or turn the order round when it already is.
  void _sortBy(String key) {
    setState(() {
      if (_sort == key) {
        _descending = !_descending;
      } else {
        _sort = key;
        _descending = false;
      }
      _pageNo = 1;
    });
    unawaited(_loadRules());
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final (name, bytes) = await _api.exportCsv(
        search: _search,
        scope: _scope,
        status: _status,
      );
      downloadBytesFile(name, bytes, mimeType: 'text/csv');
    } on CommissionApiError catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /* ------------------------------------------------------------- actions */

  Future<void> _changeDefault() async {
    final d = _default;
    if (d == null) return;
    final msg = await showDialog<String>(
      context: context,
      builder: (_) => _DefaultDialog(api: _api, current: d),
    );
    if (msg != null) {
      _toast(msg);
      await _loadDefault();
      _historyLoaded = false;
    }
  }

  Future<void> _openRuleDialog({CommissionRule? rule}) async {
    final msg = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RuleDialog(api: _api, rule: rule, loadTargets: _targetsFor),
    );
    if (msg != null) {
      _toast(msg);
      _historyLoaded = false;
      await _loadRules();
    }
  }

  Future<void> _toggle(CommissionRule r) async {
    setState(() => _busyId = r.id);
    try {
      await _api.setActive(r.id, !r.isActive);
      _toast(
        _l10n.text(
          r.isActive ? AdminStrings.commRuleOff : AdminStrings.commRuleOn,
        ),
      );
      _historyLoaded = false;
      await _loadRules();
    } on CommissionApiError catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(CommissionRule r) async {
    final l10n = _l10n;
    final ok = await showAbraConfirmDialog(
      context,
      title: l10n.text(AdminStrings.commDeleteTitle, {'id': r.id}),
      message: l10n.text(AdminStrings.commDeleteMessage),
      confirmLabel: l10n.text(AdminStrings.commDelete),
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = r.id);
    try {
      await _api.deleteRule(r.id);
      _historyLoaded = false;
      await _loadRules();
      _toast(
        l10n.text(AdminStrings.commDeleted, {'id': r.id}),
        action: SnackBarAction(
          label: l10n.text(AdminStrings.commUndo),
          onPressed: () => unawaited(_undoDelete(r)),
        ),
      );
    } on CommissionApiError catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _undoDelete(CommissionRule r) async {
    try {
      final inactive = await _api.restoreRule(r.id);
      _historyLoaded = false;
      await _loadRules();
      // The demo says nothing after Undo; only the switched-off case needs words
      if (inactive) _toast(_l10n.text(AdminStrings.commRestoredOff));
    } on CommissionApiError catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _openView(CommissionRule r) async {
    final act = await showDialog<String>(
      context: context,
      builder: (_) => _ViewDialog(
        api: _api,
        ruleId: r.id,
        canEdit: _canEdit,
        canDelete: _canDelete,
      ),
    );
    if (act == 'edit') {
      await _openRuleDialog(rule: r);
    } else if (act == 'delete') {
      await _delete(r);
    }
  }

  /* ----------------------------------------------------------- calculator */

  Future<void> _prepareCalculator() async {
    if (_calcReady) return;
    try {
      final ops = await _targetsFor('OPERATOR');
      final bts = await _targetsFor('BUS_TYPE');
      await _targetsFor('ROUTE');
      if (!mounted) return;
      setState(() {
        _calcOperator ??= ops.isEmpty ? null : ops.first.id;
        _calcBusType ??= bts.isEmpty ? null : bts.first.id;
        _calcReady = true;
      });
      // The demo shows the result straight away
      if (_calcOperator != null) await _calculate();
    } on CommissionApiError catch (e) {
      if (mounted) setState(() => _calcError = e.message);
    }
  }

  Future<void> _calculate() async {
    final fare = parseValueX100(_fareCtl.text);
    final seats = int.tryParse(_seatsCtl.text.trim());
    if (fare == null || fare < 0) {
      _toast(_l10n.text(AdminStrings.commErrValue));
      return;
    }
    if (seats == null || seats < 1 || seats > 6) {
      _toast(_l10n.text(AdminStrings.commSeatsRange));
      return;
    }
    if (_calcOperator == null) {
      _toast(_l10n.text(AdminStrings.commErrTarget));
      return;
    }
    setState(() {
      _calcBusy = true;
      _calcError = null;
    });
    try {
      final r = await _api.calculate(
        farePerSeatPaise: fare,
        seats: seats,
        operatorId: _calcOperator!,
        routeId: _calcRoute,
        busTypeId: _calcBusType,
      );
      if (mounted) setState(() => _calc = r);
    } on CommissionApiError catch (e) {
      if (mounted) setState(() => _calcError = e.message);
    } finally {
      if (mounted) setState(() => _calcBusy = false);
    }
  }

  /* -------------------------------------------------------------- history */

  Future<void> _loadHistory({required bool reset}) async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final next = reset ? 1 : (_history.length ~/ 20) + 1;
      final (items, total) = await _api.history(page: next);
      if (!mounted) return;
      setState(() {
        _history = reset ? items : [..._history, ...items];
        _historyTotal = total;
        _historyLoaded = true;
        _historyLoading = false;
      });
    } on CommissionApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.message;
        _historyLoading = false;
      });
    }
  }

  /* ---------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final compact = AbraBreakpoint.of(context).isPhone;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? AbraSpacing.md : AbraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l10n.text(AdminStrings.commTabRules)),
                Tab(text: l10n.text(AdminStrings.commTabCalc)),
                Tab(text: l10n.text(AdminStrings.commTabHistory)),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          switch (_tabs.index) {
            1 => _calculatorTab(compact),
            2 => _historyTab(),
            _ => _rulesTab(compact),
          },
        ],
      ),
    );
  }

  /* ----------------------------------------------------------- rules tab */

  Widget _rulesTab(bool compact) {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final d = _default;
    final useTable = _tableView && !compact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoBanner(l10n.text(AdminStrings.commRuleOrder)),
        const SizedBox(height: AbraSpacing.md),
        AbraCard(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.sm,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.text(AdminStrings.commDefaultTitle),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    l10n.text(
                      d != null && d.isFallback
                          ? AdminStrings.commDefaultFallback
                          : AdminStrings.commDefaultHint,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d == null
                        ? '...'
                        : d.isFallback
                        ? l10n.text(AdminStrings.commDefaultNotSaved)
                        : d.mode == 'PERCENT'
                        ? formatCommission(d.mode, d.value)
                        : formatRupees(d.value),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_canEdit) ...[
                    const SizedBox(width: AbraSpacing.md),
                    AbraButton(
                      label: l10n.text(AdminStrings.commChange),
                      icon: Icons.edit_outlined,
                      variant: AbraButtonVariant.secondary,
                      onPressed: d == null ? null : _changeDefault,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        _toolbar(compact),
        const SizedBox(height: AbraSpacing.md),
        _rulesBody(useTable),
      ],
    );
  }

  /// Search, Applies to, Status, Clear, Export CSV, New rule, Table or List: the demo's bar.
  Widget _toolbar(bool compact) {
    final l10n = _l10n;
    final all = l10n.text(AdminStrings.listAll);
    Widget dropdown(
      String label,
      String value,
      Map<String, String> items,
      ValueChanged<String> onPicked,
    ) => SizedBox(
      width: compact ? double.infinity : 170,
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>('$label:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          DropdownMenuItem(value: 'ALL', child: Text(all)),
          for (final e in items.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => onPicked(v ?? 'ALL'),
      ),
    );

    return Wrap(
      spacing: AbraSpacing.sm,
      runSpacing: AbraSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: compact ? double.infinity : 240,
          child: TextField(
            controller: _searchCtl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: l10n.text(AdminStrings.commSearch),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        dropdown(
          l10n.text(AdminStrings.commAppliesTo),
          _scope,
          {
            'OPERATOR': l10n.text(AdminStrings.commScopeOperator),
            'ROUTE': l10n.text(AdminStrings.commScopeRoute),
            'BUS_TYPE': l10n.text(AdminStrings.commScopeBusType),
          },
          (v) {
            _scope = v;
            _pageNo = 1;
            unawaited(_loadRules());
          },
        ),
        dropdown(
          l10n.text(AdminStrings.commStatus),
          _status,
          {
            'ACTIVE': l10n.text(AdminStrings.commStatusActive),
            'INACTIVE': l10n.text(AdminStrings.commStatusInactive),
          },
          (v) {
            _status = v;
            _pageNo = 1;
            unawaited(_loadRules());
          },
        ),
        AbraButton(
          label: l10n.text(AdminStrings.commClear),
          icon: Icons.close,
          variant: AbraButtonVariant.text,
          onPressed: _clearFilters,
        ),
        if (_canExport)
          AbraButton(
            label: l10n.text(AdminStrings.commExportCsv),
            icon: Icons.file_download_outlined,
            variant: AbraButtonVariant.text,
            isLoading: _exporting,
            onPressed: _export,
          ),
        if (_canEdit)
          AbraButton(
            label: l10n.text(AdminStrings.commNewRule),
            icon: Icons.add,
            onPressed: () => unawaited(_openRuleDialog()),
          ),
        if (!compact)
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<bool>(
                value: true,
                icon: const Icon(Icons.grid_view, size: 16),
                label: Text(l10n.text(AdminStrings.commTableView)),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: const Icon(Icons.view_list, size: 16),
                label: Text(l10n.text(AdminStrings.commListView)),
              ),
            ],
            selected: {_tableView},
            onSelectionChanged: (s) => setState(() => _tableView = s.first),
          ),
      ],
    );
  }

  Widget _rulesBody(bool useTable) {
    final l10n = _l10n;
    if (_loading && _page == null) {
      return const AbraCard(child: AbraLoadingView());
    }
    if (_error != null) {
      return AbraCard(
        child: AbraStateView(
          kind: AbraStateKind.error,
          message: _error,
          actionLabel: l10n.text(AbraStrings.commonRetry),
          onAction: () => unawaited(_loadRules(withDefault: true)),
        ),
      );
    }
    final page = _page!;
    final filtered = _search.isNotEmpty || _scope != 'ALL' || _status != 'ALL';
    final pages = page.total == 0
        ? 1
        : ((page.total + page.pageSize - 1) ~/ page.pageSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        if (page.items.isEmpty)
          AbraCard(
            child: AbraStateView(
              kind: AbraStateKind.empty,
              title: l10n.text(
                filtered
                    ? AdminStrings.commEmptyFilteredTitle
                    : AdminStrings.commEmptyTitle,
              ),
              message: l10n.text(
                filtered
                    ? AdminStrings.commEmptyFiltered
                    : AdminStrings.commEmptyMessage,
              ),
              actionLabel: filtered
                  ? l10n.text(AdminStrings.commClearFilters)
                  : null,
              onAction: filtered ? _clearFilters : null,
            ),
          )
        else if (useTable)
          _table(page.items)
        else
          for (final r in page.items) _ruleCard(r),
        const SizedBox(height: AbraSpacing.sm),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: AbraSpacing.xs,
          children: [
            Text(
              page.total == 1
                  ? l10n.text(AdminStrings.commResultOne)
                  : l10n.text(AdminStrings.commResults, {'n': page.total}),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
            ),
            // A Wrap, so on a phone Next drops below instead of overflowing
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AbraButton(
                  label: l10n.text(AdminStrings.commPrevious),
                  icon: Icons.chevron_left,
                  variant: AbraButtonVariant.text,
                  onPressed: _pageNo <= 1 || _loading
                      ? null
                      : () {
                          _pageNo--;
                          unawaited(_loadRules());
                        },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AbraSpacing.sm,
                  ),
                  child: Text(
                    l10n.text(AdminStrings.commPage, {
                      'page': _pageNo,
                      'pages': pages,
                    }),
                  ),
                ),
                AbraButton(
                  label: l10n.text(AdminStrings.commNext),
                  icon: Icons.chevron_right,
                  variant: AbraButtonVariant.text,
                  onPressed: _pageNo >= pages || _loading
                      ? null
                      : () {
                          _pageNo++;
                          unawaited(_loadRules());
                        },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// The demo's table: eight sortable columns, then Edit and Deactivate, then View and Delete.
  Widget _table(List<CommissionRule> rows) {
    final l10n = _l10n;
    final heading = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AbraColors.textSecondary,
      fontWeight: FontWeight.w800,
    );
    DataColumn column((String, String) c) => DataColumn(
      label: Text(l10n.text(c.$2), style: heading),
      onSort: (_, _) => _sortBy(c.$1),
    );
    final sortIndex = _ruleColumns.indexWhere((c) => c.$1 == _sort);
    return AbraCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: sortIndex < 0 ? null : sortIndex,
          sortAscending: !_descending,
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
          columnSpacing: AbraSpacing.lg,
          columns: [
            for (final c in _ruleColumns) column(c),
            const DataColumn(label: SizedBox.shrink()),
            DataColumn(
              label: Text(
                l10n.text(AdminStrings.commColActions),
                style: heading,
              ),
            ),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                cells: [
                  DataCell(Text(r.id)),
                  DataCell(_scopeBadge(r)),
                  DataCell(Text(r.targetName)),
                  DataCell(Text(formatCommission(r.mode, r.value))),
                  DataCell(Text(r.effectiveFrom)),
                  DataCell(Text('v${r.version}')),
                  DataCell(_statusBadge(r)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        r.agreedNote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(_editButtons(r)),
                  DataCell(_rowIcons(r)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _ruleCard(CommissionRule r) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AbraColors.textSecondary,
    );
    final l10n = _l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
      child: AbraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(r.id, style: theme.textTheme.titleSmall),
                _scopeBadge(r),
                _statusBadge(r),
                Text('v${r.version}', style: muted),
              ],
            ),
            const SizedBox(height: AbraSpacing.xs),
            Text(r.targetName, style: theme.textTheme.titleMedium),
            Text(formatCommission(r.mode, r.value)),
            Text(
              '${l10n.text(AdminStrings.commColFrom)}: ${r.effectiveFrom}',
              style: muted,
            ),
            if (r.agreedNote.isNotEmpty) Text(r.agreedNote, style: muted),
            const SizedBox(height: AbraSpacing.xs),
            Wrap(
              spacing: AbraSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [_editButtons(r), _rowIcons(r)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeBadge(CommissionRule r) => AbraStatusBadge(
    label: scopeLabel(_l10n, r.scope),
    tone: AbraStatusTone.info,
  );

  Widget _statusBadge(CommissionRule r) => AbraStatusBadge(
    label: _l10n.text(
      r.isActive
          ? AdminStrings.commStatusActive
          : AdminStrings.commStatusInactive,
    ),
    tone: r.isActive ? AbraStatusTone.success : AbraStatusTone.neutral,
  );

  /// Edit and Deactivate or Activate: only for people who may change commission.
  Widget _editButtons(CommissionRule r) {
    if (!_canEdit) return const SizedBox.shrink();
    final l10n = _l10n;
    final busy = _busyId == r.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AbraButton(
          label: l10n.text(AdminStrings.commEdit),
          icon: Icons.edit_outlined,
          variant: AbraButtonVariant.text,
          onPressed: busy ? null : () => unawaited(_openRuleDialog(rule: r)),
        ),
        AbraButton(
          label: l10n.text(
            r.isActive
                ? AdminStrings.commDeactivate
                : AdminStrings.commActivate,
          ),
          icon: Icons.refresh,
          variant: AbraButtonVariant.text,
          onPressed: busy ? null : () => unawaited(_toggle(r)),
        ),
      ],
    );
  }

  /// The demo's eye and bin icons.
  Widget _rowIcons(CommissionRule r) {
    final l10n = _l10n;
    final busy = _busyId == r.id;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.text(AdminStrings.commView),
          onPressed: () => unawaited(_openView(r)),
          icon: const Icon(Icons.visibility_outlined, size: 18),
        ),
        if (_canDelete)
          IconButton(
            tooltip: l10n.text(AdminStrings.commDelete),
            onPressed: busy ? null : () => unawaited(_delete(r)),
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AbraColors.danger,
            ),
          ),
      ],
    );
  }

  /* ------------------------------------------------------- calculator tab */

  Widget _calculatorTab(bool compact) {
    final l10n = _l10n;
    final ops = _targets['OPERATOR'] ?? const <TargetOption>[];
    final routes = _targets['ROUTE'] ?? const <TargetOption>[];
    final bts = _targets['BUS_TYPE'] ?? const <TargetOption>[];
    const fieldWidth = 220.0;

    Widget pick(
      String label,
      String? value,
      List<TargetOption> options,
      ValueChanged<String?> onPicked, {
      bool optional = false,
    }) => SizedBox(
      width: fieldWidth,
      child: DropdownButtonFormField<String?>(
        key: ValueKey<String>('$label:$value:${options.length}'),
        initialValue: options.any((o) => o.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          if (optional)
            DropdownMenuItem<String?>(
              child: Text(l10n.text(AdminStrings.commNotChosen)),
            ),
          for (final o in options)
            DropdownMenuItem<String?>(
              value: o.id,
              child: Text(o.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onPicked,
      ),
    );

    final form = AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.text(AdminStrings.commCalcTitle),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AbraSpacing.md),
          Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.md,
            children: [
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _fareCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.text(AdminStrings.commFare),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _seatsCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.text(AdminStrings.commSeats),
                    isDense: true,
                  ),
                ),
              ),
              pick(
                l10n.text(AdminStrings.commOperator),
                _calcOperator,
                ops,
                (v) => setState(() => _calcOperator = v),
              ),
              // Optional until routes exist (Phase 2 routes feature)
              pick(
                l10n.text(AdminStrings.commRoute),
                _calcRoute,
                routes,
                (v) => setState(() => _calcRoute = v),
                optional: true,
              ),
              pick(
                l10n.text(AdminStrings.commBusType),
                _calcBusType,
                bts,
                (v) => setState(() => _calcBusType = v),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.lg),
          AbraButton(
            label: l10n.text(AdminStrings.commCalculate),
            icon: Icons.percent,
            isLoading: _calcBusy,
            onPressed: () => unawaited(_calculate()),
          ),
        ],
      ),
    );

    final result = AbraCard(child: _resultBody());
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          form,
          const SizedBox(height: AbraSpacing.md),
          result,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: form),
        const SizedBox(width: AbraSpacing.md),
        Expanded(child: result),
      ],
    );
  }

  Widget _resultBody() {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final c = _calc;
    if (_calcError != null) {
      return Text(
        _calcError!,
        style: theme.textTheme.bodyMedium?.copyWith(color: AbraColors.danger),
      );
    }
    if (c == null) return Text(l10n.text(AdminStrings.commCalcEmpty));
    final a = c.amounts;
    Widget row(String k, int? v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: AbraColors.textSecondary)),
          Text(
            formatRupees(v ?? 0),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.text(AdminStrings.commResultTitle),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AbraSpacing.sm),
        _InfoBanner(
          l10n.text(AdminStrings.commRuleUsed, {
            'rule': c.ruleId,
            'scope': c.scope,
            'target': c.targetName,
            'commission': formatCommission(c.mode, c.value),
          }),
        ),
        const SizedBox(height: AbraSpacing.sm),
        row(l10n.text(AdminStrings.commAmtOperatorFare), a['operatorFare']),
        row(l10n.text(AdminStrings.commAmtCommission), a['commission']),
        row(l10n.text(AdminStrings.commAmtFareShown), a['fareShown']),
        row(
          l10n.text(AdminStrings.commAmtGst, {
            'pct': _trim2(c.gstPct.toDouble()),
          }),
          a['gst'],
        ),
        row(l10n.text(AdminStrings.commAmtFee), a['convenienceFee']),
        row(
          l10n.text(AdminStrings.commAmtCustomer),
          a['customerPays'],
          bold: true,
        ),
        row(
          l10n.text(AdminStrings.commAmtOperator),
          a['operatorReceives'],
          bold: true,
        ),
      ],
    );
  }

  /* ---------------------------------------------------------- history tab */

  Widget _historyTab() {
    final l10n = _l10n;
    if (_historyLoading && _history.isEmpty) {
      return const AbraCard(child: AbraLoadingView());
    }
    if (_historyError != null && _history.isEmpty) {
      return AbraCard(
        child: AbraStateView(
          kind: AbraStateKind.error,
          message: _historyError,
          actionLabel: l10n.text(AbraStrings.commonRetry),
          onAction: () => unawaited(_loadHistory(reset: true)),
        ),
      );
    }
    if (_history.isEmpty) {
      return AbraCard(
        child: AbraStateView(
          kind: AbraStateKind.empty,
          title: l10n.text(AdminStrings.commHistoryEmpty),
          message: l10n.text(AdminStrings.commHistoryEmptyHint),
        ),
      );
    }
    final theme = Theme.of(context);
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final h in _history)
            Container(
              margin: const EdgeInsetsDirectional.only(start: AbraSpacing.xs),
              padding: const EdgeInsetsDirectional.only(
                start: AbraSpacing.md,
                bottom: AbraSpacing.md,
              ),
              decoration: const BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AbraColors.divider, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${h.who} - ${_fmtDateTime(h.when)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (_history.length < _historyTotal)
            AbraButton(
              label: l10n.text(AdminStrings.commNext),
              variant: AbraButtonVariant.text,
              isLoading: _historyLoading,
              onPressed: () => unawaited(_loadHistory(reset: false)),
            ),
        ],
      ),
    );
  }
}

/* =============================================================== dialogs */

class _DefaultDialog extends StatefulWidget {
  const _DefaultDialog({required this.api, required this.current});
  final CommissionApi api;
  final DefaultRule current;
  @override
  State<_DefaultDialog> createState() => _DefaultDialogState();
}

class _DefaultDialogState extends State<_DefaultDialog> {
  late String _mode = widget.current.mode;
  late final TextEditingController _value = TextEditingController(
    text: widget.current.configured ? _trim2(widget.current.value / 100) : '',
  );
  String? _valueError;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AbraLocalizations.of(context);
    final v = parseValueX100(_value.text);
    if (v == null || v < 0) {
      setState(() => _valueError = l10n.text(AdminStrings.commErrValue));
      return;
    }
    if (_mode == 'PERCENT' && v > 4000) {
      setState(() => _valueError = l10n.text(AdminStrings.commErrPercent));
      return;
    }
    setState(() {
      _saving = true;
      _valueError = null;
      _error = null;
    });
    try {
      await widget.api.saveDefault(_mode, v);
      if (mounted) {
        Navigator.pop(context, l10n.text(AdminStrings.commDefaultSaved));
      }
    } on CommissionApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.field == 'value') {
          _valueError = e.message;
        } else {
          _error = e.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.text(AdminStrings.commDefaultDialogTitle)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) _ErrorText(_error!),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _mode,
              decoration: InputDecoration(
                labelText: l10n.text(AdminStrings.commType),
              ),
              items: [
                DropdownMenuItem(
                  value: 'PERCENT',
                  child: Text(l10n.text(AdminStrings.commTypePercent)),
                ),
                DropdownMenuItem(
                  value: 'FLAT',
                  child: Text(l10n.text(AdminStrings.commTypeFlat)),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _mode = v ?? 'PERCENT'),
            ),
            const SizedBox(height: AbraSpacing.md),
            TextField(
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.text(AdminStrings.commValueDefaultLabel),
                errorText: _valueError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        AbraButton(
          label: l10n.text(AdminStrings.commCancel),
          variant: AbraButtonVariant.text,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        AbraButton(
          label: l10n.text(AdminStrings.commSave),
          isLoading: _saving,
          onPressed: () => unawaited(_save()),
        ),
      ],
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({
    required this.api,
    required this.rule,
    required this.loadTargets,
  });
  final CommissionApi api;
  final CommissionRule? rule; // null = new rule
  final Future<List<TargetOption>> Function(String scope) loadTargets;
  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late String _scope = widget.rule?.scope ?? 'OPERATOR';
  String? _targetId;
  late String _mode = widget.rule?.mode ?? 'PERCENT';
  late final TextEditingController _value = TextEditingController(
    text: _trim2((widget.rule?.value ?? 1000) / 100),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.rule?.agreedNote ?? '',
  );
  late String _date = _initialDate();
  List<TargetOption> _options = [];
  bool _loadingTargets = false;
  bool _saving = false;
  String? _error;
  final Map<String, String> _fieldErrors = {};

  bool get _editing => widget.rule != null;

  /// New rule: today. Edit: the old date, or today if that has passed (a new version cannot start in the past).
  String _initialDate() {
    final today = todayIst();
    final old = widget.rule?.effectiveFrom;
    if (old == null || old.compareTo(today) < 0) return today;
    return old;
  }

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _targetId = widget.rule!.targetId;
      _options = [TargetOption(widget.rule!.targetId, widget.rule!.targetName)];
    } else {
      unawaited(_loadScope(_scope));
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadScope(String scope) async {
    setState(() {
      _scope = scope;
      _targetId = null;
      _loadingTargets = true;
      _options = [];
    });
    try {
      final list = await widget.loadTargets(scope);
      if (!mounted || _scope != scope) return;
      setState(() {
        _options = list;
        _targetId = list.isEmpty ? null : list.first.id;
        _loadingTargets = false;
      });
    } on CommissionApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTargets = false;
        _error = e.message;
      });
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.parse(todayIst());
    final cur = DateTime.tryParse(_date) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: cur.isBefore(today) ? today : cur,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _date = _iso(picked));
  }

  Future<void> _save() async {
    final l10n = AbraLocalizations.of(context);
    final errors = <String, String>{};
    final v = parseValueX100(_value.text);
    if (v == null || v < 0) {
      errors['value'] = l10n.text(AdminStrings.commErrValue);
    } else if (_mode == 'PERCENT' && v > 4000) {
      errors['value'] = l10n.text(AdminStrings.commErrPercent);
    }
    if (_date.isEmpty) {
      errors['effectiveFrom'] = l10n.text(AdminStrings.commErrDate);
    }
    if (!_editing && _targetId == null) {
      errors['targetId'] = l10n.text(AdminStrings.commErrTarget);
    }
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(errors);
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors.clear();
    });
    try {
      final body = <String, dynamic>{
        'mode': _mode,
        'value': v,
        'effectiveFrom': _date,
        'agreedNote': _note.text.trim(),
      };
      if (_editing) {
        await widget.api.saveNewVersion(widget.rule!.id, body);
      } else {
        body['scope'] = _scope;
        body['targetId'] = _targetId;
        await widget.api.createRule(body);
      }
      if (mounted) {
        Navigator.pop(context, l10n.text(AdminStrings.commSavedRule));
      }
    } on CommissionApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.field != null &&
            const [
              'value',
              'effectiveFrom',
              'agreedNote',
              'targetId',
              'scope',
              'mode',
            ].contains(e.field)) {
          _fieldErrors[e.field!] = e.message;
        } else {
          _error = e.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AlertDialog(
      title: Text(
        _editing
            ? l10n.text(AdminStrings.commEditRuleTitle, {'id': widget.rule!.id})
            : l10n.text(AdminStrings.commNewRuleTitle),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) _ErrorText(_error!),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _scope,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.commAppliesTo),
                  errorText: _fieldErrors['scope'],
                ),
                items: [
                  DropdownMenuItem(
                    value: 'OPERATOR',
                    child: Text(l10n.text(AdminStrings.commFormScopeOperator)),
                  ),
                  DropdownMenuItem(
                    value: 'ROUTE',
                    child: Text(l10n.text(AdminStrings.commFormScopeRoute)),
                  ),
                  DropdownMenuItem(
                    value: 'BUS_TYPE',
                    child: Text(l10n.text(AdminStrings.commFormScopeBusType)),
                  ),
                ],
                onChanged: _editing || _saving
                    ? null
                    : (v) => unawaited(_loadScope(v ?? 'OPERATOR')),
              ),
              const SizedBox(height: AbraSpacing.md),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('$_scope:${_options.length}'),
                initialValue: _options.any((o) => o.id == _targetId)
                    ? _targetId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.commWhichOne),
                  errorText: _fieldErrors['targetId'],
                  suffixIcon: _loadingTargets
                      ? const Padding(
                          padding: EdgeInsets.all(AbraSpacing.sm),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: [
                  for (final o in _options)
                    DropdownMenuItem(
                      value: o.id,
                      child: Text(o.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _editing || _saving
                    ? null
                    : (v) => setState(() => _targetId = v),
              ),
              const SizedBox(height: AbraSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _mode,
                      decoration: InputDecoration(
                        labelText: l10n.text(AdminStrings.commType),
                        errorText: _fieldErrors['mode'],
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'PERCENT',
                          child: Text(l10n.text(AdminStrings.commTypePercent)),
                        ),
                        DropdownMenuItem(
                          value: 'FLAT',
                          child: Text(l10n.text(AdminStrings.commTypeFlat)),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _mode = v ?? 'PERCENT'),
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _value,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.text(AdminStrings.commValue),
                        helperText: l10n.text(AdminStrings.commValueHint),
                        errorText: _fieldErrors['value'],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.md),
              InkWell(
                borderRadius: AbraRadius.medium,
                onTap: _saving ? null : () => unawaited(_pickDate()),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.text(AdminStrings.commColFrom),
                    errorText: _fieldErrors['effectiveFrom'],
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                    ),
                  ),
                  child: Text(_date),
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextField(
                controller: _note,
                maxLength: 300,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.commNote),
                  hintText: l10n.text(AdminStrings.commNoteHint),
                  errorText: _fieldErrors['agreedNote'],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AbraButton(
          label: l10n.text(AdminStrings.commCancel),
          variant: AbraButtonVariant.text,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        AbraButton(
          label: l10n.text(
            _editing ? AdminStrings.commSaveVersion : AdminStrings.commSaveRule,
          ),
          isLoading: _saving,
          onPressed: () => unawaited(_save()),
        ),
      ],
    );
  }
}

/// The demo's View window: the rule's fields, with Close, Edit and Delete.
class _ViewDialog extends StatefulWidget {
  const _ViewDialog({
    required this.api,
    required this.ruleId,
    required this.canEdit,
    required this.canDelete,
  });
  final CommissionApi api;
  final String ruleId;
  final bool canEdit;
  final bool canDelete;
  @override
  State<_ViewDialog> createState() => _ViewDialogState();
}

class _ViewDialogState extends State<_ViewDialog> {
  CommissionRule? _rule;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.getRule(widget.ruleId);
      if (mounted) setState(() => _rule = r);
    } on CommissionApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    final r = _rule;
    Widget kv(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: v),
        ],
      ),
    );
    return AlertDialog(
      title: Text(l10n.text(AdminStrings.commViewTitle, {'id': widget.ruleId})),
      content: SizedBox(
        width: 520,
        child: _error != null
            ? Text(_error!)
            : r == null
            ? const SizedBox(height: 80, child: AbraLoadingView())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    kv(l10n.text(AdminStrings.commColId), Text(r.id)),
                    kv(
                      l10n.text(AdminStrings.commAppliesTo),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AbraStatusBadge(
                          label: scopeLabel(l10n, r.scope),
                          tone: AbraStatusTone.info,
                        ),
                      ),
                    ),
                    kv(
                      l10n.text(AdminStrings.commColTarget),
                      Text(r.targetName),
                    ),
                    kv(
                      l10n.text(AdminStrings.commColCommission),
                      Text(formatCommission(r.mode, r.value)),
                    ),
                    kv(
                      l10n.text(AdminStrings.commColFrom),
                      Text(r.effectiveFrom),
                    ),
                    kv(
                      l10n.text(AdminStrings.commColVersion),
                      Text('v${r.version}'),
                    ),
                    kv(
                      l10n.text(AdminStrings.commStatus),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AbraStatusBadge(
                          label: l10n.text(
                            r.isActive
                                ? AdminStrings.commStatusActive
                                : AdminStrings.commStatusInactive,
                          ),
                          tone: r.isActive
                              ? AbraStatusTone.success
                              : AbraStatusTone.neutral,
                        ),
                      ),
                    ),
                    kv(
                      l10n.text(AdminStrings.commColNote),
                      Text(r.agreedNote.isEmpty ? '-' : r.agreedNote),
                    ),
                    if (r.versions.length > 1) ...[
                      const Divider(height: AbraSpacing.xl),
                      Text(
                        l10n.text(AdminStrings.commVersions),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AbraSpacing.xs),
                      for (final v in r.versions)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AbraSpacing.xxs,
                          ),
                          child: Text(
                            l10n.text(AdminStrings.commVersionLine, {
                              'version': v.version,
                              'commission': formatCommission(v.mode, v.value),
                              'date': v.effectiveFrom,
                            }),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        AbraButton(
          label: l10n.text(AdminStrings.commClose),
          variant: AbraButtonVariant.text,
          onPressed: () => Navigator.pop(context),
        ),
        if (widget.canEdit && r != null)
          AbraButton(
            label: l10n.text(AdminStrings.commEdit),
            icon: Icons.edit_outlined,
            variant: AbraButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, 'edit'),
          ),
        if (widget.canDelete && r != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, 'delete'),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(l10n.text(AdminStrings.commDelete)),
          ),
      ],
    );
  }
}

/* ============================================================ small parts */

/// The demo's blue information bar.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AbraColors.deepBlue),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.dangerContainer,
        borderRadius: AbraRadius.small,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.sm),
        child: Text(text, style: const TextStyle(color: AbraColors.danger)),
      ),
    ),
  );
}
