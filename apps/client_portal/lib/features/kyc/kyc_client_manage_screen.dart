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
import '../../routing/portal_routes.dart';
import '../onboarding/onboarding_page.dart';

// The client portal Company profile page (demo page `company`): what customers
// and Abra see about the company, and the bank account payouts go to
// (`client/company`). Abra verifies the bank account; the payout mode is set by
// Abra and only shown here.

// ===== 1. STATE AND API =====

/// The company, with its bank account (last four digits only) and payout mode.
final companyProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) async =>
      (await ref.watch(appDependenciesProvider).apiClient.get('client/company'))
          .decodeObject((json) => json),
);

final _emailPattern = RegExp(r'^\S+@\S+\.\S+$');
final _gstinPattern = RegExp(
  r'^\d{2}[A-Za-z]{5}\d{4}[A-Za-z][A-Za-z0-9]Z[A-Za-z0-9]$',
);
final _accountPattern = RegExp(r'^\d{6,18}$');
final _ifscPattern = RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$');

String? _required(String? value) =>
    (value ?? '').trim().isEmpty ? 'Required' : null;

// ===== 2. THE PAGE =====

/// "Company profile": two cards, the company and its bank account.
class KycClientManageScreen extends ConsumerWidget {
  const KycClientManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncValueView<JsonMap>(
    value: ref.watch(companyProvider),
    onRetry: () => ref.invalidate(companyProvider),
    data: (context, company) => _CompanyBody(company: company),
  );
}

class _CompanyBody extends ConsumerWidget {
  const _CompanyBody({required this.company});

  final JsonMap company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref
        .watch(accessProvider)
        .can(PermissionKeys.operatorsUpdate);
    final isPhone = AbraBreakpoint.of(context) == AbraBreakpoint.phone;
    final profile = _ProfileCard(company: company, canEdit: canEdit);
    final bank = _BankCard(company: company, canEdit: canEdit);
    return ListView(
      padding: EdgeInsets.all(isPhone ? AbraSpacing.md : AbraSpacing.lg),
      children: <Widget>[
        Text(
          'Company profile',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AbraSpacing.xs),
        Text(
          'Details customers and Abra see.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AbraColors.textSecondary),
        ),
        const SizedBox(height: AbraSpacing.lg),
        if (isPhone) ...<Widget>[
          profile,
          const SizedBox(height: AbraSpacing.md),
          bank,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: profile),
              const SizedBox(width: AbraSpacing.lg),
              Expanded(child: bank),
            ],
          ),
      ],
    );
  }
}

/// A white card with a heading.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AbraCard(
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

