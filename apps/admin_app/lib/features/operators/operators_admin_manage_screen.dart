import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/failure_text.dart';
import '../../core/format.dart';
import '../../l10n/admin_strings.dart';
import '../../routing/admin_routes.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/widgets/catalogue_common.dart';
import '../reviews/reviews_page.dart';

// ===== 1. DATA =====

/// One operator for the detail page (`GET admin/operators/:id`).
final operatorDetailProvider = FutureProvider.autoDispose
    .family<JsonMap, String>(
      (ref, id) =>
          ref.watch(catalogueRepositoryProvider).get('admin/operators/$id'),
    );

/// The buses of an operator (the Buses tab).
final operatorBusesProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, String>((ref, id) async {
      final page = await ref
          .watch(catalogueRepositoryProvider)
          .list(
            ResourceQuery(
              'buses',
              pageSize: 100,
              filters: <String, String>{'operatorId': id},
            ),
          );
      return page.items;
    });

/// What was done to an operator, newest first (the Activity tab; needs
/// `audit.read`).
final operatorActivityProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, String>((ref, id) async {
      final response = await ref
          .watch(appDependenciesProvider)
          .apiClient
          .get(
            'audit-logs',
            query: <String, Object?>{'operatorId': id, 'pageSize': 30},
          );
      return response.decodeList((json) => json);
    });

/// The tabs of the page, as the demo names them.
enum OperatorTab { overview, buses, payout, bookings, activity }

const _tabLabels = <OperatorTab, String>{
  OperatorTab.overview: AdminStrings.opdTabOverview,
  OperatorTab.buses: AdminStrings.opdTabBuses,
  OperatorTab.payout: AdminStrings.opdTabPayout,
  OperatorTab.bookings: AdminStrings.opdTabBookings,
  OperatorTab.activity: AdminStrings.opdTabActivity,
};

AbraStatusTone _statusTone(String status) => switch (status) {
  'ACTIVE' => AbraStatusTone.success,
  'PENDING_APPROVAL' => AbraStatusTone.warning,
  'SUSPENDED' || 'REJECTED' => AbraStatusTone.danger,
  _ => AbraStatusTone.neutral,
};

String _nameOf(JsonMap operator) =>
    '${operator['displayName'] ?? operator['companyName']}';

// ===== 2. WINDOWS =====

/// "Suspend" an operator: what stays running, a reason the owner reads, and what
/// Abra checked (kept for Abra). Returns true when the operator was suspended.
Future<bool> showSuspendOperatorDialog(
  BuildContext context,
  JsonMap operator,
) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (context) => _SuspendDialog(operator: operator),
  );
  return done ?? false;
}

class _SuspendDialog extends ConsumerStatefulWidget {
  const _SuspendDialog({required this.operator});

  final JsonMap operator;

  @override
  ConsumerState<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends ConsumerState<_SuspendDialog> {
  final _reason = TextEditingController();
  final _proof = TextEditingController();
  var _showError = false;
  var _saving = false;
  String? _failure;

  @override
  void dispose() {
    _reason.dispose();
    _proof.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AbraLocalizations.of(context);
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final proof = _proof.text.trim();
      await ref.read(catalogueRepositoryProvider).post(
        'admin/operators/${widget.operator['id']}/suspend',
        <String, Object?>{
          'reason': reason,
          if (proof.length >= 3) 'proofNote': proof,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = failureText(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final impact = widget.operator['impact'] is Map
        ? asJsonMap(widget.operator['impact'] as Map)
        : const <String, Object?>{};
    return AlertDialog(
      title: Text(
        l10n.text(AdminStrings.opdSuspendTitle, <String, Object?>{
          'name': _nameOf(widget.operator),
        }),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.text(AdminStrings.opdSuspendBody, <String, Object?>{
                  'bookings': impact['confirmedBookings'] ?? 0,
                  'trips': impact['upcomingTrips'] ?? 0,
                }),
              ),
              const SizedBox(height: AbraSpacing.md),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AbraSpacing.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _failure!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              TextFormField(
                controller: _reason,
                enabled: !_saving,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.opdSuspendReason),
                  errorText: _showError && _reason.text.trim().length < 3
                      ? l10n.text(AdminStrings.formRequired)
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextFormField(
                controller: _proof,
                enabled: !_saving,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.opdSuspendProof),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.text(AbraStrings.commonCancel)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AbraColors.danger,
            foregroundColor: AbraColors.white,
          ),
          onPressed: _saving ? null : _submit,
          child: Text(l10n.text(AdminStrings.opdSuspend)),
        ),
      ],
    );
  }
}

/// "Message owner": one message the owner gets in the portal and by email and
/// WhatsApp. Returns true when it was sent.
Future<bool> showMessageOwnerDialog(
  BuildContext context,
  String operatorId,
) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (context) => _MessageDialog(operatorId: operatorId),
  );
  return done ?? false;
}

