import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../core/format.dart';
import '../../l10n/portal_strings.dart';
import '../../routing/portal_routes.dart';
import 'onboarding_repository.dart';
import 'status_labels.dart';

List<JsonMap> _list(Object? value) => value is List
    ? <JsonMap>[for (final item in value) asJsonMap(item! as Map)]
    : const <JsonMap>[];

/// The documents of the company or of one bus: what is asked for, what was
/// sent, what the reviewer said about each, and the button that sends it all
/// for review. After a rejection only the rejected documents can be replaced.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({
    required this.id,
    this.embedded = false,
    this.onChanged,
    super.key,
  });

  final String id;

  /// Told after an upload or the submit, so the screen around it can update its status.
  final VoidCallback? onChanged;

  /// Inside the KYC screen, which already shows the title and the progress.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncValueView<JsonMap>(
    value: ref.watch(onboardingFileProvider(id)),
    onRetry: () => ref.invalidate(onboardingFileProvider(id)),
    data: (context, view) => _FileBody(
      id: id,
      view: view,
      embedded: embedded,
      onChanged: onChanged,
    ),
  );
}

class _FileBody extends ConsumerStatefulWidget {
  const _FileBody({
    required this.id,
    required this.view,
    required this.embedded,
    this.onChanged,
  });

  final String id;
  final JsonMap view;
  final bool embedded;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_FileBody> createState() => _FileBodyState();
}

