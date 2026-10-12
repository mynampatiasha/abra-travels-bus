import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/browser_files.dart';
import '../../../core/csv.dart';
import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import 'resource_form.dart';

/// How a list takes rows from a CSV file: the columns are the form's fields
/// (named by their key), and each row is saved exactly as the create form
/// would save it, so every rule of the backend applies and a bad row is
/// skipped with the backend's reason instead of failing the whole file.
class ImportSpec {
  const ImportSpec({
    required this.name,
    required this.fields,
    required this.save,
    this.sampleRow = const <String>[],
  });

  /// What is imported, for the title and the sample file name ("cities").
  final String name;

  /// The fields a row can fill. Choices to pick from a list of records are not
  /// supported: a file cannot name a record by its id.
  final List<FieldSpec> fields;

  /// An example value for each column, in the order of [fields].
  final List<String> sampleRow;

  /// Saves one row (the create call). Throws with the backend's reason when
  /// the row is refused.
  final Future<void> Function(JsonMap values) save;

  List<FieldSpec> get columns => <FieldSpec>[
    for (final field in fields)
      if (field is! RefSpec && field is! RowsSpec) field,
  ];
}

/// One row that could not be imported.
class _Skipped {
  const _Skipped(this.row, this.reason);

  final int row;
  final String reason;
}

