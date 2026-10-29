
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/browser_files.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

// ===== 1. MODELS =====

class ClientCrewItem {
  ClientCrewItem({
    required this.id,
    required this.operatorId,
    required this.name,
    required this.role,
    required this.phone,
    this.licenseNumber,
    this.licenseExpiryDate,
    this.badgeNumber,
    required this.status,
    this.isLicenceExpired = false,
    this.isLicenceExpiringSoon = false,
    this.tripsCount7Days = 0,
    this.documentsCount = 0,
    this.documentsExpiring = 0,
    this.documentsExpired = 0,
    this.loginState = 'NONE',
  });

  final String id;
  final String operatorId;
  final String name;
  final String role;
  final String phone;
  final String? licenseNumber;
  final String? licenseExpiryDate;
  final String? badgeNumber;
  final String status;
  final bool isLicenceExpired;
  final bool isLicenceExpiringSoon;
  final int tripsCount7Days;
  final int documentsCount;
  final int documentsExpiring;
  final int documentsExpired;
  /// NONE, ACTIVE or DISABLED: the person's driver app login.
  final String loginState;

  factory ClientCrewItem.fromJson(Map<String, dynamic> json) {
    return ClientCrewItem(
      id: json['id'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'DRIVER',
      phone: json['phone'] as String? ?? '',
      licenseNumber: json['licenseNumber'] as String? ?? json['licence'] as String?,
      licenseExpiryDate: json['licenseExpiryDate'] as String? ?? json['licExp'] as String?,
      badgeNumber: json['badgeNumber'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      isLicenceExpired: json['isLicenceExpired'] as bool? ?? false,
      isLicenceExpiringSoon: json['isLicenceExpiringSoon'] as bool? ?? false,
      tripsCount7Days: (json['tripsCount7Days'] as num?)?.toInt() ?? 0,
      documentsCount: (json['documentsCount'] as num?)?.toInt() ?? 0,
      documentsExpiring: (json['documentsExpiring'] as num?)?.toInt() ?? 0,
      documentsExpired: (json['documentsExpired'] as num?)?.toInt() ?? 0,
      loginState: json['loginState'] as String? ?? 'NONE',
    );
  }
}

class ClientCrewKpisData {
  ClientCrewKpisData({
    this.totalDrivers = 0,
    this.totalActive = 0,
    this.totalOnLeave = 0,
    this.expiringLicences30Days = 0,
  });

  final int totalDrivers;
  final int totalActive;
  final int totalOnLeave;
  final int expiringLicences30Days;

  factory ClientCrewKpisData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClientCrewKpisData();
    return ClientCrewKpisData(
      totalDrivers: (json['totalDrivers'] as num?)?.toInt() ?? 0,
      totalActive: (json['totalActive'] as num?)?.toInt() ?? 0,
      totalOnLeave: (json['totalOnLeave'] as num?)?.toInt() ?? 0,
      expiringLicences30Days: (json['expiringLicences30Days'] as num?)?.toInt() ?? 0,
    );
  }
}

class CrewDocFileItem {
  CrewDocFileItem({required this.id, required this.name, required this.mimeType, required this.sizeBytes});

  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;

