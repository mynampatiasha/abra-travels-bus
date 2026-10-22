import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_picker/file_picker.dart';
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
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../routing/admin_routes.dart';

// Both administration tabs, editing, bulk tools and the checklist preview live
// in this file. Authentication, networking and the document catalogue are shared.
const _path = 'settings/kyc-configuration';
int _keySequence = 0;
String _newKey(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_keySequence++}';
String _t(BuildContext context, String key) =>
    AbraLocalizations.of(context).text('kyc$key');
List<JsonMap> _rows(Object? value) => value is List
    ? value.whereType<Map<Object?, Object?>>().map((m) => asJsonMap(m)).toList()
    : <JsonMap>[];
String _subject(BuildContext c, Object? value) =>
    _t(c, value == 'BUS' ? 'Bus' : 'Company');
List<JsonMap> _options(JsonMap q) => q['type'] == 'BOOLEAN'
    ? <JsonMap>[
        {'value': 'true', 'label': 'Yes'},
        {'value': 'false', 'label': 'No'},
      ]
    : _rows(q['options']);

JsonMap kycExportData(JsonMap configuration) => <String, Object?>{
  'schemaVersion': 1,
  'questions': configuration['questions'],
  'rules': configuration['rules'],
};

final kycSheetHeaders = <String>[
  'Row type',
  'Question or rule name',
  'Applies to',
  'Answer type',
  'Help text',
  'Required',
  'Active',
  'Display order',
  for (var i = 1; i <= 20; i++) 'Option $i',
  'Document',
  'Match answers',
  'Condition question',
  'Condition answers',
];
String _yes(Object? value) => value == false ? 'No' : 'Yes';
String _subjectName(Object? value) => value == 'BUS' ? 'Bus' : 'Company';
String _typeName(Object? value) => switch (value) {
  'BOOLEAN' => 'Yes or No',
  'MULTI_CHOICE' => 'Choose several',
  _ => 'Choose one',
};

/// Human-readable spreadsheet rows. Technical identities never appear in cells.
List<List<String>> kycSpreadsheetRows(JsonMap config, List<JsonMap> documents) {
  final questions = _rows(config['questions']);
  final rows = <List<String>>[kycSheetHeaders];
  for (final q in questions) {
    final options = _rows(q['options']);
    rows.add([
      'Question',
      '${q['label']}',
      _subjectName(q['appliesTo']),
      _typeName(q['type']),
      '${q['help'] ?? ''}',
      _yes(q['required']),
      _yes(q['active']),
      '${q['sortOrder']}',
      for (var i = 0; i < 20; i++)
        i < options.length ? '${options[i]['label']}' : '',
      '',
      '',
      '',
      '',
    ]);
  }
  for (final r in _rows(config['rules'])) {
    final conditions = _rows(r['conditions']);
    for (final c in conditions.isEmpty ? <JsonMap>[{}] : conditions) {
      final q = questions
          .where((q) => q['key'] == c['questionKey'])
          .firstOrNull;
      final answers = _options(q ?? {})
          .where((o) => (c['values'] as List? ?? []).contains(o['value']))
          .map((o) => '${o['label']}')
          .join('\n');
      final d = documents
          .where((d) => d['key'] == r['documentKey'])
          .firstOrNull;
      rows.add([
        'Document rule',
        '${r['name']}',
        _subjectName(r['appliesTo']),
        '',
        '',
        _yes(r['required']),
        _yes(r['active']),
        '',
        for (var i = 0; i < 20; i++) '',
        '${d?['name'] ?? r['documentKey']}',
        r['match'] == 'ANY' ? 'Any answer' : 'All answers',
        '${q?['label'] ?? ''}',
        answers,
      ]);
    }
  }
  return rows;
}

String kycCsvText(List<List<String>> rows) =>
    const ListToCsvConverter().convert(
      rows
          .map(
            (row) => row
                .map(
                  (cell) =>
                      RegExp(r'^[=+@\-]').hasMatch(cell) ? "'$cell" : cell,
                )
                .toList(),
          )
          .toList(),
    );

