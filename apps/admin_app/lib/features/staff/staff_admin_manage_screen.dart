import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../routing/admin_routes.dart';

// ===== 1. MODELS ====================================================================

class StaffMember {
  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleName,
    required this.status,
    required this.mfa,
    this.lastSeen,
    this.overrides = 0,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        email: '${json['email'] ?? ''}',
        role: '${json['role'] ?? 'SUPPORT'}',
        roleName: '${json['roleName'] ?? json['role'] ?? ''}',
        status: '${json['status'] ?? 'ACTIVE'}',
        mfa: json['mfa'] == true,
        overrides: (json['overrides'] as num?)?.toInt() ?? 0,
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse('${json['lastSeen']}')?.toLocal()
            : null,
      );

  final String id;
  String name;
  final String email;
  String role;
  String roleName;
  String status;
  bool mfa;
  DateTime? lastSeen;
  int overrides;

  String get roleLabel => roleName.isNotEmpty ? roleName : role;
}

class StaffRole {
  const StaffRole({required this.key, required this.name});

  factory StaffRole.fromJson(Map<String, dynamic> json) => StaffRole(
        key: '${json['key'] ?? ''}',
        name: '${json['name'] ?? json['key'] ?? ''}',
      );

  final String key;
  final String name;
}

class StaffPage {
  const StaffPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<StaffMember> items;
  final int page;
  final int pageSize;
  final int total;
}

class StaffQuery {
  const StaffQuery({
    this.search = '',
    this.role = 'ALL',
    this.status = 'ALL',
    this.page = 1,
    this.pageSize = 15,
  });

  final String search;
  final String role;
  final String status;
  final int page;
  final int pageSize;

  StaffQuery copyWith({
    String? search,
    String? role,
    String? status,
    int? page,
    int? pageSize,
  }) =>
      StaffQuery(
        search: search ?? this.search,
        role: role ?? this.role,
        status: status ?? this.status,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );

  Map<String, String> queryParameters() => <String, String>{
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (role != 'ALL') 'role': role,
        if (status != 'ALL') 'status': status,
        'page': '$page',
        'pageSize': '$pageSize',
      };

  @override
  bool operator ==(Object other) =>
      other is StaffQuery &&
      other.search == search &&
      other.role == role &&
      other.status == status &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(search, role, status, page, pageSize);
}

class StaffInvitationPreview {
  const StaffInvitationPreview({
    required this.name,
    required this.email,
    required this.roleKey,
    required this.roleName,
  });

  factory StaffInvitationPreview.fromJson(Map<String, dynamic> json) =>
      StaffInvitationPreview(
        name: '${json['name'] ?? ''}',
        email: '${json['email'] ?? ''}',
        roleKey: '${json['roleKey'] ?? ''}',
        roleName: '${json['roleName'] ?? json['roleKey'] ?? ''}',
      );

  final String name;
  final String email;
  final String roleKey;
  final String roleName;
}

// ===== 2. API SERVICE & PROVIDERS ===================================================

class StaffAdminApi {
  StaffAdminApi(this._client);
  final ApiClient _client;

  Future<StaffPage> list(StaffQuery query) async {
    final response = await _client.get(
      'admin/staff',
      query: query.queryParameters(),
    );
    final pageInfo = response.page;
    final items = response.decodeList(
      (json) => StaffMember.fromJson(Map<String, dynamic>.from(json)),
    );
    return StaffPage(
      items: items,
      page: pageInfo?.page ?? query.page,
      pageSize: pageInfo?.pageSize ?? query.pageSize,
      total: pageInfo?.total ?? items.length,
    );
  }

