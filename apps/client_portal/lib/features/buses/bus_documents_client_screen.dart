import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';

// The documents of one bus (RC, insurance, permit, fitness, pollution, tax, or any the owner names),
// each with its own expiry date and reminder days, and the bus's usual driver and conductor.

// ===== 1. MODELS =====

class BusDocFileItem {
  BusDocFileItem({required this.id, required this.name, required this.mimeType, required this.sizeBytes});

  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;

  factory BusDocFileItem.fromJson(Map<String, dynamic> json) => BusDocFileItem(
        id: json['id'] as String? ?? '',
        name: json['originalName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

class BusDocItem {
  BusDocItem({
    required this.id,
    required this.docType,
    required this.docName,
    required this.validTill,
    required this.daysLeft,
    required this.status,
    required this.remindDaysBefore,
    required this.files,
  });

  final String id;
  final String docType;
  final String docName;
  final String validTill;
  final int daysLeft;
  final String status;
  final List<int> remindDaysBefore;
  final List<BusDocFileItem> files;

  factory BusDocItem.fromJson(Map<String, dynamic> json) => BusDocItem(
        id: json['id'] as String? ?? '',
        docType: json['docType'] as String? ?? 'OTHER',
        docName: json['docName'] as String? ?? '',
        validTill: json['validTill'] as String? ?? '',
        daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'VALID',
        remindDaysBefore: [
          for (final raw in (json['remindDaysBefore'] as List<dynamic>? ?? const <dynamic>[]))
            if (raw is num) raw.toInt(),
        ],
        files: [
          for (final raw in (json['files'] as List<dynamic>? ?? const <dynamic>[]))
            if (raw is Map<String, dynamic>) BusDocFileItem.fromJson(raw),
        ],
      );
}

class BusDocTypeItem {
  BusDocTypeItem({required this.key, required this.label, required this.required});

  final String key;
  final String label;
  final bool required;
}

class BusCrewChoice {
  BusCrewChoice({required this.id, required this.name});

  final String id;
  final String name;
}

const _maxDocFiles = 10;
const _maxDocMb = 5;
const _defaultRemindDays = '30, 15, 7, 1';

// ===== 2. PROVIDERS =====

final busDocumentsProvider = FutureProvider.autoDispose.family<List<BusDocItem>, String>((ref, busId) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  final response = await client.get('client/buses/$busId/documents');
  final data = response.data;
  return [
    if (data is List)
      for (final raw in data)
        if (raw is Map<String, dynamic>) BusDocItem.fromJson(raw),
  ];
});

final busDocTypesProvider = FutureProvider.autoDispose<List<BusDocTypeItem>>((ref) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  final response = await client.get('client/bus-document-types');
  final data = response.data;
  return [
    if (data is List)
      for (final raw in data)
        if (raw is Map<String, dynamic>)
          BusDocTypeItem(
            key: raw['key'] as String? ?? '',
            label: raw['label'] as String? ?? '',
            required: raw['required'] == true,
          ),
  ];
});

/// The active drivers or conductors of the operator, for "Usual driver" and "Usual conductor".
final busCrewChoicesProvider = FutureProvider.autoDispose.family<List<BusCrewChoice>, String>((ref, role) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  final response = await client.get(
    'client/crew',
    query: <String, dynamic>{'role': role, 'status': 'ACTIVE', 'pageSize': 100},
  );
  final data = response.data;
  final raws = data is List ? data : (data is Map && data['items'] is List ? data['items'] as List : const <Object?>[]);
  return [
    for (final raw in raws)
      if (raw is Map<String, dynamic>) BusCrewChoice(id: raw['id'] as String? ?? '', name: raw['name'] as String? ?? ''),
  ];
});

/// Sends a form with files. A file upload can be sent only once, so when the sign-in token had run out
/// (the client refreshes it and replays the same upload, which fails) the form is built again and sent once more.
Future<ApiSuccess> _uploadForm(ApiClient client, String path, FormData Function() build) async {
  try {
    return await client.postForm(path, build());
  } catch (error) {
    final failure = failureOf(error);
    if (failure is ApiFailure && failure.statusCode != 401 && failure.statusCode < 500) rethrow;
    return client.postForm(path, build());
  }
}

/// What to tell the person when a request fails: the server's own words for input problems.
String _errorText(Object error) {
  final failure = failureOf(error);
  if (failure is ApiFailure && failure.message.isNotEmpty && failure.statusCode < 500) return failure.message;
  if (failure is NetworkFailure) return 'No connection. Check the internet and try again.';
  return 'Something went wrong. Please try again.';
}

String _day(DateTime date) => date.toIso8601String().substring(0, 10);

