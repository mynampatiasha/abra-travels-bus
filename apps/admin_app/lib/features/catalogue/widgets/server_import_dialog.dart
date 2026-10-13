import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/browser_files.dart';
import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';

/// A list that can be filled from a file on the server: `GET <path>/import-template`
/// and `POST <path>/import` (the file is checked first, then saved).
class ServerImport {
  const ServerImport(this.path, this.whatKey);

  /// The list, as the list endpoint is known (`cities`, `locations`).
  final String path;

  /// What is imported, in a sentence: "cities", "places".
  final String whatKey;
}

/// Picks a CSV or Excel file: its name and bytes, or null when none was chosen.
/// Tests replace it; the browser's file chooser is used otherwise.
Future<(String, Uint8List)?> Function() pickImportFile = () async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const <String>['csv', 'xlsx'],
    withData: true,
  );
  final file = picked?.files.single;
  final bytes = file?.bytes;
  return file == null || bytes == null ? null : (file.name, bytes);
};

/// The import window: choose a file, see what is wrong with each row, then
/// import the rows that are right. Returns true when something was saved.
Future<bool> showServerImportDialog(
  BuildContext context,
  ServerImport spec,
) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ServerImportDialog(spec: spec),
  );
  return saved ?? false;
}

class _ServerImportDialog extends ConsumerStatefulWidget {
  const _ServerImportDialog({required this.spec});

  final ServerImport spec;

  @override
  ConsumerState<_ServerImportDialog> createState() =>
      _ServerImportDialogState();
}

class _ServerImportDialogState extends ConsumerState<_ServerImportDialog> {
  String? _fileName;
  Uint8List? _bytes;

  /// The answer of the last check or save.
  JsonMap? _answer;
  var _busy = false;
  var _saved = false;
  String? _failure;

  AbraLocalizations get _l10n => AbraLocalizations.of(context);
  CatalogueRepository get _repository => ref.read(catalogueRepositoryProvider);

  Future<void> _template(String format) async {
    try {
      final bytes = await _repository.download(
        '${widget.spec.path}/import-template',
        <String, String>{'format': format},
      );
      downloadBytesFile(
        '${widget.spec.path}-import-template.$format',
        bytes,
        mimeType: format == 'csv'
            ? 'text/csv'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } on Object catch (error) {
      setState(() => _failure = failureText(_l10n, error));
    }
  }

  Future<void> _choose() async {
    final picked = await pickImportFile();
    if (picked == null) return;
    setState(() {
      _fileName = picked.$1;
      _bytes = picked.$2;
      _answer = null;
      _saved = false;
    });
    await _send(dryRun: true);
  }

  Future<void> _send({required bool dryRun}) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final answer = await _repository.upload(
        '${widget.spec.path}/import',
        <String, String>{'dryRun': '$dryRun'},
        bytes: _bytes!,
        filename: _fileName!,
      );
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _saved = !dryRun;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failure = failureText(_l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final textTheme = Theme.of(context).textTheme;
    final answer = _answer;
    final accepted = (answer?['accepted'] as num?)?.toInt() ?? 0;
    final total = (answer?['total'] as num?)?.toInt() ?? 0;
    final rows = <JsonMap>[
      for (final row
          in (answer?['rows'] as List<Object?>? ?? const <Object?>[]))
        if (row is Map<String, Object?> && row['status'] == 'ERROR') row,
    ];
    final ignored = <String>[
      for (final name
          in (answer?['ignoredColumns'] as List<Object?>? ?? const <Object?>[]))
        '$name',
    ];
    final what = l10n.text(widget.spec.whatKey);

    return AlertDialog(
      title: Text(
        l10n.text(AdminStrings.impsTitle, <String, Object?>{'what': what}),
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.text(AdminStrings.impsIntro)),
              const SizedBox(height: AbraSpacing.sm),
              Wrap(
                spacing: AbraSpacing.sm,
                children: <Widget>[
                  TextButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l10n.text(AdminStrings.impsTemplateCsv)),
                    onPressed: _busy ? null : () => _template('csv'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.table_chart_outlined),
                    label: Text(l10n.text(AdminStrings.impsTemplateExcel)),
                    onPressed: _busy ? null : () => _template('xlsx'),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.md),
              Row(
                children: <Widget>[
                  AbraButton(
                    label: l10n.text(AdminStrings.impsChoose),
                    icon: Icons.upload_file_outlined,
                    variant: AbraButtonVariant.secondary,
                    onPressed: _busy || _saved ? null : _choose,
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  if (_fileName != null) Expanded(child: Text(_fileName!)),
                ],
              ),
              if (_busy) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                const LinearProgressIndicator(),
                const SizedBox(height: AbraSpacing.xs),
                Text(
                  l10n.text(
                    _saved || (_answer != null)
                        ? AdminStrings.impsSaving
                        : AdminStrings.impsChecking,
                  ),
                  style: textTheme.bodySmall,
                ),
              ],
              if (_failure != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _failure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (answer != null && !_busy) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _saved
                        ? l10n.text(AdminStrings.impsDone, <String, Object?>{
                            'created': accepted,
                            'skipped': total - accepted,
                          })
                        : l10n.text(AdminStrings.impsReady, <String, Object?>{
                            'ready': accepted,
                            'total': total,
                          }),
                    style: textTheme.titleSmall,
                  ),
                ),
                if (ignored.isNotEmpty)
                  Text(
                    l10n.text(AdminStrings.impsIgnored, <String, Object?>{
                      'columns': ignored.join(', '),
                    }),
                    style: textTheme.bodySmall,
                  ),
                if (!_saved && accepted == 0)
                  Text(l10n.text(AdminStrings.impsNothingReady)),
                if (rows.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AbraSpacing.sm),
                  Text(
                    l10n.text(AdminStrings.impsProblems, <String, Object?>{
                      'count': rows.length,
                    }),
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: AbraSpacing.xs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final row in rows)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AbraSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  l10n.text(
                                    AdminStrings.impsRowLine,
                                    <String, Object?>{
                                      'row': row['row'],
                                      'label': row['label'] ?? '',
                                    },
                                  ),
                                  style: textTheme.labelLarge,
                                ),
                                for (final error
                                    in (row['errors'] as List<Object?>? ??
                                        const <Object?>[]))
                                  Text(
                                    '$error',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AbraColors.danger,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(_saved),
          child: Text(l10n.text(AdminStrings.impsClose)),
        ),
        if (!_saved && answer != null && accepted > 0)
          AbraButton(
            label: l10n.text(AdminStrings.impsImport, <String, Object?>{
              'count': accepted,
            }),
            variant: AbraButtonVariant.primary,
            isLoading: _busy,
            onPressed: () => _send(dryRun: false),
          ),
      ],
    );
  }
}
