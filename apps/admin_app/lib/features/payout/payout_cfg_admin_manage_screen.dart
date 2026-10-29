// Payout modes and fees: the whole page (widgets, models, state, API calls) in ONE file.
//
// [PayoutCfgPage] connects the page to the admin app: [PayoutSend] goes through the app's
// API client (the `data` of the answer; errors throw) and editing follows payout.manage.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';

/// The page as the router opens it: the app's API client, and Super Admin editing only
/// (payout.manage); Admin and Accounts see it read-only.
class PayoutCfgPage extends ConsumerWidget {
  const PayoutCfgPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(appDependenciesProvider).apiClient;
    Future<dynamic> send(String method, String path, {Object? body}) async {
      final address = path.startsWith('/') ? path.substring(1) : path;
      final json = body is Map<String, dynamic> ? body : null;
      final answer = switch (method) {
        'GET' => await api.get(address),
        'POST' => await api.post(
          address,
          body: json ?? const <String, Object?>{},
        ),
        'PUT' => await api.put(
          address,
          body: json ?? const <String, Object?>{},
        ),
        'DELETE' => await api.delete(address),
        _ => throw ArgumentError('Unknown method $method'),
      };
      return answer.data;
    }

    return PayoutCfgAdminManageScreen(
      send: send,
      canEdit: ref.watch(accessProvider).can('payout.manage'),
    );
  }
}

/// method: GET | POST | PUT | DELETE. Returns decoded JSON (Map, List or null).
typedef PayoutSend =
    Future<dynamic> Function(String method, String path, {Object? body});

// ---- the app's colours (shared_theme), the same as the demo's ----------------
const _navy = AbraColors.navy;
const _blue = AbraColors.blue;
const _line = AbraColors.divider;
const _muted = AbraColors.textSecondary;
const _green = AbraColors.teal;
const _red = AbraColors.danger;
const _amber = AbraColors.orangeDark;

/// Rows per page of the operator table, as in the demo.
const _operatorsPerPage = 10;

// ---- models -----------------------------------------------------------------

class PayoutSettingsModel {
  PayoutSettingsModel({
    required this.defaultMode,
    required this.cycleDays,
    required this.minPayout,
    required this.holdDays,
    required this.razorpayRoute,
    required this.gstPct,
    required this.convenienceFee,
    required this.couponFunding,
  });

  String defaultMode; // AUTO_SPLIT | MANUAL
  int cycleDays;
  int minPayout; // paise
  int holdDays;
  bool razorpayRoute;
  double gstPct;
  int convenienceFee; // paise
  String couponFunding; // PLATFORM | OPERATOR | SPLIT

  factory PayoutSettingsModel.fromJson(Map<String, dynamic> j) =>
      PayoutSettingsModel(
        defaultMode: (j['defaultMode'] ?? 'MANUAL') as String,
        cycleDays: (j['cycleDays'] ?? 7) as int,
        minPayout: (j['minPayout'] ?? 0) as int,
        holdDays: (j['holdDays'] ?? 0) as int,
        razorpayRoute: (j['razorpayRoute'] ?? false) as bool,
        gstPct: ((j['gstPct'] ?? 0) as num).toDouble(),
        convenienceFee: (j['convenienceFee'] ?? 0) as int,
        couponFunding: (j['couponFunding'] ?? 'PLATFORM') as String,
      );

  Map<String, dynamic> toJson() => {
    'defaultMode': defaultMode,
    'cycleDays': cycleDays,
    'minPayout': minPayout,
    'holdDays': holdDays,
    'razorpayRoute': razorpayRoute,
    'gstPct': gstPct,
    'convenienceFee': convenienceFee,
    'couponFunding': couponFunding,
  };
}

class RefundSlabModel {
  RefundSlabModel(this.id, this.hoursBefore, this.refundPct);
  final String id;
  final int hoursBefore;
  final int refundPct;

  factory RefundSlabModel.fromJson(Map<String, dynamic> j) => RefundSlabModel(
    (j['_id'] ?? j['id']) as String,
    (j['hoursBefore'] as num).toInt(),
    (j['refundPct'] as num).toInt(),
  );
}

class PayoutOperator {
  PayoutOperator({
    required this.id,
    required this.name,
    required this.mode,
    required this.account,
    required this.ifsc,
    required this.bankStatus,
  });
  final String id;
  final String name;
  final String mode; // AUTO_SPLIT | MANUAL
  final String account;
  final String ifsc;
  final String bankStatus; // VERIFIED | PENDING | FAILED ...