  factory CrewDocFileItem.fromJson(Map<String, dynamic> json) => CrewDocFileItem(
        id: json['id'] as String? ?? '',
        name: json['originalName'] as String? ?? 'file',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

class CrewDocItem {
  CrewDocItem({
    required this.id,
    required this.docType,
    required this.docName,
    this.validTill,
    this.daysLeft,
    required this.status,
    required this.files,
  });

  final String id;
  final String docType;
  final String docName;
  final String? validTill;
  final int? daysLeft;
  final String status;
  final List<CrewDocFileItem> files;

  factory CrewDocItem.fromJson(Map<String, dynamic> json) => CrewDocItem(
        id: json['id'] as String? ?? '',
        docType: json['docType'] as String? ?? 'OTHER',
        docName: json['docName'] as String? ?? '',
        validTill: json['validTill'] as String?,
        daysLeft: (json['daysLeft'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'NO_DATE',
        files: [
          for (final raw in (json['files'] as List<dynamic>? ?? const <dynamic>[]))
            if (raw is Map<String, dynamic>) CrewDocFileItem.fromJson(raw),
        ],
      );
}

class CrewImportSkipped {
  CrewImportSkipped({required this.row, required this.name, required this.phone, required this.reason});

  final int row;
  final String name;
  final String phone;
  final String reason;
}

class CrewImportSummary {
  CrewImportSummary({required this.total, required this.imported, required this.skipped, required this.rows});

  final int total;
  final int imported;
  final int skipped;
  final List<CrewImportSkipped> rows;

  factory CrewImportSummary.fromJson(Map<String, dynamic> json) => CrewImportSummary(
        total: (json['total'] as num?)?.toInt() ?? 0,
        imported: (json['imported'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        rows: [
          for (final raw in (json['skippedRows'] as List<dynamic>? ?? const <dynamic>[]))
            if (raw is Map<String, dynamic>)
              CrewImportSkipped(
                row: (raw['row'] as num?)?.toInt() ?? 0,
                name: raw['name'] as String? ?? '',
                phone: raw['phone'] as String? ?? '',
                reason: raw['reason'] as String? ?? '',
              ),
        ],
      );
}

/// The kinds of document an operator can pick; "Other" lets them type the name.
const _docTypes = <(String, String)>[
  ('DRIVING_LICENCE', 'Driving licence'),
  ('AADHAAR', 'Aadhaar'),
  ('PAN', 'PAN card'),
  ('MEDICAL_FITNESS', 'Medical fitness certificate'),
  ('POLICE_VERIFICATION', 'Police verification'),
  ('BADGE', 'Badge'),
  ('OTHER', 'Other (type the name)'),
];

const _maxDocFiles = 10;
const _maxDocMb = 5;

// ===== 2. PROVIDERS =====

final clientCrewProvider = FutureProvider.autoDispose
    .family<(List<ClientCrewItem>, ClientCrewKpisData), (String, String, String)>((ref, args) async {
  final (roleFilter, statusFilter, search) = args;
  final client = ref.watch(appDependenciesProvider).apiClient;
  final query = <String, dynamic>{'pageSize': 100};
  if (roleFilter != 'ALL') {
    query['role'] = roleFilter;
  }
  if (statusFilter != 'ALL') {
    query['status'] = statusFilter;
  }
  if (search.trim().isNotEmpty) {
    query['search'] = search.trim();
  }

  final response = await client.get('client/crew', query: query);
  final List<ClientCrewItem> items = [];
  if (response.data is List) {
    for (final raw in response.data as List) {
      if (raw is Map<String, dynamic>) {
        items.add(ClientCrewItem.fromJson(raw));
      }
    }
  } else if (response.data is Map && (response.data as Map)['items'] is List) {
    for (final raw in (response.data as Map)['items'] as List) {
      if (raw is Map<String, dynamic>) {
        items.add(ClientCrewItem.fromJson(raw));
      }
    }
  }

  var kpis = ClientCrewKpisData();
  try {
    final kpiRes = await client.get('client/crew/kpis');
    if (kpiRes.data is Map<String, dynamic>) {
      kpis = ClientCrewKpisData.fromJson(kpiRes.data as Map<String, dynamic>);
    }
  } catch (_) {
    // The cards stay at zero; the table itself is what matters
  }

  return (items, kpis);
});

final crewDocumentsProvider = FutureProvider.autoDispose.family<List<CrewDocItem>, String>((ref, crewId) async {
  final client = ref.watch(appDependenciesProvider).apiClient;
  final response = await client.get('client/crew/$crewId/documents');
  final data = response.data;
  return [
    if (data is List)
      for (final raw in data)
        if (raw is Map<String, dynamic>) CrewDocItem.fromJson(raw),
  ];
});

/// Sends a form with files. A file upload can be sent only once, so when the sign-in token had
/// run out (the client refreshes it and replays the same upload, which fails) the form is built
/// again and sent one more time.
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
  if (failure is ApiFailure && failure.message.isNotEmpty && failure.statusCode < 500) {
    return failure.message;
  }
  if (failure is NetworkFailure) return 'No connection. Check the internet and try again.';
  return 'Something went wrong. Please try again.';
}

String _day(DateTime date) => date.toIso8601String().substring(0, 10);

String _size(int bytes) =>
    bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

// ===== 3. MAIN SCREEN =====

class CrewClientManageScreen extends ConsumerStatefulWidget {
  const CrewClientManageScreen({super.key});

  @override
  ConsumerState<CrewClientManageScreen> createState() => _CrewClientManageScreenState();
}

class _CrewClientManageScreenState extends ConsumerState<CrewClientManageScreen> {
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';
  bool _asTable = true;
  final _searchCtrl = TextEditingController();

  (String, String, String) get _queryArgs => (_roleFilter, _statusFilter, _searchCtrl.text);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(clientCrewProvider(_queryArgs));
  }

  void _exportCsv(List<ClientCrewItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('Name,Phone,Role,Licence,Licence Expiry,Badge,Documents,Trips in 7 Days,Status');
    for (final c in items) {
      String q(String v) => '"${v.replaceAll('"', '""')}"';
      buffer.writeln([
        q(c.name),
        q(c.phone),
        q(c.role),
        q(c.licenseNumber ?? ''),
        q(c.licenseExpiryDate ?? ''),
        q(c.badgeNumber ?? ''),
        q('${c.documentsCount}'),
        q('${c.tripsCount7Days}'),
        q(c.status),
      ].join(','));
    }
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    downloadTextFile('crew_$stamp.csv', buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The file is ready.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crewAsync = ref.watch(clientCrewProvider(_queryArgs));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isNarrow ? AbraSpacing.lg : AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalSectionTitle(
                title: 'Drivers and crew',
                subtitle: 'Drivers sign in to the driver app with their phone number.',
                breadcrumbs: const ['Fleet', 'Drivers and crew'],
                actions: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add person'),
                    style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                    onPressed: () => _showAddCrewDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),
              crewAsync.when(
                loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AbraColors.danger),
                        const SizedBox(height: 12),
                        Text(_errorText(err), style: const TextStyle(color: AbraColors.danger)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _refresh, child: const Text('Retry')),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  final (crewList, kpis) = data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kpiCards(kpis, isNarrow),
                      const SizedBox(height: AbraSpacing.xl),
                      _tableCard(context, crewList, isNarrow),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kpiCards(ClientCrewKpisData kpis, bool isNarrow) {
    final cards = <Widget>[
      PortalKpiCard(icon: Icons.people, value: '${kpis.totalDrivers}', label: 'Drivers', iconColor: AbraColors.blue),
      PortalKpiCard(
        icon: Icons.check_circle_outline,
        value: '${kpis.totalActive}',
        label: 'Active',
        iconColor: AbraColors.teal,
      ),
      PortalKpiCard(
        icon: Icons.pause_circle_outline,
        value: '${kpis.totalOnLeave}',
        label: 'On leave',
        iconColor: AbraColors.orange,
      ),
      PortalKpiCard(
        icon: Icons.description_outlined,
        value: '${kpis.expiringLicences30Days}',
        label: 'Licences expiring in 30 days',
        iconColor: AbraColors.danger,
      ),
    ];
    if (isNarrow) {
      return Column(
        children: [
          Row(children: [Expanded(child: cards[0]), const SizedBox(width: AbraSpacing.md), Expanded(child: cards[1])]),
          const SizedBox(height: AbraSpacing.md),
          Row(children: [Expanded(child: cards[2]), const SizedBox(width: AbraSpacing.md), Expanded(child: cards[3])]),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: AbraSpacing.md),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _filterBar(List<ClientCrewItem> crewList, bool isNarrow) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        );
    return Padding(
      padding: const EdgeInsets.all(AbraSpacing.md),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isNarrow ? double.infinity : 240,
            child: TextField(
              controller: _searchCtrl,
              decoration: deco('Search').copyWith(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: isNarrow ? double.infinity : 150,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _roleFilter,
              decoration: deco('Role'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All')),
                DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
              ],
              onChanged: (val) => setState(() => _roleFilter = val ?? 'ALL'),
            ),
          ),
          SizedBox(
            width: isNarrow ? double.infinity : 150,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _statusFilter,
              decoration: deco('Status'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                DropdownMenuItem(value: 'ON_LEAVE', child: Text('On leave')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
              ],
              onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Clear'),
            onPressed: () => setState(() {
              _searchCtrl.clear();
              _roleFilter = 'ALL';
              _statusFilter = 'ALL';
            }),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: const Text('Import'),
            style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
            onPressed: () => _showImportDialog(context),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export CSV'),
            onPressed: () => _exportCsv(crewList),
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, icon: Icon(Icons.table_rows_outlined, size: 18), tooltip: 'Table'),
              ButtonSegment<bool>(value: false, icon: Icon(Icons.view_agenda_outlined, size: 18), tooltip: 'List'),
            ],
            selected: <bool>{_asTable},
            onSelectionChanged: (value) => setState(() => _asTable = value.first),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(BuildContext context, List<ClientCrewItem> crewList, bool isNarrow) {
    final noun = crewList.length == 1 ? 'person' : 'people';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filterBar(crewList, isNarrow),
          const Divider(height: 1, color: AbraColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg, vertical: AbraSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.list, size: 20, color: AbraColors.deepBlue),
                const SizedBox(width: 8),
                const Text(
                  'People list',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AbraColors.deepBlue),
                ),
                const Spacer(),
                Text(
                  '${crewList.length} $noun',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AbraColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AbraColors.divider, thickness: 2),
          if (crewList.isEmpty)
            _emptyState()
          else if (_asTable)
            _CrewGrid(
              rows: crewList,
              compact: isNarrow,
              height: (MediaQuery.sizeOf(context).height * 0.68).clamp(320.0, 900.0),
              onView: (c) => _showViewCrewDialog(context, c),
              onDocuments: (c) => _showDocumentsDialog(context, c),
              onLogin: (c) => _showLoginDialog(context, c),
              onEdit: (c) => _showEditCrewDialog(context, c),
              onDelete: (c) => _confirmDeleteCrew(context, c),
            )
          else
            _listView(context, crewList),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.people_outlined, size: 48, color: AbraColors.textDisabled),
            const SizedBox(height: 12),
            Text(
              _roleFilter != 'ALL' ? 'No crew matching this role' : 'No crew yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _roleFilter != 'ALL' ? 'Try selecting another role filter' : 'Add drivers so you can assign them to trips.',
              style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary),
            ),
            if (_roleFilter == 'ALL') ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add person'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: () => _showAddCrewDialog(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _listView(BuildContext context, List<ClientCrewItem> crewList) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: crewList.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AbraColors.divider),
      itemBuilder: (context, index) {
        final c = crewList[index];
        final lic = c.licenseNumber ?? '-';
        final licExp = c.licenseExpiryDate ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.md, vertical: AbraSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        _RoleChip(role: c.role),
                        PortalStatusChip(status: c.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.phone} · Licence: $lic${licExp.isNotEmpty ? ' (till $licExp)' : ''} · Documents: ${c.documentsCount} · Trips in 7 days: ${c.tripsCount7Days}',
                      style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _ActionButtons(
                onView: () => _showViewCrewDialog(context, c),
                onDocuments: () => _showDocumentsDialog(context, c),
                onLogin: () => _showLoginDialog(context, c),
                onEdit: () => _showEditCrewDialog(context, c),
                onDelete: () => _confirmDeleteCrew(context, c),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----- dialogs -----

  void _showLoginDialog(BuildContext context, ClientCrewItem c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CrewLoginDialog(crew: c),
    ).then((_) => _refresh());
  }

  void _showDocumentsDialog(BuildContext context, ClientCrewItem c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CrewDocumentsDialog(crew: c),
    ).then((_) => _refresh());
  }

  void _showImportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CrewImportDialog(onImported: _refresh),
    );
  }

  void _showViewCrewDialog(BuildContext context, ClientCrewItem c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.name),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Full name', c.name),
              _detailRow('Role', c.role),
              _detailRow('Phone', c.phone),
              _detailRow('Status', c.status),
              if (c.licenseNumber != null && c.licenseNumber!.isNotEmpty)
                _detailRow('Driving licence number', c.licenseNumber!),
              if (c.licenseExpiryDate != null && c.licenseExpiryDate!.isNotEmpty)
                _detailRow('Licence valid till', c.licenseExpiryDate!),
              if (c.badgeNumber != null && c.badgeNumber!.isNotEmpty) _detailRow('Badge number', c.badgeNumber!),
              _detailRow('Documents', '${c.documentsCount}'),
              _detailRow('Trips in 7 days', '${c.tripsCount7Days}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Documents'),
            onPressed: () {
              Navigator.pop(ctx);
              _showDocumentsDialog(context, c);
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
            onPressed: () {
              Navigator.pop(ctx);
              _showEditCrewDialog(context, c);
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteCrew(context, c);
            },
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label\n', style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary)),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AbraColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCrewDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final licCtrl = TextEditingController();
    final licExpCtrl = TextEditingController();
    final badgeCtrl = TextEditingController();
    String role = 'DRIVER';
    bool createLogin = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add person'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name *')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                      DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                      DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                    ],
                    onChanged: (v) => setDlgState(() => role = v ?? role),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone *', hintText: '+919876543210'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: licCtrl,
                    decoration: const InputDecoration(labelText: 'Driving licence number', hintText: 'Drivers only'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: licExpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Licence valid till (YYYY-MM-DD)',
                      hintText: '2026-12-31',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: badgeCtrl,
                    decoration: const InputDecoration(labelText: 'Badge number', hintText: 'Optional'),
                  ),
                  if (role == 'DRIVER' || role == 'CONDUCTOR') ...[
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Create the driver app login'),
                      subtitle: const Text(
                        'Signs in with the phone number and a temporary password shown once.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: createLogin,
                      onChanged: (v) => setDlgState(() => createLogin = v ?? false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'You can upload the licence and other documents after adding the person.',
                      style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                try {
                  final client = ref.read(appDependenciesProvider).apiClient;
                  final body = <String, dynamic>{'name': name, 'role': role, 'phone': phone, 'status': 'ACTIVE'};
                  if (licCtrl.text.trim().isNotEmpty) body['licenseNumber'] = licCtrl.text.trim();
                  if (licExpCtrl.text.trim().isNotEmpty) body['licenseExpiryDate'] = licExpCtrl.text.trim();
                  if (badgeCtrl.text.trim().isNotEmpty) body['badgeNumber'] = badgeCtrl.text.trim();

                  final created = await client.post('client/crew', body: body);
                  CrewCredentials? credentials;
                  String? loginProblem;
                  final createdData = created.data;
                  if (createLogin && (role == 'DRIVER' || role == 'CONDUCTOR') && createdData is Map) {
                    try {
                      final login = await client.post('client/crew/${createdData['id']}/login');
                      final loginData = login.data;
                      if (loginData is Map) credentials = CrewCredentials.fromJson(loginData);
                    } catch (err) {
                      loginProblem = _errorText(err);
                    }
                  }
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loginProblem == null ? 'Added' : 'Added, but the login was not created: $loginProblem',
                        ),
                      ),
                    );
                    if (credentials != null) {
                      await showCrewCredentials(context, name, credentials);
                    }
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(err))));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCrewDialog(BuildContext context, ClientCrewItem c) {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone);
    final licCtrl = TextEditingController(text: c.licenseNumber ?? '');
    final licExpCtrl = TextEditingController(text: c.licenseExpiryDate ?? '');
    final badgeCtrl = TextEditingController(text: c.badgeNumber ?? '');
    String status = c.status;
    String role = c.role;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Edit'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                      DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                      DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                    ],
                    onChanged: (v) => setDlgState(() => role = v ?? role),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: licCtrl,
                    decoration: const InputDecoration(labelText: 'Driving licence number', hintText: 'Drivers only'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: licExpCtrl,
                    decoration: const InputDecoration(labelText: 'Licence valid till (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: badgeCtrl, decoration: const InputDecoration(labelText: 'Badge number')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(value: 'ON_LEAVE', child: Text('On leave')),
                      DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                    ],
                    onChanged: (v) => setDlgState(() => status = v ?? status),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  final client = ref.read(appDependenciesProvider).apiClient;
                  final body = <String, dynamic>{
                    'name': nameCtrl.text.trim(),
                    'role': role,
                    'phone': phoneCtrl.text.trim(),
                    'status': status,
                    'licenseNumber': licCtrl.text.trim(),
                    'badgeNumber': badgeCtrl.text.trim(),
                  };
                  if (licExpCtrl.text.trim().isNotEmpty) body['licenseExpiryDate'] = licExpCtrl.text.trim();

                  await client.put('client/crew/${c.id}', body: body);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(err))));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCrew(BuildContext context, ClientCrewItem c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        content: const Text('This removes it from every list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () async {
              try {
                final client = ref.read(appDependenciesProvider).apiClient;
                await client.delete('client/crew/${c.id}');
                if (context.mounted) {
                  Navigator.pop(ctx);
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${c.name}')));
                }
              } catch (err) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot delete ${c.name}: likely assigned to upcoming trips'),
                      backgroundColor: AbraColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ===== 4. THE TABLE =====

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AbraColors.skyContainer, borderRadius: BorderRadius.circular(4)),
      child: Text(
        role,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AbraColors.deepBlue),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.tooltip, required this.fg, required this.bg, required this.onTap});

