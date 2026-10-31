import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import '../../app/providers.dart';
import '../../core/browser_files.dart';

// The buses a driver or conductor runs (the bus they usually drive, and the buses of their upcoming
// trips) and the documents of each: RC, insurance, permit, fitness... They can view and download them;
// only the owner changes them.

// ===== 1. MODELS =====

class DriverBusItem {
  DriverBusItem({
    required this.id,
    required this.registrationNumber,
    required this.name,
    required this.documentsExpiring,
    required this.documentsExpired,
  });

  final String id;
  final String registrationNumber;
  final String name;
  final int documentsExpiring;
  final int documentsExpired;

  factory DriverBusItem.fromJson(Map<String, dynamic> json) => DriverBusItem(
        id: json['id'] as String? ?? '',
        registrationNumber: json['registrationNumber'] as String? ?? '',
        name: json['name'] as String? ?? '',
        documentsExpiring: (json['documentsExpiring'] as num?)?.toInt() ?? 0,
        documentsExpired: (json['documentsExpired'] as num?)?.toInt() ?? 0,
      );
}

class DriverBusFile {
  DriverBusFile({required this.id, required this.name, required this.mimeType, required this.sizeBytes});

  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;
}

class DriverBusDocument {
  DriverBusDocument({
    required this.id,
    required this.docName,
    required this.validTill,
    required this.daysLeft,
    required this.status,
    required this.files,
  });

  final String id;
  final String docName;
  final String validTill;
  final int daysLeft;
  final String status;
  final List<DriverBusFile> files;

  factory DriverBusDocument.fromJson(Map<String, dynamic> json) => DriverBusDocument(
        id: json['id'] as String? ?? '',
        docName: json['docName'] as String? ?? '',
        validTill: json['validTill'] as String? ?? '',
        daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'VALID',
        files: [
          for (final raw in (json['files'] as List<dynamic>? ?? const <dynamic>[]))
            if (raw is Map<String, dynamic>)
              DriverBusFile(
                id: raw['id'] as String? ?? '',
                name: raw['originalName'] as String? ?? '',
                mimeType: raw['mimeType'] as String? ?? '',
                sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
              ),
        ],
      );
}

// ===== 2. PROVIDERS =====

final driverBusesProvider = FutureProvider.autoDispose<List<DriverBusItem>>((ref) async {
  final response = await ref.watch(driverApiClientProvider).get('driver/buses');
  final data = response.data;
  return [
    if (data is List)
      for (final raw in data)
        if (raw is Map<String, dynamic>) DriverBusItem.fromJson(raw),
  ];
});

final driverBusDocumentsProvider =
    FutureProvider.autoDispose.family<List<DriverBusDocument>, String>((ref, busId) async {
  final response = await ref.watch(driverApiClientProvider).get('driver/buses/$busId/documents');
  final data = response.data;
  return [
    if (data is List)
      for (final raw in data)
        if (raw is Map<String, dynamic>) DriverBusDocument.fromJson(raw),
  ];
});

/// What to tell the driver when a request fails: the server's own words for input problems.
String _errorText(Object error) {
  final failure = switch (error) {
    AppFailure() => error,
    AppException(:final failure) => failure,
    _ => UnexpectedFailure(error.runtimeType.toString()),
  };
  if (failure is ApiFailure && failure.message.isNotEmpty && failure.statusCode < 500) return failure.message;
  if (failure is NetworkFailure) return 'No connection. Check the internet and try again.';
  return 'Something went wrong. Please try again.';
}

String _size(int bytes) =>
    bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

({String text, Color color}) _chipOf(DriverBusDocument doc) => switch (doc.status) {
      'EXPIRED' => (text: 'Expired on ${doc.validTill}', color: const Color(0xFFDC2626)),
      'EXPIRING' => (
          text: doc.daysLeft == 0
              ? 'Expires today'
              : 'Expires in ${doc.daysLeft} day${doc.daysLeft == 1 ? '' : 's'} (${doc.validTill})',
          color: const Color(0xFFEA580C),
        ),
      _ => (text: 'Valid till ${doc.validTill}', color: const Color(0xFF0F766E)),
    };

