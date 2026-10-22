import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/csv.dart';
import '../../l10n/admin_strings.dart';
import '../catalogue/catalogue_repository.dart';
import '../catalogue/widgets/catalogue_common.dart';
import '../catalogue/widgets/resource_form.dart';
import '../catalogue/widgets/server_import_dialog.dart';

// ===== 1. MODELS & STATE =====

enum BusesViewMode { table, list }

class AdminBusesFilterState {
  const AdminBusesFilterState({
    this.search = '',
    this.status = '',
    this.operatorId = '',
    this.busTypeId = '',
    this.documents = '',
    this.page = 1,
    this.pageSize = 20,
    this.viewMode = BusesViewMode.table,
  });

  final String search;
  final String status;
  final String operatorId;
  final String busTypeId;
  final String documents;
  final int page;
  final int pageSize;
  final BusesViewMode viewMode;

  AdminBusesFilterState copyWith({
    String? search,
    String? status,
    String? operatorId,
    String? busTypeId,
    String? documents,
    int? page,
    int? pageSize,
    BusesViewMode? viewMode,
  }) {
    return AdminBusesFilterState(
      search: search ?? this.search,
      status: status ?? this.status,
      operatorId: operatorId ?? this.operatorId,
      busTypeId: busTypeId ?? this.busTypeId,
      documents: documents ?? this.documents,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

class AdminBusesFilterNotifier extends Notifier<AdminBusesFilterState> {
  @override
  AdminBusesFilterState build() => const AdminBusesFilterState();

  void setSearch(String v) => state = state.copyWith(search: v, page: 1);
  void setStatus(String v) => state = state.copyWith(status: v, page: 1);
  void setOperator(String v) => state = state.copyWith(operatorId: v, page: 1);
  void setBusType(String v) => state = state.copyWith(busTypeId: v, page: 1);
  void setDocuments(String v) => state = state.copyWith(documents: v, page: 1);
  void setPage(int p) => state = state.copyWith(page: p);
  void setViewMode(BusesViewMode m) => state = state.copyWith(viewMode: m);
  void reset() => state = const AdminBusesFilterState();
}

final adminBusesFilterProvider =
    NotifierProvider<AdminBusesFilterNotifier, AdminBusesFilterState>(
  AdminBusesFilterNotifier.new,
);

final adminBusesListProvider = FutureProvider.autoDispose<PageOf>((ref) async {
  final repo = ref.watch(catalogueRepositoryProvider);
  final filter = ref.watch(adminBusesFilterProvider);

  final filters = <String, String>{};
  if (filter.search.isNotEmpty) filters['search'] = filter.search;
  if (filter.status.isNotEmpty && filter.status != 'ALL') filters['status'] = filter.status;
  if (filter.operatorId.isNotEmpty && filter.operatorId != 'ALL') filters['operatorId'] = filter.operatorId;
  if (filter.busTypeId.isNotEmpty && filter.busTypeId != 'ALL') filters['busTypeId'] = filter.busTypeId;
  if (filter.documents == 'EXPIRED') {
    filters['expiredDocuments'] = 'true';
  }

  return repo.list(
    ResourceQuery(
      'buses',
      page: filter.page,
      pageSize: filter.pageSize,
      filters: filters,
    ),
  );
});

final adminOperatorsOptionsProvider =
    FutureProvider.autoDispose<List<JsonMap>>((ref) async {
  final repo = ref.watch(catalogueRepositoryProvider);
  try {
    final page = await repo.list(const ResourceQuery('operators', pageSize: 100));
    return page.items;
  } catch (_) {
    return <JsonMap>[];
  }
});

final adminBusTypesOptionsProvider =
    FutureProvider.autoDispose<List<JsonMap>>((ref) async {
  final repo = ref.watch(catalogueRepositoryProvider);
  try {
    final page = await repo.list(const ResourceQuery('bus-types', pageSize: 100));
    return page.items;
  } catch (_) {
    return <JsonMap>[];
  }
});

// ===== 2. MAIN ADMIN BUSES SCREEN =====

class BusesAdminManageScreen extends ConsumerStatefulWidget {
  const BusesAdminManageScreen({super.key});

  @override
  ConsumerState<BusesAdminManageScreen> createState() =>
      _BusesAdminManageScreenState();
}

class _BusesAdminManageScreenState
    extends ConsumerState<BusesAdminManageScreen> {
  final Set<String> _selectedBusIds = <String>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<JsonMap> items) {
    if (items.isEmpty) return;
    final header = <String>[
      'Registration',
      'Name',
      'Operator',
      'Type',
      'Seats',
      'Layout',
      'Insurance Expiry',
      'Status',
    ];
    final rows = items.map((r) => <Object?>[
      r['registrationNumber'] ?? '',
      r['name'] ?? '',
      r['operatorName'] ?? r['operatorId'] ?? '',
      r['busTypeName'] ?? r['busTypeId'] ?? '',
      r['seatCapacity'] ?? 0,
      r['seatLayoutType'] ?? '',
      r['insuranceExpiryDate'] ?? '',
      r['status'] ?? '',
    ]);
    final csvData = Csv.encode(header, rows);
    downloadTextFile('buses_export.csv', csvData);
  }

  Future<void> _handleBulkMaintenance(BuildContext context) async {
    if (_selectedBusIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final reasonController = TextEditingController(text: 'Scheduled fleet maintenance');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move ${_selectedBusIds.length} buses to Maintenance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected buses will be unavailable for new trip allocations.',
              style: TextStyle(color: AbraColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Maintenance Reason*',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Maintenance'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final client = ref.read(appDependenciesProvider).apiClient;
        await client.post(
          'catalogue/buses/bulk-maintenance',
          body: <String, dynamic>{
            'busIds': _selectedBusIds.toList(),
            'reason': reasonController.text.trim(),
          },
        );
        setState(() => _selectedBusIds.clear());
        ref.invalidate(adminBusesListProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('Buses moved to maintenance status.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Bulk maintenance failed: $e')),
        );
      }
    }
  }

  void _showBusDetailsModal(BuildContext context, JsonMap bus) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _BusDetailsDialog(bus: bus),
    );
  }

  static const _editFields = <FieldSpec>[
    TextSpec('name', AdminStrings.fieldName, isRequired: true),
    RefSpec(
      'busTypeId',
      AdminStrings.fieldBusType,
      'bus-types?active=true',
      nameOf,
      isRequired: true,
    ),
    NumberSpec(
      'seatCapacity',
      AdminStrings.fieldSeatCapacity,
      isRequired: true,
    ),
    MultiChoiceSpec(
      'amenities',
      AdminStrings.fieldAmenities,
      CatalogueLabels.amenities,
      CatalogueLabels.readable,
      choicesPath: 'amenities',
    ),
  ];

  void _showAddBusModal(BuildContext context, bool isPlatform) {
    final l10n = AbraLocalizations.of(context);
    final repository = ref.read(catalogueRepositoryProvider);
    showResourceForm(
      context,
      title: l10n.text(AdminStrings.busCreateTitle),
      fields: <FieldSpec>[
        if (isPlatform)
          const RefSpec(
            'operatorId',
            AdminStrings.fieldOperator,
            'operators',
            operatorNameOf,
            isRequired: true,
          ),
        const TextSpec(
          'registrationNumber',
          AdminStrings.fieldRegistration,
          isRequired: true,
        ),
        ..._editFields,
      ],
      onSubmit: (values) async {
        await repository.post('buses', values);
        ref.invalidate(adminBusesListProvider);
      },
    );
  }

  void _showEditBusModal(BuildContext context, JsonMap bus) {
    final l10n = AbraLocalizations.of(context);
    final repository = ref.read(catalogueRepositoryProvider);
    showResourceForm(
      context,
      title: l10n.text(AdminStrings.busEditTitle),
      fields: _editFields,
      initial: bus,
      onSubmit: (values) async {
        await repository.put('buses/${bus['id']}', values);
        ref.invalidate(adminBusesListProvider);
      },
    );
  }

  void _showStatusDialog(BuildContext context, JsonMap bus) {
    final l10n = AbraLocalizations.of(context);
    showStatusForm(
      context,
      ref,
      title: l10n.text(AdminStrings.busStatusTitle),
      path: 'buses/${bus['id']}/status',
      options: CatalogueLabels.busStatuses,
      reasonRequired: false,
      current: bus['status'] as String?,
    ).then((changed) {
      if (changed) {
        ref.invalidate(adminBusesListProvider);
      }
    });
  }

  Future<void> _handleDeleteBus(BuildContext context, JsonMap bus) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retire Bus ${bus['registrationNumber']}?'),
        content: const Text(
          'This will mark the bus as Retired and soft-delete it from active scheduling. This bus cannot be assigned to future trips.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retire Bus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(catalogueRepositoryProvider);
        await repo.delete('buses/${bus['id']}');
        ref.invalidate(adminBusesListProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('Bus successfully retired.')),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Cannot retire bus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminBusesFilterProvider);
    final filterNotifier = ref.read(adminBusesFilterProvider.notifier);
    final busesAsync = ref.watch(adminBusesListProvider);
    final access = ref.watch(accessProvider);
    final isPlatform = access.hasPlatformScope;
    final canManage = access.can(PermissionKeys.busesUpdate);
    final canCreate = access.can(PermissionKeys.busesCreate);
    final operatorsAsync = isPlatform
        ? ref.watch(adminOperatorsOptionsProvider)
        : const AsyncValue<List<JsonMap>>.data(<JsonMap>[]);
    final busTypesAsync = ref.watch(adminBusTypesOptionsProvider);

    return Scaffold(
      backgroundColor: AbraColors.lightGray,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 600 ? AbraSpacing.md : AbraSpacing.xl,
          vertical: AbraSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Breadcrumb & Title Section matching demo_d_buses.png
            if (MediaQuery.of(context).size.width < 600) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operations / Buses',
                    style: TextStyle(
                      color: AbraColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Buses',
                    style: TextStyle(
                      color: AbraColors.navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Every bus on the platform. Approval of new buses is done in KYC reviews.',
                    style: TextStyle(
                      color: AbraColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  Wrap(
                    spacing: AbraSpacing.sm,
                    runSpacing: AbraSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (canCreate)
                        AbraButton(
                          label: 'Add',
                          icon: Icons.add,
                          onPressed: () => _showAddBusModal(context, isPlatform),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('Import buses'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AbraColors.navy,
                          side: const BorderSide(color: AbraColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AbraRadius.md),
                          ),
                        ),
                        onPressed: () async {
                          final imported = await showServerImportDialog(
                            context,
                            const ServerImport('buses', 'buses'),
                          );
                          if (imported) {
                            ref.invalidate(adminBusesListProvider);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations / Buses',
                          style: TextStyle(
                            color: AbraColors.textSecondary.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Buses',
                          style: TextStyle(
                            color: AbraColors.navy,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Every bus on the platform. Approval of new buses is done in KYC reviews.',
                          style: TextStyle(
                            color: AbraColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  // Top-right actions: Add bus & Import buses
                  Wrap(
                    spacing: AbraSpacing.sm,
                    runSpacing: AbraSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (canCreate)
                        AbraButton(
                          label: 'Add',
                          icon: Icons.add,
                          onPressed: () => _showAddBusModal(context, isPlatform),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('Import buses'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AbraColors.navy,
                          side: const BorderSide(color: AbraColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AbraRadius.md),
                          ),
                        ),
                        onPressed: () async {
                          final imported = await showServerImportDialog(
                            context,
                            const ServerImport('buses', 'buses'),
                          );
                          if (imported) {
                            ref.invalidate(adminBusesListProvider);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
            const SizedBox(height: AbraSpacing.xl),

            // Filter Bar matching demo_d_buses.png
            _buildFilterBar(
              context,
              filter,
              filterNotifier,
              operatorsAsync.asData?.value ?? <JsonMap>[],
              busTypesAsync.asData?.value ?? <JsonMap>[],
              busesAsync.asData?.value.items ?? <JsonMap>[],
              isPlatform,
            ),
            const SizedBox(height: AbraSpacing.md),

            // Bulk actions bar (when items are selected)
            if (_selectedBusIds.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AbraColors.skyContainer,
                  borderRadius: BorderRadius.circular(AbraRadius.md),
                  border: Border.all(color: AbraColors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AbraColors.deepBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedBusIds.length} buses selected',
                      style: const TextStyle(
                        color: AbraColors.deepBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (canManage)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AbraColors.orange),
                        icon: const Icon(Icons.build_circle_outlined, size: 16),
                        label: const Text('Mark Maintenance'),
                        onPressed: () => _handleBulkMaintenance(context),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _selectedBusIds.clear()),
                      child: const Text('Deselect all'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.md),
            ],

            // Content Table or List View
            busesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AbraColors.white,
                  borderRadius: BorderRadius.circular(AbraRadius.lg),
                ),
                child: Center(
                  child: Text(
                    'Failed to load buses: $err',
                    style: const TextStyle(color: AbraColors.danger),
                  ),
                ),
              ),
              data: (page) => _buildDataCard(context, page, filter, filterNotifier, canManage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    AdminBusesFilterState filter,
    AdminBusesFilterNotifier notifier,
    List<JsonMap> operators,
    List<JsonMap> busTypes,
    List<JsonMap> currentItems,
    bool isPlatform,
  ) {
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.all(AbraSpacing.md),
      decoration: BoxDecoration(
        color: AbraColors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AbraRadius.md),
                      borderSide: const BorderSide(color: AbraColors.border),
                    ),
                  ),
                  onSubmitted: (v) => notifier.setSearch(v.trim()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: filter.status.isEmpty ? 'ALL' : filter.status,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('Pending Approval', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'RETIRED', child: Text('Retired', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => notifier.setStatus(v == 'ALL' ? '' : (v ?? '')),
                ),
                if (isPlatform) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: filter.operatorId.isEmpty ? 'ALL' : filter.operatorId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Operator',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All')),
                      ...operators.map((op) => DropdownMenuItem(
                        value: '${op['id']}',
                        child: Text(
                          '${op['displayName'] ?? op['companyName'] ?? op['name'] ?? op['id']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                    ],
                    onChanged: (v) => notifier.setOperator(v == 'ALL' ? '' : (v ?? '')),
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: filter.busTypeId.isEmpty ? 'ALL' : filter.busTypeId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('All')),
                    ...busTypes.map((bt) => DropdownMenuItem(
                      value: '${bt['id']}',
                      child: Text('${bt['name'] ?? bt['id']}', overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) => notifier.setBusType(v == 'ALL' ? '' : (v ?? '')),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: filter.documents.isEmpty ? 'ALL' : filter.documents,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Documents',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All')),
                    DropdownMenuItem(value: 'EXPIRED', child: Text('Expired', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'VALID', child: Text('Valid', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => notifier.setDocuments(v == 'ALL' ? '' : (v ?? '')),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AbraColors.textSecondary,
                        side: const BorderSide(color: AbraColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        notifier.reset();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Export CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AbraColors.navy,
                        side: const BorderSide(color: AbraColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                      ),
                      onPressed: () => _exportCsv(currentItems),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Search text field
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AbraRadius.md),
                        borderSide: const BorderSide(color: AbraColors.border),
                      ),
                    ),
                    onSubmitted: (v) => notifier.setSearch(v.trim()),
                  ),
                ),

                // 2. Status dropdown
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: filter.status.isEmpty ? 'ALL' : filter.status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('Pending Approval', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'RETIRED', child: Text('Retired', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => notifier.setStatus(v == 'ALL' ? '' : (v ?? '')),
                  ),
                ),

                // 3. Operator dropdown (platform staff only)
                if (isPlatform)
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: filter.operatorId.isEmpty ? 'ALL' : filter.operatorId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Operator',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All')),
                        ...operators.map((op) => DropdownMenuItem(
                          value: '${op['id']}',
                          child: Text(
                            '${op['displayName'] ?? op['companyName'] ?? op['name'] ?? op['id']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                      ],
                      onChanged: (v) => notifier.setOperator(v == 'ALL' ? '' : (v ?? '')),
                    ),
                  ),

                // 4. Type dropdown
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: filter.busTypeId.isEmpty ? 'ALL' : filter.busTypeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All')),
                      ...busTypes.map((bt) => DropdownMenuItem(
                        value: '${bt['id']}',
                        child: Text('${bt['name'] ?? bt['id']}', overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => notifier.setBusType(v == 'ALL' ? '' : (v ?? '')),
                  ),
                ),

                // 5. Documents dropdown
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: filter.documents.isEmpty ? 'ALL' : filter.documents,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Documents',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All')),
                      DropdownMenuItem(value: 'EXPIRED', child: Text('Expired', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'VALID', child: Text('Valid', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => notifier.setDocuments(v == 'ALL' ? '' : (v ?? '')),
                  ),
                ),

                // 6. Clear button
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AbraColors.textSecondary,
                    side: const BorderSide(color: AbraColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    notifier.reset();
                  },
                ),

                // 7. Export CSV button
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AbraColors.navy,
                    side: const BorderSide(color: AbraColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbraRadius.md)),
                  ),
                  onPressed: () => _exportCsv(currentItems),
                ),
              ],
            ),
          ],

          const SizedBox(height: AbraSpacing.sm),
          const Divider(color: AbraColors.divider),
          const SizedBox(height: AbraSpacing.xs),

          // Table / List Switch Buttons
          Row(
            children: [
              _buildViewToggleButton(
                icon: Icons.table_chart_outlined,
                label: 'Table',
                isSelected: filter.viewMode == BusesViewMode.table,
                onTap: () => notifier.setViewMode(BusesViewMode.table),
              ),
              const SizedBox(width: 8),
              _buildViewToggleButton(
                icon: Icons.format_list_bulleted,
                label: 'List',
                isSelected: filter.viewMode == BusesViewMode.list,
                onTap: () => notifier.setViewMode(BusesViewMode.list),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AbraRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AbraColors.skyContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AbraRadius.md),
          border: Border.all(
            color: isSelected ? AbraColors.blue : AbraColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AbraColors.deepBlue : AbraColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AbraColors.deepBlue : AbraColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(
    BuildContext context,
    PageOf page,
    AdminBusesFilterState filter,
    AdminBusesFilterNotifier notifier,
    bool canManage,
  ) {
    if (page.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AbraColors.white,
          borderRadius: BorderRadius.circular(AbraRadius.lg),
          border: Border.all(color: AbraColors.divider),
        ),
        child: const Column(
          children: [
            Icon(Icons.directions_bus_outlined, size: 48, color: AbraColors.textDisabled),
            SizedBox(height: 12),
            Text(
              'No buses found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AbraColors.navy),
            ),
            SizedBox(height: 4),
            Text(
              'Try clearing search filters or import new buses.',
              style: TextStyle(color: AbraColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final isCompact = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: AbraColors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.divider),
        boxShadow: AbraShadows.soft,
      ),
      child: Column(
        children: [
          if (!isCompact && filter.viewMode == BusesViewMode.table)
            _buildTableView(context, page.items, canManage)
          else
            _buildListView(context, page.items, canManage),

          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AbraColors.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${page.firstIndex}-${page.lastIndex} of ${page.total}',
                  style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: page.hasPrevious ? () => notifier.setPage(page.page - 1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: page.hasNext ? () => notifier.setPage(page.page + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(BuildContext context, List<JsonMap> items, bool canManage) {
    final allSelected = items.isNotEmpty && items.every((i) => _selectedBusIds.contains('${i['id']}'));

    const double rowHeight = 56.0;
    const double headingHeight = 56.0;

    final dataTable = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: headingHeight,
        dataRowMinHeight: rowHeight,
        dataRowMaxHeight: rowHeight,
        headingRowColor: WidgetStateProperty.all(AbraColors.lightGray.withValues(alpha: 0.5)),
        horizontalMargin: 16,
        columnSpacing: 20,
        columns: [
          DataColumn(
            label: Checkbox(
              value: allSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedBusIds.addAll(items.map((i) => '${i['id']}'));
                  } else {
                    _selectedBusIds.clear();
                  }
                });
              },
            ),
          ),
          const DataColumn(label: Text('Registration', style: TextStyle(fontWeight: FontWeight.w700))),
          const DataColumn(label: Text('Operator', style: TextStyle(fontWeight: FontWeight.w700))),
          const DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700))),
          const DataColumn(label: Text('Seats', style: TextStyle(fontWeight: FontWeight.w700))),
          const DataColumn(label: Text('Layout', style: TextStyle(fontWeight: FontWeight.w700))),
          const DataColumn(label: Text('Insurance', style: TextStyle(fontWeight: FontWeight.w700))),
          const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: items.map((bus) {
          final id = '${bus['id']}';
          final isSelected = _selectedBusIds.contains(id);
          final status = '${bus['status'] ?? 'ACTIVE'}';
          final regNumber = '${bus['registrationNumber'] ?? '—'}';
          final busName = '${bus['name'] ?? ''}';
          final opName = '${bus['operatorName'] ?? bus['operatorId'] ?? '—'}';
          final typeName = '${bus['busTypeName'] ?? bus['busTypeId'] ?? '—'}';
          final seats = '${bus['seatCapacity'] ?? 40}';
          final layout = '${bus['seatLayoutType'] ?? '2+2 Seater'}';
          final insuranceRaw = bus['insuranceExpiryDate'];
          final insuranceFormatted = _formatInsuranceDate(insuranceRaw);

          return DataRow(
            selected: isSelected,
            onSelectChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedBusIds.add(id);
                } else {
                  _selectedBusIds.remove(id);
                }
              });
            },
            cells: [
              DataCell(
                Checkbox(
                  value: isSelected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedBusIds.add(id);
                      } else {
                        _selectedBusIds.remove(id);
                      }
                    });
                  },
                ),
              ),
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      regNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.navy),
                    ),
                    if (busName.isNotEmpty)
                      Text(
                        busName,
                        style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary),
                      ),
                  ],
                ),
              ),
              DataCell(Text(opName)),
              DataCell(Text(typeName)),
              DataCell(Text(seats)),
              DataCell(Text(layout)),
              DataCell(Text(insuranceFormatted)),
              DataCell(_buildStatusBadge(status)),
            ],
          );
        }).toList(),
      ),
    );

    final pinnedActions = DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.white,
        border: Border(left: BorderSide(color: AbraColors.divider)),
      ),
      child: Column(
        children: [
          Container(
            height: headingHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            color: AbraColors.lightGray.withValues(alpha: 0.5),
            child: const Text('Actions', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final bus in items)
            Container(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AbraColors.divider, width: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    tooltip: 'View details',
                    onPressed: () => _showBusDetailsModal(context, bus),
                  ),
                  if (canManage) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit',
                      onPressed: () => _showEditBusModal(context, bus),
                    ),
                    if ('${bus['status'] ?? 'ACTIVE'}' != 'RETIRED')
                      IconButton(
                        icon: const Icon(Icons.build_circle_outlined, size: 18),
                        tooltip: 'Change status',
                        onPressed: () => _showStatusDialog(context, bus),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AbraColors.danger),
                      tooltip: 'Retire bus',
                      onPressed: () => _handleDeleteBus(context, bus),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: dataTable),
        pinnedActions,
      ],
    );
  }

  Widget _buildListView(BuildContext context, List<JsonMap> items, bool canManage) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, index) => const Divider(height: 1, color: AbraColors.divider),
      itemBuilder: (ctx, idx) {
        final bus = items[idx];
        final id = '${bus['id']}';
        final isSelected = _selectedBusIds.contains(id);
        final reg = '${bus['registrationNumber'] ?? '—'}';
        final name = '${bus['name'] ?? ''}';
        final op = '${bus['operatorName'] ?? bus['operatorId'] ?? '—'}';
        final type = '${bus['busTypeName'] ?? bus['busTypeId'] ?? '—'}';
        final seats = '${bus['seatCapacity'] ?? 40}';
        final layout = '${bus['seatLayoutType'] ?? '2+2 Seater'}';
        final status = '${bus['status'] ?? 'ACTIVE'}';
        final insurance = _formatInsuranceDate(bus['insuranceExpiryDate']);

        return InkWell(
          onTap: () => _showBusDetailsModal(context, bus),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedBusIds.add(id);
                          } else {
                            _selectedBusIds.remove(id);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                reg,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AbraColors.navy),
                              ),
                              if (name.isNotEmpty)
                                Text('($name)', style: const TextStyle(color: AbraColors.textSecondary)),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text('Operator: $op', style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                              Text('Type: $type', style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                              Text('Seats: $seats ($layout)', style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                              Text('Insurance: $insurance', style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      tooltip: 'View details',
                      onPressed: () => _showBusDetailsModal(context, bus),
                    ),
                    if (canManage) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => _showEditBusModal(context, bus),
                      ),
                      if (status != 'RETIRED')
                        IconButton(
                          icon: const Icon(Icons.build_circle_outlined, size: 20),
                          tooltip: 'Change status',
                          onPressed: () => _showStatusDialog(context, bus),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AbraColors.danger),
                        tooltip: 'Retire bus',
                        onPressed: () => _handleDeleteBus(context, bus),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
        bg = AbraColors.tealContainer;
        fg = AbraColors.tealDark;
        label = 'Active';
      case 'MAINTENANCE':
        bg = AbraColors.orangeContainer;
        fg = AbraColors.orangeDark;
        label = 'Maintenance';
      case 'PENDING_APPROVAL':
        bg = AbraColors.skyContainer;
        fg = AbraColors.deepBlue;
        label = 'Pending approval';
      case 'RETIRED':
        bg = AbraColors.lightGray;
        fg = AbraColors.textDisabled;
        label = 'Retired';
      default:
        bg = AbraColors.navyContainer;
        fg = AbraColors.navy;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  String _formatInsuranceDate(Object? raw) {
    if (raw == null) return '—';
    final parsed = DateTime.tryParse('$raw');
    if (parsed == null) return '$raw';
    return DateFormat('d MMM yyyy').format(parsed);
  }
}

// ===== 3. BUS DETAILS & SEAT LAYOUT MODAL =====

class _BusDetailsDialog extends ConsumerStatefulWidget {
  const _BusDetailsDialog({required this.bus});

  final JsonMap bus;

  @override
  ConsumerState<_BusDetailsDialog> createState() => _BusDetailsDialogState();
}

class _BusDetailsDialogState extends ConsumerState<_BusDetailsDialog> {
  JsonMap? _layout;
  bool _loadingLayout = true;

  @override
  void initState() {
    super.initState();
    _fetchLayout();
  }

  Future<void> _fetchLayout() async {
    try {
      final client = ref.read(appDependenciesProvider).apiClient;
      final res = await client.get('client/buses/${widget.bus['id']}/layout');
      if (mounted) {
        setState(() {
          _layout = res.decodeObject<JsonMap>((JsonMap j) => j);
          _loadingLayout = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLayout = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final reg = '${bus['registrationNumber'] ?? '—'}';
    final name = '${bus['name'] ?? ''}';
    final op = '${bus['operatorName'] ?? bus['operatorId'] ?? '—'}';
    final type = '${bus['busTypeName'] ?? bus['busTypeId'] ?? '—'}';
    final seats = '${bus['seatCapacity'] ?? 40}';
    final layoutType = '${bus['seatLayoutType'] ?? '2+2 Seater'}';
    final status = '${bus['status'] ?? 'ACTIVE'}';
    final insurance = bus['insuranceExpiryDate'] != null
        ? '${bus['insuranceExpiryDate']}'.split('T').first
        : '—';

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$reg $name', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Specifications card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AbraColors.lightGray,
                  borderRadius: BorderRadius.circular(AbraRadius.md),
                ),
                child: Column(
                  children: [
                    _specRow('Operator', op),
                    const Divider(height: 12),
                    _specRow('Bus Type', type),
                    const Divider(height: 12),
                    _specRow('Seat Capacity', '$seats seats'),
                    const Divider(height: 12),
                    _specRow('Layout Architecture', layoutType),
                    const Divider(height: 12),
                    _specRow('Insurance Validity', insurance),
                    const Divider(height: 12),
                    _specRow('Operational Status', status),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Visual Seat Map Section
              const Text(
                'Assigned Seat Layout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AbraColors.navy),
              ),
              const SizedBox(height: 8),
              if (_loadingLayout)
                const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
              else if (_layout == null || (_layout!['seats'] as List?)?.isEmpty == true)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AbraColors.lightGray,
                    borderRadius: BorderRadius.circular(AbraRadius.md),
                  ),
                  child: const Center(
                    child: Text(
                      'No custom seat map drawn yet. Using default 2+2 layout grid.',
                      style: TextStyle(color: AbraColors.textSecondary),
                    ),
                  ),
                )
              else
                _buildSeatLayoutGrid(_layout!),

              const SizedBox(height: 20),
              // Document Status Checklist
              const Text(
                'Compliance & Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AbraColors.navy),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AbraColors.border),
                  borderRadius: BorderRadius.circular(AbraRadius.md),
                ),
                child: Column(
                  children: [
                    _docItem('Insurance Certificate', 'Valid until $insurance', true),
                    const Divider(height: 12),
                    _docItem('Fitness Certificate', 'Verified on file', true),
                    const Divider(height: 12),
                    _docItem('Stage Carriage Permit', 'National Route Permit active', true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _specRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AbraColors.textSecondary, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.navy)),
      ],
    );
  }

  Widget _docItem(String title, String subtitle, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.warning_amber_rounded,
          color: isValid ? AbraColors.teal : AbraColors.orange,
          size: 20,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AbraColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildSeatLayoutGrid(JsonMap layout) {
    final seats = (layout['seats'] as List?)?.cast<JsonMap>() ?? <JsonMap>[];
    int maxRow = 0;
    int maxCol = 0;
    for (final s in seats) {
      final r = (s['row'] as num?)?.toInt() ?? 0;
      final c = (s['col'] as num?)?.toInt() ?? 0;
      if (r > maxRow) maxRow = r;
      if (c > maxCol) maxCol = c;
    }

    final grid = List.generate(
      maxRow + 1,
      (_) => List<JsonMap?>.filled(maxCol + 1, null),
    );
    for (final s in seats) {
      final r = (s['row'] as num?)?.toInt() ?? 0;
      final c = (s['col'] as num?)?.toInt() ?? 0;
      if (r <= maxRow && c <= maxCol) {
        grid[r][c] = s;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AbraColors.white,
        borderRadius: BorderRadius.circular(AbraRadius.md),
        border: Border.all(color: AbraColors.border),
      ),
      child: Column(
        children: [
          // Driver cabin banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: AbraColors.navyContainer,
              borderRadius: BorderRadius.circular(AbraRadius.sm),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.airline_seat_recline_normal, size: 16, color: AbraColors.navy),
                SizedBox(width: 6),
                Text('Driver Cabin / Front of Bus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Seat rows
          for (int r = 0; r <= maxRow; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int c = 0; c <= maxCol; c++) ...[
                    _renderGridCell(grid[r][c]),
                    if (c < maxCol) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderGridCell(JsonMap? cell) {
    if (cell == null || cell['seatType'] == 'EMPTY') {
      return const SizedBox(width: 38, height: 38);
    }
    if (cell['seatType'] == 'AISLE') {
      return Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: Container(width: 4, height: 30, color: AbraColors.divider),
      );
    }

    final num = '${cell['seatNumber'] ?? ''}';
    final type = '${cell['seatType'] ?? 'SEATER'}';
    Color bg = AbraColors.skyContainer;
    Color border = AbraColors.blue;

    if (type == 'SLEEPER') {
      bg = AbraColors.navyContainer;
      border = AbraColors.navy;
    } else if (type == 'LADIES') {
      bg = AbraColors.orangeContainer;
      border = AbraColors.orange;
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AbraRadius.sm),
        border: Border.all(color: border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        num,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: border,
        ),
      ),
    );
  }
}
