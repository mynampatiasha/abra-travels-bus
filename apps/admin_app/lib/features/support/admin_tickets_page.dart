import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart' show failureOf;
import '../../core/browser_files.dart';

/// Support tickets (`/admin/support`): the list with filters, one ticket with its replies, and
/// take it, reply, resolve, reopen. Everything comes from and goes to the backend.
class AdminTicketsPage extends ConsumerStatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  ConsumerState<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

const _statuses = <String, String>{
  '': 'All statuses',
  'OPEN': 'Open',
  'IN_PROGRESS': 'In progress',
  'RESOLVED': 'Resolved',
};
const _categories = <String, String>{
  '': 'All categories',
  'BOOKING': 'Booking',
  'PAYMENT': 'Payment',
  'REFUND': 'Refund',
  'TRIP': 'Trip',
  'SAFETY': 'Safety',
  'ACCOUNT': 'Account',
  'OTHER': 'Other',
};
const _priorities = <String, String>{
  '': 'All priorities',
  'LOW': 'Low',
  'NORMAL': 'Normal',
  'HIGH': 'High',
};

String _label(Map<String, String> from, Object? key) => from['$key'] ?? '$key';

/// A sentence the person can act on: the server's own words when it gave one.
String _say(Object error) {
  final failure = failureOf(error);
  if (failure is ApiFailure && failure.message.isNotEmpty && failure.statusCode < 500) {
    return failure.message;
  }
  return 'Something went wrong. Check your connection and try again.';
}

class _AdminTicketsPageState extends ConsumerState<AdminTicketsPage> {
  final _search = TextEditingController();
  String _status = '';
  String _category = '';
  String _priority = '';
  bool _overdueOnly = false;
  bool _mineOnly = false;
  bool _exporting = false;
  int _page = 1;
  int _total = 0;
  bool _busy = true;
  String? _error;
  List<JsonMap> _tickets = const [];

  static const _pageSize = 10;