/// What a save did: a message under the buttons.
mixin _SaveState<T extends StatefulWidget> on State<T> {
  var saving = false;
  String? failure;
  String? done;

  Future<void> run(
    WidgetRef ref,
    Future<void> Function() action,
    String message,
  ) async {
    final l10n = AbraLocalizations.of(context);
    setState(() {
      saving = true;
      failure = null;
      done = null;
    });
    try {
      await action();
      ref.invalidate(companyProvider);
      if (mounted) setState(() => done = message);
    } on Object catch (error) {
      if (mounted) setState(() => failure = failureText(l10n, error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget feedback() => failure != null
      ? Semantics(
          liveRegion: true,
          child: Text(
            failure!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        )
      : done != null
      ? Semantics(
          liveRegion: true,
          child: Text(
            done!,
            style: const TextStyle(color: AbraColors.tealDark),
          ),
        )
      : const SizedBox.shrink();
}

// ===== 3. COMPANY =====

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({required this.company, required this.canEdit});

  final JsonMap company;
  final bool canEdit;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard>
    with _SaveState<_ProfileCard> {
  final _form = GlobalKey<FormState>();
  late final _name = _controller('companyName');
  late final _owner = _controller('ownerName');
  late final _email = _controller('email');
  late final _phone = _controller('supportPhone');
  late final _city = _controller('city');
  late final _gstin = _controller('gstin');

  TextEditingController _controller(String key) =>
      TextEditingController(text: '${widget.company[key] ?? ''}');

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _owner,
      _email,
      _phone,
      _city,
      _gstin,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await run(ref, () async {
      await ref
          .read(appDependenciesProvider)
          .apiClient
          .put(
            'client/company',
            body: <String, Object?>{
              'companyName': _name.text.trim(),
              'ownerName': _owner.text.trim(),
              'email': _email.text.trim(),
              'supportPhone': _phone.text.trim(),
              'city': _city.text.trim(),
              'gstin': _gstin.text.trim(),
            },
          );
    }, 'Saved');
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller,
    enabled: widget.canEdit && !saving,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label),
    validator: validator,
  );

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Company',
    children: <Widget>[
      Form(
        key: _form,
        child: Wrap(
          runSpacing: AbraSpacing.md,
          children:
              <Widget>[
                    _field('Company name *', _name, validator: _required),
                    _field('Owner name *', _owner, validator: _required),
                    _field(
                      'Email *',
                      _email,
                      keyboard: TextInputType.emailAddress,
                      validator: (value) =>
                          _emailPattern.hasMatch((value ?? '').trim())
                          ? null
                          : 'Enter a valid email',
                    ),
                    _field(
                      'Support phone',
                      _phone,
                      keyboard: TextInputType.phone,
                    ),
                    _field('City', _city),
                    _field(
                      'GSTIN',
                      _gstin,
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ||
                              _gstinPattern.hasMatch(value!.trim())
                          ? null
                          : 'Looks wrong, for example 36ABCDE1234F1Z5',
                    ),
                  ]
                  .map(
                    (field) => SizedBox(width: double.infinity, child: field),
                  )
                  .toList(),
        ),
      ),
      const SizedBox(height: AbraSpacing.md),
      feedback(),
      if (widget.canEdit)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AbraButton(
            label: 'Save',
            icon: Icons.check,
            onPressed: saving ? null : _save,
          ),
        ),
    ],
  );
}

// ===== 4. BANK ACCOUNT =====

class _BankCard extends ConsumerStatefulWidget {
  const _BankCard({required this.company, required this.canEdit});

  final JsonMap company;
  final bool canEdit;

  @override
  ConsumerState<_BankCard> createState() => _BankCardState();
}

class _BankCardState extends ConsumerState<_BankCard>
    with _SaveState<_BankCard> {
  final _form = GlobalKey<FormState>();
  late final _holder = TextEditingController(
    text: '${_bank?['holderName'] ?? ''}',
  );
  final _account = TextEditingController();
  late final _ifsc = TextEditingController(text: '${_bank?['ifsc'] ?? ''}');

  JsonMap? get _bank => widget.company['bank'] is Map
      ? asJsonMap(widget.company['bank'] as Map)
      : null;

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await run(ref, () async {
      await ref
          .read(appDependenciesProvider)
          .apiClient
          .put(
            'client/company/bank',
            body: <String, Object?>{
              'holderName': _holder.text.trim(),
              'accountNumber': _account.text.trim(),
              'ifsc': _ifsc.text.trim().toUpperCase(),
            },
          );
      _account.clear();
    }, 'Saved. Abra will verify the account.');
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final status = '${bank?['status'] ?? 'PENDING'}';
    final note = '${bank?['note'] ?? ''}';
    final auto = widget.company['payoutMode'] == 'AUTO_SPLIT';
    return _Section(
      title: 'Bank account for payouts',
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AbraSpacing.md),
          decoration: BoxDecoration(
            color: AbraColors.orangeContainer,
            borderRadius: BorderRadius.circular(AbraRadius.md),
          ),
          child: const Text(
            'Changing the bank account pauses payouts until Abra verifies it.',
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        Form(
          key: _form,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _holder,
                enabled: widget.canEdit && !saving,
                decoration: const InputDecoration(labelText: 'Account holder'),
                validator: _required,
              ),
              const SizedBox(height: AbraSpacing.md),
              TextFormField(
                controller: _account,
                enabled: widget.canEdit && !saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Account number',
                  helperText: bank == null
                      ? null
                      : 'Saved: XXXXXX${bank['accountLast4']}. Type the number again to change it.',
                ),
                validator: (value) =>
                    _accountPattern.hasMatch((value ?? '').trim())
                    ? null
                    : 'Enter 6 to 18 digits',
              ),
              const SizedBox(height: AbraSpacing.md),
              TextFormField(
                controller: _ifsc,
                enabled: widget.canEdit && !saving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'IFSC'),
                validator: (value) =>
                    _ifscPattern.hasMatch((value ?? '').trim())
                    ? null
                    : 'Looks wrong, for example HDFC0001234',
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        Wrap(
          spacing: AbraSpacing.md,
          runSpacing: AbraSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Text('Status'),
            AbraStatusBadge(
              label: bank == null
                  ? 'Not added'
                  : switch (status) {
                      'VERIFIED' => 'Verified',
                      'FAILED' => 'Failed',
                      _ => 'Pending',
                    },
              tone: bank == null
                  ? AbraStatusTone.neutral
                  : switch (status) {
                      'VERIFIED' => AbraStatusTone.success,
                      'FAILED' => AbraStatusTone.danger,
                      _ => AbraStatusTone.warning,
                    },
            ),
          ],
        ),
        if (note.isNotEmpty) ...<Widget>[
          const SizedBox(height: AbraSpacing.sm),
          Text('Abra could not verify it: $note'),
        ],
        const SizedBox(height: AbraSpacing.md),
        feedback(),
        if (widget.canEdit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AbraButton(
              label: 'Save bank details',
              icon: Icons.check,
              onPressed: saving ? null : _save,
            ),
          ),
        const SizedBox(height: AbraSpacing.md),
        Text.rich(
          TextSpan(
            text: 'Payout mode: ',
            children: <InlineSpan>[
              TextSpan(
                text: auto ? 'Automatic (Razorpay Route)' : 'Manual settlement',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: ', set by Abra.'),
            ],
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AbraColors.textSecondary),
        ),
      ],
    );
  }
}