class _MessageDialog extends ConsumerStatefulWidget {
  const _MessageDialog({required this.operatorId});

  final String operatorId;

  @override
  ConsumerState<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends ConsumerState<_MessageDialog> {
  final _message = TextEditingController();
  var _showError = false;
  var _saving = false;
  String? _failure;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AbraLocalizations.of(context);
    final text = _message.text.trim();
    if (text.length < 2) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(catalogueRepositoryProvider).post(
        'admin/operators/${widget.operatorId}/messages',
        <String, Object?>{'message': text},
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = failureText(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.text(AdminStrings.opdMessageTitle)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AbraSpacing.md),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _failure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            TextFormField(
              controller: _message,
              enabled: !_saving,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.text(AdminStrings.opdMessageField),
                errorText: _showError && _message.text.trim().length < 2
                    ? l10n.text(AdminStrings.formRequired)
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.text(AbraStrings.commonCancel)),
        ),
        AbraButton(
          label: l10n.text(AdminStrings.opdMessageSend),
          variant: AbraButtonVariant.primary,
          isLoading: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ===== 3. TABS =====

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.current,
    required this.onSelect,
    required this.busCount,
  });

  final OperatorTab current;
  final ValueChanged<OperatorTab> onSelect;
  final int busCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AbraColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final tab in OperatorTab.values)
              Semantics(
                selected: tab == current,
                button: true,
                child: InkWell(
                  onTap: () => onSelect(tab),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AbraSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tab == current
                              ? AbraColors.blue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          l10n.text(_tabLabels[tab]!),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: tab == current
                                ? AbraColors.deepBlue
                                : AbraColors.textSecondary,
                          ),
                        ),
                        if (tab == OperatorTab.buses) ...<Widget>[
                          const SizedBox(width: AbraSpacing.xs),
                          Text(
                            '$busCount',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AbraColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A label with its value, one line of a card.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
          ),
        ),
        Expanded(child: SelectableText(value.isEmpty ? '-' : value)),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AbraCard(
    padding: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AbraSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

/// A number with what it counts (the four cards of the Numbers box).
class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.lightGray,
        borderRadius: AbraRadius.medium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(value, style: theme.textTheme.headlineSmall),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AbraSpacing.lg),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AbraColors.textSecondary),
    ),
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.operator});

  final JsonMap operator;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final owner = operator['owner'] is Map
        ? asJsonMap(operator['owner'] as Map)
        : const <String, Object?>{};
    final numbers = operator['numbers'] is Map
        ? asJsonMap(operator['numbers'] as Map)
        : const <String, Object?>{};
    final suspension = operator['suspension'] is Map
        ? asJsonMap(operator['suspension'] as Map)
        : null;
    final sales = ((numbers['salesPaise'] as num?) ?? 0).toInt();
    final company = _Card(
      title: l10n.text(AdminStrings.opdCompany),
      children: <Widget>[
        _Line(
          l10n.text(AdminStrings.opdCompanyName),
          '${operator['companyName']}',
        ),
        _Line(l10n.text(AdminStrings.opdOwner), '${owner['name'] ?? ''}'),
        _Line(l10n.text(AdminStrings.opdEmail), '${owner['email'] ?? ''}'),
        _Line(l10n.text(AdminStrings.opdPhone), '${owner['phone'] ?? ''}'),
        _Line(l10n.text(AdminStrings.opdJoined), dateOf(operator['joinedAt'])),
      ],
    );
    final figures = _Card(
      title: l10n.text(AdminStrings.opdNumbers),
      children: <Widget>[
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AbraSpacing.md,
          crossAxisSpacing: AbraSpacing.md,
          childAspectRatio: 2.4,
          children: <Widget>[
            _Kpi(l10n.text(AdminStrings.opdBuses), '${numbers['buses'] ?? 0}'),
            _Kpi(l10n.text(AdminStrings.opdTrips), '${numbers['trips'] ?? 0}'),
            _Kpi(
              l10n.text(AdminStrings.opdBookings),
              '${numbers['bookings'] ?? 0}',
            ),
            _Kpi(
              l10n.text(AdminStrings.opdSales),
              l10n.formatters.currencyFromMinor(sales),
            ),
          ],
        ),
      ],
    );
    final isWide = AbraBreakpoint.of(context) != AbraBreakpoint.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: company),
              const SizedBox(width: AbraSpacing.lg),
              Expanded(child: figures),
            ],
          )
        else ...<Widget>[
          company,
          const SizedBox(height: AbraSpacing.md),
          figures,
        ],
        if (suspension != null) ...<Widget>[
          const SizedBox(height: AbraSpacing.lg),
          _Card(
            title: l10n.text(AdminStrings.opdSuspensionTitle),
            children: <Widget>[
              _Line(
                l10n.text(AdminStrings.opdSuspensionReason),
                '${suspension['reason']}',
              ),
              _Line(
                l10n.text(AdminStrings.opdSuspensionProof),
                '${suspension['proofNote'] ?? ''}',
              ),
              _Line(
                l10n.text(AdminStrings.opdSuspensionSince),
                dateOf(suspension['at']),
              ),
              if (suspension['reactivatedAt'] != null)
                _Line(
                  l10n.text(AdminStrings.opdSuspensionEnded),
                  dateOf(suspension['reactivatedAt']),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BusesTab extends ConsumerWidget {
  const _BusesTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    return AsyncValueView<List<JsonMap>>(
      value: ref.watch(operatorBusesProvider(id)),
      onRetry: () => ref.invalidate(operatorBusesProvider(id)),
      data: (context, buses) => buses.isEmpty
          ? _Empty(l10n.text(AdminStrings.opdBusesEmpty))
          : AbraCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: <DataColumn>[
                    DataColumn(label: Text(l10n.text(AdminStrings.opdBusReg))),
                    DataColumn(label: Text(l10n.text(AdminStrings.opdBusName))),
                    DataColumn(
                      label: Text(l10n.text(AdminStrings.fieldBusType)),
                    ),
                    DataColumn(
                      label: Text(l10n.text(AdminStrings.opdBusSeats)),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(l10n.text(AdminStrings.opdBusStatus)),
                    ),
                  ],
                  rows: <DataRow>[
                    for (final bus in buses)
                      DataRow(
                        cells: <DataCell>[
                          DataCell(Text('${bus['registrationNumber']}')),
                          DataCell(Text('${bus['name']}')),
                          DataCell(
                            LookupName('bus-types', '${bus['busTypeId']}'),
                          ),
                          DataCell(Text('${bus['seatCapacity'] ?? '-'}')),
                          DataCell(
                            StatusBadge(
                              '${bus['status']}',
                              CatalogueLabels.busStatuses,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PayoutTab extends StatelessWidget {
  const _PayoutTab({
    required this.operator,
    required this.canEdit,
    required this.onChangeMode,
    required this.onVerifyBank,
  });

  final JsonMap operator;
  final bool canEdit;
  final VoidCallback onChangeMode;
  final VoidCallback onVerifyBank;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final isWide = AbraBreakpoint.of(context) != AbraBreakpoint.phone;
    final payoutInfo = operator['payout'] is Map
        ? asJsonMap(operator['payout'] as Map)
        : const <String, Object?>{};
    final bank = payoutInfo['bank'] is Map
        ? asJsonMap(payoutInfo['bank'] as Map)
        : null;
    final auto = payoutInfo['mode'] == 'AUTO_SPLIT';
    final bankStatus = '${bank?['status']}';
    final note = '${bank?['note'] ?? ''}';
    final commission = _Card(
      title: l10n.text(AdminStrings.opdCommissionTitle),
      children: <Widget>[_Empty(l10n.text(AdminStrings.opdCommissionEmpty))],
    );
    final payout = _Card(
      title: l10n.text(AdminStrings.opdPayoutTitle),
      children: <Widget>[
        _Line(
          l10n.text(AdminStrings.opdPayoutMode),
          l10n.text(
            auto ? AdminStrings.opdPayoutAuto : AdminStrings.opdPayoutManual,
          ),
        ),
        if (bank == null)
          _Empty(l10n.text(AdminStrings.opdBankNone))
        else ...<Widget>[
          _Line(l10n.text(AdminStrings.opdBankHolder), '${bank['holderName']}'),
          _Line(
            l10n.text(AdminStrings.opdBankAccount),
            'XXXXXX${bank['accountLast4']}',
          ),
          _Line(l10n.text(AdminStrings.opdBankIfsc), '${bank['ifsc']}'),
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 130,
                  child: Text(
                    l10n.text(AdminStrings.opdBankStatus),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ),
                AbraStatusBadge(
                  label: l10n.text(switch (bankStatus) {
                    'VERIFIED' => AdminStrings.opdBankVerifiedLabel,
                    'FAILED' => AdminStrings.opdBankFailedLabel,
                    _ => AdminStrings.opdBankPending,
                  }),
                  tone: switch (bankStatus) {
                    'VERIFIED' => AbraStatusTone.success,
                    'FAILED' => AbraStatusTone.danger,
                    _ => AbraStatusTone.warning,
                  },
                ),
              ],
            ),
          ),
          if (note.isNotEmpty)
            _Line(l10n.text(AdminStrings.opdBankCheck), note),
        ],
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(top: AbraSpacing.sm),
            child: Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.sm,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onChangeMode,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(l10n.text(AdminStrings.opdChangeMode)),
                ),
                if (bank != null && bankStatus != 'VERIFIED')
                  OutlinedButton.icon(
                    onPressed: onVerifyBank,
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(l10n.text(AdminStrings.opdVerifyBank)),
                  ),
              ],
            ),
          ),
      ],
    );
    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: commission),
              const SizedBox(width: AbraSpacing.lg),
              Expanded(child: payout),
            ],
          )
        : Column(
            children: <Widget>[
              commission,
              const SizedBox(height: AbraSpacing.md),
              payout,
            ],
          );
  }
}