class _FileBodyState extends ConsumerState<_FileBody> {
  var _busy = false;

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  void _reload() {
    ref
      ..invalidate(onboardingFileProvider(widget.id))
      ..invalidate(dashboardProvider);
    widget.onChanged?.call();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(onboardingRepositoryProvider).submit(widget.id);
      _reload();
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.text(PortalStrings.obSubmitted))),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureText(_l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final theme = Theme.of(context);
    final status = '${view['status']}';
    final isBus = view['subjectType'] == 'BUS';
    final editable = status == 'DRAFT' || status == 'REJECTED';
    final documents = _list(view['documents']);
    final checklist = _list(view['checklist']);
    final askedFor = <String>{
      for (final item in checklist) '${item['documentTypeId']}',
    };
    final problems = <String>[
      for (final problem
          in (view['problems'] as List<Object?>? ?? const <Object?>[]))
        '$problem',
    ];

    final banner = switch (status) {
      'PENDING' => (
        PortalStrings.obWaitingBanner,
        AbraColors.orangeContainer,
        Icons.hourglass_top,
      ),
      'APPROVED' => (
        PortalStrings.obApprovedBanner,
        AbraColors.tealContainer,
        Icons.verified_outlined,
      ),
      'REJECTED' => (
        PortalStrings.obRejectedBanner,
        AbraColors.dangerContainer,
        Icons.error_outline,
      ),
      _ => null,
    };

    final list = ListView(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      children: <Widget>[
        if (!widget.embedded) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(PortalRoutes.dashboard),
              icon: const Icon(Icons.arrow_back),
              label: Text(_l10n.text(PortalStrings.obBack)),
            ),
          ),
          Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                isBus
                    ? '${view['busRegistrationNumber'] ?? ''} ${view['busName'] ?? ''}'
                          .trim()
                    : '${view['companyName']}',
                style: theme.textTheme.headlineSmall,
              ),
              fileStatusBadge(_l10n, status),
            ],
          ),
          Text(
            _l10n.text(isBus ? PortalStrings.obBus : PortalStrings.obCompany),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AbraSpacing.md),
        if (banner != null)
          Container(
            padding: const EdgeInsets.all(AbraSpacing.md),
            decoration: BoxDecoration(
              color: banner.$2,
              borderRadius: AbraRadius.medium,
            ),
            child: Row(
              children: <Widget>[
                Icon(banner.$3),
                const SizedBox(width: AbraSpacing.md),
                Expanded(child: Text(_l10n.text(banner.$1))),
              ],
            ),
          ),
        if (view['decisionNote'] != null && status == 'REJECTED')
          Padding(
            padding: const EdgeInsets.only(top: AbraSpacing.sm),
            child: Text(
              '${_l10n.text(PortalStrings.obNote)}: ${view['decisionNote']}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AbraColors.danger,
              ),
            ),
          ),
        const SizedBox(height: AbraSpacing.lg),
        _Progress(
          done: checklist
              .where(
                (item) =>
                    item['isRequired'] == true &&
                    documents.any(
                      (doc) =>
                          '${doc['documentTypeId']}' ==
                          '${item['documentTypeId']}',
                    ),
              )
              .length,
          total: checklist.where((item) => item['isRequired'] == true).length,
        ),
        const SizedBox(height: AbraSpacing.md),
        Text(
          _l10n.text(PortalStrings.obChecklist),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AbraSpacing.sm),
        _CardGrid(
          children: <Widget>[
            for (final item in checklist)
              _DocumentCard(
                key: ValueKey<String>('doc-${item['documentTypeId']}'),
                fileId: widget.id,
                item: item,
                document: documents
                    .where(
                      (doc) =>
                          '${doc['documentTypeId']}' ==
                          '${item['documentTypeId']}',
                    )
                    .firstOrNull,
                fileEditable: editable,
                onChanged: _reload,
              ),
            // A document of a type that is no longer asked for stays visible
            for (final doc in documents.where(
              (doc) => !askedFor.contains('${doc['documentTypeId']}'),
            ))
              _DocumentCard(
                key: ValueKey<String>('old-${doc['documentTypeId']}'),
                fileId: widget.id,
                item: <String, Object?>{
                  'documentTypeId': doc['documentTypeId'],
                  'name': doc['name'],
                  'isRequired': false,
                  'requiresExpiry': false,
                  'maxFiles': 1,
                  'maxFileSizeMb': 5,
                  'allowedMimeTypes': const <String>[],
                  'instructions': '',
                },
                document: doc,
                fileEditable: false,
                onChanged: _reload,
              ),
          ],
        ),
        if (editable) ...<Widget>[
          const SizedBox(height: AbraSpacing.md),
          if (problems.isNotEmpty) ...<Widget>[
            Text(
              _l10n.text(PortalStrings.obCannotSubmit),
              style: theme.textTheme.titleSmall,
            ),
            for (final problem in problems)
              Padding(
                padding: const EdgeInsets.only(top: AbraSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.circle,
                      size: 8,
                      color: AbraColors.orangeDark,
                    ),
                    const SizedBox(width: AbraSpacing.sm),
                    Expanded(child: Text(problem)),
                  ],
                ),
              ),
            const SizedBox(height: AbraSpacing.md),
          ],
        ],
      ],
    );
    if (!editable) return list;
    final ready = view['canSubmit'] == true;
    return Column(
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
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    ready
                        ? 'Everything required is uploaded.'
                        : 'Upload all required documents to continue.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                AbraButton(
                  label: _l10n.text(PortalStrings.obSubmit),
                  icon: Icons.send_outlined,
                  variant: AbraButtonVariant.callToAction,
                  isLoading: _busy,
                  onPressed: ready ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "3 of 4 required documents uploaded" with a bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => total == 0
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$done of $total required documents uploaded',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AbraColors.textSecondary),
            ),
            const SizedBox(height: AbraSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 6,
                backgroundColor: AbraColors.border,
                color: AbraColors.blue,
              ),
            ),
          ],
        );
}

/// Document cards in one column on a phone and two from tablet width.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});

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

const _extensions = <String, List<String>>{
  'application/pdf': <String>['pdf'],
  'image/jpeg': <String>['jpg', 'jpeg'],
  'image/png': <String>['png'],
};

/// One document of the checklist: its rules, what was sent, the reviewer's
/// answer, and (while it can be changed) the files and date to send.
class _DocumentCard extends ConsumerStatefulWidget {
  const _DocumentCard({
    required this.fileId,
    required this.item,
    required this.document,
    required this.fileEditable,
    required this.onChanged,
    super.key,
  });