Uint8List kycExcelBytes(
  List<List<String>> rows, {
  String sheetName = 'KYC configuration',
}) {
  final book = xlsx.Excel.createExcel();
  final sheet = book[sheetName];
  book.delete('Sheet1');
  for (final row in rows) {
    sheet.appendRow(row.map((value) => xlsx.TextCellValue(value)).toList());
  }
  for (var i = 0; i < rows.first.length; i++) {
    sheet.setColumnWidth(i, i == 1 || i >= 28 ? 36 : 22);
    sheet
        .cell(xlsx.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .cellStyle = xlsx.CellStyle(
      bold: true,
      backgroundColorHex: xlsx.ExcelColor.fromHexString('#12334B'),
      fontColorHex: xlsx.ExcelColor.white,
      textWrapping: xlsx.TextWrapping.WrapText,
    );
  }
  return Uint8List.fromList(book.encode()!);
}

List<List<String>> kycReadSpreadsheet(Uint8List bytes, String extension) {
  if (bytes.length > 2000000) {
    throw const FormatException('Choose a file smaller than 2 MB.');
  }
  if (extension == 'csv') {
    final text = utf8.decode(bytes).replaceFirst('\uFEFF', '');
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
        .convert(normalized)
        .map(
          (r) => r.map((v) {
            final cell = '$v';
            return cell.startsWith("'") &&
                    RegExp(r'^[=+@\-]').hasMatch(cell.substring(1))
                ? cell.substring(1)
                : cell;
          }).toList(),
        )
        .toList();
  }
  if (extension != 'xlsx') {
    throw const FormatException('Upload an Excel (.xlsx) or CSV file.');
  }
  final book = xlsx.Excel.decodeBytes(bytes);
  final sheet = book.tables['KYC configuration'] ?? book.tables.values.first;
  if (sheet.maxRows > 5101) {
    throw const FormatException('The file has too many rows.');
  }
  return sheet.rows
      .map((r) => r.map((c) => '${c?.value ?? ''}').toList())
      .toList();
}

/// Reuse saved identities when labels match so an export/import preserves rules.
JsonMap kycParseSpreadsheet(
  List<List<String>> rows,
  JsonMap existing,
  List<JsonMap> documents,
) {
  if (rows.isEmpty ||
      rows.first.length < kycSheetHeaders.length ||
      !List.generate(
        kycSheetHeaders.length,
        (i) => rows.first[i].trim() == kycSheetHeaders[i],
      ).every((v) => v)) {
    throw const FormatException(
      'The column headings do not match. Download the sample and keep its headings.',
    );
  }
  if (rows.length > 5101) {
    throw const FormatException('The file has too many rows.');
  }
  final questions = <JsonMap>[];
  final rules = <JsonMap>[];
  final oldQuestions = _rows(existing['questions']);
  final oldRules = _rows(existing['rules']);
  final input = <(int, List<String>)>[];
  for (var i = 1; i < rows.length; i++) {
    if (rows[i].every((v) => v.trim().isEmpty)) continue;
    final row = List<String>.generate(
      kycSheetHeaders.length,
      (j) => j < rows[i].length ? rows[i][j].trim() : '',
    );
    input.add((i + 1, row));
  }
  Never invalid(int row, String message) =>
      throw FormatException('Row $row: $message');
  String subject(int n, String value) => switch (value.toLowerCase()) {
    'company' => 'OPERATOR',
    'bus' => 'BUS',
    _ => invalid(n, 'Applies to must be Company or Bus.'),
  };
  bool yes(int n, String value, String field) => switch (value.toLowerCase()) {
    'yes' => true,
    'no' => false,
    _ => invalid(n, '$field must be Yes or No.'),
  };
  for (final (n, row) in input) {
    if (row[0] == 'Document rule') continue;
    if (row[0] != 'Question') {
      invalid(n, 'Row type must be Question or Document rule.');
    }
    final appliesTo = subject(n, row[2]);
    if (row[1].isEmpty) invalid(n, 'Enter the question text.');
    if (questions.any(
      (q) => q['label'] == row[1] && q['appliesTo'] == appliesTo,
    )) {
      invalid(n, 'This question is repeated.');
    }
    final type = switch (row[3].toLowerCase()) {
      'choose one' => 'SINGLE_CHOICE',
      'choose several' => 'MULTI_CHOICE',
      'yes or no' => 'BOOLEAN',
      _ => invalid(
        n,
        'Answer type must be Choose one, Choose several, or Yes or No.',
      ),
    };
    final old = oldQuestions
        .where((q) => q['label'] == row[1] && q['appliesTo'] == appliesTo)
        .firstOrNull;
    final labels = row.sublist(8, 28).where((s) => s.isNotEmpty).toList();
    if (type == 'BOOLEAN' ? labels.isNotEmpty : labels.length < 2) {
      invalid(
        n,
        'Choice questions need at least two options. Yes or No questions need no options.',
      );
    }
    if (labels.map((s) => s.toLowerCase()).toSet().length != labels.length) {
      invalid(n, 'Answer options must be different.');
    }
    final order = row[7].isEmpty ? questions.length : int.tryParse(row[7]);
    if (order == null || order < 0 || order > 9999) {
      invalid(n, 'Display order must be a number from 0 to 9999.');
    }
    questions.add({
      'key': old?['key'] ?? _newKey('question'),
      'label': row[1],
      'help': row[4],
      'appliesTo': appliesTo,
      'type': type,
      'options': [
        for (final label in labels)
          {
            'label': label,
            'value':
                _rows(
                  old?['options'],
                ).where((o) => o['label'] == label).firstOrNull?['value'] ??
                _newKey('answer'),
          },
      ],
      'required': yes(n, row[5], 'Required'),
      'active': yes(n, row[6], 'Active'),
      'sortOrder': order,
    });
  }
  for (final (n, row) in input.where((r) => r.$2[0] == 'Document rule')) {
    final appliesTo = subject(n, row[2]);
    if (row[1].isEmpty) invalid(n, 'Enter a name for the document rule.');
    final matches = documents
        .where((d) => d['name'] == row[28] && d['appliesTo'] == appliesTo)
        .toList();
    if (matches.length != 1) {
      invalid(
        n,
        'Choose an existing document name for this subject: "${row[28]}".',
      );
    }
    final match = switch (row[29].toLowerCase()) {
      'all answers' => 'ALL',
      'any answer' => 'ANY',
      _ => invalid(n, 'Match answers must be All answers or Any answer.'),
    };
    final required = yes(n, row[5], 'Required');
    final active = yes(n, row[6], 'Active');
    JsonMap? condition;
    if (row[30].isNotEmpty || row[31].isNotEmpty) {
      final q = questions
          .where((q) => q['label'] == row[30] && q['appliesTo'] == appliesTo)
          .firstOrNull;
      if (q == null) {
        invalid(n, 'Condition question must match a question in this file.');
      }
      final labels = row[31]
          .split(
            row[31].contains('\n')
                ? '\n'
                : _options(q).any((o) => o['label'] == row[31])
                ? '\u0000'
                : ';',
          )
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (labels.isEmpty) {
        invalid(n, 'Enter the condition answers separated by semicolons.');
      }
      final values = <String>[];
      for (final label in labels) {
        final o = _options(q).where((o) => o['label'] == label).firstOrNull;
        if (o == null) {
          invalid(n, '"$label" is not an option for this question.');
        }
        values.add('${o['value']}');
      }
      condition = {'questionKey': q['key'], 'values': values};
    }
    final current = rules
        .where((r) => r['name'] == row[1] && r['appliesTo'] == appliesTo)
        .firstOrNull;
    if (current != null) {
      if (condition == null ||
          _rows(current['conditions']).isEmpty ||
          current['documentKey'] != matches.single['key'] ||
          current['required'] != required ||
          current['active'] != active ||
          current['match'] != match) {
        invalid(
          n,
          'Repeated rule rows must have the same document and settings, with one condition per row.',
        );
      }
      (current['conditions'] as List).add(condition);
    } else {
      final old = oldRules
          .where((r) => r['name'] == row[1] && r['appliesTo'] == appliesTo)
          .firstOrNull;
      rules.add({
        'key': old?['key'] ?? _newKey('rule'),
        'name': row[1],
        'appliesTo': appliesTo,
        'documentKey': matches.single['key'],
        'required': required,
        'active': active,
        'match': match,
        'conditions': [?condition],
      });
    }
  }
  if (questions.isEmpty && rules.isEmpty) {
    throw const FormatException(
      'The file contains no questions or document rules.',
    );
  }
  return {'schemaVersion': 1, 'questions': questions, 'rules': rules};
}

class AdminKycConfigurationPage extends ConsumerStatefulWidget {
  const AdminKycConfigurationPage({super.key});

  @override
  ConsumerState<AdminKycConfigurationPage> createState() =>
      _AdminKycConfigurationPageState();
}

class _AdminKycConfigurationPageState
    extends ConsumerState<AdminKycConfigurationPage> {
  JsonMap? _data;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int _tab = 0;
  int _page = 0;
  String _search = '';
  String _subjectFilter = 'ALL';
  String _statusFilter = 'ALL';
  String _requiredFilter = 'ALL';
  String _documentFilter = 'ALL';
  String _sortBy = 'DEFAULT';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<JsonMap> _request(String suffix, JsonMap body) async =>
      (await ref
              .read(appDependenciesProvider)
              .apiClient
              .post('$_path$suffix', body: body))
          .decodeObject((json) => json);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          (await ref.read(appDependenciesProvider).apiClient.get(_path))
              .decodeObject((json) => json);
      if (mounted) {
        setState(() {
          _data = data;
          _page = 0;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = failureText(AbraLocalizations.of(context), error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(JsonMap config, String reason) async {
    setState(() => _saving = true);
    try {
      final saved =
          (await ref
                  .read(appDependenciesProvider)
                  .apiClient
                  .put(
                    _path,
                    body: <String, Object?>{
                      ...config,
                      'expectedVersion': _data!['version'],
                      'reason': reason,
                    },
                  ))
              .decodeObject((json) => json);
      if (mounted) {
        setState(() {
          _data = saved;
          _page = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(JsonMap? record) async {
    final questions = _rows(_data!['questions']);
    final rules = _rows(_data!['rules']);
    Future<void> save(JsonMap values) async {
      final updatedQuestions = List<JsonMap>.from(questions);
      final updatedRules = List<JsonMap>.from(rules);
      final collection = _tab == 0 ? updatedQuestions : updatedRules;
      final index = record == null
          ? -1
          : collection.indexWhere((r) => r['key'] == record['key']);
      if (index < 0) {
        collection.add(values);
      } else {
        collection[index] = values;
      }
      await _save(
        {
          'schemaVersion': 1,
          'questions': updatedQuestions,
          'rules': updatedRules,
        },
        '${record == null ? 'Created' : 'Updated'} KYC ${_tab == 0 ? 'question' : 'rule'} ${values['key']}',
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _tab == 0
          ? _QuestionDialog(
              record: record,
              save: save,
              nextOrder: questions.length,
            )
          : _RuleDialog(
              record: record,
              questions: questions,
              documents: _rows(_data!['documents']),
              save: save,
            ),
    );
  }

  Future<void> _delete(JsonMap record) async {
    final confirmed = await showAbraConfirmDialog(
      context,
      title: _t(context, 'DeleteTitle'),
      message:
          '${record['label'] ?? record['name']}\n${_t(context, 'DeleteHelp')}',
      confirmLabel: _t(context, 'Delete'),
    );
    if (!confirmed || !mounted) return;
    final config = kycExportData(_data!);
    config[_tab == 0 ? 'questions' : 'rules'] = _rows(
      config[_tab == 0 ? 'questions' : 'rules'],
    ).where((r) => r['key'] != record['key']).toList();
    try {
      await _save(
        config,
        'Deleted KYC ${_tab == 0 ? 'question' : 'rule'} ${record['key']}',
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureText(AbraLocalizations.of(context), error)),
          ),
        );
      }
    }
  }

  Future<void> _import() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportDialog(
      existing: _data!,
      documents: _rows(_data!['documents']),
      sample: {
        'schemaVersion': 1,
        'questions': <JsonMap>[
          {
            'key': 'business_type',
            'label': 'What is your business type?',
            'help': '',
            'appliesTo': 'OPERATOR',
            'type': 'SINGLE_CHOICE',
            'options': [
              {'value': 'company', 'label': 'Company'},
              {'value': 'individual', 'label': 'Individual'},
            ],
            'required': true,
            'active': true,
            'sortOrder': 0,
          },
        ],
        'rules': <JsonMap>[],
      },
      validate: (config) => _request('/validate-import', {
        ...config,
        'expectedVersion': _data!['version'],
        'reason': 'Validate KYC import',
      }),
      save: (config) => _save(config, 'Imported KYC configuration'),
    ),
  );

  void _filter(VoidCallback change) => setState(() {
    change();
    _page = 0;
  });
  void _clearFilters() => _filter(() {
    _search = '';
    _searchController.clear();
    _subjectFilter = 'ALL';
    _statusFilter = 'ALL';
    _requiredFilter = 'ALL';
    _documentFilter = 'ALL';
    _sortBy = 'DEFAULT';
  });

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AbraLoadingView();
    if (_error != null) {
      return AbraStateView(
        kind: AbraStateKind.error,
        message: _error,
        actionLabel: _t(context, 'Refresh'),
        onAction: _load,
      );
    }
    final data = _data!;
    final questions = _rows(data['questions']);
    final rules = _rows(data['rules']);
    final documents = _rows(data['documents']);
    final canManage = ref
        .watch(accessProvider)
        .can(PermissionKeys.documentsManage);
    final collection = _tab == 0 ? questions : rules;
    final filtered =
        collection.where((r) {
          final searchable =
              '${r['key']} ${r['label'] ?? r['name']} ${r['documentKey'] ?? ''}'
                  .toLowerCase();
          return searchable.contains(_search.toLowerCase()) &&
              (_subjectFilter == 'ALL' || r['appliesTo'] == _subjectFilter) &&
              (_statusFilter == 'ALL' ||
                  r['active'] == (_statusFilter == 'ACTIVE')) &&
              (_requiredFilter == 'ALL' ||
                  r['required'] == (_requiredFilter == 'REQUIRED')) &&
              (_tab == 0 ||
                  _documentFilter == 'ALL' ||
                  r['documentKey'] == _documentFilter);
        }).toList()..sort((a, b) {
          String name(JsonMap r) =>
              '${r['label'] ?? r['name'] ?? ''}'.toLowerCase();
          switch (_sortBy) {
            case 'NAME':
              return name(a).compareTo(name(b));
            case 'STATUS':
              final byStatus = '${b['active']}'.compareTo('${a['active']}');
              return byStatus != 0 ? byStatus : name(a).compareTo(name(b));
            case 'DOCUMENT':
              final byDocument = '${a['documentKey']}'.compareTo(
                '${b['documentKey']}',
              );
              return byDocument != 0 ? byDocument : name(a).compareTo(name(b));
          }
          return _tab == 0
              ? (a['sortOrder'] as num).compareTo(b['sortOrder'] as num)
              : '${a['name']}'.compareTo('${b['name']}');
        });
    final pages = (filtered.length / 10).ceil().clamp(1, 1000);
    final page = _page.clamp(0, pages - 1);
    final visible = filtered.skip(page * 10).take(10).toList();
    return Theme(
      data: _kycTheme(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 600;
          final contentWidth = (constraints.maxWidth - (narrow ? 32 : 48))
              .clamp(0.0, 1240.0);
          // Room left for the dropdowns once search and Clear filters have theirs.
          final choiceCount = _tab == 1 ? 5 : 4;
          final filterWidth =
              ((contentWidth - 32 - 220 - 110 - 12 * (choiceCount + 1)) /
                      choiceCount)
                  .clamp(150.0, 200.0);
          return SingleChildScrollView(
            padding: EdgeInsets.all(narrow ? 16 : 24),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'KYC configuration',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF12304A),
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set the questions clients answer and which documents each answer requires.',
                      style: TextStyle(color: Color(0xFF66798A)),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final stat in <(String, int, IconData)>[
                          (
                            _t(context, 'Questions'),
                            questions.length,
                            Icons.help_outline,
                          ),
                          (
                            _t(context, 'Rules'),
                            rules.length,
                            Icons.rule_outlined,
                          ),
                          (
                            _t(context, 'ActiveRules'),
                            rules.where((r) => r['active'] == true).length,
                            Icons.check_circle_outline,
                          ),
                          (
                            'Documents covered',
                            rules
                                .where((r) => r['active'] == true)
                                .map((r) => r['documentKey'])
                                .toSet()
                                .length,
                            Icons.folder_outlined,
                          ),
                        ])
                          SizedBox(
                            width:
                                (contentWidth -
                                    (contentWidth < 760 ? 12 : 36)) /
                                (contentWidth < 760 ? 2 : 4),
                            child: _stat(
                              context,
                              stat.$1,
                              stat.$2,
                              stat.$3,
                              tint: stat.$3 == Icons.check_circle_outline
                                  ? const Color(0xFFE1F4EA)
                                  : stat.$3 == Icons.folder_outlined
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFE8F6FD),
                              tintForeground:
                                  stat.$3 == Icons.check_circle_outline
                                  ? const Color(0xFF12663F)
                                  : stat.$3 == Icons.folder_outlined
                                  ? const Color(0xFF7A4B00)
                                  : const Color(0xFF1677C8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _t(context, 'Intro'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    Wrap(
                      spacing: AbraSpacing.sm,
                      runSpacing: AbraSpacing.sm,
                      children: [
                        if (canManage)
                          AbraButton(
                            label: _t(
                              context,
                              _tab == 0 ? 'AddQuestion' : 'AddRule',
                            ),
                            icon: Icons.add,
                            onPressed: _saving ? null : () => _edit(null),
                          ),
                        AbraButton(
                          label: _t(context, 'Preview'),
                          icon: Icons.preview_outlined,
                          variant: AbraButtonVariant.secondary,
                          onPressed: _saving
                              ? null
                              : () => showDialog<void>(
                                  context: context,
                                  builder: (_) => _PreviewDialog(
                                    questions: questions,
                                    preview: (body) =>
                                        _request('/preview', body),
                                  ),
                                ),
                        ),
                        AbraButton(
                          label: _t(context, 'Export'),
                          icon: Icons.download_outlined,
                          variant: AbraButtonVariant.secondary,
                          onPressed: _saving
                              ? null
                              : () => _export(data, documents),
                        ),
                        if (canManage)
                          AbraButton(
                            label: _t(context, 'Import'),
                            icon: Icons.upload_file_outlined,
                            variant: AbraButtonVariant.secondary,
                            onPressed: _saving ? null : _import,
                          ),
                        IconButton(
                          tooltip: _t(context, 'Refresh'),
                          onPressed: _saving ? null : _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    if (!canManage) Text(_t(context, 'ReadOnly')),
                    if (_saving) const LinearProgressIndicator(),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AbraSpacing.lg,
                          vertical: AbraSpacing.sm,
                        ),
                        child: Wrap(
                          spacing: AbraSpacing.md,
                          runSpacing: AbraSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.folder_copy_outlined,
                                  color: AbraColors.tealDark,
                                ),
                                const SizedBox(width: AbraSpacing.md),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: narrow
                                        ? contentWidth - 100
                                        : contentWidth - 260,
                                  ),
                                  child: Text(_t(context, 'DocumentHelp')),
                                ),
                              ],
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                              ),
                              onPressed: () =>
                                  context.go(AdminRoutes.documentTypes),
                              child: Text(_t(context, 'ManageDocuments')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFD7E0E7)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final tab in <(String, IconData)>[
                            (_t(context, 'Questions'), Icons.help_outline),
                            (_t(context, 'Rules'), Icons.rule_outlined),
                          ].indexed)
                            Flexible(
                              child: InkWell(
                                onTap: _saving
                                    ? null
                                    : () => _filter(() => _tab = tab.$1),
                                child: Semantics(
                                  selected: _tab == tab.$1,
                                  button: true,
                                  child: AnimatedContainer(
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                      horizontal: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          width: 3,
                                          color: _tab == tab.$1
                                              ? const Color(0xFF1677C8)
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          tab.$2.$2,
                                          size: 18,
                                          color: _tab == tab.$1
                                              ? const Color(0xFF1677C8)
                                              : const Color(0xFF66798A),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            tab.$2.$1,
                                            style: TextStyle(
                                              fontWeight: _tab == tab.$1
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: _tab == tab.$1
                                                  ? const Color(0xFF0B4EA2)
                                                  : const Color(0xFF66798A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: AbraSpacing.md,
                          runSpacing: AbraSpacing.md,
                          children: [
                            SizedBox(
                              width: narrow ? contentWidth - 32 : 220,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: _t(context, 'Search'),
                                  prefixIcon: const Icon(Icons.search),
                                ),
                                onChanged: (value) =>
                                    _filter(() => _search = value),
                              ),
                            ),
                            _choice(
                              context,
                              'Subject',
                              _subjectFilter,
                              {
                                'ALL': _t(context, 'AllSubjects'),
                                'OPERATOR': _t(context, 'Company'),
                                'BUS': _t(context, 'Bus'),
                              },
                              (v) => _filter(() => _subjectFilter = v),
                              width: filterWidth,
                            ),
                            _choice(
                              context,
                              'Status',
                              _statusFilter,
                              {
                                'ALL': _t(context, 'AllStatuses'),
                                'ACTIVE': _t(context, 'Active'),
                                'INACTIVE': _t(context, 'Inactive'),
                              },
                              (v) => _filter(() => _statusFilter = v),
                              width: filterWidth,
                            ),
                            _choice(
                              context,
                              'Requirement',
                              _requiredFilter,
                              {
                                'ALL': _t(context, 'AllRequirements'),
                                'REQUIRED': _t(context, 'Required'),
                                'OPTIONAL': _t(context, 'Optional'),
                              },
                              (v) => _filter(() => _requiredFilter = v),
                              width: filterWidth,
                            ),
                            if (_tab == 1)
                              _choice(
                                context,
                                'Document',
                                _documentFilter,
                                {
                                  'ALL': _t(context, 'AllDocuments'),
                                  for (final d in documents)
                                    '${d['key']}': '${d['name']}',
                                },
                                (v) => _filter(() => _documentFilter = v),
                                width: filterWidth,
                              ),
                            _choice(
                              context,
                              'SortBy',
                              _sortBy,
                              _tab == 0
                                  ? {
                                      'DEFAULT': 'Display order',
                                      'NAME': 'Question A-Z',
                                      'STATUS': 'Status',
                                    }
                                  : {
                                      'DEFAULT': 'Rule name',
                                      'DOCUMENT': 'Document',
                                      'STATUS': 'Status',
                                    },
                              (v) => _filter(() => _sortBy = v),
                              width: filterWidth,
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 48),
                              ),
                              onPressed: _clearFilters,
                              child: Text(_t(context, 'ClearFilters')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.lg),
                    Text(
                      '${filtered.length} ${_t(context, 'Results')}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.fact_check_outlined,
                                size: 36,
                                color: Color(0xFF66798A),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _t(
                                  context,
                                  collection.isEmpty ? 'Empty' : 'NoMatches',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final record in visible)
                          SizedBox(
                            width: contentWidth >= 900
                                ? (contentWidth - 16) / 2
                                : contentWidth,
                            child: _recordCard(
                              record,
                              questions,
                              documents,
                              canManage,
                            ),
                          ),
                      ],
                    ),
                    if (filtered.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: _t(context, 'Previous'),
                            onPressed: page > 0
                                ? () => setState(() => _page = page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('${page + 1} / $pages'),
                          IconButton(
                            tooltip: _t(context, 'Next'),
                            onPressed: page + 1 < pages
                                ? () => setState(() => _page = page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _export(
    JsonMap data,
    List<JsonMap> documents,
  ) => showDialog<void>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Export KYC configuration'),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Includes all questions and document rules. You can edit the file and import it again.',
          ),
        ),
        SimpleDialogOption(
          onPressed: () {
            downloadBytesFile(
              'abra-kyc-configuration.xlsx',
              kycExcelBytes(kycSpreadsheetRows(data, documents)),
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            );
            Navigator.pop(c);
          },
          child: const ListTile(
            leading: Icon(Icons.table_view),
            title: Text('Download Excel (.xlsx)'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () {
            downloadTextFile(
              'abra-kyc-configuration.csv',
              kycCsvText(kycSpreadsheetRows(data, documents)),
            );
            Navigator.pop(c);
          },
          child: const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('Download CSV'),
          ),
        ),
      ],
    ),
  );

  Widget _recordCard(
    JsonMap r,
    List<JsonMap> questions,
    List<JsonMap> documents,
    bool editable,
  ) {
    final isQuestion = _tab == 0;
    final conditions = _rows(r['conditions']);
    final name = isQuestion ? '${r['label']}' : '${r['name']}';
    final summary = isQuestion
        ? _options(r).map((o) => '${o['label']}').join(' · ')
        : conditions.isEmpty
        ? _t(context, 'Always')
        : conditions
              .map((c) {
                final q = questions
                    .where((q) => q['key'] == c['questionKey'])
                    .firstOrNull;
                final labels = _options(q ?? {})
                    .where((o) => (c['values'] as List).contains(o['value']))
                    .map((o) => '${o['label']}')
                    .join(', ');
                return '${q?['label'] ?? c['questionKey']}: $labels';
              })
              .join(
                r['match'] == 'ANY'
                    ? ' ${_t(context, 'Or')} '
                    : ' ${_t(context, 'And')} ',
              );
    final doc = documents
        .where((d) => d['key'] == r['documentKey'])
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF12304A),
                            ),
                      ),
                      Text(
                        _subject(context, r['appliesTo']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (editable) ...[
                  IconButton(
                    tooltip: _t(context, 'Edit'),
                    onPressed: _saving ? null : () => _edit(r),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: _t(context, 'Delete'),
                    onPressed: _saving ? null : () => _delete(r),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AbraSpacing.sm),
            Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.xs,
              children: [
                _badge(
                  _t(context, r['active'] == true ? 'Active' : 'Inactive'),
                  color: r['active'] == true
                      ? const Color(0xFF12663F)
                      : const Color(0xFF12304A),
                  background: r['active'] == true
                      ? const Color(0xFFE1F4EA)
                      : const Color(0xFFE5EAEE),
                ),
                _badge(
                  _t(context, r['required'] == true ? 'Required' : 'Optional'),
                  color: r['required'] == true
                      ? const Color(0xFF0B4EA2)
                      : const Color(0xFF12304A),
                  background: r['required'] == true
                      ? const Color(0xFFDDF3FC)
                      : const Color(0xFFE5EAEE),
                ),
                if (isQuestion)
                  _badge(switch (r['type']) {
                    'MULTI_CHOICE' => 'Choose several',
                    'BOOLEAN' => 'Yes or No',
                    _ => 'Choose one',
                  }),
                if (!isQuestion) _badge('${doc?['name'] ?? r['documentKey']}'),
              ],
            ),
            const SizedBox(height: 10),
            if (summary.isNotEmpty)
              Text(
                summary,
                style: const TextStyle(color: Color(0xFF66798A), height: 1.5),
              ),
            if (!isQuestion && doc?['isActive'] == false)
              Text(
                _t(context, 'DocumentInactive'),
                style: const TextStyle(color: AbraColors.danger),
              ),
            if (isQuestion && '${r['help'] ?? ''}'.isNotEmpty)
              Text('${r['help']}'),
          ],
        ),
      ),
    );
  }
}

ThemeData _kycTheme(BuildContext context) => Theme.of(context).copyWith(
  cardTheme: CardThemeData(
    color: Colors.white,
    margin: EdgeInsets.zero,
    elevation: 2,
    shadowColor: const Color(0x1A12304A),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFD7E0E7)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD7E0E7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD7E0E7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF36BDF5), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB91C1C)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 2),
    ),
  ),
  switchTheme: SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? const Color(0xFF1677C8)
          : const Color(0xFFB7C4CF),
    ),
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF1677C8),
      backgroundColor: const Color(0xFFE8F6FD),
      side: BorderSide.none,
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF1677C8),
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);

