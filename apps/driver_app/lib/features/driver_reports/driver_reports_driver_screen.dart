import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/l10n/driver_strings.dart';

// ===== 1. CONTROLLER =====
class DriverReportsController {
  DriverReportsController(this.ref);
  final Ref ref;

  List<Map<String, dynamic>> get reports {
    final db = ref.watch(driverMockDbProvider);
    final driver = ref.watch(currentDriverProvider);
    return db.driverReports
        .where((r) => r['driver'] == driver)
        .toList()
        .cast<Map<String, dynamic>>();
  }

  void saveReport({
    required String typeId,
    required String typeName,
    required Map<String, dynamic> answers,
    required bool isSubmit,
    List<String> attachedFiles = const [],
  }) {
    final db = ref.read(driverMockDbProvider);
    final driver = ref.read(currentDriverProvider);
    db.driverReports.insert(0, {
      'id': 'DRP-${DateTime.now().millisecondsSinceEpoch}',
      'driver': driver,
      'typeId': typeId,
      'typeName': typeName,
      'period': DateTime.now().toIso8601String().substring(0, 10),
      'status': isSubmit ? 'SUBMITTED' : 'DRAFT',
      'submittedAt': isSubmit ? DateTime.now().toIso8601String() : null,
      'late': false,
      'reviewComment': '',
      'answers': answers,
      'attachedFiles': attachedFiles,
    });
  }
}

final driverReportsControllerProvider =
    Provider<DriverReportsController>((ref) => DriverReportsController(ref));

// ===== 2. REPORTS SCREEN =====
class DriverReportsScreen extends ConsumerWidget {
  const DriverReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(driverReportsControllerProvider);
    final lang = ref.watch(driverLanguageProvider);
    final allReports = controller.reports;