  Future<StaffMember> get(String id) async {
    final response = await _client.get('admin/staff/$id');
    return response.decodeObject(
      (json) => StaffMember.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  Future<StaffMember> invite({
    required String name,
    required String email,
    required String role,
  }) async {
    final response = await _client.post(
      'admin/staff',
      body: <String, Object?>{
        'name': name,
        'email': email,
        'role': role,
      },
    );
    return response.decodeObject(
      (json) => StaffMember.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  Future<StaffMember> update(
    String id, {
    String? name,
    String? role,
  }) async {
    final body = <String, Object?>{};
    if (name != null) body['name'] = name;
    if (role != null) body['role'] = role;
    final response = await _client.patch(
      'admin/staff/$id',
      body: body,
    );
    return response.decodeObject(
      (json) => StaffMember.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  Future<void> resend(String id) async {
    await _client.post('admin/staff/$id/resend');
  }

  Future<StaffMember> deactivate(String id, {String? reason}) async {
    final response = await _client.post(
      'admin/staff/$id/deactivate',
      body: <String, Object?>{
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return response.decodeObject(
      (json) => StaffMember.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  Future<StaffMember> activate(String id, {String? reason}) async {
    final response = await _client.post(
      'admin/staff/$id/activate',
      body: <String, Object?>{
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return response.decodeObject(
      (json) => StaffMember.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  Future<Uint8List> export(StaffQuery query, String format) {
    final params = Map<String, String>.from(query.queryParameters())
      ..['format'] = format;
    final uri = Uri(queryParameters: params);
    return _client.getBytes('admin/staff/export?${uri.query}');
  }

  Future<StaffInvitationPreview> inspectInvitation(String token) async {
    final response = await _client.post(
      'staff-invitations/inspect',
      body: {'token': token},
    );
    return response.decodeObject(
      (json) => StaffInvitationPreview.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  Future<void> acceptInvitation({
    required String token,
    required String password,
  }) async {
    await _client.post(
      'staff-invitations/accept',
      body: {
        'token': token,
        'password': password,
      },
    );
  }

  Future<List<StaffRole>> roles() async {
    final response = await _client.get('admin/staff/roles');
    return response.decodeList(
      (json) => StaffRole.fromJson(Map<String, dynamic>.from(json)),
    );
  }
}

final staffApiProvider = Provider<StaffAdminApi>(
  (ref) => StaffAdminApi(ref.watch(appDependenciesProvider).apiClient),
);

final staffRolesProvider = FutureProvider<List<StaffRole>>(
  (ref) => ref.watch(staffApiProvider).roles(),
);

class StaffQueryNotifier extends Notifier<StaffQuery> {
  @override
  StaffQuery build() => const StaffQuery();

  void set(StaffQuery next) {
    state = next;
  }
}

final staffQueryProvider =
    NotifierProvider<StaffQueryNotifier, StaffQuery>(StaffQueryNotifier.new);

final staffListFutureProvider = FutureProvider.family<StaffPage, StaffQuery>(
  (ref, query) => ref.watch(staffApiProvider).list(query),
);

// ===== 3. MAIN STAFF SCREEN =========================================================

class StaffAdminManageScreen extends ConsumerStatefulWidget {
  const StaffAdminManageScreen({super.key});

  @override
  ConsumerState<StaffAdminManageScreen> createState() =>
      _StaffAdminManageScreenState();
}

class _StaffAdminManageScreenState extends ConsumerState<StaffAdminManageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  static const _defaultRoles = [
    StaffRole(key: 'SUPER_ADMIN', name: 'Super Admin'),
    StaffRole(key: 'ADMIN', name: 'Admin'),
    StaffRole(key: 'SUPPORT', name: 'Support'),
    StaffRole(key: 'ACCOUNTS', name: 'Accounts'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(staffQueryProvider);
    final staffAsync = ref.watch(staffListFutureProvider(query));
    final rolesAsync = ref.watch(staffRolesProvider);
    final rolesList = rolesAsync.value ?? _defaultRoles;

    final totalCount = staffAsync.value?.total ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Staff and roles',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Who can do what in the admin portal.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AbraColors.blue,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AbraColors.blue,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Staff ($totalCount)'),
                  const Tab(text: 'Permission matrix'),
                  const Tab(text: 'Sessions'),
                ],
                onTap: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),

            IndexedStack(
              index: _tabController.index,
              children: [
                _buildStaffListTab(context, query, staffAsync, rolesList),
                _buildPermissionMatrixTab(context),
                _buildSessionsTab(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffListTab(
    BuildContext context,
    StaffQuery query,
    AsyncValue<StaffPage> staffAsync,
    List<StaffRole> rolesList,
  ) {
    return Column(
      children: [
        // Filter and Action Bar
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 768;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Search box
                        SizedBox(
                          width: isNarrow ? constraints.maxWidth : 200,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search',
                              hintText: 'Name or email',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              suffixIcon: query.search.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(staffQueryProvider.notifier).set(
                                              query.copyWith(search: '', page: 1),
                                            );
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: (value) {
                              ref.read(staffQueryProvider.notifier).set(
                                    query.copyWith(search: value, page: 1),
                                  );
                            },
                          ),
                        ),
                        // Role filter
                        SizedBox(
                          width: isNarrow ? constraints.maxWidth : 170,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('role_${query.role}'),
                            initialValue: query.role,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(value: 'ALL', child: Text('All roles')),
                              ...rolesList.map(
                                (r) => DropdownMenuItem(value: r.key, child: Text(r.name)),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                ref.read(staffQueryProvider.notifier).set(
                                      query.copyWith(role: v, page: 1),
                                    );
                              }
                            },
                          ),
                        ),
                        // Status filter
                        SizedBox(
                          width: isNarrow ? constraints.maxWidth : 170,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('status_${query.status}'),
                            initialValue: query.status,
                            isDense: true,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'ALL', child: Text('All statuses')),
                              DropdownMenuItem(
                                  value: 'ACTIVE', child: Text('Active')),
                              DropdownMenuItem(
                                  value: 'INVITED', child: Text('Invited')),
                              DropdownMenuItem(
                                  value: 'DEACTIVATED', child: Text('Deactivated')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                ref.read(staffQueryProvider.notifier).set(
                                      query.copyWith(status: v, page: 1),
                                    );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Export button
                        OutlinedButton.icon(
                          onPressed: () => _exportCsv(context, query),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AbraColors.navy,
                          ),
                        ),
                        // Add staff button
                        ElevatedButton.icon(
                          onPressed: () => _openAddStaffModal(context, rolesList: rolesList),
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text('Add staff'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AbraColors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Staff Table with Async State
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: staffAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load staff list: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.refresh(staffListFutureProvider(query)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No staff members found matching the criteria.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Person')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Two-step')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Overrides')),
                          DataColumn(label: Text('Last seen')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: page.items.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      s.email,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s.roleLabel,
                                    style: const TextStyle(
                                      color: AbraColors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: s.mfa
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s.mfa ? 'On' : 'Off',
                                    style: TextStyle(
                                      color: s.mfa
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(_buildStatusBadge(s.status)),
                              DataCell(
                                Text(s.overrides > 0
                                    ? '${s.overrides} custom'
                                    : '-'),
                              ),
                              DataCell(
                                Text(
                                  s.lastSeen != null
                                      ? DateFormat('MMM dd, hh:mm a')
                                          .format(s.lastSeen!)
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 16),
                                      tooltip: 'Edit',
                                      onPressed: () =>
                                          _openEditStaffModal(context, member: s, rolesList: rolesList),
                                    ),
                                    if (s.status == 'ACTIVE')
                                      TextButton(
                                        onPressed: () =>
                                            _confirmDeactivate(context, s),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                        ),
                                        child: const Text('Deactivate'),
                                      )
                                    else if (s.status == 'DEACTIVATED')
                                      TextButton(
                                        onPressed: () =>
                                            _confirmActivate(context, s),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.green.shade700,
                                        ),
                                        child: const Text('Activate'),
                                      )
                                    else if (s.status == 'INVITED')
                                      TextButton(
                                        onPressed: () => _resendInvite(context, s),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AbraColors.blue,
                                        ),
                                        child: const Text('Resend invite'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    // Paging controls footer
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${page.total} staff',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            onPressed: page.page > 1
                                ? () {
                                    ref.read(staffQueryProvider.notifier).set(
                                          query.copyWith(page: page.page - 1),
                                        );
                                  }
                                : null,
                          ),
                          Text(
                            'Page ${page.page} of ${((page.total - 1) ~/ page.pageSize) + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            onPressed: (page.page * page.pageSize) < page.total
                                ? () {
                                    ref.read(staffQueryProvider.notifier).set(
                                          query.copyWith(page: page.page + 1),
                                        );
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, StaffQuery query) async {
    try {
      final bytes = await ref.read(staffApiProvider).export(query, 'csv');
      downloadBytesFile('staff.csv', bytes, mimeType: 'text/csv');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff list downloaded (CSV)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download staff export: $e')),
        );
      }
    }
  }

  void _openAddStaffModal(BuildContext context, {required List<StaffRole> rolesList}) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'SUPPORT';
    bool submitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMdlState) => AlertDialog(
          title: const Text('Add staff'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('add_role_$role'),
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: rolesList
                      .map((r) => DropdownMenuItem(value: r.key, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) => setMdlState(() => role = v ?? 'SUPPORT'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline,
                          color: AbraColors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A new person gets an email with a link to set a password and two-step verification.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      if (name.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill in name and email')),
                        );
                        return;
                      }

                      setMdlState(() => submitting = true);
                      try {
                        await ref.read(staffApiProvider).invite(
                              name: name,
                              email: email,
                              role: role,
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        ref.invalidate(staffListFutureProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Invitation sent to $email')),
                          );
                        }
                      } catch (e) {
                        setMdlState(() => submitting = false);
                        final message = e.toString().contains('already has an account')
                            ? 'This email already has an account'
                            : 'Failed to invite staff: $e';
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
              ),
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send invitation'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditStaffModal(
    BuildContext context, {
    required StaffMember member,
    required List<StaffRole> rolesList,
  }) {
    final nameCtrl = TextEditingController(text: member.name);
    String role = member.role;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMdlState) => AlertDialog(
          title: const Text('Edit staff'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: member.email),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email (locked)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('edit_role_$role'),
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: rolesList
                      .map((r) => DropdownMenuItem(value: r.key, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) => setMdlState(() => role = v ?? 'SUPPORT'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setMdlState(() => saving = true);
                      try {
                        await ref.read(staffApiProvider).update(
                              member.id,
                              name: nameCtrl.text.trim(),
                              role: role,
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        ref.invalidate(staffListFutureProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Staff member updated')),
                          );
                        }
                      } catch (e) {
                        setMdlState(() => saving = false);
                        String msg = 'Failed to update: $e';
                        if (e.toString().contains('at least one Super Admin')) {
                          msg = 'There must be at least one Super Admin';
                        } else if (e.toString().contains('own role')) {
                          msg = 'You cannot change your own role';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, StaffMember member) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate ${member.name}'),
        content: const Text(
          'They are signed out at once and cannot sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(staffApiProvider).deactivate(member.id);
                ref.invalidate(staffListFutureProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deactivated ${member.name}')),
                  );
                }
              } catch (e) {
                String msg = 'Failed to deactivate: $e';
                if (e.toString().contains('at least one active Super Admin') ||
                    e.toString().contains('Keep at least one active Super Admin')) {
                  msg = 'Keep at least one active Super Admin';
                } else if (e.toString().contains('own account')) {
                  msg = 'You cannot deactivate your own account';
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmActivate(BuildContext context, StaffMember member) async {
    try {
      await ref.read(staffApiProvider).activate(member.id);
      ref.invalidate(staffListFutureProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activated ${member.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to activate: $e')),
        );
      }
    }
  }

  Future<void> _resendInvite(BuildContext context, StaffMember member) async {
    try {
      await ref.read(staffApiProvider).resend(member.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation resent to ${member.email}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend invitation: $e')),
        );
      }
    }
  }

  Widget _buildPermissionMatrixTab(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 48, color: AbraColors.navy),
              SizedBox(height: 16),
              Text(
                'Permission matrix',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AbraColors.navy,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Not connected yet (built in Step 2: Permission matrix and roles)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.devices_outlined, size: 48, color: AbraColors.navy),
              SizedBox(height: 16),
              Text(
                'Active staff sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AbraColors.navy,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Not connected yet (built in Step 4: Active staff sessions)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'ACTIVE':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'INVITED':
        bg = Colors.blue.shade50;
        fg = AbraColors.blue;
        break;
      case 'DEACTIVATED':
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ===== 4. SET PASSWORD SCREEN FOR INVITED STAFF =====================================

class StaffSetPasswordScreen extends ConsumerStatefulWidget {
  const StaffSetPasswordScreen({required this.token, super.key});
  final String token;

  @override
  ConsumerState<StaffSetPasswordScreen> createState() =>
      _StaffSetPasswordScreenState();
}

class _StaffSetPasswordScreenState extends ConsumerState<StaffSetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  bool _success = false;

  StaffInvitationPreview? _preview;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _inspect();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    if (widget.token.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'This invitation link is missing a valid token.';
      });
      return;
    }

    try {
      final preview =
          await ref.read(staffApiProvider).inspectInvitation(widget.token);
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'This invitation link is not valid or has expired.';
      });
    }
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 10) {
      setState(() => _error = 'Password must be at least 10 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(staffApiProvider).acceptInvitation(
            token: widget.token,
            password: password,
          );
      setState(() {
        _submitting = false;
        _success = true;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Failed to set password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildBody(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Checking invitation...'),
        ],
      );
    }

    if (_loadError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Invalid Invitation Link',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AdminRoutes.signIn),
            style: ElevatedButton.styleFrom(
              backgroundColor: AbraColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Back to Sign In'),
          ),
        ],
      );
    }

    if (_success) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 54),
          const SizedBox(height: 16),
          const Text(
            'Account Activated',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your password has been set. You can now sign in to the Abra Travels admin portal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AdminRoutes.signIn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Sign in now'),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Join Abra Travels Staff',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AbraColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Welcome ${_preview?.name}! Set a password for your account (${_preview?.email}) as ${_preview?.roleName}.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'New password',
            hintText: 'At least 10 characters',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscure,
          decoration: const InputDecoration(
            labelText: 'Confirm password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: AbraColors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Password must be at least 10 characters and cannot contain your name or email. You will set up two-step verification on your first sign in.',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AbraColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Set password & activate'),
          ),
        ),
      ],
    );
  }
}