  bool get verified => bankStatus == 'VERIFIED';

  bool get hasBank => bankStatus != 'NONE';

  /// "XXXXXX8074 - HDFC0008227" as the demo shows it, in one line.
  String get bankLine => hasBank ? '$account - $ifsc' : 'No bank account yet';

  /// A row of `GET admin/operators` (payoutMode, and the bank with its last four digits only).
  factory PayoutOperator.fromJson(Map<String, dynamic> j) {
    final bank = j['bank'] is Map ? j['bank'] as Map : null;
    return PayoutOperator(
      id: j['id'] as String,
      name: (j['displayName'] ?? j['companyName'] ?? '') as String,
      mode: (j['payoutMode'] ?? 'MANUAL') as String,
      account: bank == null ? '' : 'XXXXXX${bank['accountLast4']}',
      ifsc: '${bank?['ifsc'] ?? ''}',
      // No bank account yet reads as "Not added"
      bankStatus: '${bank?['status'] ?? 'NONE'}',
    );
  }
}

// ---- screen -----------------------------------------------------------------

class PayoutCfgAdminManageScreen extends StatefulWidget {
  const PayoutCfgAdminManageScreen({
    super.key,
    required this.send,
    required this.canEdit,
  });

  final PayoutSend send;

  /// Super Admin only. Admin and Accounts get false: fields disabled, buttons hidden.
  /// Support never reaches this page (route guard, Session A).
  final bool canEdit;

  @override
  State<PayoutCfgAdminManageScreen> createState() =>
      _PayoutCfgAdminManageScreenState();
}