  final IconData icon;
  final String tooltip;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 16, color: fg)),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onView,
    required this.onDocuments,
    required this.onLogin,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onView;
  final VoidCallback onDocuments;
  final VoidCallback onLogin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconAction(
          icon: Icons.visibility_outlined,
          tooltip: 'View',
          fg: const Color(0xFF0284C7),
          bg: const Color(0xFFE0F2FE),
          onTap: onView,
        ),
        _IconAction(
          icon: Icons.folder_open_outlined,
          tooltip: 'Documents',
          fg: const Color(0xFF059669),
          bg: const Color(0xFFD1FAE5),
          onTap: onDocuments,
        ),
        _IconAction(
          icon: Icons.vpn_key_outlined,
          tooltip: 'Driver app login',
          fg: const Color(0xFFB45309),
          bg: const Color(0xFFFEF3C7),
          onTap: onLogin,
        ),
        _IconAction(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          fg: const Color(0xFF4F46E5),
          bg: const Color(0xFFE0E7FF),
          onTap: onEdit,
        ),
        _IconAction(
          icon: Icons.delete_outline,
          tooltip: 'Delete',
          fg: AbraColors.danger,
          bg: AbraColors.dangerContainer,
          onTap: onDelete,
        ),
      ],
    );
  }
}

/// The people table, in the style of the Candidate Tracking page: a blue header that stays on top
/// while the rows scroll, SI/NO and Name that stay on the left while the other columns scroll
/// sideways, and a mouse that can drag the table.
class _CrewGrid extends StatefulWidget {
  const _CrewGrid({
    required this.rows,
    required this.compact,
    required this.height,
    required this.onView,
    required this.onDocuments,
    required this.onLogin,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClientCrewItem> rows;
  final bool compact;
  final double height;
  final void Function(ClientCrewItem) onView;
  final void Function(ClientCrewItem) onDocuments;
  final void Function(ClientCrewItem) onLogin;
  final void Function(ClientCrewItem) onEdit;
  final void Function(ClientCrewItem) onDelete;

  @override
  State<_CrewGrid> createState() => _CrewGridState();
}

class _CrewGridState extends State<_CrewGrid> {
  static const _rowHeight = 60.0;
  static const _headHeight = 48.0;
  // Phone, Role, Licence, Licence valid till, Documents, Driver app, Trips in 7 days, Status, Actions
  static const _widths = <double>[150, 120, 180, 160, 170, 150, 120, 120, 240];
  static const _heads = <String>[
    'Phone',
    'Role',
    'Licence',
    'Licence valid till',
    'Documents',
    'Driver app',
    'Trips in 7 days',
    'Status',
    'Actions',
  ];

  final _left = ScrollController();
  final _right = ScrollController();
  final _across = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _left.addListener(() => _follow(_left, _right));
    _right.addListener(() => _follow(_right, _left));
  }

  void _follow(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if ((to.offset - target).abs() < 0.5) return;
    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    _across.dispose();
    super.dispose();
  }

  static const _headGradient = LinearGradient(colors: [AbraColors.deepBlue, AbraColors.blue]);

  Widget _head(String text, double width, {bool last = false, bool center = false}) {
    return Container(
      width: width,
      height: _headHeight,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: _headGradient,
        border: last ? null : const Border(right: BorderSide(color: Color(0x26FFFFFF))),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _cell(double width, Widget child, {Color? background}) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: child,
    );
  }

  Widget _loginCell(ClientCrewItem c) {
    if (c.role != 'DRIVER' && c.role != 'CONDUCTOR') {
      return const Text('-', style: TextStyle(fontSize: 13));
    }
    final (String text, Color fg, Color bg)? chip = switch (c.loginState) {
      'ACTIVE' => ('Login on', AbraColors.tealDark, AbraColors.tealContainer),
      'DISABLED' => ('Login off', AbraColors.danger, AbraColors.dangerContainer),
      _ => null,
    };
    if (chip == null) {
      return TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
        icon: const Icon(Icons.vpn_key_outlined, size: 16),
        label: const Text('Create'),
        onPressed: () => widget.onLogin(c),
      );
    }
    return InkWell(
      onTap: () => widget.onLogin(c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: chip.$3, borderRadius: BorderRadius.circular(AbraRadius.pill)),
        child: Text(chip.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: chip.$2)),
      ),
    );
  }

  Widget _documentsCell(ClientCrewItem c) {
    if (c.documentsCount == 0) {
      return TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
        icon: const Icon(Icons.upload_file, size: 16),
        label: const Text('Add'),
        onPressed: () => widget.onDocuments(c),
      );
    }
    final warn = c.documentsExpired > 0
        ? ('${c.documentsExpired} expired', AbraColors.danger)
        : c.documentsExpiring > 0
            ? ('${c.documentsExpiring} expiring', AbraColors.orangeDark)
            : null;
    return InkWell(
      onTap: () => widget.onDocuments(c),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c.documentsCount} document${c.documentsCount == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AbraColors.blue),
          ),
          if (warn != null)
            Text(warn.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: warn.$2)),
        ],
      ),
    );
  }

  Widget _licenceDateCell(ClientCrewItem c) {
    final date = c.licenseExpiryDate ?? '';
    if (date.isEmpty) return const Text('-', style: TextStyle(fontSize: 13));
    final color = c.isLicenceExpired
        ? AbraColors.danger
        : c.isLicenceExpiringSoon
            ? AbraColors.orangeDark
            : AbraColors.textPrimary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        if (c.isLicenceExpired)
          const Text('Expired', style: TextStyle(fontSize: 11, color: AbraColors.danger, fontWeight: FontWeight.bold))
        else if (c.isLicenceExpiringSoon)
          const Text(
            'Expires soon',
            style: TextStyle(fontSize: 11, color: AbraColors.orangeDark, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  List<Widget> _rightCells(ClientCrewItem c, List<double> w) {
    return [
      _cell(w[0], Text(c.phone, style: const TextStyle(fontSize: 13))),
      _cell(w[1], _RoleChip(role: c.role)),
      _cell(
        w[2],
        Text(
          c.licenseNumber?.isNotEmpty == true ? c.licenseNumber! : '-',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
      _cell(w[3], _licenceDateCell(c)),
      _cell(w[4], _documentsCell(c)),
      _cell(w[5], _loginCell(c)),
      _cell(w[6], Text('${c.tripsCount7Days}', style: const TextStyle(fontSize: 13))),
      _cell(w[7], PortalStatusChip(status: c.status)),
      _cell(
        w[8],
        _ActionButtons(
          onView: () => widget.onView(c),
          onDocuments: () => widget.onDocuments(c),
          onLogin: () => widget.onLogin(c),
          onEdit: () => widget.onEdit(c),
          onDelete: () => widget.onDelete(c),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final slWidth = widget.compact ? 44.0 : 56.0;
    final nameWidth = widget.compact ? 140.0 : 200.0;
    final frozenWidth = slWidth + nameWidth;
    final contentHeight = _headHeight + widget.rows.length * _rowHeight;
    final height = contentHeight < widget.height ? contentHeight + 14 : widget.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final base = _widths.fold<double>(0, (a, b) => a + b);
        final room = constraints.maxWidth - frozenWidth;
        // Wider than the columns need: spread the extra room so the table fills the screen
        final scale = room > base ? room / base : 1.0;
        final widths = [for (final w in _widths) w * scale];
        final rightWidth = widths.fold<double>(0, (a, b) => a + b);

        final behavior = ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
        );

        return SizedBox(
          height: height,
          child: ScrollConfiguration(
            behavior: behavior,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Scrollbar(
                    controller: _across,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _across,
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: EdgeInsets.only(left: frozenWidth),
                        child: SizedBox(
                          width: rightWidth,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  for (var i = 0; i < _heads.length; i++)
                                    _head(_heads[i], widths[i], last: i == _heads.length - 1),
                                ],
                              ),
                              Expanded(
                                child: ListView.builder(
                                  controller: _right,
                                  padding: const EdgeInsets.only(bottom: 14),
                                  itemExtent: _rowHeight,
                                  itemCount: widget.rows.length,
                                  itemBuilder: (context, i) => Row(children: _rightCells(widget.rows[i], widths)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // SI/NO and Name stay fixed on the left
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: frozenWidth,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(2, 0))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _head('SI/NO', slWidth, center: true),
                            _head('Name', nameWidth, last: true),
                          ],
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _left,
                            padding: const EdgeInsets.only(bottom: 14),
                            itemExtent: _rowHeight,
                            itemCount: widget.rows.length,
                            itemBuilder: (context, i) {
                              final c = widget.rows[i];
                              return Row(
                                children: [
                                  _cell(
                                    slWidth,
                                    Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AbraColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _cell(
                                    nameWidth,
                                    Text(
                                      c.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AbraColors.deepBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===== 5. DOCUMENTS =====

class _CrewDocumentsDialog extends ConsumerStatefulWidget {
  const _CrewDocumentsDialog({required this.crew});

  final ClientCrewItem crew;

  @override
  ConsumerState<_CrewDocumentsDialog> createState() => _CrewDocumentsDialogState();
}

class _CrewDocumentsDialogState extends ConsumerState<_CrewDocumentsDialog> {
  String _docType = 'DRIVING_LICENCE';
  final _nameCtrl = TextEditingController();
  DateTime? _validTill;
  final List<PlatformFile> _picked = [];
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _base => 'client/crew/${widget.crew.id}/documents';

  void _reload() => ref.invalidate(crewDocumentsProvider(widget.crew.id));

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _allowed(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  /// Checks files before they are sent; returns what is wrong, or null.
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

  Future<void> _pickDate({DateTime? initial, required void Function(DateTime) onPicked}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
    );
    if (date != null) onPicked(date);
  }

  List<MultipartFile> _parts(List<PlatformFile> files) => [
        for (final file in files) MultipartFile.fromBytes(file.bytes!, filename: file.name),
      ];

  Future<void> _upload() async {
    if (_docType == 'OTHER' && _nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Type the name of the document.');
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
          if (_docType == 'OTHER') 'docName': _nameCtrl.text.trim(),
          if (_validTill != null) 'validTill': _day(_validTill!),
          'files': _parts(_picked),
        }),
      );
      if (!mounted) return;
      setState(() {
        _picked.clear();
        _validTill = null;
        _nameCtrl.clear();
        _docType = 'DRIVING_LICENCE';
      });
      _reload();
      _toast('Document added');
    } catch (err) {
      if (mounted) setState(() => _error = _errorText(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFiles(CrewDocItem doc) async {
    final files = await _pick();
    if (files.isEmpty) return;
    final problem = _check(files, doc.files.length);
    if (problem != null) {
      _toast(problem);
      return;
    }
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await _uploadForm(
        client,
        '$_base/${doc.id}/files',
        () => FormData.fromMap(<String, Object?>{'files': _parts(files)}),
      );
      _reload();
      _toast('Files added');
    } catch (err) {
      _toast(_errorText(err));
    }
  }

  Future<void> _setValidity(CrewDocItem doc, DateTime? date) async {
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      await client.patch('$_base/${doc.id}', body: <String, Object?>{'validTill': date == null ? null : _day(date)});
      _reload();
      _toast(date == null ? 'Validity date removed' : 'Validity date saved');
    } catch (err) {
      _toast(_errorText(err));
    }
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

  Future<void> _open(CrewDocItem doc, CrewDocFileItem file, {required bool download}) async {
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      final Uint8List bytes = await client.getBytes('$_base/${doc.id}/files/${file.id}');
      if (download) {
        downloadBytesFile(file.name, bytes, file.mimeType);
      } else {
        openFileInBrowser(bytes, file.mimeType);
      }
    } catch (err) {
      _toast(_errorText(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(crewDocumentsProvider(widget.crew.id));
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: Text('Documents - ${widget.crew.name}'),
      content: SizedBox(
        width: width < 640 ? width - 80 : 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _addForm(),
              const SizedBox(height: AbraSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AbraSpacing.md),
              docs.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
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
                            'No documents yet. Add the licence and other papers above.',
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

  Widget _addForm() {
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
            items: [for (final t in _docTypes) DropdownMenuItem(value: t.$1, child: Text(t.$2))],
            onChanged: (v) => setState(() => _docType = v ?? _docType),
          ),
          if (_docType == 'OTHER') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Document name *', isDense: true, counterText: ''),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(_validTill == null ? 'Valid till (optional)' : 'Valid till ${_day(_validTill!)}'),
                onPressed: () => _pickDate(initial: _validTill, onPicked: (d) => setState(() => _validTill = d)),
              ),
              if (_validTill != null)
                IconButton(
                  tooltip: 'No validity date',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _validTill = null),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Choose files'),
                onPressed: _busy ? null : _chooseFiles,
              ),
            ],
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
            'PDF, JPG or PNG, up to $_maxDocMb MB each, at most $_maxDocFiles files.',
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

  Widget _validityChip(CrewDocItem doc) {
    final (String text, Color fg, Color bg) = switch (doc.status) {
      'EXPIRED' => ('Expired on ${doc.validTill}', AbraColors.danger, AbraColors.dangerContainer),
      'EXPIRING' => (
          doc.daysLeft == 0
              ? 'Expires today'
              : 'Expires in ${doc.daysLeft} day${doc.daysLeft == 1 ? '' : 's'} (${doc.validTill})',
          AbraColors.orangeDark,
          AbraColors.orangeContainer,
        ),
      'VALID' => ('Valid till ${doc.validTill}', AbraColors.tealDark, AbraColors.tealContainer),
      _ => ('No expiry date', AbraColors.textSecondary, AbraColors.lightGray),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AbraRadius.pill)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _docCard(CrewDocItem doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: AbraSpacing.md),
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AbraColors.border),
      ),
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
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add files'),
                onPressed: doc.files.length >= _maxDocFiles ? null : () => _addFiles(doc),
              ),
              TextButton.icon(
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(doc.validTill == null ? 'Set validity date' : 'Change validity date'),
                onPressed: () => _pickDate(
                  initial: doc.validTill == null ? null : DateTime.tryParse(doc.validTill!),
                  onPicked: (d) => _setValidity(doc, d),
                ),
              ),
              if (doc.validTill != null)
                TextButton(onPressed: () => _setValidity(doc, null), child: const Text('Remove date')),
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

// ===== 6. IMPORT =====

class _CrewImportDialog extends ConsumerStatefulWidget {
  const _CrewImportDialog({required this.onImported});

  final VoidCallback onImported;

  @override
  ConsumerState<_CrewImportDialog> createState() => _CrewImportDialogState();
}

class _CrewImportDialogState extends ConsumerState<_CrewImportDialog> {
  PlatformFile? _file;
  String? _error;
  bool _busy = false;
  CrewImportSummary? _summary;

  Future<void> _downloadSample() async {
    try {
      final bytes = await ref.read(appDependenciesProvider).apiClient.getBytes('client/crew/import/sample');
      downloadBytesFile('Crew_Import_Sample.csv', bytes, 'text/csv');
    } catch (err) {
      if (mounted) setState(() => _error = _errorText(err));
    }
  }

  Future<void> _choose() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    setState(() {
      _file = file;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null) {
      setState(() => _error = 'Choose the filled CSV file first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _uploadForm(
        ref.read(appDependenciesProvider).apiClient,
        'client/crew/import',
        () => FormData.fromMap(<String, Object?>{
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        }),
      );
      final data = response.data;
      if (!mounted) return;
      setState(() {
        _summary = CrewImportSummary.fromJson(data is Map<String, dynamic> ? data : <String, dynamic>{});
      });
      widget.onImported();
    } catch (err) {
      if (mounted) setState(() => _error = _errorText(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return AlertDialog(
      title: Text(summary == null ? 'Import people from CSV' : 'Import summary'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(child: summary == null ? _form() : _result(summary)),
      ),
      actions: summary == null
          ? [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton.icon(
                icon: _busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload, size: 16),
                label: const Text('Import now'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: _busy ? null : _submit,
              ),
            ]
          : [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AbraSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF7DD3FC)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 12,
            children: [
              const SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1: Download the sample CSV',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'It has the column names and a few example rows. Fill in your people and save it as CSV.',
                      style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download sample CSV'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: _downloadSample,
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        Container(
          padding: const EdgeInsets.all(AbraSpacing.md),
          decoration: BoxDecoration(
            color: AbraColors.lightGray,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AbraColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Columns', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              SizedBox(height: 6),
              Text(
                'Required: Name, Phone.\n'
                'Optional: Role (DRIVER, CONDUCTOR or MANAGER; empty means DRIVER), Licence Number, '
                'Licence Valid Till (YYYY-MM-DD), Badge Number, Status (ACTIVE, ON_LEAVE or INACTIVE).\n'
                'A phone number that already exists is skipped and listed in the summary. At most 500 people per file. '
                'Documents are added afterwards, from each person.',
                style: TextStyle(fontSize: 12, color: AbraColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.md),
        const Text('Step 2: Choose the filled CSV file', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Choose file'),
              onPressed: _busy ? null : _choose,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _file == null ? 'No file chosen. Only .csv files.' : _file!.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AbraColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AbraColors.danger, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _count(String label, int value, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            const SizedBox(height: 4),
            Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _result(CrewImportSummary summary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _count('Total processed', summary.total, AbraColors.navy, AbraColors.lightGray),
            const SizedBox(width: 10),
            _count('Imported', summary.imported, AbraColors.tealDark, AbraColors.tealContainer),
            const SizedBox(width: 10),
            _count('Skipped', summary.skipped, AbraColors.danger, AbraColors.dangerContainer),
          ],
        ),
        if (summary.rows.isNotEmpty) ...[
          const SizedBox(height: AbraSpacing.md),
          Text(
            'Rejected rows (${summary.rows.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.danger),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 44,
              headingRowColor: const WidgetStatePropertyAll(AbraColors.dangerContainer),
              columns: const [
                DataColumn(label: Text('Row')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Reason')),
              ],
              rows: [
                for (final r in summary.rows)
                  DataRow(cells: [
                    DataCell(Text('${r.row}')),
                    DataCell(Text(r.name.isEmpty ? '-' : r.name)),
                    DataCell(Text(r.phone.isEmpty ? '-' : r.phone)),
                    DataCell(Text(r.reason)),
                  ]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ===== 7. DRIVER APP LOGIN =====

class CrewCredentials {
  CrewCredentials({required this.username, required this.temporaryPassword});

  final String username;
  final String temporaryPassword;

  factory CrewCredentials.fromJson(Map<dynamic, dynamic> json) => CrewCredentials(
        username: '${json['username'] ?? ''}',
        temporaryPassword: '${json['temporaryPassword'] ?? ''}',
      );
}

/// The WhatsApp chat with the driver, with the login details already written. The operator
/// presses send; nothing is sent by the system.
String whatsAppShareAddress(String name, CrewCredentials credentials) {
  final number = credentials.username.replaceAll(RegExp(r'\D'), '');
  final text = 'Hello $name, your Abra Driver app login is ready.\n'
      'Phone number: ${credentials.username}\n'
      'Temporary password: ${credentials.temporaryPassword}\n'
      'Sign in to the Abra Driver app with these, then choose your own password.';
  return 'https://wa.me/$number?text=${Uri.encodeComponent(text)}';
}

/// The phone number and the temporary password, shown once, with a button to copy each.
Future<void> showCrewCredentials(BuildContext context, String name, CrewCredentials credentials) {
  Widget line(BuildContext ctx, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary)),
                  SelectableText(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$label copied')));
                }
              },
            ),
          ],
        ),
      );
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('Driver app login - $name'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(ctx, 'Phone number (username)', credentials.username),
            line(ctx, 'Temporary password', credentials.temporaryPassword),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AbraColors.orangeContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This password is shown only now. Give it to the driver; they choose their own '
                'password the first time they sign in to the driver app. If it is lost, use '
                '"Reset password" to make a new one.',
                style: TextStyle(fontSize: 12, color: AbraColors.orangeDark),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.chat_outlined, size: 16),
          label: const Text('Share on WhatsApp'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF128C7E)),
          onPressed: () => openWebAddress(whatsAppShareAddress(name, credentials)),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
      ],
    ),
  );
}

class _CrewLoginDialog extends ConsumerStatefulWidget {
  const _CrewLoginDialog({required this.crew});

  final ClientCrewItem crew;

  @override
  ConsumerState<_CrewLoginDialog> createState() => _CrewLoginDialogState();
}

class _CrewLoginDialogState extends ConsumerState<_CrewLoginDialog> {
  late String _state = widget.crew.loginState;
  bool _busy = false;
  String? _error;

  String get _base => 'client/crew/${widget.crew.id}/login';

  bool get _canHaveLogin => widget.crew.role == 'DRIVER' || widget.crew.role == 'CONDUCTOR';

  Future<void> _run(String path, {required String nextState, bool showPassword = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref.read(appDependenciesProvider).apiClient.post(path);
      if (!mounted) return;
      setState(() => _state = nextState);
      final data = response.data;
      if (showPassword && data is Map) {
        await showCrewCredentials(context, widget.crew.name, CrewCredentials.fromJson(data));
      }
    } catch (err) {
      if (mounted) setState(() => _error = _errorText(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (String text, Color fg, Color bg) = switch (_state) {
      'ACTIVE' => ('Login is on', AbraColors.tealDark, AbraColors.tealContainer),
      'DISABLED' => ('Login is off', AbraColors.danger, AbraColors.dangerContainer),
      _ => ('No login yet', AbraColors.textSecondary, AbraColors.lightGray),
    };
    return AlertDialog(
      title: Text('Driver app login - ${widget.crew.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone number (username): ${widget.crew.phone}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AbraRadius.pill)),
              child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
            ),
            const SizedBox(height: 12),
            if (!_canHaveLogin)
              const Text(
                'Only drivers and conductors sign in to the driver app.',
                style: TextStyle(color: AbraColors.textSecondary),
              )
            else
              const Text(
                'The driver signs in to the driver app with the phone number and a temporary '
                'password, then chooses their own password.',
                style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AbraColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (_canHaveLogin && _state == 'NONE')
          FilledButton.icon(
            icon: const Icon(Icons.vpn_key_outlined, size: 16),
            label: const Text('Create login'),
            style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
            onPressed: _busy ? null : () => _run(_base, nextState: 'ACTIVE', showPassword: true),
          ),
        if (_canHaveLogin && _state != 'NONE') ...[
          OutlinedButton(
            onPressed: _busy ? null : () => _run('$_base/reset-password', nextState: _state, showPassword: true),
            child: const Text('Reset password'),
          ),
          if (_state == 'ACTIVE')
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AbraColors.danger),
              onPressed: _busy ? null : () => _run('$_base/disable', nextState: 'DISABLED'),
              child: const Text('Switch off'),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
              onPressed: _busy ? null : () => _run('$_base/enable', nextState: 'ACTIVE'),
              child: const Text('Switch on'),
            ),
        ],
      ],
    );
  }
}