String _size(int bytes) =>
    bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

/// "30, 15, 7" as the whole numbers the server wants; null when something is not a number.
List<int>? _parseDays(String text) {
  final parts = text.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  final days = parts.map(int.tryParse).toList();
  return days.any((day) => day == null) ? null : [for (final day in days) day!];
}

// ===== 3. THE DIALOG =====

/// Opens the documents of a bus. [onChanged] runs after the usual driver or conductor changes.
Future<void> showBusDocumentsDialog(
  BuildContext context, {
  required String busId,
  required String registration,
  String? defaultDriverId,
  String? defaultConductorId,
  VoidCallback? onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BusDocumentsDialog(
      busId: busId,
      registration: registration,
      defaultDriverId: defaultDriverId,
      defaultConductorId: defaultConductorId,
      onChanged: onChanged,
    ),
  );
}

class BusDocumentsDialog extends ConsumerStatefulWidget {
  const BusDocumentsDialog({
    required this.busId,
    required this.registration,
    this.defaultDriverId,
    this.defaultConductorId,
    this.onChanged,
    super.key,
  });

  final String busId;
  final String registration;
  final String? defaultDriverId;
  final String? defaultConductorId;
  final VoidCallback? onChanged;

  @override
  ConsumerState<BusDocumentsDialog> createState() => _BusDocumentsDialogState();
}