// ===== 3. THE BUSES =====

/// "My buses": the buses this driver or conductor runs, with how many documents need attention.
class DriverBusesScreen extends ConsumerWidget {
  const DriverBusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buses = ref.watch(driverBusesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My buses', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(driverBusesProvider.future),
        child: buses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorView(
            title: 'Unable to load your buses',
            message: _errorText(err),
            onRetry: () => ref.invalidate(driverBusesProvider),
          ),
          data: (list) => list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.directions_bus_outlined, size: 56, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Center(child: Text('No bus yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'When your operator puts you on a bus or a trip, its documents show here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _busCard(context, list[index]),
                ),
        ),
      ),
    );
  }

  Widget _busCard(BuildContext context, DriverBusItem bus) {
    final warning = bus.documentsExpired > 0
        ? ('${bus.documentsExpired} document${bus.documentsExpired == 1 ? '' : 's'} expired', const Color(0xFFDC2626))
        : bus.documentsExpiring > 0
            ? ('${bus.documentsExpiring} document${bus.documentsExpiring == 1 ? '' : 's'} expiring soon', const Color(0xFFEA580C))
            : null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.directions_bus, color: Color(0xFF12304A)),
        title: Text(bus.registrationNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          warning == null ? bus.name : '${bus.name}\n${warning.$1}',
          style: TextStyle(color: warning?.$2),
        ),
        isThreeLine: warning != null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DriverBusDocumentsScreen(bus: bus)),
        ),
      ),
    );
  }
}

// ===== 4. THE DOCUMENTS OF ONE BUS =====

class DriverBusDocumentsScreen extends ConsumerWidget {
  const DriverBusDocumentsScreen({required this.bus, super.key});

  final DriverBusItem bus;

  String get _base => 'driver/buses/${bus.id}/documents';

  Future<void> _open(BuildContext context, WidgetRef ref, DriverBusDocument doc, DriverBusFile file, {required bool download}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final Uint8List bytes = await ref.read(driverApiClientProvider).getBytes('$_base/${doc.id}/files/${file.id}');
      if (!context.mounted) return;
      if (download) {
        downloadBytesFile(file.name, bytes, file.mimeType);
      } else if (file.mimeType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            child: Stack(
              children: [
                InteractiveViewer(child: Image.memory(bytes)),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ),
              ],
            ),
          ),
        );
      } else {
        openFileInBrowser(bytes, file.mimeType);
      }
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(err))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(driverBusDocumentsProvider(bus.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(bus.registrationNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(driverBusDocumentsProvider(bus.id).future),
        child: docs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorView(
            title: 'Unable to load the documents',
            message: _errorText(err),
            onRetry: () => ref.invalidate(driverBusDocumentsProvider(bus.id)),
          ),
          data: (list) => list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No documents yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Your operator has not added documents for this bus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [for (final doc in list) _docCard(context, ref, doc)],
                ),
        ),
      ),
    );
  }

  Widget _docCard(BuildContext context, WidgetRef ref, DriverBusDocument doc) {
    final chip = _chipOf(doc);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.docName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text(chip.text, style: TextStyle(color: chip.color, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            for (final file in doc.files)
              Row(
                children: [
                  Icon(
                    file.mimeType == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${file.name} (${_size(file.sizeBytes)})', overflow: TextOverflow.ellipsis)),
                  IconButton(
                    tooltip: 'View',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    onPressed: () => _open(context, ref, doc, file, download: false),
                  ),
                  IconButton(
                    tooltip: 'Download',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.download_outlined, size: 20),
                    onPressed: () => _open(context, ref, doc, file, download: true),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.title, required this.message, required this.onRetry});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