Future<void> showImportDialog(BuildContext context, ImportSpec spec) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImportDialog(spec: spec),
    );

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.spec});

  final ImportSpec spec;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  String? _fileName;
  List<List<String>>? _rows;
  String? _problem;
  var _running = false;
  var _done = false;
  var _imported = 0;
  final _skipped = <_Skipped>[];

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  void _downloadSample() {
    final columns = widget.spec.columns;
    downloadTextFile(
      '${widget.spec.name}_import_sample.csv',
      Csv.encode(
        <String>[for (final field in columns) field.key],
        <List<Object?>>[
          if (widget.spec.sampleRow.isNotEmpty) widget.spec.sampleRow,
        ],
      ),
    );
  }

  Future<void> _choose() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final rows = Csv.parse(utf8.decode(bytes, allowMalformed: true));
    final header = rows.isEmpty
        ? const <String>[]
        : rows.first.map((cell) => cell.trim()).toList();
    final missing = <String>[
      for (final field in widget.spec.columns)
        if (field.isRequired && !header.contains(field.key)) field.key,
    ];
    setState(() {
      _fileName = file.name;
      _rows = rows;
      _problem = rows.length < 2
          ? _l10n.text(AdminStrings.importEmptyFile)
          : missing.isNotEmpty
          ? _l10n.text(AdminStrings.importMissingColumns, <String, Object?>{
              'columns': missing.join(', '),
            })
          : null;
    });
  }

  /// The request values of one row, or the reason it cannot be sent.
  (JsonMap?, String?) _values(Map<String, String> cells) {
    final values = <String, Object?>{};
    for (final field in widget.spec.columns) {
      final raw = (cells[field.key] ?? '').trim();
      if (raw.isEmpty) {
        if (field.isRequired) return (null, '${field.key} is empty');
        continue;
      }
      switch (field) {
        case TextSpec():
          values[field.key] = raw;
        case NumberSpec(:final scale, :final allowDecimal):
          final number = num.tryParse(raw);
          if (number == null ||
              (!allowDecimal &&
                  number is double &&
                  number != number.roundToDouble())) {
            return (null, '${field.key} must be a number');
          }
          values[field.key] = scale == 1 ? number : (number * scale).round();
        case BoolSpec():
          final yes = <String>{
            'true',
            'yes',
            'y',
            '1',
          }.contains(raw.toLowerCase());
          final no = <String>{
            'false',
            'no',
            'n',
            '0',
          }.contains(raw.toLowerCase());
          if (!yes && !no) return (null, '${field.key} must be yes or no');
          values[field.key] = yes;
        case ChoiceSpec(:final options):
          final match = options.keys.where(
            (key) => key.toLowerCase() == raw.toLowerCase(),
          );
          if (match.isEmpty) {
            return (
              null,
              '${field.key} must be one of ${options.keys.join(', ')}',
            );
          }
          values[field.key] = match.first;
        case MultiChoiceSpec(:final options):
          final items = raw
              .split(RegExp('[;|]'))
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty);
          final bad = items.where((item) => !options.contains(item)).toList();
          if (bad.isNotEmpty) {
            return (
              null,
              '${field.key}: unknown ${bad.join(', ')} (use ${options.join('; ')})',
            );
          }
          values[field.key] = items.toList();
        case DateSpec():
          final day = DateTime.tryParse(raw);
          if (day == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
            return (null, '${field.key} must be a date (YYYY-MM-DD)');
          }
          values[field.key] = raw;
        case RefSpec() || RowsSpec():
          break;
      }
    }
    return (values, null);
  }

  Future<void> _run() async {
    final rows = _rows;
    if (rows == null || _problem != null) return;
    setState(() {
      _running = true;
      _imported = 0;
      _skipped.clear();
    });
    final header = rows.first.map((cell) => cell.trim()).toList();
    for (var index = 1; index < rows.length; index++) {
      final cells = <String, String>{
        for (var column = 0; column < header.length; column++)
          header[column]: column < rows[index].length
              ? rows[index][column]
              : '',
      };
      final (values, problem) = _values(cells);
      if (values == null) {
        _skipped.add(_Skipped(index + 1, problem ?? ''));
        continue;
      }
      try {
        await widget.spec.save(values);
        _imported += 1;
      } on Object catch (error) {
        if (!mounted) return;
        _skipped.add(_Skipped(index + 1, failureText(_l10n, error)));
      }
    }
    if (mounted) {
      setState(() {
        _running = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        _l10n.text(AdminStrings.importTitle, <String, Object?>{
          'name': widget.spec.name,
        }),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!_done) ...<Widget>[
                Text(
                  _l10n.text(AdminStrings.importIntro),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AbraSpacing.md),
                Wrap(
                  spacing: AbraSpacing.md,
                  runSpacing: AbraSpacing.sm,
                  children: <Widget>[
                    AbraButton(
                      label: _l10n.text(AdminStrings.importSample),
                      icon: Icons.download_outlined,
                      variant: AbraButtonVariant.secondary,
                      onPressed: _running ? null : _downloadSample,
                    ),
                    AbraButton(
                      label: _l10n.text(AdminStrings.importChoose),
                      icon: Icons.attach_file,
                      variant: AbraButtonVariant.secondary,
                      onPressed: _running ? null : _choose,
                    ),
                  ],
                ),
                if (_fileName != null) ...<Widget>[
                  const SizedBox(height: AbraSpacing.md),
                  Text(_fileName!, style: theme.textTheme.titleSmall),
                ],
                if (_problem != null) ...<Widget>[
                  const SizedBox(height: AbraSpacing.sm),
                  Text(
                    _problem!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AbraColors.danger,
                    ),
                  ),
                ],
                if (_running) ...<Widget>[
                  const SizedBox(height: AbraSpacing.md),
                  const LinearProgressIndicator(),
                ],
              ] else ...<Widget>[
                Text(
                  _l10n.text(AdminStrings.importDone, <String, Object?>{
                    'imported': _imported,
                    'skipped': _skipped.length,
                  }),
                  style: theme.textTheme.titleMedium,
                ),
                if (_skipped.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AbraSpacing.md),
                  DataTable(
                    headingRowHeight: 40,
                    columns: <DataColumn>[
                      DataColumn(
                        label: Text(_l10n.text(AdminStrings.importRow)),
                      ),
                      DataColumn(
                        label: Text(_l10n.text(AdminStrings.importReason)),
                      ),
                    ],
                    rows: <DataRow>[
                      for (final skipped in _skipped)
                        DataRow(
                          cells: <DataCell>[
                            DataCell(Text('${skipped.row}')),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 380,
                                ),
                                child: Text(skipped.reason),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (!_done)
          TextButton(
            onPressed: _running ? null : () => Navigator.of(context).pop(),
            child: Text(_l10n.text(AbraStrings.commonCancel)),
          ),
        if (!_done)
          FilledButton(
            onPressed: _running || _rows == null || _problem != null
                ? null
                : _run,
            child: Text(_l10n.text(AdminStrings.importRun)),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_l10n.text(AdminStrings.importClose)),
          ),
      ],
    );
  }
}