Widget _badge(String label, {Color? color, Color? background}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: background ?? const Color(0xFFE5EAEE),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    label,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: color ?? const Color(0xFF66798A),
    ),
  ),
);

Widget _stat(
  BuildContext c,
  String label,
  int count,
  IconData icon, {
  Color tint = const Color(0xFFE8F6FD),
  Color tintForeground = const Color(0xFF1677C8),
}) => Card(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        if (MediaQuery.sizeOf(c).width >= 600) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tintForeground, size: 22),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF12304A),
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF66798A)),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _choice(
  BuildContext c,
  String label,
  String value,
  Map<String, String> options,
  ValueChanged<String> onChanged, {
  double? width,
}) => SizedBox(
  width: MediaQuery.sizeOf(c).width < 600
      ? double.infinity
      : (width ?? (label == 'AnswerType' ? 260 : 200)),
  child: DropdownButtonFormField<String>(
    key: ValueKey('$label:$value:${options.keys.join(',')}'),
    initialValue: options.containsKey(value) ? value : options.keys.first,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label == 'SortBy' ? 'Sort by' : _t(c, label),
    ),
    items: [
      for (final e in options.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  ),
);

Widget _dialog(
  BuildContext c,
  String title,
  List<Widget> children,
  List<Widget> actions,
) => Theme(
  data: _kycTheme(c),
  child: AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    alignment: MediaQuery.sizeOf(c).width < 600
        ? Alignment.bottomCenter
        : Alignment.center,
    insetPadding: MediaQuery.sizeOf(c).width < 600
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: MediaQuery.sizeOf(c).width < 600
          ? const BorderRadius.vertical(top: Radius.circular(20))
          : BorderRadius.circular(16),
    ),
    titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    title: Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD7E0E7))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF12304A),
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(c).closeButtonTooltip,
            onPressed:
                actions.whereType<AbraButton>().any(
                  (button) => button.isLoading,
                )
                ? null
                : () => Navigator.pop(c),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    actionsPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
    content: SizedBox(
      width: 680,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: AbraSpacing.md),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD7E0E7)),
        ],
      ),
    ),
    actions: actions,
  ),
);

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({
    required this.record,
    required this.save,
    required this.nextOrder,
  });
  final JsonMap? record;
  final int nextOrder;
  final Future<void> Function(JsonMap) save;
  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _form = GlobalKey<FormState>();
  late final _key = TextEditingController(
    text: '${widget.record?['key'] ?? _newKey('question')}',
  );
  late final _label = TextEditingController(
    text: '${widget.record?['label'] ?? ''}',
  );
  late final _help = TextEditingController(
    text: '${widget.record?['help'] ?? ''}',
  );
  late final List<TextEditingController> _answerLabels =
      widget.record == null || _rows(widget.record?['options']).isEmpty
      ? [TextEditingController(), TextEditingController()]
      : _rows(
          widget.record?['options'],
        ).map((o) => TextEditingController(text: '${o['label']}')).toList();
  late final List<String> _answerValues =
      widget.record == null || _rows(widget.record?['options']).isEmpty
      ? [_newKey('answer'), _newKey('answer')]
      : _rows(widget.record?['options']).map((o) => '${o['value']}').toList();
  late final _order = TextEditingController(
    text: '${widget.record?['sortOrder'] ?? widget.nextOrder}',
  );
  late String _subjectValue = '${widget.record?['appliesTo'] ?? 'OPERATOR'}';
  late String _type = '${widget.record?['type'] ?? 'SINGLE_CHOICE'}';
  late bool _required = widget.record?['required'] != false;
  late bool _active = widget.record?['active'] != false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_key, _label, _help, ..._answerLabels, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final options = <JsonMap>[];
      if (_type != 'BOOLEAN') {
        if (_answerLabels.length < 2 ||
            _answerLabels
                    .map((c) => c.text.trim().toLowerCase())
                    .toSet()
                    .length !=
                _answerLabels.length) {
          throw const FormatException(
            'Add at least two different answer options.',
          );
        }
        for (var i = 0; i < _answerLabels.length; i++) {
          options.add({
            'value': _answerValues[i],
            'label': _answerLabels[i].text.trim(),
          });
        }
      }
      await widget.save({
        'key': _key.text.trim(),
        'label': _label.text.trim(),
        'help': _help.text.trim(),
        'appliesTo': _subjectValue,
        'type': _type,
        'options': options,
        'required': _required,
        'active': _active,
        'sortOrder': int.parse(_order.text),
      });
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : failureText(AbraLocalizations.of(context), error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _dialog(
    context,
    _t(context, widget.record == null ? 'AddQuestion' : 'EditQuestion'),
    [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Write the question your clients will see, then add the answers they can choose.',
              ),
            ),
            TextFormField(
              controller: _label,
              enabled: !_busy,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: _t(context, 'QuestionText'),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? _t(context, 'FieldRequired')
                  : null,
            ),
            TextFormField(
              controller: _help,
              enabled: !_busy,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(labelText: _t(context, 'HelpText')),
            ),
            const SizedBox(height: AbraSpacing.md),
            IgnorePointer(
              ignoring: _busy,
              child: Wrap(
                spacing: AbraSpacing.md,
                runSpacing: AbraSpacing.md,
                children: [
                  _choice(
                    context,
                    'Subject',
                    _subjectValue,
                    {
                      'OPERATOR': _t(context, 'Company'),
                      'BUS': _t(context, 'Bus'),
                    },
                    (v) => setState(() => _subjectValue = v),
                  ),
                  _choice(context, 'AnswerType', _type, {
                    'SINGLE_CHOICE': _t(context, 'SingleChoice'),
                    'MULTI_CHOICE': _t(context, 'MultiChoice'),
                    'BOOLEAN': _t(context, 'YesNo'),
                  }, (v) => setState(() => _type = v)),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.md),
            if (_type != 'BOOLEAN') ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _t(context, 'AnswerOptions'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _answerLabels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ObjectKey(_answerLabels[i]),
                          controller: _answerLabels[i],
                          enabled: !_busy,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                            hintText: 'For example: Own buses',
                            counterText: '',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter an answer option.'
                              : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove option',
                        onPressed: _busy || _answerLabels.length <= 2
                            ? null
                            : () => setState(() {
                                _answerLabels.removeAt(i).dispose();
                                _answerValues.removeAt(i);
                              }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy || _answerLabels.length >= 20
                      ? null
                      : () => setState(() {
                          _answerLabels.add(TextEditingController());
                          _answerValues.add(_newKey('answer'));
                        }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Clients will choose Yes or No.'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_t(context, 'AnswerRequired')),
              value: _required,
              onChanged: _busy ? null : (v) => setState(() => _required = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_t(context, 'Active')),
              value: _active,
              onChanged: _busy ? null : (v) => setState(() => _active = v),
            ),
          ],
        ),
      ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: AbraColors.danger)),
    ],
    [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: Text(_t(context, 'Cancel')),
      ),
      AbraButton(
        label: _t(context, 'Save'),
        isLoading: _busy,
        onPressed: _save,
      ),
    ],
  );
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({
    required this.record,
    required this.questions,
    required this.documents,
    required this.save,
  });
  final JsonMap? record;
  final List<JsonMap> questions;
  final List<JsonMap> documents;
  final Future<void> Function(JsonMap) save;
  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _form = GlobalKey<FormState>();
  late final _key = TextEditingController(
    text: '${widget.record?['key'] ?? _newKey('rule')}',
  );
  late final _name = TextEditingController(
    text: '${widget.record?['name'] ?? ''}',
  );
  late String _subjectValue = '${widget.record?['appliesTo'] ?? 'OPERATOR'}';
  late String? _document = widget.record?['documentKey'] as String?;
  late String _match = '${widget.record?['match'] ?? 'ALL'}';
  late bool _required = widget.record?['required'] != false;
  late bool _active = widget.record?['active'] != false;
  late final List<JsonMap> _conditions = _rows(widget.record?['conditions'])
      .map(
        (c) => <String, Object?>{
          'questionKey': c['questionKey'],
          'values': List<String>.from(c['values'] as List),
        },
      )
      .toList();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_document == null ||
        _conditions.any(
          (c) =>
              _rows(
                widget.questions,
              ).where((q) => q['key'] == c['questionKey']).isEmpty ||
              (c['values'] as List).isEmpty,
        )) {
      setState(() => _error = _t(context, 'RuleInvalid'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save({
        'key': _key.text.trim(),
        'name': _name.text.trim(),
        'appliesTo': _subjectValue,
        'documentKey': _document,
        'required': _required,
        'active': _active,
        'match': _match,
        'conditions': _conditions,
      });
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = failureText(AbraLocalizations.of(context), error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.documents
        .where((d) => d['appliesTo'] == _subjectValue)
        .toList();
    final questions = widget.questions
        .where((q) => q['appliesTo'] == _subjectValue)
        .toList();
    return _dialog(
      context,
      _t(context, widget.record == null ? 'AddRule' : 'EditRule'),
      [
        Form(
          key: _form,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Choose a document and when clients should provide it. With no answer conditions, it applies to everyone.',
                ),
              ),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                maxLength: 120,
                decoration: InputDecoration(labelText: _t(context, 'RuleName')),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? _t(context, 'FieldRequired')
                    : null,
              ),
            ],
          ),
        ),
        IgnorePointer(
          ignoring: _busy,
          child: _choice(
            context,
            'Subject',
            _subjectValue,
            {'OPERATOR': _t(context, 'Company'), 'BUS': _t(context, 'Bus')},
            (v) => setState(() {
              _subjectValue = v;
              _document = null;
              _conditions.clear();
            }),
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('document:$_subjectValue:$_document'),
          initialValue: docs.any((d) => d['key'] == _document)
              ? _document
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: _t(context, 'Document')),
          items: [
            for (final d in docs)
              DropdownMenuItem(
                value: '${d['key']}',
                child: Text(
                  '${d['name']}${d['isActive'] == false ? ' (${_t(context, 'Inactive')})' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy ? null : (v) => setState(() => _document = v),
        ),
        if (docs.isEmpty) Text(_t(context, 'NoDocuments')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_t(context, 'DocumentRequired')),
          value: _required,
          subtitle: Text(_t(context, 'RequiredWins')),
          onChanged: _busy ? null : (v) => setState(() => _required = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_t(context, 'Active')),
          value: _active,
          onChanged: _busy ? null : (v) => setState(() => _active = v),
        ),
        Text(_t(context, 'ConditionsHelp')),
        if (_conditions.isNotEmpty)
          IgnorePointer(
            ignoring: _busy,
            child: _choice(context, 'Match', _match, {
              'ALL': _t(context, 'MatchAll'),
              'ANY': _t(context, 'MatchAny'),
            }, (v) => setState(() => _match = v)),
          ),
        for (var i = 0; i < _conditions.length; i++) _condition(i, questions),
        TextButton.icon(
          onPressed: _busy || _conditions.length >= 10 || questions.isEmpty
              ? null
              : () => setState(() {
                  _conditions.add({'questionKey': null, 'values': <String>[]});
                }),
          icon: const Icon(Icons.add),
          label: Text(_t(context, 'AddCondition')),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AbraColors.danger)),
      ],
      [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(_t(context, 'Cancel')),
        ),
        AbraButton(
          label: _t(context, 'Save'),
          isLoading: _busy,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _condition(int index, List<JsonMap> questions) {
    final c = _conditions[index];
    final q = questions.where((q) => q['key'] == c['questionKey']).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('condition:$index:${c['questionKey']}'),
                    initialValue: q?['key'] as String?,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _t(context, 'Question'),
                    ),
                    items: [
                      for (final candidate in questions)
                        DropdownMenuItem(
                          value: '${candidate['key']}',
                          child: Text(
                            '${candidate['label']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            c['questionKey'] = v;
                            c['values'] = <String>[];
                          }),
                  ),
                ),
                IconButton(
                  tooltip: _t(context, 'RemoveCondition'),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _conditions.removeAt(index)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (q != null)
              Wrap(
                spacing: AbraSpacing.sm,
                children: [
                  for (final o in _options(q))
                    FilterChip(
                      label: Text('${o['label']}'),
                      selected: (c['values'] as List).contains(o['value']),
                      onSelected: _busy
                          ? null
                          : (selected) => setState(() {
                              final values = List<String>.from(
                                c['values'] as List,
                              );
                              selected
                                  ? values.add('${o['value']}')
                                  : values.remove(o['value']);
                              c['values'] = values;
                            }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({
    required this.sample,
    required this.validate,
    required this.save,
    required this.existing,
    required this.documents,
  });
  final JsonMap sample;
  final JsonMap existing;
  final List<JsonMap> documents;
  final Future<JsonMap> Function(JsonMap) validate;
  final Future<void> Function(JsonMap) save;
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  JsonMap? _validated;
  JsonMap? _parsed;
  String? _filename;
  String? _error;
  bool _busy = false;
  String _ruleDescription(JsonMap rule) {
    final document = widget.documents
        .where((d) => d['key'] == rule['documentKey'])
        .firstOrNull;
    final conditions = _rows(rule['conditions']).map((condition) {
      final question = _rows(
        _parsed?['questions'],
      ).where((q) => q['key'] == condition['questionKey']).firstOrNull;
      final answers = _options(question ?? {})
          .where((o) => (condition['values'] as List).contains(o['value']))
          .map((o) => '${o['label']}')
          .join(', ');
      return '${question?['label']}: $answers';
    }).toList();
    return '${document?['name'] ?? ''} · ${rule['required'] == true ? 'Required' : 'Optional'} · ${rule['active'] == true ? 'Active' : 'Inactive'}\n${conditions.isEmpty ? 'Applies to everyone' : conditions.join(rule['match'] == 'ANY' ? '\nOR\n' : '\nAND\n')}';
  }

  Future<void> _pick() async {
    setState(() {
      _validated = null;
      _parsed = null;
      _error = null;
      _filename = null;
      _busy = true;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.bytes == null) {
        throw const FormatException(
          'This file could not be read. Please choose it again.',
        );
      }
      final config = kycParseSpreadsheet(
        kycReadSpreadsheet(file.bytes!, file.extension?.toLowerCase() ?? ''),
        widget.existing,
        widget.documents,
      );
      if (mounted) {
        setState(() {
          _parsed = config;
          _filename = file.name;
        });
      }
      await widget.validate(config);
      if (mounted) setState(() => _validated = config);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : failureText(AbraLocalizations.of(context), e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.save(_validated!);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = failureText(AbraLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _dialog(
    context,
    _t(context, 'Import'),
    [
      const Text(
        '1. Download the Excel sample',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const Text(
        'Fill in the questions and answers. For document rules, use the document names listed in Required documents. Use one row per condition when a rule has several conditions.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _busy
              ? null
              : () => downloadBytesFile(
                  'abra-kyc-sample.xlsx',
                  kycExcelBytes(
                    kycSpreadsheetRows(widget.sample, widget.documents),
                  ),
                  mimeType:
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                ),
          icon: const Icon(Icons.download),
          label: const Text('Download Excel sample'),
        ),
      ),
      const Divider(),
      const Text(
        '2. Upload your completed file',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const Text(
        'Excel (.xlsx) or CSV, up to 2 MB. Keep the sample column headings. Your upload is checked before anything is saved.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Excel or CSV'),
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_filename != null) Text(_filename!),
      if (_parsed != null) ...[
        const Divider(),
        const Text(
          'Review your import',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final q in _rows(_parsed!['questions']))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text('${q['label']}'),
            subtitle: Text(
              '${_subjectName(q['appliesTo'])} · ${_typeName(q['type'])} · ${q['required'] == true ? 'Required' : 'Optional'} · ${q['active'] == true ? 'Active' : 'Inactive'}\n${_options(q).map((o) => o['label']).join(' · ')}',
            ),
          ),
        for (final r in _rows(_parsed!['rules']))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text('${r['name']}'),
            subtitle: Text(_ruleDescription(r)),
          ),
      ],
      if (_validated != null)
        Text(
          '${_t(context, 'ValidImport')}: ${_rows(_validated!['questions']).length} ${_t(context, 'Questions')}, ${_rows(_validated!['rules']).length} ${_t(context, 'Rules')}',
          style: const TextStyle(color: AbraColors.tealDark),
        ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: AbraColors.danger)),
    ],
    [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: Text(_t(context, 'Cancel')),
      ),
      AbraButton(
        label: _t(context, 'Import'),
        isLoading: _busy,
        onPressed: _validated != null ? _save : null,
      ),
    ],
  );
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({required this.questions, required this.preview});
  final List<JsonMap> questions;
  final Future<JsonMap> Function(JsonMap) preview;
  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  String _subjectValue = 'OPERATOR';
  final JsonMap _answers = {};
  JsonMap? _result;
  String? _error;
  bool _busy = false;
  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.preview({
        'appliesTo': _subjectValue,
        'answers': _answers,
      });
      if (mounted) setState(() => _result = result);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = failureText(AbraLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions =
        widget.questions
            .where(
              (q) => q['active'] == true && q['appliesTo'] == _subjectValue,
            )
            .toList()
          ..sort(
            (a, b) => (a['sortOrder'] as num).compareTo(b['sortOrder'] as num),
          );
    return _dialog(
      context,
      _t(context, 'Preview'),
      [
        IgnorePointer(
          ignoring: _busy,
          child: _choice(
            context,
            'Subject',
            _subjectValue,
            {'OPERATOR': _t(context, 'Company'), 'BUS': _t(context, 'Bus')},
            (v) => setState(() {
              _subjectValue = v;
              _answers.clear();
              _result = null;
            }),
          ),
        ),
        if (questions.isEmpty) Text(_t(context, 'NoQuestions')),
        for (final q in questions)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${q['label']}${q['required'] == true ? ' *' : ''}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if ('${q['help'] ?? ''}'.isNotEmpty) Text('${q['help']}'),
              Wrap(
                spacing: AbraSpacing.sm,
                children: [
                  for (final o in _options(q))
                    FilterChip(
                      label: Text('${o['label']}'),
                      selected: q['type'] == 'MULTI_CHOICE'
                          ? ((_answers[q['key']] as List?) ?? []).contains(
                              o['value'],
                            )
                          : _answers[q['key']] == o['value'],
                      onSelected: _busy
                          ? null
                          : (selected) => setState(() {
                              _result = null;
                              if (q['type'] == 'MULTI_CHOICE') {
                                final values = List<String>.from(
                                  (_answers[q['key']] as List?) ?? [],
                                );
                                selected
                                    ? values.add('${o['value']}')
                                    : values.remove(o['value']);
                                _answers['${q['key']}'] = values;
                              } else if (selected) {
                                _answers['${q['key']}'] = o['value'];
                              } else {
                                _answers.remove(q['key']);
                              }
                            }),
                    ),
                ],
              ),
            ],
          ),
        if (_result != null) ...[
          const Divider(),
          Text(
            _t(context, 'ApplicableDocuments'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if ((_result!['missingQuestions'] as List).isNotEmpty)
            Text(
              '${_t(context, 'MissingAnswers')}: ${questions.where((q) => (_result!['missingQuestions'] as List).contains(q['key'])).map((q) => q['label']).join(', ')}',
            ),
          if (_rows(_result!['documents']).isEmpty)
            Text(_t(context, 'NoApplicableDocuments')),
          for (final d in _rows(_result!['documents']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text('${d['name']}'),
              subtitle: Text('${d['instructions'] ?? ''}'),
              trailing: Text(
                _t(context, d['isRequired'] == true ? 'Required' : 'Optional'),
              ),
            ),
        ],
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AbraColors.danger)),
      ],
      [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(_t(context, 'Close')),
        ),
        AbraButton(
          label: _t(context, 'ShowChecklist'),
          isLoading: _busy,
          onPressed: _preview,
        ),
      ],
    );
  }
}