  ApiClient get _api => ref.read(appDependenciesProvider).apiClient;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.get(
        'admin/support/tickets',
        query: {'page': _page, 'pageSize': _pageSize, ..._filters()},
      );
      final tickets = response.decodeList((json) => json);
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _total = response.page?.total ?? tickets.length;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _tickets = const [];
          _error = _say(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Every ticket that matches the filters, as a CSV file. Text that could be read as a formula
  /// is prefixed so a spreadsheet shows it as text.
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final all = <JsonMap>[];
      var page = 1;
      var total = 0;
      do {
        final response = await _api.get(
          'admin/support/tickets',
          query: {..._filters(), 'page': page, 'pageSize': 100},
        );
        final rows = response.decodeList((json) => json);
        all.addAll(rows);
        total = response.page?.total ?? all.length;
        if (rows.isEmpty) break;
        page++;
      } while (all.length < total);
      String safe(Object? value) {
        final text = '${value ?? ''}';
        return RegExp(r'^[=+@\-]').hasMatch(text) ? "'$text" : text;
      }

      final rows = <List<String>>[
        ['Ticket', 'Customer', 'Category', 'Subject', 'Status', 'Priority', 'Assigned to', 'Overdue', 'Raised'],
        for (final t in all)
          [
            safe(t['ticketNumber']),
            safe(t['customerName']),
            safe(_label(_categories, t['category'])),
            safe(t['subject']),
            safe(_label(_statuses, t['status'])),
            safe(_label(_priorities, t['priority'])),
            safe(t['assignedToName']),
            t['overdue'] == true ? 'Yes' : 'No',
            safe(t['createdAt']),
          ],
      ];
      if (!mounted) return;
      downloadTextFile('abra-support-tickets.csv', const ListToCsvConverter().convert(rows));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_say(e))));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Map<String, Object?> _filters() => {
    if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
    if (_status.isNotEmpty) 'status': _status,
    if (_category.isNotEmpty) 'category': _category,
    if (_priority.isNotEmpty) 'priority': _priority,
    if (_overdueOnly) 'overdue': 'true',
    if (_mineOnly) 'mine': 'true',
  };

  void _filter(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
    _load();
  }

  void _open(JsonMap ticket) {
    final access = ref.read(accessProvider);
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AbraSpacing.xl),
            child: _TicketDetail(
              id: '${ticket['id']}',
              canManage: access.can(PermissionKeys.supportManage),
              onChanged: _load,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, Map<String, String> items, ValueChanged<String> onChanged) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    );
  }

  AbraStatusTone _tone(String status) => switch (status) {
    'OPEN' => AbraStatusTone.warning,
    'IN_PROGRESS' => AbraStatusTone.info,
    'RESOLVED' => AbraStatusTone.success,
    _ => AbraStatusTone.neutral,
  };

  Widget _card(JsonMap t) {
    final theme = Theme.of(context);
    final overdue = t['overdue'] == true;
    return AbraCard(
      onTap: () => _open(t),
      semanticLabel: '${t['ticketNumber']}, ${_label(_statuses, t['status'])}. Opens the ticket',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${t['ticketNumber']}', style: theme.textTheme.titleMedium),
              const SizedBox(width: AbraSpacing.sm),
              Expanded(
                child: Text('${t['customerName']}', style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text('${t['message']}', maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AbraSpacing.sm),
          Wrap(
            spacing: AbraSpacing.sm,
            runSpacing: AbraSpacing.xs,
            children: [
              AbraStatusBadge(label: _label(_statuses, t['status']), tone: _tone('${t['status']}')),
              AbraStatusBadge(label: _label(_categories, t['category']), tone: AbraStatusTone.neutral),
              AbraStatusBadge(
                label: '${_label(_priorities, t['priority'])} priority',
                tone: t['priority'] == 'HIGH' ? AbraStatusTone.danger : AbraStatusTone.neutral,
              ),
              if (overdue) const AbraStatusBadge(label: 'Overdue', tone: AbraStatusTone.danger),
            ],
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text(
            '${t['repliesCount'] ?? 0} replies'
            '${'${t['assignedToName']}'.isEmpty ? '' : ' - ${t['assignedToName']}'}',
            style: theme.textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = (_total / _pageSize).ceil().clamp(1, 1 << 30);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        children: [
          Text('Support tickets', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AbraSpacing.xs),
          Text(
            'Questions and problems customers raised. Staff have a day to answer each one.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search ticket, customer or message',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _filter(() {}),
                ),
              ),
              _dropdown('Status', _status, _statuses, (v) => _filter(() => _status = v)),
              _dropdown('Category', _category, _categories, (v) => _filter(() => _category = v)),
              _dropdown('Priority', _priority, _priorities, (v) => _filter(() => _priority = v)),
              FilterChip(
                label: const Text('Overdue only'),
                selected: _overdueOnly,
                onSelected: (v) => _filter(() => _overdueOnly = v),
              ),
              FilterChip(
                label: const Text('Assigned to me'),
                selected: _mineOnly,
                onSelected: (v) => _filter(() => _mineOnly = v),
              ),
              IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
              OutlinedButton.icon(
                onPressed: _exporting ? null : _export,
                icon: const Icon(Icons.download),
                label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.lg),
          if (_busy && _tickets.isEmpty)
            const Padding(padding: EdgeInsets.all(AbraSpacing.xl), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Column(
              children: [
                Text(_error!),
                const SizedBox(height: AbraSpacing.sm),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ],
            )
          else if (_tickets.isEmpty)
            const Padding(padding: EdgeInsets.all(AbraSpacing.xl), child: Center(child: Text('No tickets match.')))
          else ...[
            Text('$_total tickets', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AbraSpacing.sm),
            for (final t in _tickets) ...[_card(t), const SizedBox(height: AbraSpacing.sm)],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page > 1 ? () => _filterPage(_page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page $_page of $pages'),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page < pages ? () => _filterPage(_page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _filterPage(int page) {
    setState(() => _page = page);
    _load();
  }
}

/// One ticket: what the customer wrote, the replies, and what staff may do.
class _TicketDetail extends ConsumerStatefulWidget {
  const _TicketDetail({required this.id, required this.canManage, required this.onChanged});

  final String id;
  final bool canManage;
  final VoidCallback onChanged;

  @override
  ConsumerState<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends ConsumerState<_TicketDetail> {
  JsonMap? _ticket;
  List<JsonMap> _canned = const [];
  final _reply = TextEditingController();
  String? _cannedId;
  String? _error;
  String? _notice;
  bool _busy = false;

  ApiClient get _api => ref.read(appDependenciesProvider).apiClient;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await _load();
      await _loadCanned();
    });
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final response = await _api.get('admin/support/tickets/${widget.id}');
      final data = response.data;
      if (mounted) setState(() => _ticket = data is Map ? asJsonMap(data) : null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = _say(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadCanned() async {
    try {
      final response = await _api.get('admin/support/canned-replies');
      final data = response.data;
      if (mounted && data is List) {
        setState(() => _canned = [for (final item in data) if (item is Map) asJsonMap(item)]);
      }
    } on Object {
      // Ready-made replies are a help, not a need
    }
  }

  Future<void> _act(Future<Object?> Function() call, {required String done, bool clearReply = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await call();
      if (clearReply) _reply.clear();
      widget.onChanged();
      if (mounted) setState(() => _notice = done);
      await _load();
    } on Object catch (e) {
      if (mounted) setState(() => _error = _say(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCanned() async {
    final text = _reply.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write the reply first, then save it as a ready-made reply.');
      return;
    }
    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save as ready-made reply'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Short title'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (title == null || title.isEmpty || !mounted) return;
    await _act(
      () => _api.post('admin/support/canned-replies', body: {'title': title, 'body': text}),
      done: 'Ready-made reply saved.',
    );
    await _loadCanned();
  }

  Future<void> _removeCanned() async {
    final id = _cannedId;
    if (id == null) return;
    await _act(() => _api.delete('admin/support/canned-replies/$id'), done: 'Ready-made reply removed.');
    if (mounted) setState(() => _cannedId = null);
    await _loadCanned();
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    return parsed == null ? '' : MaterialLocalizations.of(context).formatMediumDate(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _ticket;
    final status = '${t?['status'] ?? ''}';
    final replies = [for (final r in t?['replies'] as List? ?? const []) if (r is Map) asJsonMap(r)];
    final proofs = [for (final p in t?['proofs'] as List? ?? const []) if (p is Map) asJsonMap(p)];
    final resolved = status == 'RESOLVED';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t == null ? 'Ticket' : '${t['ticketNumber']} - ${_label(_categories, t['category'])}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ],
        ),
        if (_busy && t == null) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
            child: Text(_error!, style: const TextStyle(color: AbraColors.danger)),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
            child: Text(_notice!, style: TextStyle(color: Colors.green.shade800)),
          ),
        if (t != null) ...[
          Wrap(
            spacing: AbraSpacing.sm,
            runSpacing: AbraSpacing.xs,
            children: [
              AbraStatusBadge(
                label: _label(_statuses, status),
                tone: switch (status) {
                  'OPEN' => AbraStatusTone.warning,
                  'IN_PROGRESS' => AbraStatusTone.info,
                  _ => AbraStatusTone.success,
                },
              ),
              if (t['overdue'] == true) const AbraStatusBadge(label: 'Overdue', tone: AbraStatusTone.danger),
              AbraStatusBadge(label: '${_label(_priorities, t['priority'])} priority', tone: AbraStatusTone.neutral),
            ],
          ),
          const SizedBox(height: AbraSpacing.md),
          Text('From ${t['customerName']}${'${t['bookingRef']}'.isEmpty ? '' : ' - booking ${t['bookingRef']}'}'),
          Text('Raised ${_date(t['createdAt'])}', style: theme.textTheme.bodySmall),
          const SizedBox(height: AbraSpacing.md),
          Container(
            padding: const EdgeInsets.all(AbraSpacing.md),
            decoration: const BoxDecoration(color: AbraColors.lightBlue, borderRadius: AbraRadius.medium),
            child: SelectableText('${t['message']}'),
          ),
          if (proofs.isNotEmpty) ...[
            const SizedBox(height: AbraSpacing.sm),
            Text('Proof files: ${proofs.map((p) => p['originalName']).join(', ')}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AbraSpacing.md),
          for (final r in replies)
            Padding(
              padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['authorType'] == 'STAFF' ? 'Support' : 'Customer'} - ${r['authorName']}, ${_date(r['at'])}',
                    style: theme.textTheme.labelMedium?.copyWith(color: AbraColors.textSecondary),
                  ),
                  SelectableText('${r['body']}'),
                ],
              ),
            ),
          if (widget.canManage) ...[
            const Divider(),
            if (!resolved) ...[
              if (_canned.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
                  child: DropdownButtonFormField<String>(
                    initialValue: _cannedId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ready-made reply',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final c in _canned) DropdownMenuItem(value: '${c['id']}', child: Text('${c['title']}')),
                    ],
                    onChanged: (v) => setState(() {
                      _cannedId = v;
                      final chosen = _canned.where((c) => '${c['id']}' == v);
                      if (chosen.isNotEmpty) _reply.text = '${chosen.first['body']}';
                    }),
                  ),
                ),
              if (_cannedId != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _busy ? null : _removeCanned,
                    child: const Text('Remove this ready-made reply'),
                  ),
                ),
              TextField(
                controller: _reply,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Your reply', border: OutlineInputBorder()),
              ),
              const SizedBox(height: AbraSpacing.sm),
            ],
            Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.sm,
              children: [
                if (!resolved)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => _api.post('admin/support/tickets/${widget.id}/reply', body: {'message': _reply.text}),
                            done: 'Reply sent.',
                            clearReply: true,
                          ),
                    child: const Text('Send reply'),
                  ),
                if (!resolved)
                  OutlinedButton(onPressed: _busy ? null : _saveCanned, child: const Text('Save as ready-made reply')),
                if (!resolved && t['assignedToMe'] != true)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => _api.post('admin/support/tickets/${widget.id}/assign', body: {'assignToMe': true}),
                            done: 'Assigned to you.',
                          ),
                    child: const Text('Assign to me'),
                  ),
                if (!resolved && t['assignedToMe'] == true)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => _api.post('admin/support/tickets/${widget.id}/assign', body: {'assignToMe': false}),
                            done: 'Given back to the team.',
                          ),
                    child: const Text('Give back'),
                  ),
                if (!resolved)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => _api.post('admin/support/tickets/${widget.id}/resolve'),
                            done: 'Ticket resolved.',
                          ),
                    child: const Text('Mark resolved'),
                  ),
                if (resolved)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => _api.post('admin/support/tickets/${widget.id}/reopen'),
                            done: 'Ticket reopened.',
                          ),
                    child: const Text('Reopen'),
                  ),
                for (final p in const ['LOW', 'NORMAL', 'HIGH'])
                  if (t['priority'] != p)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () => _api.patch('admin/support/tickets/${widget.id}', body: {'priority': p}),
                              done: 'Priority set to ${_label(_priorities, p).toLowerCase()}.',
                            ),
                      child: Text('Set ${_label(_priorities, p).toLowerCase()} priority'),
                    ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
