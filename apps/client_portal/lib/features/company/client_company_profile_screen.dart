import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/failure_text.dart';
import '../auth/sign_in_screen.dart' show showClientLoginMethods;

/// The client portal Company profile page (demo page `company`): what customers
/// and Abra see about the company, and the bank account payouts go to
/// (`client/company`). Abra verifies the bank account; the payout mode is set by
/// Abra and only shown here.

final companyProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) async =>
      (await ref.watch(appDependenciesProvider).apiClient.get('client/company'))
          .decodeObject((json) => json),
);

// Keep clientCompanyProvider as an alias in case of references
final clientCompanyProvider = companyProvider;

final _emailPattern = RegExp(r'^\S+@\S+\.\S+$');
final _gstinPattern = RegExp(
  r'^\d{2}[A-Za-z]{5}\d{4}[A-Za-z][A-Za-z0-9]Z[A-Za-z0-9]$',
);
final _accountPattern = RegExp(r'^\d{6,18}$');
final _ifscPattern = RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$');

String? _required(String? value) =>
    (value ?? '').trim().isEmpty ? 'Required' : null;

/// Single screen for "Company profile" with the demo layout and real backend calls.
class ClientCompanyProfileScreen extends ConsumerWidget {
  const ClientCompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncValueView<JsonMap>(
    value: ref.watch(companyProvider),
    onRetry: () => ref.invalidate(companyProvider),
    data: (context, company) => _CompanyProfileBody(company: company),
  );
}

class _CompanyProfileBody extends ConsumerWidget {
  const _CompanyProfileBody({required this.company});

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
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Company profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => showClientLoginMethods(context),
              icon: const Icon(Icons.key_outlined, size: 18),
              label: const Text('Login methods'),
            ),
          ],
        ),
        const SizedBox(height: AbraSpacing.xs),
        Text(
          'Details customers and Abra see.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AbraColors.textSecondary,
          ),
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

/// A card with header and content.
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

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
            style: TextStyle(color: AbraColors.textPrimary),
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
          Text(
            'Abra could not verify it: $note',
            style: const TextStyle(color: AbraColors.danger),
          ),
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
