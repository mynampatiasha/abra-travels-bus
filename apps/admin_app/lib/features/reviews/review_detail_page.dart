import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../core/format.dart';
import '../../l10n/admin_strings.dart';
import '../../routing/admin_routes.dart';
import 'review_repository.dart';
import 'reviews_page.dart';

List<JsonMap> _list(Object? value) => value is List
    ? <JsonMap>[for (final item in value) asJsonMap(item! as Map)]
    : const <JsonMap>[];

/// One onboarding file: what the owner sent, with each document's files, and
/// what the reviewer can do — accept or reject each document (a rejection
/// carries the reason the owner will read), then approve the file or send it
/// back. The backend checks every rule; this screen only offers the actions.
class ReviewDetailPage extends ConsumerWidget {
  const ReviewDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncValueView<JsonMap>(
    value: ref.watch(reviewDetailProvider(id)),
    onRetry: () => ref.invalidate(reviewDetailProvider(id)),
    data: (context, view) => _ReviewBody(id: id, view: view),
  );
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({required this.id, required this.view});

  final String id;
  final JsonMap view;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  var _busy = false;

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  /// Runs a change, then loads the file again; shows the backend's reason when refused.
  Future<void> _run(Future<Object?> Function() action, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(reviewDetailProvider(widget.id));
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureText(_l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askText(
    String title,
    String label, {
    required bool required,
    List<String> presets = const <String>[],
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (presets.isNotEmpty) ...<Widget>[
                Text(
                  'Common reasons',
                  style: Theme.of(dialogContext).textTheme.labelMedium
                      ?.copyWith(color: AbraColors.textSecondary),
                ),
                const SizedBox(height: AbraSpacing.sm),
                Wrap(
                  spacing: AbraSpacing.sm,
                  runSpacing: AbraSpacing.sm,
                  children: <Widget>[
                    for (final preset in presets)
                      ActionChip(
                        label: Text(preset),
                        onPressed: () {
                          final text = controller.text.trim();
                          controller.text = text.isEmpty
                              ? preset
                              : '$text. $preset';
                          controller.selection = TextSelection.collapsed(
                            offset: controller.text.length,
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AbraSpacing.md),
              ],
              TextField(
                controller: controller,
                autofocus: presets.isEmpty,
                maxLines: 3,
                decoration: InputDecoration(labelText: label),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_l10n.text(AbraStrings.commonCancel)),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.length < 3) return;
              Navigator.of(dialogContext).pop(text);
            },
            child: Text(title),
          ),
        ],
      ),
    );
  }

  Future<void> _reject(JsonMap document) async {
    final reason = await _askText(
      _l10n.text(AdminStrings.revReject),
      _l10n.text(AdminStrings.revReasonLabel),
      required: true,
      presets: const <String>[
        'The scan is blurred or cut off',
        'The document has expired',
        'The name does not match the company',
        'Wrong document uploaded',
      ],
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref
          .read(reviewRepositoryProvider)
          .reviewDocument(
            widget.id,
            '${document['documentTypeId']}',
            accept: false,
            reason: reason,
          ),
    );
  }

  Future<void> _accept(JsonMap document) => _run(
    () => ref
        .read(reviewRepositoryProvider)
        .reviewDocument(
          widget.id,
          '${document['documentTypeId']}',
          accept: true,
        ),
  );

  Future<void> _approve() async {
    final name = '${widget.view['companyName']}';
    final confirmed = await showAbraConfirmDialog(
      context,
      title: _l10n.text(AdminStrings.revApproveTitle, <String, Object?>{
        'name': name,
      }),
      message: _l10n.text(AdminStrings.revApproveMessage),
      confirmLabel: _l10n.text(AdminStrings.revApprove),
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => ref.read(reviewRepositoryProvider).approve(widget.id),
      done: _l10n.text(AdminStrings.revApprovedDone),
    );
  }

  Future<void> _sendBack() async {
    final note = await _askText(
      _l10n.text(AdminStrings.revSendBackTitle),
      _l10n.text(AdminStrings.revNoteLabel),
      required: false,
    );
    if (note == null || !mounted) return;
    await _run(
      () => ref
          .read(reviewRepositoryProvider)
          .sendBack(widget.id, note: note.isEmpty ? null : note),
      done: _l10n.text(AdminStrings.revSentBackDone),
    );
  }

  Future<void> _open(JsonMap file) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(reviewRepositoryProvider)
          .fileBytes('${file['id']}');
      openFileInBrowser(bytes, '${file['mimeType']}');
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.text(AdminStrings.revOpenFailed))),
      );
    }
  }

  String _historyText(JsonMap entry) {
    const keys = <String, String>{
      'CREATED': AdminStrings.revHistCreated,
      'SUBMITTED': AdminStrings.revHistSubmitted,
      'RESUBMITTED': AdminStrings.revHistResubmitted,
      'DOCUMENT_APPROVED': AdminStrings.revHistDocumentApproved,
      'DOCUMENT_REJECTED': AdminStrings.revHistDocumentRejected,
      'APPROVED': AdminStrings.revHistApproved,
      'REJECTED': AdminStrings.revHistRejected,
    };
    final key = keys['${entry['action']}'];
    final text = key == null
        ? '${entry['action']}'
        : _l10n.text(key, <String, Object?>{
            'doc': '${entry['documentTypeKey'] ?? ''}',
          });
    final note = entry['note'];
    return note == null ? text : '$text: $note';
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final theme = Theme.of(context);
    final status = '${view['status']}';
    final canReview = status == 'PENDING';
    final documents = _list(view['documents']);
    final checklist = _list(view['checklist']);
    final present = <String>{
      for (final doc in documents) '${doc['documentTypeId']}',
    };
    final missing = <JsonMap>[
      for (final item in checklist)
        if (item['isRequired'] == true &&
            !present.contains('${item['documentTypeId']}'))
          item,
    ];
    final isBus = view['subjectType'] == 'BUS';

    final kyc = view['kyc'] is Map ? asJsonMap(view['kyc'] as Map) : null;
    final configuration = kyc != null && kyc['configuration'] is Map
        ? asJsonMap(kyc['configuration'] as Map)
        : const <String, Object?>{};
    final answers = kyc != null && kyc['answers'] is Map
        ? asJsonMap(kyc['answers'] as Map)
        : const <String, Object?>{};
    final questions = <JsonMap>[
      for (final q in _list(configuration['questions']))
        if (q['active'] == true && q['appliesTo'] == view['subjectType']) q,
    ];
    // The backend decides (a required document may still be missing); this
    // only keeps the button off while a document sent is not accepted yet.
    final canApprove =
        documents.isNotEmpty &&
        documents.every((doc) => '${doc['status']}' == 'APPROVED');

    final list = ListView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(AdminRoutes.reviews),
            icon: const Icon(Icons.arrow_back),
            label: Text(_l10n.text(AdminStrings.revBack)),
          ),
        ),
        AbraCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AbraColors.skyContainer,
                    borderRadius: AbraRadius.medium,
                  ),
                  child: Icon(
                    isBus ? Icons.directions_bus_outlined : Icons.apartment,
                    color: AbraColors.deepBlue,
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: AbraSpacing.md,
                        runSpacing: AbraSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            '${view['companyName']}'
                            '${isBus ? ' · ${view['busRegistrationNumber'] ?? ''}' : ''}',
                            style: theme.textTheme.headlineSmall,
                          ),
                          AbraStatusBadge(
                            label: _l10n.text(
                              submissionStatuses[status] ??
                                  AdminStrings.revStatusDraft,
                            ),
                            tone: submissionTone(status),
                          ),
                          // Every step of this file (Phase 1 step 9)
                          TextButton.icon(
                            onPressed: () =>
                                showKycFileHistory(context, '${view['id']}'),
                            icon: const Icon(Icons.history, size: 18),
                            label: const Text('History'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AbraSpacing.xs),
                      Text(
                        _l10n.text(
                          isBus
                              ? AdminStrings.revSubjectBus
                              : AdminStrings.revSubjectCompany,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AbraColors.textSecondary,
                        ),
                      ),
                      if (view['submittedAt'] != null)
                        Text(
                          _l10n.text(
                            AdminStrings.revSubmittedOn,
                            <String, Object?>{
                              'date': dateOf(view['submittedAt']),
                              'times': view['submitCount'],
                            },
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      if (status == 'DRAFT')
                        Padding(
                          padding: const EdgeInsets.only(top: AbraSpacing.sm),
                          child: Text(_l10n.text(AdminStrings.revNotSentYet)),
                        ),
                      if (view['decisionNote'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AbraSpacing.sm),
                          child: Text(
                            '${_l10n.text(AdminStrings.revDecisionNote)}: ${view['decisionNote']}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (questions.isNotEmpty) ...<Widget>[
          const SizedBox(height: AbraSpacing.lg),
          Text('KYC answers', style: theme.textTheme.titleMedium),
          const SizedBox(height: AbraSpacing.sm),
          AbraCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              child: _TwoColumns(
                children: <Widget>[
                  for (final q in questions)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${q['label']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AbraColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AbraSpacing.xxs),
                        Text(
                          _answerText(q, answers[q['key']]),
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AbraSpacing.lg),
        Text(
          _l10n.text(AdminStrings.revDocuments),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AbraSpacing.sm),
        if (documents.isEmpty && missing.isEmpty)
          Text(_l10n.text(AdminStrings.revNoDocuments)),
        _TwoColumns(
          children: <Widget>[
            for (final document in documents)
              _documentCard(document, canReview),
            for (final item in missing)
              AbraCard(
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AbraSpacing.lg),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${item['name']}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      AbraStatusBadge(
                        label: _l10n.text(AdminStrings.revDocMissing),
                        tone: AbraStatusTone.danger,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AbraSpacing.xl),
        Text(
          _l10n.text(AdminStrings.revHistory),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AbraSpacing.sm),
        AbraCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final entry in _list(view['history']).reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AbraSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AbraColors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AbraSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(_historyText(entry)),
                              Text(
                                dateOf(entry['at']),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AbraColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (!canReview) return list;
    // The decision stays in view while the documents are read
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: list),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AbraColors.white,
            border: Border(top: BorderSide(color: AbraColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AbraSpacing.lg,
              vertical: AbraSpacing.md,
            ),
            child: Wrap(
              spacing: AbraSpacing.md,
              runSpacing: AbraSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    canApprove
                        ? (missing.isEmpty
                              ? 'All documents are accepted.'
                              : 'A required document is still missing.')
                        : 'Accept every document to approve, or reject at least one to send the file back.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ),
                AbraButton(
                  label: _l10n.text(AdminStrings.revSendBack),
                  icon: Icons.undo,
                  variant: AbraButtonVariant.secondary,
                  onPressed: _busy ? null : _sendBack,
                ),
                AbraButton(
                  label: _l10n.text(AdminStrings.revApprove),
                  icon: Icons.verified_outlined,
                  isLoading: _busy,
                  onPressed: canApprove ? _approve : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The answer in words: the label of the chosen option, "Yes"/"No", or the raw value.
  String _answerText(JsonMap question, Object? answer) {
    if (answer == null) return 'Not answered';
    final options = question['type'] == 'BOOLEAN'
        ? <JsonMap>[
            <String, Object?>{'value': 'true', 'label': 'Yes'},
            <String, Object?>{'value': 'false', 'label': 'No'},
          ]
        : _list(question['options']);
    String label(Object? value) =>
        options
            .where((o) => '${o['value']}' == '$value')
            .map((o) => '${o['label']}')
            .firstOrNull ??
        '$value';
    return answer is List ? answer.map(label).join(', ') : label(answer);
  }

  Widget _documentCard(JsonMap document, bool canReview) {
    final theme = Theme.of(context);
    final status = '${document['status']}';
    final files = _list(document['files']);
    final labels = <String, String>{
      'APPROVED': AdminStrings.revDocApproved,
      'REJECTED': AdminStrings.revDocRejected,
      'PENDING': AdminStrings.revDocPending,
    };
    return AbraCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AbraColors.lightBlue,
                    borderRadius: AbraRadius.medium,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AbraColors.blue,
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${document['name']}',
                        style: theme.textTheme.titleSmall,
                      ),
                      if (document['expiryDate'] != null)
                        Text(
                          _l10n.text(AdminStrings.revExpires, <String, Object?>{
                            'date': dateOf(document['expiryDate']),
                          }),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AbraSpacing.sm),
                AbraStatusBadge(
                  label: _l10n.text(
                    labels[status] ?? AdminStrings.revDocPending,
                  ),
                  tone: submissionTone(status),
                ),
              ],
            ),
            if (document['rejectionReason'] != null)
              Container(
                margin: const EdgeInsets.only(top: AbraSpacing.sm),
                padding: const EdgeInsets.all(AbraSpacing.sm),
                decoration: const BoxDecoration(
                  color: AbraColors.dangerContainer,
                  borderRadius: AbraRadius.small,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AbraColors.danger,
                    ),
                    const SizedBox(width: AbraSpacing.sm),
                    Expanded(
                      child: Text(
                        '${document['rejectionReason']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AbraColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AbraSpacing.sm),
            if (files.isEmpty) Text(_l10n.text(AdminStrings.revNoFiles)),
            for (final file in files)
              Container(
                margin: const EdgeInsets.only(bottom: AbraSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AbraSpacing.md,
                  vertical: AbraSpacing.xs,
                ),
                decoration: const BoxDecoration(
                  color: AbraColors.lightGray,
                  borderRadius: AbraRadius.medium,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.description_outlined, size: 20),
                    const SizedBox(width: AbraSpacing.sm),
                    Expanded(
                      child: Text(
                        '${file['originalName']} · ${sizeOf(file['sizeBytes'])}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _open(file),
                      child: Text(_l10n.text(AdminStrings.revOpenFile)),
                    ),
                  ],
                ),
              ),
            if (canReview) ...<Widget>[
              const SizedBox(height: AbraSpacing.sm),
              Wrap(
                spacing: AbraSpacing.sm,
                runSpacing: AbraSpacing.sm,
                children: <Widget>[
                  AbraButton(
                    label: _l10n.text(AdminStrings.revAccept),
                    icon: Icons.check,
                    variant: AbraButtonVariant.secondary,
                    onPressed: _busy || status == 'APPROVED'
                        ? null
                        : () => _accept(document),
                  ),
                  AbraButton(
                    label: _l10n.text(AdminStrings.revReject),
                    icon: Icons.close,
                    variant: AbraButtonVariant.secondary,
                    onPressed: _busy ? null : () => _reject(document),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cards in one column on a phone and two from tablet width.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 2 : 1;
      const gap = AbraSpacing.md;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// "10/10/2026, 2:37 pm" in India time.
String _indiaTime(Object? iso) {
  final at = DateTime.tryParse('${iso ?? ''}');
  if (at == null) return '';
  final t = at.toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${dateOf(t.toIso8601String().replaceFirst('Z', ''))}, '
      '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

/// The steps of a KYC file (`GET onboarding/submissions/<id>/history`).
final kycFileHistoryProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, String>(
      (ref, id) async =>
          (await ref
                  .watch(appDependenciesProvider)
                  .apiClient
                  .get('onboarding/submissions/$id/history'))
              .decodeList((json) => json),
    );

/// The History window of the demo: what happened, who did it and when.
Future<void> showKycFileHistory(
  BuildContext context,
  String id,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('History'),
    content: SizedBox(
      width: 460,
      child: Consumer(
        builder: (context, ref, _) => AsyncValueView<List<JsonMap>>(
          value: ref.watch(kycFileHistoryProvider(id)),
          onRetry: () => ref.invalidate(kycFileHistoryProvider(id)),
          data: (context, entries) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final entry in entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      switch ('${entry['action']}') {
                        'APPROVED' || 'DOCUMENT_APPROVED' => Icons.check_circle,
                        'REJECTED' || 'DOCUMENT_REJECTED' => Icons.cancel,
                        _ => Icons.radio_button_checked,
                      },
                      color: switch ('${entry['action']}') {
                        'APPROVED' || 'DOCUMENT_APPROVED' => AbraColors.teal,
                        'REJECTED' || 'DOCUMENT_REJECTED' => AbraColors.danger,
                        _ => AbraColors.blue,
                      },
                    ),
                    title: Text(
                      '${entry['label']}'
                      '${entry['documentName'] == null ? '' : ': ${entry['documentName']}'}',
                    ),
                    subtitle: Text(
                      <String>[
                        if (entry['by'] != null) '${entry['by']}',
                        _indiaTime(entry['at']),
                        if (entry['note'] != null) '${entry['note']}',
                      ].join(' · '),
                    ),
                  ),
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
