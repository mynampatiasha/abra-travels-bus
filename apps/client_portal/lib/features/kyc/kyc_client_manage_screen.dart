import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../routing/portal_routes.dart';
import '../onboarding/onboarding_page.dart';
import '../onboarding/onboarding_repository.dart';

final clientKycProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) async =>
      (await ref.watch(appDependenciesProvider).apiClient.get('client/kyc'))
          .decodeObject((j) => j),
);

/// How often the waiting screen asks the server for the decision.
const _checkEvery = 20;

/// Introduction, questions, conditional document checklist and review status in
/// one feature file. The server owns the checklist and the approval decision.
class ClientKycVerificationScreen extends ConsumerStatefulWidget {
  const ClientKycVerificationScreen({super.key});
  @override
  ConsumerState<ClientKycVerificationScreen> createState() =>
      _ClientKycVerificationScreenState();
}

class _ClientKycVerificationScreenState extends ConsumerState<ClientKycVerificationScreen> {
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
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.failure is ApiFailure &&
          (e.failure as ApiFailure).code == 'INVALID_STATE_TRANSITION') {
        // Already submitted (or decided): show the current status instead of the form.
        setState(() => _editing = false);
        ref.invalidate(clientKycProvider);
        return;
      }
      setState(() => _error = failureText(AbraLocalizations.of(context), e));
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
            final status = '${view['status']}';
            _introduced = kyc['introductionAcceptedAt'] != null ||
                view['introductionAcceptedAt'] != null ||
                status == 'PENDING' ||
                status == 'APPROVED';
            _editing = !_introduced;
          }
          final status = '${view['status']}';
          _underReview = status == 'PENDING';
          final editable = status == 'DRAFT';
          if (view['approved'] == true) return _approved(context, view);
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

  Widget _approved(BuildContext context, JsonMap view) => _page([
    AbraCard(
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
    const SizedBox(height: AbraSpacing.lg),
    _SubmittedDocuments(submissionId: '${view['submissionId']}'),
  ], maxWidth: 640);

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
          child: OnboardingPage(
            id: '${view['submissionId']}',
            embedded: true,
            // After the submit the status is no longer a draft: show the waiting screen.
            onChanged: () => ref.invalidate(clientKycProvider),
          ),
        ),
      ],
    );
  }
}

/// The papers of an approved KYC: what was submitted, when, and each file to open or save.
final kycSubmissionProvider = FutureProvider.autoDispose.family<JsonMap, String>(
  (ref, submissionId) async => (await ref
      .watch(appDependenciesProvider)
      .apiClient
      .get('onboarding/submissions/$submissionId')).decodeObject((json) => json),
);

String _fileSize(Object? bytes) {
  final size = (bytes is num) ? bytes.toInt() : 0;
  return size >= 1024 * 1024
      ? '${(size / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(size / 1024).ceil()} KB';
}

class _SubmittedDocuments extends ConsumerWidget {
  const _SubmittedDocuments({required this.submissionId});

  final String submissionId;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    JsonMap file, {
    required bool download,
  }) async {
    try {
      final bytes = await ref
          .read(onboardingRepositoryProvider)
          .fileBytes('${file['id']}');
      if (download) {
        downloadBytesFile('${file['originalName']}', bytes, '${file['mimeType']}');
      } else {
        openFileInBrowser(bytes, '${file['mimeType']}');
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureText(AbraLocalizations.of(context), e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AsyncValueView<JsonMap>(
      value: ref.watch(kycSubmissionProvider(submissionId)),
      onRetry: () => ref.invalidate(kycSubmissionProvider(submissionId)),
      data: (context, submission) {
        final documents = [
          for (final raw in (submission['documents'] as List? ?? const <Object?>[]))
            if (raw is Map) asJsonMap(raw),
        ];
        final submittedAt = indiaTime(submission['submittedAt']);
        final decidedAt = indiaTime(submission['decidedAt']);
        final times = (submission['submitCount'] as num?)?.toInt() ?? 1;
        return AbraCard(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Submitted documents',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showKycHistory(context, submissionId),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History'),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xs),
              if (submittedAt.isNotEmpty)
                _FactLine(
                  label: times > 1 ? 'Last submitted' : 'Submitted',
                  value: submittedAt,
                ),
              if (decidedAt.isNotEmpty) _FactLine(label: 'Approved', value: decidedAt),
              if (times > 1) _FactLine(label: 'Sent for review', value: '$times times'),
              const SizedBox(height: AbraSpacing.md),
              if (documents.isEmpty)
                Text(
                  'No documents were found for this file.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
              for (final document in documents) ...[
                _SubmittedDocumentCard(
                  document: document,
                  onView: (file) => _open(context, ref, file, download: false),
                  onDownload: (file) => _open(context, ref, file, download: true),
                ),
                const SizedBox(height: AbraSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: AbraColors.textSecondary),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _SubmittedDocumentCard extends StatelessWidget {
  const _SubmittedDocumentCard({
    required this.document,
    required this.onView,
    required this.onDownload,
  });

  final JsonMap document;
  final void Function(JsonMap file) onView;
  final void Function(JsonMap file) onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = '${document['status']}';
    final files = [
      for (final raw in (document['files'] as List? ?? const <Object?>[]))
        if (raw is Map) asJsonMap(raw),
    ];
    final reviewed = indiaTime(document['reviewedAt']);
    final expiry = document['expiryDate'];
    final (label, fg, bg) = switch (status) {
      'APPROVED' => ('Approved', AbraColors.tealDark, AbraColors.tealContainer),
      'REJECTED' => ('Needs fixing', AbraColors.danger, AbraColors.dangerContainer),
      _ => ('Waiting', AbraColors.orangeDark, AbraColors.orangeContainer),
    };
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AbraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${document['name']}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AbraRadius.pill),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          if (reviewed.isNotEmpty || expiry != null) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (reviewed.isNotEmpty) 'Checked $reviewed',
                if (expiry != null) 'Valid till $expiry',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AbraSpacing.xs),
          for (final file in files)
            Row(
              children: [
                Icon(
                  '${file['mimeType']}' == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: 18,
                  color: AbraColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${file['originalName']} (${_fileSize(file['sizeBytes'])})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (indiaTime(file['uploadedAt']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'Uploaded ${indiaTime(file['uploadedAt'])}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AbraColors.textSecondary,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'View',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  onPressed: () => onView(file),
                ),
                IconButton(
                  tooltip: 'Download',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  onPressed: () => onDownload(file),
                ),
              ],
            ),
        ],
      ),
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

// ===== BUS KYC AND HISTORY =====

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
