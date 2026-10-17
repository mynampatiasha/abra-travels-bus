import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
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

// ===== 2. PROVIDERS =====

final clientCrewProvider = FutureProvider.autoDispose
    .family<(List<ClientCrewItem>, ClientCrewKpisData), (String, String, String)>((ref, args) async {
  final (roleFilter, statusFilter, search) = args;
  try {
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
    } catch (_) {}

    return (items, kpis);
  } catch (_) {
    return (<ClientCrewItem>[], ClientCrewKpisData());
  }
});

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
    buffer.writeln('Name,Phone,Role,Licence,Licence Expiry,Badge,Trips in 7 Days,Status');
    for (final c in items) {
      final name = c.name.replaceAll('"', '""');
      final phone = c.phone.replaceAll('"', '""');
      final role = c.role.replaceAll('"', '""');
      final lic = (c.licenseNumber ?? '').replaceAll('"', '""');
      final licExp = (c.licenseExpiryDate ?? '').replaceAll('"', '""');
      final badge = (c.badgeNumber ?? '').replaceAll('"', '""');
      final status = c.status.replaceAll('"', '""');
      buffer.writeln('"$name","$phone","$role","$lic","$licExp","$badge","${c.tripsCount7Days}","$status"');
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
          padding: const EdgeInsets.all(AbraSpacing.xxl),
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
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AbraColors.danger),
                        const SizedBox(height: 12),
                        Text('Error loading crew: $err', style: const TextStyle(color: AbraColors.danger)),
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
                      if (isNarrow)
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: PortalKpiCard(
                                    icon: Icons.people,
                                    value: '${kpis.totalDrivers}',
                                    label: 'Drivers',
                                    iconColor: AbraColors.blue,
                                  ),
                                ),
                                const SizedBox(width: AbraSpacing.md),
                                Expanded(
                                  child: PortalKpiCard(
                                    icon: Icons.check_circle_outline,
                                    value: '${kpis.totalActive}',
                                    label: 'Active',
                                    iconColor: AbraColors.teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AbraSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: PortalKpiCard(
                                    icon: Icons.pause_circle_outline,
                                    value: '${kpis.totalOnLeave}',
                                    label: 'On leave',
                                    iconColor: AbraColors.orange,
                                  ),
                                ),
                                const SizedBox(width: AbraSpacing.md),
                                Expanded(
                                  child: PortalKpiCard(
                                    icon: Icons.description_outlined,
                                    value: '${kpis.expiringLicences30Days}',
                                    label: 'Licences expiring in 30 days',
                                    iconColor: AbraColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: PortalKpiCard(
                                icon: Icons.people,
                                value: '${kpis.totalDrivers}',
                                label: 'Drivers',
                                iconColor: AbraColors.blue,
                              ),
                            ),
                            const SizedBox(width: AbraSpacing.md),
                            Expanded(
                              child: PortalKpiCard(
                                icon: Icons.check_circle_outline,
                                value: '${kpis.totalActive}',
                                label: 'Active',
                                iconColor: AbraColors.teal,
                              ),
                            ),
                            const SizedBox(width: AbraSpacing.md),
                            Expanded(
                              child: PortalKpiCard(
                                icon: Icons.pause_circle_outline,
                                value: '${kpis.totalOnLeave}',
                                label: 'On leave',
                                iconColor: AbraColors.orange,
                              ),
                            ),
                            const SizedBox(width: AbraSpacing.md),
                            Expanded(
                              child: PortalKpiCard(
                                icon: Icons.description_outlined,
                                value: '${kpis.expiringLicences30Days}',
                                label: 'Licences expiring in 30 days',
                                iconColor: AbraColors.danger,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: AbraSpacing.xl),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AbraRadius.lg),
                          border: Border.all(color: AbraColors.border),
                          boxShadow: AbraShadows.soft,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AbraSpacing.md),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: isNarrow ? double.infinity : 220,
                                    child: TextField(
                                      controller: _searchCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Search',
                                        hintText: 'Search',
                                        prefixIcon: const Icon(Icons.search, size: 18),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onSubmitted: (_) => setState(() {}),
                                    ),
                                  ),
                                  SizedBox(
                                    width: isNarrow ? double.infinity : 150,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _roleFilter,
                                      decoration: InputDecoration(
                                        labelText: 'Role',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
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
                                      initialValue: _statusFilter,
                                      decoration: InputDecoration(
                                        labelText: 'Status',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
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
                                    onPressed: () {
                                      setState(() {
                                        _searchCtrl.clear();
                                        _roleFilter = 'ALL';
                                        _statusFilter = 'ALL';
                                      });
                                    },
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
                                      ButtonSegment<bool>(
                                        value: true,
                                        icon: Icon(Icons.table_rows_outlined, size: 18),
                                        tooltip: 'Table',
                                      ),
                                      ButtonSegment<bool>(
                                        value: false,
                                        icon: Icon(Icons.view_agenda_outlined, size: 18),
                                        tooltip: 'List',
                                      ),
                                    ],
                                    selected: <bool>{_asTable},
                                    onSelectionChanged: (value) => setState(() => _asTable = value.first),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AbraColors.divider),
                            if (crewList.isEmpty)
                              Padding(
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
                              )
                            else if (_asTable)
                              SizedBox(
                                width: double.infinity,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                                    dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                                    columns: const [
                                      DataColumn(label: Text('Name')),
                                      DataColumn(label: Text('Role')),
                                      DataColumn(label: Text('Licence')),
                                      DataColumn(label: Text('Trips in 7 days')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: crewList.map((c) {
                                      final lic = c.licenseNumber ?? '-';
                                      final licExp = c.licenseExpiryDate ?? '';

                                      return DataRow(cells: [
                                        DataCell(Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            Text(c.phone, style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                                          ],
                                        )),
                                        DataCell(Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AbraColors.skyContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(c.role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AbraColors.deepBlue)),
                                        )),
                                        DataCell(Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(lic),
                                            if (c.isLicenceExpired)
                                              Text('EXPIRED ($licExp)', style: const TextStyle(fontSize: 10, color: AbraColors.danger, fontWeight: FontWeight.bold))
                                            else if (c.isLicenceExpiringSoon)
                                              Text('Expires soon: $licExp', style: const TextStyle(fontSize: 10, color: AbraColors.orangeDark, fontWeight: FontWeight.bold))
                                            else if (licExp.isNotEmpty)
                                              Text('till $licExp', style: const TextStyle(fontSize: 10, color: AbraColors.textSecondary)),
                                          ],
                                        )),
                                        DataCell(Text('${c.tripsCount7Days}')),
                                        DataCell(PortalStatusChip(status: c.status)),
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.visibility_outlined, size: 18),
                                              tooltip: 'View',
                                              onPressed: () => _showViewCrewDialog(context, c),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18),
                                              tooltip: 'Edit',
                                              onPressed: () => _showEditCrewDialog(context, c),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: AbraColors.danger),
                                              tooltip: 'Delete',
                                              onPressed: () => _confirmDeleteCrew(context, c),
                                            ),
                                          ],
                                        )),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
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
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AbraColors.skyContainer,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(c.role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AbraColors.deepBlue)),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  PortalStatusChip(status: c.status),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${c.phone} · Licence: $lic${licExp.isNotEmpty ? ' (till $licExp)' : ''} · Trips in 7 days: ${c.tripsCount7Days}',
                                                style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.visibility_outlined, size: 18),
                                              tooltip: 'View',
                                              onPressed: () => _showViewCrewDialog(context, c),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18),
                                              tooltip: 'Edit',
                                              onPressed: () => _showEditCrewDialog(context, c),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: AbraColors.danger),
                                              tooltip: 'Delete',
                                              onPressed: () => _confirmDeleteCrew(context, c),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
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
              if (c.badgeNumber != null && c.badgeNumber!.isNotEmpty)
                _detailRow('Badge number', c.badgeNumber!),
              _detailRow('Trips in 7 days', '${c.tripsCount7Days}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
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
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
            ),
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
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *', hintText: '+919876543210')),
                  const SizedBox(height: 12),
                  TextField(controller: licCtrl, decoration: const InputDecoration(labelText: 'Driving licence number', hintText: 'Drivers only')),
                  const SizedBox(height: 12),
                  TextField(controller: licExpCtrl, decoration: const InputDecoration(labelText: 'Licence valid till (YYYY-MM-DD)', hintText: '2026-12-31')),
                  const SizedBox(height: 12),
                  TextField(controller: badgeCtrl, decoration: const InputDecoration(labelText: 'Badge number', hintText: 'Optional')),
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
                  final body = <String, dynamic>{
                    'name': name,
                    'role': role,
                    'phone': phone,
                    'status': 'ACTIVE',
                  };
                  if (licCtrl.text.trim().isNotEmpty) {
                    body['licenseNumber'] = licCtrl.text.trim();
                  }
                  if (licExpCtrl.text.trim().isNotEmpty) {
                    body['licenseExpiryDate'] = licExpCtrl.text.trim();
                  }
                  if (badgeCtrl.text.trim().isNotEmpty) {
                    body['badgeNumber'] = badgeCtrl.text.trim();
                  }

                  await client.post('client/crew', body: body);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added')),
                    );
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add crew member: $err')),
                    );
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
                  TextField(controller: licCtrl, decoration: const InputDecoration(labelText: 'Driving licence number', hintText: 'Drivers only')),
                  const SizedBox(height: 12),
                  TextField(controller: licExpCtrl, decoration: const InputDecoration(labelText: 'Licence valid till (YYYY-MM-DD)')),
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
                  if (licExpCtrl.text.trim().isNotEmpty) {
                    body['licenseExpiryDate'] = licExpCtrl.text.trim();
                  }

                  await client.put('client/crew/${c.id}', body: body);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved')),
                    );
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update crew member: $err')),
                    );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted ${c.name}')),
                  );
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