    final toSend = allReports
        .where((r) => ['DUE', 'OVERDUE', 'RETURNED', 'DRAFT'].contains(r['status'] as String))
        .toList();
    final sent = allReports
        .where((r) => ['SUBMITTED', 'APPROVED'].contains(r['status'] as String))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('tab_reports', lang), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('reports_intro', lang),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 18),

            // To Send Section
            Text(
              t('to_send', lang),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            if (toSend.isEmpty)
              Card(
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('You are all caught up! No reports due.',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ),
              )
            else
              for (final r in toSend) ...[
                _buildReportCard(context, ref, r, lang: lang, isPending: true),
                const SizedBox(height: 8),
              ],

            const SizedBox(height: 20),

            // Report Something Now
            Text(
              t('report_now', lang),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _eventButton(context, ref, lang, 'Incident Report', 'incident'),
                _eventButton(context, ref, lang, 'Bus Defect / Problem', 'defect'),
                _eventButton(context, ref, lang, 'Fuel & Expense Claim', 'expense'),
              ],
            ),

            const SizedBox(height: 24),

            // Sent History
            Text(
              t('sent_by_you', lang),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            if (sent.isEmpty)
              Card(
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('No submitted reports yet.', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ),
              )
            else
              for (final r in sent) ...[
                _buildReportCard(context, ref, r, lang: lang, isPending: false),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _eventButton(BuildContext context, WidgetRef ref, String lang, String title, String typeId) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1677C8),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      onPressed: () => _openReportForm(context, ref, typeId, title),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> r, {
    required String lang,
    required bool isPending,
  }) {
    final status = r['status'] as String;
    final isOverdue = status == 'OVERDUE' || status == 'RETURNED';

    Color chipBg;
    Color chipText;
    switch (status) {
      case 'APPROVED':
        chipBg = const Color(0xFFDCFCE7);
        chipText = const Color(0xFF166534);
        break;
      case 'SUBMITTED':
        chipBg = const Color(0xFFE0F2FE);
        chipText = const Color(0xFF0284C7);
        break;
      case 'RETURNED':
        chipBg = const Color(0xFFFEE2E2);
        chipText = const Color(0xFF991B1B);
        break;
      case 'OVERDUE':
        chipBg = const Color(0xFFFEE2E2);
        chipText = const Color(0xFFDC2626);
        break;
      default:
        chipBg = const Color(0xFFFEF3C7);
        chipText = const Color(0xFF92400E);
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              r['typeName'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(6)),
              child: Text(
                status,
                style: TextStyle(color: chipText, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Period: ${r['period']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            if ((r['attachedFiles'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.attach_file, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  '${(r['attachedFiles'] as List).length} file(s) attached',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ]),
            ],
            if (status == 'RETURNED' && (r['reviewComment'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Operator note: ${r['reviewComment']}',
                  style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        onTap: () {
          _openReportForm(context, ref, r['typeId'] as String, r['typeName'] as String, existing: r);
        },
      ),
    );
  }

  void _openReportForm(
    BuildContext context,
    WidgetRef ref,
    String typeId,
    String typeName, {
    Map<String, dynamic>? existing,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DriverReportFormScreen(
          typeId: typeId,
          typeName: typeName,
          existingReport: existing,
        ),
      ),
    );
  }
}

// ===== 3. REPORT FORM SCREEN (with real file_picker) =====
class DriverReportFormScreen extends ConsumerStatefulWidget {
  const DriverReportFormScreen({
    required this.typeId,
    required this.typeName,
    this.existingReport,
    super.key,
  });

  final String typeId;
  final String typeName;
  final Map<String, dynamic>? existingReport;

  @override
  ConsumerState<DriverReportFormScreen> createState() => _DriverReportFormScreenState();
}

class _DriverReportFormScreenState extends ConsumerState<DriverReportFormScreen> {
  final TextEditingController _fuelController = TextEditingController();
  final TextEditingController _tollController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _hasIncident = 'No';
  List<PlatformFile> _attachedFiles = [];
  bool _isPickingFile = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReport != null) {
      final a = widget.existingReport!['answers'] as Map<String, dynamic>? ?? {};
      _fuelController.text = (a['fuel_amt'] ?? '').toString();
      _tollController.text = (a['toll'] ?? '').toString();
      _notesController.text = (a['notes'] ?? '').toString();
      _hasIncident = (a['incident'] ?? 'No').toString();
    }
  }

  Future<void> _pickFiles() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'heic'],
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFiles = [..._attachedFiles, ...result.files];
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  void _removeFile(int index) {
    setState(() => _attachedFiles.removeAt(index));
  }

  void _submit(bool isFinal) {
    final lang = ref.read(driverLanguageProvider);

    if (isFinal && _fuelController.text.trim().isEmpty && widget.typeId == 'expense') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter fuel amount before submitting.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final answers = {
      'fuel_amt': _fuelController.text,
      'toll': _tollController.text,
      'incident': _hasIncident,
      'notes': _notesController.text,
    };

    final fileNames = _attachedFiles.map((f) => f.name).toList();

    ref.read(driverReportsControllerProvider).saveReport(
      typeId: widget.typeId,
      typeName: widget.typeName,
      answers: answers,
      isSubmit: isFinal,
      attachedFiles: fileNames,
    );

    Navigator.of(context).pop();
    final message = isFinal
        ? '${t('send_report', lang)} ✓ Sent to your company!'
        : '${t('save_draft', lang)} saved.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(driverLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.typeName, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── System computed card ──
            Card(
              color: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Numbers (Auto-calculated)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Total Distance: —\n• Total Driving Hours: —\n• Passengers Carried: —\n• Total Delays: —',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Form inputs ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fuel Expense (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fuelController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 8500',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Toll Charges (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tollController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 640',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Any Incidents or Delays?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('No'),
                          selected: _hasIncident == 'No',
                          selectedColor: const Color(0xFFDCFCE7),
                          onSelected: (_) => setState(() => _hasIncident = 'No'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Yes'),
                          selected: _hasIncident == 'Yes',
                          selectedColor: const Color(0xFFFEE2E2),
                          onSelected: (_) => setState(() => _hasIncident = 'Yes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text('Driver Notes / Comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Smooth highway driving, AC working well...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── File Attachment section ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attachments',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          '${_attachedFiles.length} file(s)',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Attach photos of receipts, fuel bills, or incident proof.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Attached file chips
                    if (_attachedFiles.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachedFiles.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final file = entry.value;
                          final isImage = ['jpg', 'jpeg', 'png', 'heic']
                              .contains(file.extension?.toLowerCase() ?? '');
                          return Chip(
                            avatar: Icon(
                              isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                              size: 16,
                              color: const Color(0xFF1677C8),
                            ),
                            label: Text(
                              file.name.length > 20 ? '${file.name.substring(0, 18)}…' : file.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeFile(idx),
                            backgroundColor: const Color(0xFFE0F2FE),
                            deleteIconColor: const Color(0xFF0284C7),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Pick file button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1677C8),
                        side: const BorderSide(color: Color(0xFF1677C8)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      icon: _isPickingFile
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file_rounded, size: 20),
                      label: Text(
                        _isPickingFile
                            ? 'Opening picker...'
                            : t('attach_receipt', lang),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: _isPickingFile ? null : _pickFiles,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _submit(false),
                    child: Text(t('save_draft', lang)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1677C8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _submit(true),
                    child: Text(t('send_report', lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