// ===== 3b. PAYOUT WINDOWS =====

/// "Change payout mode": automatic (needs a verified bank account) or manual.
/// Returns true when it was saved.
Future<bool> showPayoutModeDialog(
  BuildContext context,
  JsonMap operator,
) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (context) => _PayoutModeDialog(operator: operator),
  );
  return done ?? false;
}

class _PayoutModeDialog extends ConsumerStatefulWidget {
  const _PayoutModeDialog({required this.operator});

  final JsonMap operator;

  @override
  ConsumerState<_PayoutModeDialog> createState() => _PayoutModeDialogState();
}

class _PayoutModeDialogState extends ConsumerState<_PayoutModeDialog> {
  late String _mode =
      (widget.operator['payout'] is Map
              ? asJsonMap(widget.operator['payout'] as Map)['mode']
              : null)
          as String? ??
      'MANUAL';
  var _saving = false;
  String? _failure;

  Future<void> _submit() async {
    final l10n = AbraLocalizations.of(context);
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(catalogueRepositoryProvider).put(
        'admin/operators/${widget.operator['id']}/payout-mode',
        <String, Object?>{'mode': _mode},
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = failureText(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AlertDialog(
      title: Text(
        l10n.text(AdminStrings.opdModeTitle, <String, Object?>{
          'name': _nameOf(widget.operator),
        }),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AbraSpacing.md),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _failure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.text(AdminStrings.opdModeField),
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'AUTO_SPLIT',
                  child: Text(l10n.text(AdminStrings.opdModeAutoOption)),
                ),
                DropdownMenuItem<String>(
                  value: 'MANUAL',
                  child: Text(l10n.text(AdminStrings.opdModeManualOption)),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _mode = value ?? _mode),
            ),
            const SizedBox(height: AbraSpacing.md),
            Text(
              l10n.text(AdminStrings.opdModeHint),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.text(AbraStrings.commonCancel)),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(l10n.text(AdminStrings.opdModeSave)),
        ),
      ],
    );
  }
}