  final String fileId;
  final JsonMap item;
  final JsonMap? document;
  final bool fileEditable;
  final VoidCallback onChanged;

  @override
  ConsumerState<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends ConsumerState<_DocumentCard> {
  final _picked = <PlatformFile>[];
  DateTime? _expiry;
  var _busy = false;
  String? _error;

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  String get _typeId => '${widget.item['documentTypeId']}';
  int get _maxFiles => (widget.item['maxFiles'] as num?)?.toInt() ?? 1;
  int get _maxMb => (widget.item['maxFileSizeMb'] as num?)?.toInt() ?? 5;
  bool get _needsExpiry => widget.item['requiresExpiry'] == true;
  String get _state => '${widget.document?['status'] ?? 'MISSING'}';

  /// An approved document stays as it is; the rest can change while the file is open.
  bool get _canChange => widget.fileEditable && _state != 'APPROVED';

  List<String> get _allowedExtensions => <String>[
    for (final mime
        in (widget.item['allowedMimeTypes'] as List<Object?>? ??
            const <Object?>[]))
      ...?_extensions['$mime'],
  ];

  String _day(DateTime date) => date.toIso8601String().substring(0, 10);

  Future<void> _choose() async {
    final result = await FilePicker.pickFiles(
      type: _allowedExtensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: _allowedExtensions.isEmpty ? null : _allowedExtensions,
      allowMultiple: _maxFiles > 1,
      withData: true,
    );
    if (result == null || !mounted) return;
    final files = result.files.where((file) => file.bytes != null).toList();
    final tooBig = files
        .where((file) => file.size > _maxMb * 1024 * 1024)
        .firstOrNull;
    setState(() {
      _error = null;
      if (tooBig != null) {
        _error = _l10n.text(PortalStrings.obFileTooLarge, <String, Object?>{
          'name': tooBig.name,
          'size': _maxMb,
        });
      } else if (files.length > _maxFiles) {
        _error = _l10n.text(PortalStrings.obTooManyFiles, <String, Object?>{
          'count': _maxFiles,
        });
      } else {
        _picked
          ..clear()
          ..addAll(files);
      }
    });
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final existing = DateTime.tryParse(
      '${widget.document?['expiryDate'] ?? ''}',
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? existing ?? now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null && mounted) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    final repository = ref.read(onboardingRepositoryProvider);
    final existingExpiry = widget.document?['expiryDate'];
    final expiry = _expiry == null
        ? (existingExpiry == null ? null : '$existingExpiry')
        : _day(_expiry!);
    if (_needsExpiry && expiry == null) {
      setState(() => _error = _l10n.text(PortalStrings.obChooseExpiry));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fileIds = <String>[];
      if (_picked.isEmpty) {
        // only the date changed: keep the files that are already there
        fileIds.addAll(
          _list(widget.document?['files']).map((file) => '${file['id']}'),
        );
      } else {
        for (final file in _picked) {
          fileIds.add(
            await repository.upload(
              documentTypeId: _typeId,
              bytes: file.bytes!,
              filename: file.name,
            ),
          );
        }
      }
      await repository.setDocument(
        widget.fileId,
        _typeId,
        fileIds: fileIds,
        expiryDate: _needsExpiry ? expiry : null,
      );
      if (!mounted) return;
      setState(() {
        _picked.clear();
        _expiry = null;
      });
      widget.onChanged();
    } on Object catch (error) {
      if (mounted) setState(() => _error = failureText(_l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(JsonMap file) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref
          .read(onboardingRepositoryProvider)
          .fileBytes('${file['id']}');
      openFileInBrowser(bytes, '${file['mimeType']}');
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(_l10n.text(PortalStrings.obOpenFailed))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final document = widget.document;
    final files = _list(document?['files']);
    final stateLabel = switch (_state) {
      'APPROVED' => PortalStrings.obStateApproved,
      'REJECTED' => PortalStrings.obStateRejected,
      'PENDING' => PortalStrings.obStatePending,
      _ => PortalStrings.obStateMissing,
    };
    final stateTone = switch (_state) {
      'APPROVED' => AbraStatusTone.success,
      'REJECTED' => AbraStatusTone.danger,
      'PENDING' => AbraStatusTone.warning,
      _ => AbraStatusTone.neutral,
    };
    final expiryText = _expiry != null
        ? dateOf(_day(_expiry!))
        : document?['expiryDate'] != null
        ? dateOf(document!['expiryDate'])
        : null;
    final canSave =
        _canChange &&
        (_picked.isNotEmpty || (_expiry != null && files.isNotEmpty));
    final types = <String>[
      for (final mime
          in (item['allowedMimeTypes'] as List<Object?>? ?? const <Object?>[]))
        (_extensions['$mime']?.first ?? '$mime').toUpperCase(),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.md),
      child: AbraCard(
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
                        Wrap(
                          spacing: AbraSpacing.md,
                          runSpacing: AbraSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              '${item['name']}',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              _l10n.text(
                                item['isRequired'] == true
                                    ? PortalStrings.obRequired
                                    : PortalStrings.obOptional,
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if ('${item['instructions'] ?? ''}'.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AbraSpacing.xs),
                            child: Text(
                              '${item['instructions']}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AbraColors.textSecondary,
                              ),
                            ),
                          ),
                        if (types.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AbraSpacing.xs),
                            child: Text(
                              _l10n.text(
                                PortalStrings.obAccepts,
                                <String, Object?>{
                                  'types': types.join(', '),
                                  'size': _maxMb,
                                  'count': _maxFiles,
                                },
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.sm),
                  AbraStatusBadge(
                    label: _l10n.text(stateLabel),
                    tone: stateTone,
                  ),
                ],
              ),
              if (document?['rejectionReason'] != null)
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
                          '${document!['rejectionReason']}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AbraColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AbraSpacing.sm),
              for (final file in files)
                Row(
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
                      onPressed: () => _view(file),
                      child: Text(_l10n.text(PortalStrings.obView)),
                    ),
                  ],
                ),
              if (_needsExpiry && expiryText != null)
                Text(
                  '${_l10n.text(PortalStrings.obExpiryLabel)}: $expiryText',
                  style: theme.textTheme.bodyMedium,
                ),
              for (final file in _picked)
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.upload_file,
                      size: 20,
                      color: AbraColors.blue,
                    ),
                    const SizedBox(width: AbraSpacing.sm),
                    Expanded(
                      child: Text(
                        '${file.name} · ${sizeOf(file.size)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: _l10n.text(PortalStrings.obRemove),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _picked.remove(file)),
                    ),
                  ],
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AbraSpacing.xs),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AbraColors.danger,
                    ),
                  ),
                ),
              if (_canChange) ...<Widget>[
                const SizedBox(height: AbraSpacing.sm),
                Wrap(
                  spacing: AbraSpacing.sm,
                  runSpacing: AbraSpacing.sm,
                  children: <Widget>[
                    AbraButton(
                      label: _l10n.text(
                        files.isEmpty
                            ? PortalStrings.obAdd
                            : PortalStrings.obReplace,
                      ),
                      icon: Icons.attach_file,
                      variant: AbraButtonVariant.secondary,
                      onPressed: _busy ? null : _choose,
                    ),
                    if (_needsExpiry)
                      AbraButton(
                        label: _l10n.text(PortalStrings.obExpiryLabel),
                        icon: Icons.event_outlined,
                        variant: AbraButtonVariant.secondary,
                        onPressed: _busy ? null : _pickExpiry,
                      ),
                    if (canSave)
                      AbraButton(
                        label: _l10n.text(
                          _busy
                              ? PortalStrings.obUploading
                              : PortalStrings.obSaveDocument,
                        ),
                        icon: Icons.save_outlined,
                        isLoading: _busy,
                        onPressed: _save,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