// ===== 3. BUS KYC AND HISTORY (Phase 1 step 9) =====

/// The KYC file of one bus (`client/kyc/buses/<busId>`): made the first time,
/// with the bus questions Abra set, if any.
final busKycProvider = FutureProvider.autoDispose.family<JsonMap, String>(
  (ref, busId) async =>
      (await ref
              .watch(appDependenciesProvider)
              .apiClient
              .get('client/kyc/buses/$busId'))
          .decodeObject((json) => json),
);

/// What happened to a KYC file, oldest first.
final kycHistoryProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, String>(
      (ref, submissionId) async =>
          (await ref
                  .watch(appDependenciesProvider)
                  .apiClient
                  .get('onboarding/submissions/$submissionId/history'))
              .decodeList((json) => json),
    );

const _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "10 Oct 2026, 2:37 pm" in India time.
String indiaTime(Object? iso) {
  final at = DateTime.tryParse('${iso ?? ''}');
  if (at == null) return '';
  final t = at.toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_months[t.month - 1]} ${t.year}, $hour:$minute '
      '${t.hour < 12 ? 'am' : 'pm'}';
}

/// The History window: every step of a KYC file with when and who.
Future<void> showKycHistory(BuildContext context, String submissionId) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('History'),
        content: SizedBox(
          width: 460,
          child: Consumer(
            builder: (context, ref, _) => AsyncValueView<List<JsonMap>>(
              value: ref.watch(kycHistoryProvider(submissionId)),
              onRetry: () => ref.invalidate(kycHistoryProvider(submissionId)),
              data: (context, entries) => entries.isEmpty
                  ? const Text('Nothing has happened yet.')
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final entry in entries)
                            _HistoryLine(entry: entry),
                        ],
                      ),
                    ),
            ),
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

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.entry});

  final JsonMap entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = '${entry['action']}';
    final color = switch (action) {
      'APPROVED' || 'DOCUMENT_APPROVED' => AbraColors.teal,
      'REJECTED' || 'DOCUMENT_REJECTED' => AbraColors.danger,
      _ => AbraColors.blue,
    };
    final details = <String>[
      if (entry['documentName'] != null) '${entry['documentName']}',
      if (entry['by'] != null) 'by ${entry['by']}',
      indiaTime(entry['at']),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${entry['label']}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  details.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
                if (entry['note'] != null)
                  Text(
                    '${entry['note']}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AbraColors.danger,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bus KYC: the bus questions (when Abra set any), then its documents, then
/// the decision. After a rejection only the rejected documents can change.
class BusKycScreen extends ConsumerStatefulWidget {
  const BusKycScreen({required this.busId, super.key});

  final String busId;

  @override
  ConsumerState<BusKycScreen> createState() => _BusKycScreenState();
}

class _BusKycScreenState extends ConsumerState<BusKycScreen> {
  final Map<String, Object?> _answers = <String, Object?>{};
  String? _loadedId;
  bool _editing = false;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(appDependenciesProvider)
          .apiClient
          .put(
            'client/kyc/buses/${widget.busId}',
            body: <String, Object?>{'answers': _answers},
          );
      if (!mounted) return;
      ref.invalidate(busKycProvider(widget.busId));
      setState(() {
        _busy = false;
        _editing = false;
      });
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
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(busKycProvider(widget.busId));
    return value.when(
      loading: () => const AbraLoadingView(),
      // "Your company must be approved first" and other refusals, in words
      error: (error, _) => AbraStateView(
        kind: AbraStateKind.empty,
        title: 'Bus documents are not open yet',
        message: failureText(l10n, error),
        actionLabel: 'Back to dashboard',
        onAction: () => context.go(PortalRoutes.dashboard),
      ),
      data: (view) {
        final kyc = view['kyc'] is Map
            ? asJsonMap(view['kyc']! as Map)
            : <String, Object?>{};
        final submissionId = '${view['submissionId']}';
        final answered =
            kyc['answers'] is Map && (kyc['answers']! as Map).isNotEmpty;
        if (_loadedId != submissionId) {
          _loadedId = submissionId;
          _answers.clear();
          if (answered) _answers.addAll(asJsonMap(kyc['answers']! as Map));
          _editing = !answered;
        }
        final status = '${view['status']}';
        final hasQuestions = view['hasQuestions'] == true;
        final askQuestions = hasQuestions && status == 'DRAFT' && _editing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _BusKycHeader(
              view: view,
              step: askQuestions ? 1 : (status == 'PENDING' ? 3 : 2),
              steps: hasQuestions ? 3 : 2,
              onEditAnswers: hasQuestions && status == 'DRAFT' && !_editing
                  ? () => setState(() => _editing = true)
                  : null,
            ),
            Expanded(
              child: askQuestions
                  ? _BusQuestions(
                      kyc: kyc,
                      answers: _answers,
                      busy: _busy,
                      error: _error,
                      onChanged: () => setState(() {}),
                      onSave: _save,
                    )
                  : OnboardingPage(id: submissionId, embedded: true),
            ),
          ],
        );
      },
    );
  }
}