/// "Verify bank": records the result of checking the account by hand.
/// Returns 'VERIFIED' or 'FAILED' when saved, null when closed.
Future<String?> showVerifyBankDialog(BuildContext context, JsonMap operator) =>
    showDialog<String>(
      context: context,
      builder: (context) => _VerifyBankDialog(operator: operator),
    );

class _VerifyBankDialog extends ConsumerStatefulWidget {
  const _VerifyBankDialog({required this.operator});

  final JsonMap operator;

  @override
  ConsumerState<_VerifyBankDialog> createState() => _VerifyBankDialogState();
}

class _VerifyBankDialogState extends ConsumerState<_VerifyBankDialog> {
  final _note = TextEditingController();
  var _outcome = 'VERIFIED';
  var _showError = false;
  var _saving = false;
  String? _failure;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AbraLocalizations.of(context);
    final note = _note.text.trim();
    if (note.length < 3) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(catalogueRepositoryProvider).post(
        'admin/operators/${widget.operator['id']}/bank/verify',
        <String, Object?>{'outcome': _outcome, 'note': note},
      );
      if (mounted) Navigator.of(context).pop(_outcome);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = failureText(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AlertDialog(
      title: Text(
        l10n.text(AdminStrings.opdVerifyTitle, <String, Object?>{
          'name': _nameOf(widget.operator),
        }),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.text(AdminStrings.opdVerifyHint),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AbraSpacing.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _failure!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: _outcome,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.opdVerifyOutcome),
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'VERIFIED',
                    child: Text(l10n.text(AdminStrings.opdVerifyPassed)),
                  ),
                  DropdownMenuItem<String>(
                    value: 'FAILED',
                    child: Text(l10n.text(AdminStrings.opdVerifyFailedOption)),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _outcome = value ?? _outcome),
              ),
              const SizedBox(height: AbraSpacing.md),
              TextFormField(
                controller: _note,
                enabled: !_saving,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.text(AdminStrings.opdVerifyNote),
                  errorText: _showError && _note.text.trim().length < 3
                      ? l10n.text(AdminStrings.formRequired)
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.text(AbraStrings.commonCancel)),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(l10n.text(AdminStrings.opdVerifySave)),
        ),
      ],
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    return AsyncValueView<List<JsonMap>>(
      value: ref.watch(operatorActivityProvider(id)),
      onRetry: () => ref.invalidate(operatorActivityProvider(id)),
      data: (context, entries) => entries.isEmpty
          ? _Empty(l10n.text(AdminStrings.opdActivityEmpty))
          : AbraCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AbraSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AbraSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              CatalogueLabels.readable(
                                '${entry['action']}'.replaceAll('.', ' '),
                              ),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (entry['reason'] != null)
                              Text('${entry['reason']}'),
                            Text(
                              dateOf(entry['at']),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AbraColors.textSecondary),
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
}