class _BusDocumentsDialogState extends ConsumerState<BusDocumentsDialog> {
  String _docType = 'RC';
  final _nameCtrl = TextEditingController();
  final _remindCtrl = TextEditingController(text: _defaultRemindDays);
  DateTime? _validTill;
  final List<PlatformFile> _picked = [];
  String? _error;
  bool _busy = false;
  late String? _driverId = widget.defaultDriverId;
  late String? _conductorId = widget.defaultConductorId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _remindCtrl.dispose();
    super.dispose();
  }

  String get _base => 'client/buses/${widget.busId}/documents';

  void _reload() => ref.invalidate(busDocumentsProvider(widget.busId));

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _allowed(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  String? _check(List<PlatformFile> files, int already) {
    if (files.length + already > _maxDocFiles) return 'A document can have at most $_maxDocFiles files.';
    for (final file in files) {
      if (!_allowed(file.name)) return '${file.name}: only PDF, JPG or PNG files can be added.';
      if (file.size > _maxDocMb * 1024 * 1024) return '${file.name} is larger than $_maxDocMb MB.';
    }
    return null;
  }

  Future<List<PlatformFile>> _pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    return result?.files.where((f) => f.bytes != null).toList() ?? <PlatformFile>[];
  }

  Future<void> _chooseFiles() async {
    final files = await _pick();
    if (files.isEmpty || !mounted) return;
    final all = [..._picked, ...files];
    setState(() {
      _error = _check(all, 0);
      if (_error == null) {
        _picked
          ..clear()
          ..addAll(all);
      }
    });
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
    );
  }

  List<MultipartFile> _parts(List<PlatformFile> files) => [
        for (final file in files) MultipartFile.fromBytes(file.bytes!, filename: file.name),
      ];

  Future<void> _upload() async {
    if (_docType == 'OTHER' && _nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Type the name of the document.');
      return;
    }
    if (_validTill == null) {
      setState(() => _error = 'Choose the expiry date (Valid till).');
      return;
    }
    if (_parseDays(_remindCtrl.text) == null) {
      setState(() => _error = 'Reminder days must be numbers like 30, 15, 7, 1.');
      return;
    }
    if (_picked.isEmpty) {
      setState(() => _error = 'Choose at least one file.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await _uploadForm(
        client,
        _base,
        () => FormData.fromMap(<String, Object?>{
          'docType': _docType,
          if (_nameCtrl.text.trim().isNotEmpty) 'docName': _nameCtrl.text.trim(),
          'validTill': _day(_validTill!),
          'remindDaysBefore': _remindCtrl.text.trim(),
          'files': _parts(_picked),
        }),
      );
      if (!mounted) return;
      setState(() {
        _picked.clear();
        _validTill = null;
        _nameCtrl.clear();
        _remindCtrl.text = _defaultRemindDays;
      });
      _reload();
      _toast('Document added');
    } catch (err) {
      if (mounted) setState(() => _error = _errorText(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFiles(BusDocItem doc) async {
    final files = await _pick();
    if (files.isEmpty) return;
    final problem = _check(files, doc.files.length);
    if (problem != null) {
      _toast(problem);
      return;
    }
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await _uploadForm(client, '$_base/${doc.id}/files', () => FormData.fromMap(<String, Object?>{'files': _parts(files)}));
      _reload();
      _toast('Files added');
    } catch (err) {
      _toast(_errorText(err));
    }
  }

  Future<void> _patch(BusDocItem doc, Map<String, Object?> body, String done) async {
    try {
      await ref.read(appDependenciesProvider).apiClient.patch('$_base/${doc.id}', body: body);
      _reload();
      _toast(done);
    } catch (err) {
      _toast(_errorText(err));
    }
  }

  Future<void> _rename(BusDocItem doc) async {
    final ctrl = TextEditingController(text: doc.docName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: ctrl,
          maxLength: 100,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Document name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == doc.docName) return;
    await _patch(doc, {'docName': name}, 'Name saved');
  }

  Future<void> _changeDate(BusDocItem doc) async {
    final date = await _pickDate(DateTime.tryParse(doc.validTill));
    if (date != null) await _patch(doc, {'validTill': _day(date)}, 'Expiry date saved');
  }

  Future<void> _changeReminders(BusDocItem doc) async {
    final ctrl = TextEditingController(text: doc.remindDaysBefore.join(', '));
    String? problem;
    final days = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Reminder days'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How many days before the expiry date should we remind you, the staff and the driver and crew?'),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Days before expiry (e.g. 30, 15, 7, 1)', errorText: problem),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final parsed = _parseDays(ctrl.text);
                if (parsed == null) {
                  setDlg(() => problem = 'Use numbers separated by commas.');
                  return;
                }
                Navigator.pop(ctx, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (days != null) await _patch(doc, {'remindDaysBefore': days}, 'Reminder days saved');
  }

  Future<void> _delete(String label, String path, {required String ask}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text(ask),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(appDependenciesProvider).apiClient.delete(path);
      _reload();
      _toast('Deleted');
    } catch (err) {
      _toast(_errorText(err));
    }
  }

  Future<void> _open(BusDocItem doc, BusDocFileItem file, {required bool download}) async {
    try {
      final Uint8List bytes = await ref.read(appDependenciesProvider).apiClient.getBytes('$_base/${doc.id}/files/${file.id}');
      if (download) {
        downloadBytesFile(file.name, bytes, file.mimeType);
      } else {
        openFileInBrowser(bytes, file.mimeType);
      }
    } catch (err) {
      _toast(_errorText(err));
    }
  }

  Future<void> _saveCrew({String? driver, String? conductor, required bool driverChanged}) async {
    try {
      await ref.read(appDependenciesProvider).apiClient.patch(
        'client/buses/${widget.busId}',
        body: <String, Object?>{
          if (driverChanged) 'defaultDriverId': driver else 'defaultConductorId': conductor,
        },
      );
      widget.onChanged?.call();
      _toast(driverChanged ? 'Usual driver saved' : 'Usual conductor saved');
    } catch (err) {
      _toast(_errorText(err));
      if (mounted) {
        setState(() {
          _driverId = widget.defaultDriverId;
          _conductorId = widget.defaultConductorId;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(busDocumentsProvider(widget.busId));
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: Text('Documents - ${widget.registration}'),
      content: SizedBox(
        width: width < 640 ? width - 80 : 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _crewSection(),
              const SizedBox(height: AbraSpacing.md),
              _addForm(),
              const SizedBox(height: AbraSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AbraSpacing.md),
              docs.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (err, _) => Column(
                  children: [
                    Text(_errorText(err), style: const TextStyle(color: AbraColors.danger)),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No documents yet. Add the RC, insurance, permit and fitness papers above.',
                            style: TextStyle(color: AbraColors.textSecondary),
                          ),
                        ),
                      )
                    : Column(children: [for (final doc in list) _docCard(doc)]),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }

  Widget _crewDropdown({
    required String label,
    required String role,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    final choices = ref.watch(busCrewChoicesProvider(role));
    return choices.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, _) => Text(_errorText(err), style: const TextStyle(color: AbraColors.danger, fontSize: 12)),
      data: (list) {
        final known = list.any((c) => c.id == value);
        return DropdownButtonFormField<String>(
          initialValue: known ? value : '',
          isExpanded: true,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            const DropdownMenuItem(value: '', child: Text('Not set')),
            for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }

  Widget _crewSection() {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(color: AbraColors.lightGray, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Who runs this bus', style: TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue)),
          const SizedBox(height: 4),
          const Text(
            'New trips start with this driver and conductor, and they are told when a document of this bus is about to expire.',
            style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
          ),
          const SizedBox(height: 10),
          _crewDropdown(
            label: 'Usual driver',
            role: 'DRIVER',
            value: _driverId,
            onChanged: (v) {
              setState(() => _driverId = v == '' ? null : v);
              _saveCrew(driver: v == '' ? null : v, driverChanged: true);
            },
          ),
          const SizedBox(height: 10),
          _crewDropdown(
            label: 'Usual conductor',
            role: 'CONDUCTOR',
            value: _conductorId,
            onChanged: (v) {
              setState(() => _conductorId = v == '' ? null : v);
              _saveCrew(conductor: v == '' ? null : v, driverChanged: false);
            },
          ),
        ],
      ),
    );
  }

  Widget _addForm() {
    final types = ref.watch(busDocTypesProvider).asData?.value ?? const <BusDocTypeItem>[];
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7DD3FC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add a document', style: TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _docType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Document', isDense: true),
            items: [
              for (final t in types) DropdownMenuItem(value: t.key, child: Text(t.required ? '${t.label} *' : t.label)),
            ],
            onChanged: (v) => setState(() => _docType = v ?? _docType),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: _docType == 'OTHER' ? 'Document name *' : 'Document name (optional, to use your own)',
              isDense: true,
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(_validTill == null ? 'Valid till *' : 'Valid till ${_day(_validTill!)}'),
                onPressed: () async {
                  final date = await _pickDate(_validTill);
                  if (date != null) setState(() => _validTill = date);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Choose files'),
                onPressed: _busy ? null : _chooseFiles,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _remindCtrl,
            decoration: const InputDecoration(
              labelText: 'Remind me this many days before it expires',
              helperText: 'For example 30, 15, 7, 1. We also remind on the day and after it expires.',
              isDense: true,
            ),
          ),
          if (_picked.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final (i, file) in _picked.indexed)
              Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 16, color: AbraColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${file.name} (${_size(file.size)})', overflow: TextOverflow.ellipsis)),
                  IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _picked.removeAt(i)),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 4),
          const Text(
            'PDF, JPG or PNG, up to $_maxDocMb MB each, at most $_maxDocFiles files. * is needed before trips go on sale.',
            style: TextStyle(fontSize: 11, color: AbraColors.textSecondary),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: AbraColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload, size: 16),
            label: const Text('Upload'),
            style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
            onPressed: _busy ? null : _upload,
          ),
        ],
      ),
    );
  }

  Widget _validityChip(BusDocItem doc) {
    final (String text, Color fg, Color bg) = switch (doc.status) {
      'EXPIRED' => ('Expired on ${doc.validTill}', AbraColors.danger, AbraColors.dangerContainer),
      'EXPIRING' => (
          doc.daysLeft == 0
              ? 'Expires today'
              : 'Expires in ${doc.daysLeft} day${doc.daysLeft == 1 ? '' : 's'} (${doc.validTill})',
          AbraColors.orangeDark,
          AbraColors.orangeContainer,
        ),
      _ => ('Valid till ${doc.validTill}', AbraColors.tealDark, AbraColors.tealContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AbraRadius.pill)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _docCard(BusDocItem doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: AbraSpacing.md),
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AbraColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(doc.docName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              _validityChip(doc),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reminders: ${doc.remindDaysBefore.join(', ')} days before',
            style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final file in doc.files)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    file.mimeType == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                    size: 18,
                    color: AbraColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${file.name} (${_size(file.sizeBytes)})', overflow: TextOverflow.ellipsis)),
                  IconButton(
                    tooltip: 'View',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    onPressed: () => _open(doc, file, download: false),
                  ),
                  IconButton(
                    tooltip: 'Download',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    onPressed: () => _open(doc, file, download: true),
                  ),
                  if (doc.files.length > 1)
                    IconButton(
                      tooltip: 'Delete file',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18, color: AbraColors.danger),
                      onPressed: () => _delete(
                        'Delete ${file.name}?',
                        '$_base/${doc.id}/files/${file.id}',
                        ask: 'This file will be removed from the document.',
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Rename'),
                onPressed: () => _rename(doc),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add files'),
                onPressed: doc.files.length >= _maxDocFiles ? null : () => _addFiles(doc),
              ),
              TextButton.icon(
                icon: const Icon(Icons.event_outlined, size: 16),
                label: const Text('Change expiry date'),
                onPressed: () => _changeDate(doc),
              ),
              TextButton.icon(
                icon: const Icon(Icons.notifications_outlined, size: 16),
                label: const Text('Reminder days'),
                onPressed: () => _changeReminders(doc),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AbraColors.danger),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete document'),
                onPressed: () => _delete(
                  'Delete ${doc.docName}?',
                  '$_base/${doc.id}',
                  ask: 'The document and all its files will be removed.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