class _PayoutCfgAdminManageScreenState
    extends State<PayoutCfgAdminManageScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  PayoutSettingsModel _s = PayoutSettingsModel(
    defaultMode: 'MANUAL',
    cycleDays: 7,
    minPayout: 0,
    holdDays: 0,
    razorpayRoute: false,
    gstPct: 0,
    convenienceFee: 0,
    couponFunding: 'PLATFORM',
  );
  bool _settingsSaved = false; // false = nothing saved yet on the server

  final _cycle = TextEditingController();
  final _minPayout = TextEditingController();
  final _hold = TextEditingController();
  final _gst = TextEditingController();
  final _fee = TextEditingController();
  final Map<String, String?> _errors = {};

  List<RefundSlabModel> _slabs = [];
  List<PayoutOperator> _ops = [];
  String _modeFilter = 'ALL'; // ALL | AUTO_SPLIT | MANUAL
  bool? _listView; // null = decide by width
  // The demo's list tools: search and paging on operators, a view switch on the slabs
  final _search = TextEditingController();
  int _opPage = 1;
  bool _slabsAsList = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_cycle, _minPayout, _hold, _gst, _fee, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- helpers ----

  String _rupees(int paise) {
    final r = paise / 100;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2);
  }

  int _toPaise(String rupees) => (double.parse(rupees) * 100).round();

  void _toast(String msg, {String? action, VoidCallback? onAction}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(msg),
        action: action == null
            ? null
            : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      ),
    );
  }

  /// The server's sentence (for example why Route cannot be switched off), never raw errors.
  String _err(Object e) => failureText(AbraLocalizations.of(context), e);

  /// Every operator page by page (the list API gives at most 100 per page).
  Future<List<Map<String, dynamic>>> _fetchOperators() async {
    final all = <Map<String, dynamic>>[];
    for (var page = 1; page <= 50; page++) {
      final rows = await widget.send(
        'GET',
        '/admin/operators?page=$page&pageSize=100',
      );
      final list = (rows as List? ?? const []).cast<Map<String, dynamic>>();
      all.addAll(list);
      if (list.length < 100) break;
    }
    return all;
  }

  // ---- load ----

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final st = await widget.send('GET', '/admin/payout/settings');
      final sl = await widget.send('GET', '/admin/payout/refund-slabs');
      final op = await _fetchOperators();
      final saved = (st is Map) ? st['settings'] : null;
      if (saved is Map<String, dynamic>) {
        _s = PayoutSettingsModel.fromJson(saved);
        _settingsSaved = true;
      }
      _fillControllers();
      _slabs =
          (sl as List)
              .map((e) => RefundSlabModel.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.hoursBefore.compareTo(a.hoursBefore));
      _ops = op
          // The demo leaves out operators still waiting for approval.
          .where((o) => o['status'] != 'PENDING_APPROVAL')
          .map(PayoutOperator.fromJson)
          .toList();
    } catch (e) {
      _loadError = _err(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fillControllers() {
    _cycle.text = '${_s.cycleDays}';
    _minPayout.text = _rupees(_s.minPayout);
    _hold.text = '${_s.holdDays}';
    _gst.text = _s.gstPct == _s.gstPct.roundToDouble()
        ? _s.gstPct.toStringAsFixed(0)
        : '${_s.gstPct}';
    _fee.text = _rupees(_s.convenienceFee);
  }

  // ---- save settings ----

  Future<void> _save() async {
    _errors.clear();
    final cycle = int.tryParse(_cycle.text.trim());
    final hold = int.tryParse(_hold.text.trim());
    final gst = double.tryParse(_gst.text.trim());
    final minP = double.tryParse(_minPayout.text.trim());
    final fee = double.tryParse(_fee.text.trim());
    if (cycle == null || cycle < 1)
      _errors['cycle'] = 'Cycle must be 1 day or more';
    if (hold == null || hold < 0)
      _errors['hold'] = 'Hold days must be 0 or more';
    if (gst == null || gst < 0 || gst > 28)
      _errors['gst'] = 'GST must be 0 to 28';
    if (minP == null || minP < 0)
      _errors['min'] = 'Minimum payout must be 0 or more';
    if (fee == null || fee < 0)
      _errors['fee'] = 'Convenience fee must be 0 or more';
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    final next = PayoutSettingsModel(
      defaultMode: _s.defaultMode,
      cycleDays: cycle!,
      minPayout: _toPaise(_minPayout.text.trim()),
      holdDays: hold!,
      razorpayRoute: _s.razorpayRoute,
      gstPct: gst!,
      convenienceFee: _toPaise(_fee.text.trim()),
      couponFunding: _s.couponFunding,
    );
    setState(() => _saving = true);
    try {
      await widget.send('PUT', '/admin/payout/settings', body: next.toJson());
      _s = next;
      _settingsSaved = true;
      _toast('Saved. Applies to new bookings and settlements.');
    } catch (e) {
      _toast(
        _err(e),
      ); // for example: "Razorpay Route cannot be switched off: 3 operators..."
      // The server refused: put the switch back to what is saved.
      await _load();
    }
    if (mounted) setState(() => _saving = false);
  }

  // ---- slabs ----

  Future<void> _addSlab() async {
    final hours = TextEditingController();
    final pct = TextEditingController();
    String? eh, ep;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add refund slab'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('slabHours'),
                controller: hours,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Hours before departure',
                  errorText: eh,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('slabPct'),
                controller: pct,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Refund percent',
                  errorText: ep,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('slabSave'),
              onPressed: () {
                final h = int.tryParse(hours.text);
                final p = int.tryParse(pct.text);
                setD(() {
                  eh = h == null ? 'Hours required' : null;
                  ep = (p == null || p > 100) ? 'Percent 0 to 100' : null;
                  if (h != null && _slabs.any((s) => s.hoursBefore == h)) {
                    eh = 'A slab for these hours already exists';
                  }
                });
                if (eh == null && ep == null) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await widget.send(
          'POST',
          '/admin/payout/refund-slabs',
          body: {
            'hoursBefore': int.parse(hours.text),
            'refundPct': int.parse(pct.text),
          },
        );
        await _reloadSlabs();
        _toast('Slab added');
      } catch (e) {
        _toast(_err(e));
      }
    }
    // The dialog may still be closing: its text boxes are left to the garbage collector
  }

  Future<void> _reloadSlabs() async {
    final sl = await widget.send('GET', '/admin/payout/refund-slabs');
    if (!mounted) return;
    setState(() {
      _slabs =
          (sl as List)
              .map((e) => RefundSlabModel.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.hoursBefore.compareTo(a.hoursBefore));
    });
  }

  Future<void> _removeSlab(RefundSlabModel s) async {
    try {
      await widget.send('DELETE', '/admin/payout/refund-slabs/${s.id}');
      await _reloadSlabs();
      _toast(
        'Slab removed',
        action: 'Undo',
        onAction: () async {
          try {
            await widget.send(
              'POST',
              '/admin/payout/refund-slabs/${s.id}/restore',
            );
            await _reloadSlabs();
          } catch (e) {
            _toast(_err(e));
          }
        },
      );
    } catch (e) {
      _toast(_err(e));
    }
  }

  // ---- operators ----

  Future<void> _changeMode(PayoutOperator o) async {
    String mode = o.mode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Payout mode - ${o.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'AUTO_SPLIT',
                groupValue: mode,
                onChanged: (v) => setD(() => mode = v!),
                title: const Text(
                  'Automatic - Razorpay Route splits each payment',
                ),
              ),
              RadioListTile<String>(
                value: 'MANUAL',
                groupValue: mode,
                onChanged: (v) => setD(() => mode = v!),
                title: const Text(
                  'Manual - Abra collects and settles each cycle',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Automatic needs Razorpay Route switched on and a verified bank account. '
                'Existing unpaid settlements keep their old mode.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || mode == o.mode) return;
    if (mode == 'AUTO_SPLIT' && !_s.razorpayRoute) {
      _toast('Razorpay Route must be switched on first');
      return;
    }
    if (mode == 'AUTO_SPLIT' && !o.verified) {
      _toast('Bank account must be verified first');
      return;
    }
    try {
      await widget.send(
        'PUT',
        '/admin/operators/${o.id}/payout-mode',
        body: {'mode': mode},
      );
      await _reloadOperators();
      _toast('Payout mode saved');
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _verifyBank(PayoutOperator o) async {
    try {
      // One click as in the demo; the operator page can also record a failed check
      await widget.send(
        'POST',
        '/admin/operators/${o.id}/bank/verify',
        body: {
          'outcome': 'VERIFIED',
          'note': 'Checked on the Payout and fees page',
        },
      );
      await _reloadOperators();
      _toast('Bank verification updated');
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _reloadOperators() async {
    final list = await _fetchOperators();
    if (!mounted) return;
    setState(() {
      _ops = list
          .where((o) => o['status'] != 'PENDING_APPROVAL')
          .map(PayoutOperator.fromJson)
          .toList();
    });
  }

  /// The operators the Search and Mode filters leave.
  List<PayoutOperator> get _filteredOps {
    final term = _search.text.trim().toLowerCase();
    return _ops
        .where((o) => _modeFilter == 'ALL' || o.mode == _modeFilter)
        .where(
          (o) =>
              term.isEmpty ||
              o.name.toLowerCase().contains(term) ||
              o.ifsc.toLowerCase().contains(term),
        )
        .toList();
  }

  void _clearOperatorFilters() => setState(() {
    _search.clear();
    _modeFilter = 'ALL';
    _opPage = 1;
  });

  Future<void> _exportCsv() async {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final rows = <String>['Operator,Mode,Bank account,IFSC,Verification'];
    for (final o in _filteredOps) {
      rows.add(
        [
          q(o.name),
          q(o.mode == 'AUTO_SPLIT' ? 'Automatic' : 'Manual'),
          q(o.account),
          q(o.ifsc),
          q(o.bankStatus),
        ].join(','),
      );
    }
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    downloadTextFile('payout_modes_$stamp.csv', rows.join('\n'));
    _toast('The file is ready.');
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: const TextStyle(color: _red)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        // As in the demo: Save stays beside the title, and the two cards side by side,
        // until the page is narrow
        final headerRow = c.maxWidth >= 560;
        final twoCards = c.maxWidth >= 720;
        final pad = wide ? 24.0 : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(headerRow),
              const SizedBox(height: 16),
              if (!_settingsSaved)
                _notice(
                  'Nothing is saved yet. The fields show empty starting values; '
                  'GST and fees are not set until you save.',
                ),
              if (twoCards)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _payoutCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _feesCard()),
                  ],
                )
              else ...[
                _payoutCard(),
                const SizedBox(height: 16),
                _feesCard(),
              ],
              const SizedBox(height: 16),
              _slabsCard(),
              const SizedBox(height: 16),
              _operatorsCard(wide),
            ],
          ),
        );
      },
    );
  }

  Widget _header(bool wide) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Commercial / Payout and fees',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          'Payout modes and fees',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'How operators are paid, and what customers pay on top.',
          style: TextStyle(color: _muted),
        ),
      ],
    );
    final save = widget.canEdit
        ? FilledButton.icon(
            key: const Key('saveChanges'),
            // Blue, the primary action colour of the demo
            style: FilledButton.styleFrom(backgroundColor: _blue),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Saving...' : 'Save changes'),
          )
        : null;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          if (save != null) save,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        if (save != null) ...[const SizedBox(height: 12), save],
      ],
    );
  }

  Widget _notice(String text) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      border: Border.all(color: _amber),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: const TextStyle(color: _amber)),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _h3(String t) => Text(
    t,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  );

  Widget _numField(
    String key,
    String label,
    TextEditingController c, {
    bool decimal = false,
  }) {
    return TextField(
      key: Key('f_$key'),
      controller: c,
      enabled: widget.canEdit,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        errorText: _errors[key],
        isDense: true,
      ),
    );
  }

  Widget _grid(List<Widget> kids) => LayoutBuilder(
    builder: (context, c) {
      final two = c.maxWidth >= 420;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: kids
            .map(
              (k) => SizedBox(
                width: two ? (c.maxWidth - 12) / 2 : c.maxWidth,
                child: k,
              ),
            )
            .toList(),
      );
    },
  );

  Widget _payoutCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h3('Payout settings'),
        const SizedBox(height: 12),
        _grid([
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: const Key('f_defaultMode'),
            value: _s.defaultMode,
            decoration: const InputDecoration(
              labelText: 'Default mode for new operators',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'AUTO_SPLIT',
                child: Text('Automatic (Razorpay Route)'),
              ),
              DropdownMenuItem(
                value: 'MANUAL',
                child: Text('Manual settlement'),
              ),
            ],
            onChanged: widget.canEdit
                ? (v) => setState(() => _s.defaultMode = v!)
                : null,
          ),
          _numField('cycle', 'Settlement cycle (days)', _cycle),
          _numField('min', 'Minimum payout (Rs)', _minPayout, decimal: true),
          _numField('hold', 'Hold days after trip', _hold),
        ]),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('routeSwitch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Razorpay Route enabled'),
          value: _s.razorpayRoute,
          onChanged: widget.canEdit
              ? (v) => setState(() => _s.razorpayRoute = v)
              : null,
        ),
      ],
    ),
  );

  Widget _feesCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h3('Customer fees and coupons'),
        const SizedBox(height: 12),
        _grid([
          _numField('gst', 'GST on fare (%)', _gst, decimal: true),
          _numField('fee', 'Convenience fee (Rs)', _fee, decimal: true),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const Key('f_couponFunding'),
          value: _s.couponFunding,
          decoration: const InputDecoration(
            labelText: 'Who funds coupon discounts',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'PLATFORM', child: Text('Abra Travels')),
            DropdownMenuItem(value: 'OPERATOR', child: Text('The operator')),
            DropdownMenuItem(value: 'SPLIT', child: Text('Shared 50/50')),
          ],
          onChanged: widget.canEdit
              ? (v) => setState(() => _s.couponFunding = v!)
              : null,
        ),
      ],
    ),
  );

  Widget _slabsCard() {
    final noZero = _slabs.isNotEmpty && !_slabs.any((s) => s.hoursBefore == 0);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _h3('Cancellation refund slabs'),
                    const SizedBox(height: 2),
                    const Text(
                      'Default. Hours before departure to refund percent. Operators may be given their own later.',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (widget.canEdit)
                OutlinedButton.icon(
                  key: const Key('addSlab'),
                  onPressed: _addSlab,
                  icon: const Icon(Icons.add),
                  label: const Text('Add slab'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (noZero)
            _notice(
              'There is no 0-hour slab. A cancellation later than the smallest '
              'slab gets 0% refund. Add a 0-hour slab if that is not what you want.',
            ),
          // The demo's list tools (the slabs have no filters, so Clear only resets the view)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('slabsClear'),
                onPressed: () => setState(() => _slabsAsList = false),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Clear'),
              ),
              _viewSwitch(
                const Key('slabsView'),
                asList: _slabsAsList,
                onChanged: (asList) => setState(() => _slabsAsList = asList),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_slabs.isEmpty)
            const Text(
              'No slabs. Every cancellation gets a full (100%) refund.',
              style: TextStyle(color: _muted),
            )
          else if (_slabsAsList)
            Column(
              children: [
                for (final s in _slabs)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _line)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${s.hoursBefore} h',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('Refund ${s.refundPct}%'),
                        ..._slabActions(s),
                      ],
                    ),
                  ),
              ],
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1.5),
                2: IntrinsicColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Cancel at least (hours before)',
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Refund',
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox.shrink(),
                  ],
                ),
                for (final s in _slabs)
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _line)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('${s.hoursBefore} h'),
                      ),
                      Text('${s.refundPct}%'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _slabActions(s),
                      ),
                    ],
                  ),
              ],
            ),
          if (_slabs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_slabs.length} result${_slabs.length == 1 ? '' : 's'} · Page 1 of 1',
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  /// Remove (editors) and View (everyone), as on each demo row.
  List<Widget> _slabActions(RefundSlabModel s) => [
    if (widget.canEdit)
      TextButton.icon(
        key: Key('removeSlab_${s.id}'),
        onPressed: () => _removeSlab(s),
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('Remove'),
      ),
    IconButton(
      key: Key('viewSlab_${s.id}'),
      tooltip: 'View',
      icon: const Icon(Icons.visibility_outlined, size: 20),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${s.hoursBefore} h'),
          content: Text(
            'Cancel at least ${s.hoursBefore} hours before departure: '
            '${s.refundPct}% refund.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  ];

  /// The demo's "Table | List" switch.
  Widget _viewSwitch(
    Key key, {
    required bool asList,
    required ValueChanged<bool> onChanged,
  }) => SegmentedButton<bool>(
    key: key,
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(
        value: false,
        icon: Icon(Icons.grid_view_outlined, size: 18),
        label: Text('Table'),
      ),
      ButtonSegment(
        value: true,
        icon: Icon(Icons.view_list_outlined, size: 18),
        label: Text('List'),
      ),
    ],
    selected: {asList},
    onSelectionChanged: (value) => onChanged(value.first),
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  Widget _modePill(PayoutOperator o) =>
      _pill(o.mode == 'AUTO_SPLIT' ? 'Automatic' : 'Manual', _blue);

  Widget _bankPill(PayoutOperator o) => _pill(
    switch (o.bankStatus) {
      'VERIFIED' => 'Verified',
      'FAILED' => 'Failed',
      'NONE' => 'Not added',
      _ => 'Pending',
    },
    o.verified
        ? _green
        : (o.bankStatus == 'FAILED'
              ? _red
              : (o.bankStatus == 'NONE' ? _muted : _amber)),
  );

  List<Widget> _opActions(PayoutOperator o) => !widget.canEdit
      ? const []
      : [
          TextButton.icon(
            key: Key('changeMode_${o.id}'),
            onPressed: () => _changeMode(o),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const Text('Change mode'),
          ),
          // Only an added, not yet verified account can be verified
          if (!o.verified && o.bankStatus != 'NONE')
            TextButton.icon(
              key: Key('verifyBank_${o.id}'),
              onPressed: () => _verifyBank(o),
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text('Verify bank'),
            ),
        ];

  Widget _operatorsCard(bool wide) {
    final asList = _listView ?? !wide;
    final all = _filteredOps;
    final pages = all.isEmpty ? 1 : ((all.length - 1) ~/ _operatorsPerPage) + 1;
    final page = _opPage.clamp(1, pages);
    final ops = all
        .skip((page - 1) * _operatorsPerPage)
        .take(_operatorsPerPage)
        .toList();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h3('Operator payout modes and bank accounts'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  key: const Key('operatorSearch'),
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _opPage = 1),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('modeFilter'),
                  value: _modeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Mode',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All')),
                    DropdownMenuItem(
                      value: 'AUTO_SPLIT',
                      child: Text('Automatic'),
                    ),
                    DropdownMenuItem(value: 'MANUAL', child: Text('Manual')),
                  ],
                  onChanged: (v) => setState(() {
                    _modeFilter = v!;
                    _opPage = 1;
                  }),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('operatorsClear'),
                onPressed: _clearOperatorFilters,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Clear'),
              ),
              OutlinedButton.icon(
                key: const Key('exportCsv'),
                onPressed: _exportCsv,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export CSV'),
              ),
              _viewSwitch(
                const Key('viewSwitch'),
                asList: asList,
                onChanged: (value) => setState(() => _listView = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ops.isEmpty)
            const Text('No operators to show.', style: TextStyle(color: _muted))
          else if (asList)
            Column(
              children: [
                for (final o in ops)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          o.bankLine,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _modePill(o),
                            _bankPill(o),
                            ..._opActions(o),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Operator')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Bank account')),
                  DataColumn(label: Text('Verification')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final o in ops)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            o.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(_modePill(o)),
                        DataCell(Text(o.bankLine)),
                        DataCell(_bankPill(o)),
                        DataCell(Row(children: _opActions(o))),
                      ],
                    ),
                ],
              ),
            ),
          // "11 results  Previous  Page 1 of 2  Next", as under the demo's table
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${all.length} result${all.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              TextButton(
                key: const Key('operatorsPrevious'),
                onPressed: page > 1
                    ? () => setState(() => _opPage = page - 1)
                    : null,
                child: const Text('Previous'),
              ),
              Text(
                'Page $page of $pages',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              TextButton(
                key: const Key('operatorsNext'),
                onPressed: page < pages
                    ? () => setState(() => _opPage = page + 1)
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