class _BusKycHeader extends StatelessWidget {
  const _BusKycHeader({
    required this.view,
    required this.step,
    required this.steps,
    this.onEditAnswers,
  });

  final JsonMap view;
  final int step;
  final int steps;
  final VoidCallback? onEditAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = '${view['status']}';
    final subtitle = switch (status) {
      'APPROVED' => 'Verified. This bus can run trips.',
      'PENDING' => 'Abra is reviewing the documents. You will be told here.',
      'REJECTED' =>
        'Some documents need fixing. Replace only the rejected ones, then '
            'send them again. Accepted documents and your answers are locked.',
      _ => 'Step $step of $steps',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AbraSpacing.lg,
        AbraSpacing.lg,
        AbraSpacing.lg,
        AbraSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Buses / Bus KYC',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            children: <Widget>[
              Text(
                'Bus ${view['registrationNumber']}'
                '${view['busName'] == null ? '' : ' · ${view['busName']}'}',
                style: theme.textTheme.headlineSmall,
              ),
              Wrap(
                spacing: AbraSpacing.sm,
                children: <Widget>[
                  if (onEditAnswers != null)
                    TextButton(
                      onPressed: onEditAnswers,
                      child: const Text('Edit answers'),
                    ),
                  AbraButton(
                    label: 'History',
                    icon: Icons.history,
                    variant: AbraButtonVariant.secondary,
                    onPressed: () =>
                        showKycHistory(context, '${view['submissionId']}'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: status == 'REJECTED'
                  ? AbraColors.danger
                  : AbraColors.textSecondary,
            ),
          ),
          if (status == 'DRAFT') ...<Widget>[
            const SizedBox(height: AbraSpacing.md),
            Row(
              children: <Widget>[
                for (var i = 1; i <= steps; i++) ...<Widget>[
                  if (i > 1) const SizedBox(width: AbraSpacing.xs + 2),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < step
                            ? AbraColors.blue
                            : i == step
                            ? AbraColors.skyBlue
                            : AbraColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The bus questions Abra set; the answers decide the documents.
class _BusQuestions extends StatelessWidget {
  const _BusQuestions({
    required this.kyc,
    required this.answers,
    required this.busy,
    required this.error,
    required this.onChanged,
    required this.onSave,
  });

  final JsonMap kyc;
  final Map<String, Object?> answers;
  final bool busy;
  final String? error;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  bool _selected(JsonMap question, String value) =>
      question['type'] == 'MULTI_CHOICE'
      ? (answers['${question['key']}'] as List? ?? const <Object?>[]).contains(
          value,
        )
      : answers['${question['key']}'] == value;

  void _toggle(JsonMap question, String value, bool selected) {
    final key = '${question['key']}';
    if (question['type'] == 'MULTI_CHOICE') {
      final values = List<String>.from(answers[key] as List? ?? <String>[]);
      selected ? values.add(value) : values.remove(value);
      answers[key] = values;
    } else {
      selected ? answers[key] = value : answers.remove(key);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configuration = kyc['configuration'] is Map
        ? asJsonMap(kyc['configuration']! as Map)
        : <String, Object?>{};
    final questions =
        (configuration['questions'] as List? ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()
            .map(asJsonMap)
            .where((q) => q['active'] == true && q['appliesTo'] == 'BUS')
            .toList()
          ..sort(
            (a, b) => ((a['sortOrder'] as num?) ?? 0).compareTo(
              (b['sortOrder'] as num?) ?? 0,
            ),
          );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: AbraCard(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Answer these questions to see the documents this bus needs.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
            const SizedBox(height: AbraSpacing.lg),
            for (final question in questions) ...<Widget>[
              Text(
                '${question['label']}'
                '${question['required'] == true ? ' *' : ' (optional)'}',
                style: theme.textTheme.titleSmall,
              ),
              if ('${question['help'] ?? ''}'.isNotEmpty)
                Text(
                  '${question['help']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              const SizedBox(height: AbraSpacing.sm),
              Wrap(
                spacing: AbraSpacing.sm,
                runSpacing: AbraSpacing.sm,
                children: <Widget>[
                  for (final option
                      in question['type'] == 'BOOLEAN'
                          ? const <JsonMap>[
                              <String, Object?>{
                                'value': 'true',
                                'label': 'Yes',
                              },
                              <String, Object?>{
                                'value': 'false',
                                'label': 'No',
                              },
                            ]
                          : (question['options'] as List? ?? const <Object?>[])
                                .whereType<Map<Object?, Object?>>()
                                .map(asJsonMap))
                    FilterChip(
                      label: Text('${option['label']}'),
                      showCheckmark: false,
                      selectedColor: AbraColors.skyContainer,
                      side: BorderSide(
                        color: _selected(question, '${option['value']}')
                            ? AbraColors.blue
                            : AbraColors.border,
                      ),
                      selected: _selected(question, '${option['value']}'),
                      onSelected: busy
                          ? null
                          : (selected) => _toggle(
                              question,
                              '${option['value']}',
                              selected,
                            ),
                    ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),
            ],
            if (error != null) ...<Widget>[
              Text(error!, style: const TextStyle(color: AbraColors.danger)),
              const SizedBox(height: AbraSpacing.md),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: AbraButton(
                label: 'Save answers and see documents',
                isLoading: busy,
                onPressed: busy ? null : onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
