import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

// ===== 1. HELPERS & MODEL ===========================================================

String relativeTime(Object? iso, {DateTime? now}) {
  final at = DateTime.tryParse('${iso ?? ''}');
  if (at == null) return '-';
  final minutes = (now ?? DateTime.now()).difference(at).inMinutes;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '$minutes min ago';
  if (minutes < 24 * 60) return '${minutes ~/ 60} h ago';
  return '${minutes ~/ (24 * 60)} days ago';
}

String formatDateTime(Object? iso) {
  final dt = DateTime.tryParse('$iso')?.toLocal();
  if (dt == null) return '-';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class PortalUserModel {
  const PortalUserModel({
    required this.id,
    required this.operatorId,
    required this.name,
    required this.email,
    required this.role,
    required this.roleName,
    required this.status,
    required this.lastSeen,
    required this.createdAt,
  });

  factory PortalUserModel.fromJson(Map<String, dynamic> json) {
    final role = '${json['role'] ?? 'BOOKING_STAFF'}';
    final roleName = '${json['roleName'] ?? _defaultRoleLabel(role)}';

    return PortalUserModel(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      operatorId: '${json['operatorId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: role,
      roleName: roleName,
      status: '${json['status'] ?? 'ACTIVE'}',
      lastSeen: json['lastSeen'] as String? ?? json['last'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  final String id;
  final String operatorId;
  final String name;
  final String email;
  final String role;
  final String roleName;
  final String status;
  final String? lastSeen;
  final String? createdAt;

  static String _defaultRoleLabel(String key) {
    switch (key.toUpperCase()) {
      case 'SUPER_ADMIN':
      case 'OPERATOR_ADMIN':
      case 'OWNER':
        return 'Owner';
      case 'ADMIN':
      case 'OPERATOR_MANAGER':
      case 'MANAGER':
        return 'Manager';
      case 'SUPPORT':
      case 'BOOKING_STAFF':
        return 'Booking staff';
      case 'ACCOUNTS':
      case 'ACCOUNT_STAFF':
        return 'Accounts';
      default:
        return key;
    }
  }
}

class PortalMatrixRowModel {
  const PortalMatrixRowModel({
    required this.id,
    required this.title,
    required this.owner,
    required this.manager,
    required this.booking,
    required this.accounts,
  });

  factory PortalMatrixRowModel.fromJson(Map<String, dynamic> json) {
    final levels = (json['levels'] as Map?) ?? const {};
    return PortalMatrixRowModel(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      owner: '${levels['owner'] ?? 'NONE'}',
      manager: '${levels['manager'] ?? 'NONE'}',
      booking: '${levels['booking'] ?? 'NONE'}',
      accounts: '${levels['accounts'] ?? 'NONE'}',
    );
  }

  final String id;
  final String title;
  final String owner;
  final String manager;
  final String booking;
  final String accounts;
}

// ===== 2. SCREEN WIDGET =============================================================

class ClientStaffRolesScreen extends ConsumerStatefulWidget {
  const ClientStaffRolesScreen({super.key});

  @override
  ConsumerState<ClientStaffRolesScreen> createState() =>
      _ClientStaffRolesScreenState();
}

class _ClientStaffRolesScreenState
    extends ConsumerState<ClientStaffRolesScreen> {
  String _activeTab = 'list'; // 'list' (Portal users), 'mat' (Permission matrix)
  bool _isLoading = true;
  String? _errorMessage;
  List<PortalUserModel> _users = [];
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';
  bool _isTableView = true;

  bool _isLoadingMatrix = false;
  String? _matrixError;
  List<PortalMatrixRowModel>? _matrixRows;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadUsers());
      unawaited(_loadMatrix());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMatrix() async {
    setState(() {
      _isLoadingMatrix = true;
      _matrixError = null;
    });

    try {
      final response = await ref
          .read(appDependenciesProvider)
          .apiClient
          .get('client/users/matrix');

      final data = response.data;
      final rawPages = data is Map
          ? (data['pages'] as List<dynamic>?) ?? <dynamic>[]
          : <dynamic>[];
      final loaded = rawPages
          .whereType<Map<String, dynamic>>()
          .map(PortalMatrixRowModel.fromJson)
          .toList();

      if (mounted) {
        setState(() {
          _matrixRows = loaded;
          _isLoadingMatrix = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _matrixError = 'Not connected yet';
          _isLoadingMatrix = false;
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, Object?>{
        if (_searchCtrl.text.trim().isNotEmpty)
          'search': _searchCtrl.text.trim(),
        if (_statusFilter != 'ALL') 'status': _statusFilter,
      };

      final response = await ref
          .read(appDependenciesProvider)
          .apiClient
          .get('client/users', query: queryParams);

      final data = response.data;
      final rawItems = data is Map
          ? (data['items'] as List<dynamic>?) ?? <dynamic>[]
          : <dynamic>[];
      final loaded = rawItems
          .whereType<Map<String, dynamic>>()
          .map(PortalUserModel.fromJson)
          .toList();

      if (mounted) {
        setState(() {
          _users = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load portal users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final bytes = await ref
          .read(appDependenciesProvider)
          .apiClient
          .getBytes('client/users/export?format=csv');
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      downloadTextFile('portal_users_$stamp.csv', utf8.decode(bytes));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The file is ready.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Staff and roles',
            subtitle:
                'Who in your company can use this portal, and what they can do.',
            breadcrumbs: const ['System', 'Staff and roles'],
            actions: [
              if (_activeTab == 'list') ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: _exportCsv,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add user'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                  ),
                  onPressed: () => _showAddUserDialog(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),

          // Prototype Tabs: [Portal users (N) | Permission matrix]
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AbraColors.lightGray,
              borderRadius: BorderRadius.circular(AbraRadius.md),
              border: Border.all(color: AbraColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabChip(
                  'list',
                  'Portal users (${_users.length})',
                ),
                const SizedBox(width: 4),
                _tabChip('mat', 'Permission matrix'),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),

          if (_activeTab == 'list') _buildUsersContent() else _buildMatrixView(),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) {
    final isSel = _activeTab == key;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = key);
        if (key == 'mat' && _matrixRows == null && !_isLoadingMatrix) {
          unawaited(_loadMatrix());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AbraRadius.sm),
          boxShadow: isSel ? AbraShadows.card : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? AbraColors.navy : AbraColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ===== USERS TAB ==================================================================

  Widget _buildUsersContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters toolbar matching prototype
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AbraRadius.md),
            border: Border.all(color: AbraColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by person name or email...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AbraRadius.sm),
                        borderSide: const BorderSide(color: AbraColors.border),
                      ),
                    ),
                    onSubmitted: (_) => unawaited(_loadUsers()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'INVITED', child: Text('Invited')),
                  DropdownMenuItem(
                    value: 'DEACTIVATED',
                    child: Text('Deactivated'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _statusFilter = v);
                    unawaited(_loadUsers());
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => unawaited(_loadUsers()),
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.table_chart_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.view_list_outlined, size: 16),
                  ),
                ],
                selected: {_isTableView},
                onSelectionChanged: (set) {
                  setState(() => _isTableView = set.first);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.md),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 36, color: Colors.red.shade400),
                  const SizedBox(height: 8),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => unawaited(_loadUsers()),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        else if (_users.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.manage_accounts_outlined,
                    size: 48,
                    color: AbraColors.textDisabled,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No staff members yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AbraColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Invite team members to help manage your operations.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _isTableView ? _buildUsersTable() : _buildUsersListView(),
      ],
    );
  }

  Widget _buildUsersTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AbraColors.textPrimary,
              fontSize: 13,
            ),
            dataTextStyle: const TextStyle(
              color: AbraColors.textPrimary,
              fontSize: 13,
            ),
            columns: const [
              DataColumn(label: Text('Person')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Last seen')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _users.map((s) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.name.isEmpty ? '(No name)' : s.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          s.email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AbraColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AbraColors.skyContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s.roleName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AbraColors.deepBlue,
                        ),
                      ),
                    ),
                  ),
                  DataCell(PortalStatusChip(status: s.status)),
                  DataCell(Text(relativeTime(s.lastSeen))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          tooltip: 'View details',
                          onPressed: () => _showUserDetailsDialog(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit',
                          onPressed: () => _showEditUserDialog(s),
                        ),
                        if (s.status == 'ACTIVE')
                          IconButton(
                            icon: const Icon(Icons.lock_outline, size: 18),
                            tooltip: 'Deactivate',
                            onPressed: () => _toggleUserStatus(s, false),
                          )
                        else if (s.status == 'DEACTIVATED')
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            tooltip: 'Activate',
                            onPressed: () => _toggleUserStatus(s, true),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersListView() {
    return Column(
      children: _users.map((s) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AbraRadius.md),
            side: const BorderSide(color: AbraColors.border),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AbraColors.skyContainer,
              child: Text(
                s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AbraColors.deepBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              s.name.isEmpty ? '(No name)' : s.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${s.email} • ${s.roleName}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PortalStatusChip(status: s.status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  tooltip: 'View details',
                  onPressed: () => _showUserDetailsDialog(s),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => _showEditUserDialog(s),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===== DIALOGS ====================================================================

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'SUPPORT';
    bool isSaving = false;
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add user'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      dialogError!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'name@company.com',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'ADMIN',
                      child: Text('Manager'),
                    ),
                    DropdownMenuItem(
                      value: 'SUPPORT',
                      child: Text('Booking staff'),
                    ),
                    DropdownMenuItem(
                      value: 'ACCOUNTS',
                      child: Text('Accounts'),
                    ),
                  ],
                  onChanged: (v) => setDState(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();

                      if (name.isEmpty || email.isEmpty) {
                        setDState(() => dialogError = 'Please fill in both name and email.');
                        return;
                      }
                      if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
                        setDState(() => dialogError = 'Please enter a valid email address.');
                        return;
                      }

                      setDState(() {
                        isSaving = true;
                        dialogError = null;
                      });

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await ref
                            .read(appDependenciesProvider)
                            .apiClient
                            .post(
                              'client/users',
                              body: {
                                'name': name,
                                'email': email,
                                'role': role,
                              },
                            );

                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Invitation sent')),
                        );
                        if (mounted) {
                          unawaited(_loadUsers());
                        }
                      } catch (e) {
                        setDState(() {
                          isSaving = false;
                          dialogError = e.toString().contains('already exists')
                              ? 'This email already has an account'
                              : 'Failed to invite user: $e';
                        });
                      }
                    },
              child: isSaving
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

  void _showUserDetailsDialog(PortalUserModel user) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.name.isEmpty ? user.email : user.name),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Email', user.email),
              _detailRow('Role', user.roleName),
              _detailRow('Status', user.status),
              _detailRow('Last seen', relativeTime(user.lastSeen)),
              if (user.createdAt != null)
                _detailRow('Created', formatDateTime(user.createdAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AbraColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AbraColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(PortalUserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    String role = user.role.toUpperCase();
    if (role == 'OPERATOR_MANAGER') role = 'ADMIN';
    if (role == 'BOOKING_STAFF') role = 'SUPPORT';
    if (role == 'ACCOUNT_STAFF') role = 'ACCOUNTS';
    if (!['ADMIN', 'SUPPORT', 'ACCOUNTS'].contains(role)) {
      role = 'SUPPORT';
    }

    bool isSaving = false;
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Edit user'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dialogError != null) ...[
                  Text(dialogError!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'ADMIN',
                      child: Text('Manager'),
                    ),
                    DropdownMenuItem(
                      value: 'SUPPORT',
                      child: Text('Booking staff'),
                    ),
                    DropdownMenuItem(
                      value: 'ACCOUNTS',
                      child: Text('Accounts'),
                    ),
                  ],
                  onChanged: (v) => setDState(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDState(() {
                        isSaving = true;
                        dialogError = null;
                      });

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await ref
                            .read(appDependenciesProvider)
                            .apiClient
                            .patch(
                              'client/users/${user.id}',
                              body: {
                                'name': nameCtrl.text.trim(),
                                'role': role,
                              },
                            );

                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Saved')),
                        );
                        if (mounted) {
                          unawaited(_loadUsers());
                        }
                      } catch (e) {
                        setDState(() {
                          isSaving = false;
                          dialogError = 'Failed to update user: $e';
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleUserStatus(PortalUserModel user, bool activate) {
    final actionName = activate ? 'Activate' : 'Deactivate';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionName ${user.name}'),
        content: Text(
          activate
              ? 'This person will be able to sign in and access the portal again.'
              : 'They are signed out at once and cannot sign in until activated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: activate
                ? null
                : FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                final endpoint = activate ? 'activate' : 'deactivate';
                await ref
                    .read(appDependenciesProvider)
                    .apiClient
                    .post('client/users/${user.id}/$endpoint');

                messenger.showSnackBar(
                  SnackBar(content: Text('$actionName successful')),
                );
                if (mounted) {
                  unawaited(_loadUsers());
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Action failed: $e')),
                );
              }
            },
            child: Text(actionName),
          ),
        ],
      ),
    );
  }

  // ===== MATRIX TAB =================================================================

  Widget _buildMatrixView() {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prototype Shield Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(AbraRadius.md),
              border: Border.all(color: const Color(0xFF81C784)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield, color: Color(0xFF2E7D32), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Owner has full access to everything: every page, and every action on it, including '
                    'view, add, edit, delete, import, export, approve and reject, money and settlements, '
                    'settings and integrations, and staff, roles and access. This can never be reduced, '
                    'and there must always be at least one active Owner.',
                    style: TextStyle(
                      color: Color(0xFF1B5E20),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4 Prototype Level Badges
          Row(
            children: [
              _levelBadge('NONE', 'The page is hidden from the menu.'),
              const SizedBox(width: 12),
              _levelBadge('VIEW', 'Can see the page and export.'),
              const SizedBox(width: 12),
              _levelBadge('EDIT', 'Can add, edit, export, and change status.'),
              const SizedBox(width: 12),
              _levelBadge('FULL', 'Can do everything, including delete.'),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'What each role can view and manage in the operator portal:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AbraColors.navy,
            ),
          ),
          const SizedBox(height: 12),

        if (_isLoadingMatrix)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_matrixError != null || _matrixRows == null || _matrixRows!.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.md),
              border: Border.all(color: AbraColors.border),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 40, color: AbraColors.textSecondary),
                SizedBox(height: 12),
                Text(
                  'Not connected yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AbraColors.navy,
                  ),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 820,
              child: Table(
                border: TableBorder.all(color: AbraColors.divider),
                columnWidths: const {
                  0: FlexColumnWidth(3.0),
                  1: FlexColumnWidth(1.8),
                  2: FlexColumnWidth(1.8),
                  3: FlexColumnWidth(1.8),
                  4: FlexColumnWidth(1.8),
                },
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: AbraColors.lightGray),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Area / Page',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            'Owner\n(Full access)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            'Manager',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            'Booking staff',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            'Accounts',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final row in _matrixRows!)
                    _matrixRow(
                      row.title,
                      row.owner,
                      row.manager,
                      row.booking,
                      row.accounts,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelBadge(String level, String description) {
    Color bg;
    Color fg;
    switch (level) {
      case 'FULL':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'EDIT':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case 'VIEW':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = const Color(0xFF757575);
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              level,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: fg,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }

  static TableRow _matrixRow(
    String section,
    String owner,
    String manager,
    String booking,
    String accounts,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            section,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Center(child: Padding(padding: const EdgeInsets.all(8), child: _chip(owner))),
        Center(child: Padding(padding: const EdgeInsets.all(8), child: _chip(manager))),
        Center(child: Padding(padding: const EdgeInsets.all(8), child: _chip(booking))),
        Center(child: Padding(padding: const EdgeInsets.all(8), child: _chip(accounts))),
      ],
    );
  }

  static Widget _chip(String level) {
    Color bg;
    Color fg;
    switch (level) {
      case 'FULL':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'EDIT':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case 'VIEW':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = const Color(0xFF9E9E9E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
