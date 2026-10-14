import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../kyc/kyc_client_manage_screen.dart' show showKycHistory;
import 'onboarding_page.dart';
import 'onboarding_repository.dart';

final clientKycProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) async =>
      (await ref.watch(appDependenciesProvider).apiClient.get('client/kyc'))
          .decodeObject((j) => j),
);

/// How often the waiting screen asks the server for the decision.
const _checkEvery = 20;

/// Introduction, questions, conditional document checklist and review status in
/// one feature file. The server owns the checklist and the approval decision.
class ClientKycBasedScreen extends ConsumerStatefulWidget {
  const ClientKycBasedScreen({super.key});
  @override
  ConsumerState<ClientKycBasedScreen> createState() =>
      _ClientKycBasedScreenState();
}

class _ClientKycBasedScreenState extends ConsumerState<ClientKycBasedScreen> {
  final _company = TextEditingController();
  final Map<String, Object?> _answers = {};
  bool _introduced = false;
  bool _editing = true;
  bool _busy = false;
  bool _underReview = false;
  String? _error;
  String? _loadedId;
  int _secondsToCheck = _checkEvery;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _busy || !_underReview) return;
      if (_secondsToCheck > 1) {
        setState(() => _secondsToCheck -= 1);
        return;
      }
      setState(() => _secondsToCheck = _checkEvery);
      ref.invalidate(clientKycProvider);
      unawaited(ref.read(accessProvider.notifier).refreshApproval());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _company.dispose();
    super.dispose();
  }

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
            'client/kyc',
            body: <String, Object?>{
              'companyName': _company.text.trim(),
              'introductionAccepted': true,
              'answers': _answers,
            },
          );
      if (!mounted) return;
      setState(() => _editing = false);
      ref.invalidate(clientKycProvider);
      if (_loadedId != null) ref.invalidate(onboardingFileProvider(_loadedId!));
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = failureText(AbraLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(clientKycProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AbraStateView(
          kind: AbraStateKind.error,
          message: failureText(AbraLocalizations.of(context), e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(clientKycProvider),
        ),
        data: (view) {
          final rawKyc = view['kyc'];
          final kyc = rawKyc is Map ? asJsonMap(rawKyc) : <String, Object?>{};
          if (_loadedId != view['submissionId']) {
            _loadedId = '${view['submissionId']}';
            _company.text = '${view['companyName'] ?? ''}';
            final saved = kyc['answers'];
            if (saved is Map) _answers.addAll(asJsonMap(saved));
            _introduced = kyc['introductionAcceptedAt'] != null;
            _editing = !_introduced;
          }
          final status = '${view['status']}';
          _underReview = status == 'PENDING';
          final editable = status == 'DRAFT';
          if (view['approved'] == true) return _approved(context);
          if (!_introduced) return _welcome(context);
          if (editable && _editing && kyc.isNotEmpty) {
            return _questions(context, kyc);
          }
          return _documents(context, view, status, editable);
        },
      );

  // ------------------------------------------------------------- screens

  /// The width every KYC screen is centred at.
  Widget _page(List<Widget> children, {double maxWidth = 760}) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );

  Widget _approved(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AbraCard(
          padding: const EdgeInsets.all(AbraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BigIcon(
                icon: Icons.verified_user_outlined,
                background: AbraColors.tealContainer,
                color: AbraColors.teal,
              ),
              const SizedBox(height: AbraSpacing.lg),
              Text(
                'Your company is approved',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AbraSpacing.sm),
              Text(
                'Your company is approved. Your account is ready.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(accessProvider.notifier).refreshApproval();
                    if (context.mounted) context.go('/dashboard');
                  },
                  child: const Text('Open my account'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    return _page([
      Container(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        decoration: const BoxDecoration(
          gradient: AbraGradients.brand,
          borderRadius: AbraRadius.extraLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WELCOME',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AbraColors.white,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AbraSpacing.sm),
            Text(
              'Welcome to Abra Travels',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AbraColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AbraSpacing.sm),
            Text(
              'Manage your company and buses, list approved trips, and follow your bookings in one place. First, we verify your company so customers can travel with confidence.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AbraColors.white,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AbraSpacing.lg),
      const AbraCard(
        child: Column(
          children: [
            _StepRow(
              icon: Icons.help_outline,
              title: 'Tell us about your company',
              text:
                  'Your answers determine the documents our admin team asks you to provide.',
            ),
            SizedBox(height: AbraSpacing.lg),
            _StepRow(
              icon: Icons.upload_file,
              title: 'Upload your documents',
              text:
                  'Provide required documents and any optional documents you want reviewed.',
            ),
            SizedBox(height: AbraSpacing.lg),
            _StepRow(
              icon: Icons.verified_user_outlined,
              title: 'Wait for verification',
              text:
                  'We notify you when the admin approves your account or asks you to correct a document. Account features open after approval.',
            ),
          ],
        ),
      ),
      const SizedBox(height: AbraSpacing.lg),
      const _InfoBanner(
        icon: Icons.lock_outline,
        text:
            'Buses, trips and staff open after approval. You can follow your notifications at any time.',
      ),
      const SizedBox(height: AbraSpacing.lg),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: () => setState(() => _introduced = true),
          child: const Text('Continue to KYC'),
        ),
      ),
    ]);
  }

  Widget _questions(BuildContext context, JsonMap kyc) {
    final theme = Theme.of(context);
    final configuration = asJsonMap(kyc['configuration']! as Map);
    final questions =
        (configuration['questions']! as List)
            .whereType<Map<Object?, Object?>>()
            .map(asJsonMap)
            .where((q) => q['active'] == true && q['appliesTo'] == 'OPERATOR')
            .toList()
          ..sort(
            (a, b) =>
                (a['sortOrder']! as int).compareTo(b['sortOrder']! as int),
          );
    return _page([
      const _StepBar(done: 1, total: 3),
      const SizedBox(height: AbraSpacing.lg),
      Text('Complete your KYC', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AbraSpacing.xs),
      Text(
        'Answer these questions to see the documents you need to upload.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AbraColors.textSecondary,
        ),
      ),
      const SizedBox(height: AbraSpacing.lg),
      AbraCard(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _company,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Company name *'),
            ),
            const SizedBox(height: AbraSpacing.xl),
            for (final q in questions) ...[
              Text(
                '${q['label']}${q['required'] == true ? ' *' : ' (optional)'}',
                style: theme.textTheme.titleSmall,
              ),
              if ('${q['help']}'.isNotEmpty) ...[
                const SizedBox(height: AbraSpacing.xs),
                Text(
                  '${q['help']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AbraSpacing.sm),
              Wrap(
                spacing: AbraSpacing.sm,
                runSpacing: AbraSpacing.sm,
                children: [
                  for (final option
                      in q['type'] == 'BOOLEAN'
                          ? <JsonMap>[
                              {'value': 'true', 'label': 'Yes'},
                              {'value': 'false', 'label': 'No'},
                            ]
                          : (q['options']! as List)
                                .whereType<Map<Object?, Object?>>()
                                .map(asJsonMap))
                    FilterChip(
                      label: Text('${option['label']}'),
                      showCheckmark: false,
                      selectedColor: AbraColors.skyContainer,
                      side: BorderSide(
                        color: _isSelected(q, option)
                            ? AbraColors.blue
                            : AbraColors.border,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isSelected(q, option)
                            ? AbraColors.deepBlue
                            : AbraColors.textPrimary,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      selected: _isSelected(q, option),
                      onSelected: _busy
                          ? null
                          : (selected) => setState(() {
                              final key = '${q['key']}';
                              final value = '${option['value']}';
                              if (q['type'] == 'MULTI_CHOICE') {
                                final values = List<String>.from(
                                  _answers[key] as List? ?? [],
                                );
                                selected
                                    ? values.add(value)
                                    : values.remove(value);
                                _answers[key] = values;
                              } else {
                                selected
                                    ? _answers[key] = value
                                    : _answers.remove(key);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),
            ],
            if (_error != null) ...[
              _InfoBanner(
                icon: Icons.error_outline,
                text: _error!,
                tone: AbraStatusTone.danger,
              ),
              const SizedBox(height: AbraSpacing.md),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy ? 'Saving…' : 'Save answers and view documents',
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  bool _isSelected(JsonMap q, JsonMap option) => q['type'] == 'MULTI_CHOICE'
      ? (_answers['${q['key']}'] as List? ?? []).contains(option['value'])
      : _answers['${q['key']}'] == option['value'];

  Widget _documents(
    BuildContext context,
    JsonMap view,
    String status,
    bool editable,
  ) {
    final theme = Theme.of(context);
    final waiting = status == 'PENDING';
    final subtitle = status == 'REJECTED'
        ? 'Please correct the documents marked as rejected.'
        : 'Upload your documents and submit for verification.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AbraSpacing.lg,
            AbraSpacing.lg,
            AbraSpacing.lg,
            AbraSpacing.sm,
          ),
          child: waiting
              ? _WaitingCard(secondsToCheck: _secondsToCheck)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _StepBar(done: 2, total: 3),
                    const SizedBox(height: AbraSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status == 'REJECTED'
                                    ? 'Documents need fixing'
                                    : 'Your documents',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: AbraSpacing.xs),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AbraColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (editable)
                          TextButton(
                            onPressed: () => setState(() => _editing = true),
                            child: const Text('Edit answers'),
                          ),
                        TextButton.icon(
                          onPressed: () => showKycHistory(
                            context,
                            '${view['submissionId']}',
                          ),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('History'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        Expanded(
          child: OnboardingPage(id: '${view['submissionId']}', embedded: true),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- pieces

/// Three steps (questions, documents, decision): the ones done are filled.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step $done of $total',
    child: Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AbraSpacing.xs + 2),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < done - 1
                    ? AbraColors.blue
                    : i == done - 1
                    ? AbraColors.skyBlue
                    : AbraColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AbraColors.skyContainer,
            borderRadius: AbraRadius.medium,
          ),
          child: Icon(icon, color: AbraColors.deepBlue),
        ),
        const SizedBox(width: AbraSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: AbraSpacing.xxs),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.tone = AbraStatusTone.info,
  });
  final IconData icon;
  final String text;
  final AbraStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AbraStatusColors.from(context).of(tone);
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AbraRadius.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.foreground),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigIcon extends StatelessWidget {
  const _BigIcon({
    required this.icon,
    required this.background,
    required this.color,
  });
  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 44, color: color),
    ),
  );
}

/// The waiting screen: the file has been sent and the team decides.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.secondsToCheck});
  final int secondsToCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(String title, String text, int state) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == 2
                ? AbraColors.teal
                : state == 1
                ? AbraColors.orange
                : AbraColors.border,
          ),
          child: Icon(
            state == 2 ? Icons.check : Icons.circle,
            size: state == 2 ? 15 : 8,
            color: AbraColors.white,
          ),
        ),
        const SizedBox(width: AbraSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return AbraCard(
      padding: const EdgeInsets.all(AbraSpacing.xl),
      child: Column(
        children: [
          const _BigIcon(
            icon: Icons.hourglass_top,
            background: AbraColors.orangeContainer,
            color: AbraColors.orange,
          ),
          const SizedBox(height: AbraSpacing.lg),
          Text(
            'Under verification',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            'Our team is reviewing your documents. We will notify you here, by email and on your phone as soon as there is a decision.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              children: [
                step('Documents sent', 'Your documents reached our team', 2),
                const SizedBox(height: AbraSpacing.md),
                step(
                  'Review in progress',
                  'Usually within 1–2 working days',
                  1,
                ),
                const SizedBox(height: AbraSpacing.md),
                step('Decision', 'You will be notified', 0),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Text(
            'Checking again in $secondsToCheck s',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go('/notifications'),
            child: const Text('Open notifications'),
          ),
        ],
      ),
    );
  }
}