// ===== 4. THE SCREEN =====

/// One operator (`#/operators/:id`): who they are, what they run, and what
/// Abra can do about it. Suspend stops new sales at once (trips already sold
/// still run); the owner is told. Bookings and commission fill in with the
/// phases that build them.
class OperatorDetailPage extends ConsumerWidget {
  const OperatorDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncValueView<JsonMap>(
    value: ref.watch(operatorDetailProvider(id)),
    onRetry: () => ref.invalidate(operatorDetailProvider(id)),
    data: (context, operator) => _OperatorBody(id: id, operator: operator),
  );
}

class _OperatorBody extends ConsumerStatefulWidget {
  const _OperatorBody({required this.id, required this.operator});

  final String id;
  final JsonMap operator;

  @override
  ConsumerState<_OperatorBody> createState() => _OperatorBodyState();
}

class _OperatorBodyState extends ConsumerState<_OperatorBody> {
  var _tab = OperatorTab.overview;
  var _busy = false;

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  void _reload() {
    ref
      ..invalidate(operatorDetailProvider(widget.id))
      ..invalidate(operatorActivityProvider(widget.id));
  }

  Future<void> _suspend() async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await showSuspendOperatorDialog(context, widget.operator);
    if (!done || !mounted) return;
    _reload();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _l10n.text(AdminStrings.opdSuspended, <String, Object?>{
            'name': _nameOf(widget.operator),
          }),
        ),
      ),
    );
  }

  Future<void> _reactivate() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(catalogueRepositoryProvider)
          .post('admin/operators/${widget.id}/reactivate');
      _reload();
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.text(AdminStrings.opdReactivated))),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureText(_l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeMode() async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showPayoutModeDialog(context, widget.operator);
    if (!saved || !mounted) return;
    _reload();
    messenger.showSnackBar(
      SnackBar(content: Text(_l10n.text(AdminStrings.opdModeSaved))),
    );
  }

  Future<void> _verifyBank() async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await showVerifyBankDialog(context, widget.operator);
    if (outcome == null || !mounted) return;
    _reload();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _l10n.text(
            outcome == 'VERIFIED'
                ? AdminStrings.opdBankMarkedVerified
                : AdminStrings.opdBankMarkedFailed,
          ),
        ),
      ),
    );
  }

  Future<void> _message() async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showMessageOwnerDialog(context, widget.id);
    if (!sent || !mounted) return;
    _reload();
    messenger.showSnackBar(
      SnackBar(content: Text(_l10n.text(AdminStrings.opdMessageSent))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final operator = widget.operator;
    final status = '${operator['status']}';
    final kyc = operator['kycStatus'] as String?;
    final canDecide = ref
        .watch(accessProvider)
        .can(PermissionKeys.operatorsApprove);
    final numbers = operator['numbers'] is Map
        ? asJsonMap(operator['numbers'] as Map)
        : const <String, Object?>{};
    final isCompact = AbraBreakpoint.of(context) == AbraBreakpoint.phone;

    final actions = <Widget>[
      if (canDecide && status == 'ACTIVE')
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AbraColors.danger,
            foregroundColor: AbraColors.white,
          ),
          onPressed: _busy ? null : _suspend,
          icon: const Icon(Icons.lock_outline),
          label: Text(l10n.text(AdminStrings.opdSuspend)),
        ),
      if (canDecide && status == 'SUSPENDED')
        FilledButton.icon(
          onPressed: _busy ? null : _reactivate,
          icon: const Icon(Icons.check),
          label: Text(l10n.text(AdminStrings.opdReactivate)),
        ),
      if (canDecide)
        OutlinedButton.icon(
          onPressed: _busy ? null : _message,
          icon: const Icon(Icons.mail_outline),
          label: Text(l10n.text(AdminStrings.opdMessage)),
        ),
    ];

    return ListView(
      padding: EdgeInsets.all(isCompact ? AbraSpacing.md : AbraSpacing.lg),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(AdminRoutes.operators),
            icon: const Icon(Icons.arrow_back),
            label: Text(l10n.text(AdminStrings.opdBack)),
          ),
        ),
        AbraCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            child: Wrap(
              spacing: AbraSpacing.lg,
              runSpacing: AbraSpacing.md,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Wrap(
                  spacing: AbraSpacing.md,
                  runSpacing: AbraSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _nameOf(operator),
                      style: theme.textTheme.headlineSmall,
                    ),
                    AbraStatusBadge(
                      label: l10n.text(
                        CatalogueLabels.operatorStatuses[status] ??
                            AdminStrings.operatorPending,
                      ),
                      tone: _statusTone(status),
                    ),
                    AbraStatusBadge(
                      label: kyc == null
                          ? l10n.text(AdminStrings.opdKycNone)
                          : l10n.text(
                              submissionStatuses[kyc] ??
                                  AdminStrings.revStatusDraft,
                            ),
                      tone: kyc == null
                          ? AbraStatusTone.neutral
                          : submissionTone(kyc),
                    ),
                  ],
                ),
                Wrap(
                  spacing: AbraSpacing.sm,
                  runSpacing: AbraSpacing.sm,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        _TabStrip(
          current: _tab,
          busCount: ((numbers['buses'] as num?) ?? 0).toInt(),
          onSelect: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: AbraSpacing.lg),
        switch (_tab) {
          OperatorTab.overview => _OverviewTab(operator: operator),
          OperatorTab.buses => _BusesTab(id: widget.id),
          OperatorTab.payout => _PayoutTab(
            operator: operator,
            canEdit: canDecide,
            onChangeMode: _changeMode,
            onVerifyBank: _verifyBank,
          ),
          OperatorTab.bookings => _Empty(
            l10n.text(AdminStrings.opdBookingsEmpty),
          ),
          OperatorTab.activity => _ActivityTab(id: widget.id),
        },
      ],
    );
  }
}
