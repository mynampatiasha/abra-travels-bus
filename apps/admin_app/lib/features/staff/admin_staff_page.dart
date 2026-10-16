import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_theme/shared_theme.dart';

class StaffMember {
  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role, // SUPER_ADMIN, ADMIN, SUPPORT, ACCOUNTS
    required this.status, // ACTIVE, INVITED, DEACTIVATED
    required this.mfa,
    required this.lastSeen,
    this.overrides = 0,
  });

  final String id;
  String name;
  final String email;
  String role;
  String status;
  bool mfa;
  DateTime lastSeen;
  int overrides;

  String get roleLabel {
    switch (role) {
      case 'SUPER_ADMIN':
        return 'Super Admin';
      case 'ADMIN':
        return 'Admin';
      case 'SUPPORT':
        return 'Support Agent';
      case 'ACCOUNTS':
        return 'Accountant';
      default:
        return role;
    }
  }
}

class SessionRecord {
  SessionRecord({
    required this.id,
    required this.who,
    required this.device,
    required this.ip,
    required this.signedInAt,
  });

  final String id;
  final String who;
  final String device;
  final String ip;
  final DateTime signedInAt;
}

class AdminStaffPage extends ConsumerStatefulWidget {
  const AdminStaffPage({super.key});

  @override
  ConsumerState<AdminStaffPage> createState() => _AdminStaffPageState();
}

class _AdminStaffPageState extends ConsumerState<AdminStaffPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';

  late List<StaffMember> _staff;
  late List<SessionRecord> _sessions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();

    _staff = [
      StaffMember(
        id: 'SF1',
        name: 'Admin Super',
        email: 'admin.super@abratravels.in',
        role: 'SUPER_ADMIN',
        status: 'ACTIVE',
        mfa: true,
        lastSeen: now.subtract(const Duration(minutes: 5)),
      ),
      StaffMember(
        id: 'SF2',
        name: 'Abishek',
        email: 'abishek@abratravels.in',
        role: 'ADMIN',
        status: 'ACTIVE',
        mfa: true,
        lastSeen: now.subtract(const Duration(hours: 1)),
      ),
      StaffMember(
        id: 'SF3',
        name: 'Mynampati Asha',
        email: 'asha.mynampati@abratravels.in',
        role: 'ADMIN',
        status: 'ACTIVE',
        mfa: true,
        lastSeen: now.subtract(const Duration(hours: 3)),
      ),
      StaffMember(
        id: 'SF4',
        name: 'Divya Rao',
        email: 'divya.rao@abratravels.in',
        role: 'SUPPORT',
        status: 'ACTIVE',
        mfa: true,
        lastSeen: now.subtract(const Duration(minutes: 2)),
        overrides: 1,
      ),
      StaffMember(
        id: 'SF5',
        name: 'Kiran Kumar',
        email: 'kiran.kumar@abratravels.in',
        role: 'SUPPORT',
        status: 'ACTIVE',
        mfa: false,
        lastSeen: now.subtract(const Duration(hours: 4)),
      ),
      StaffMember(
        id: 'SF6',
        name: 'Ravi Teja',
        email: 'ravi.teja@abratravels.in',
        role: 'ACCOUNTS',
        status: 'ACTIVE',
        mfa: true,
        lastSeen: now.subtract(const Duration(hours: 6)),
      ),
      StaffMember(
        id: 'SF7',
        name: 'Sunita Paul',
        email: 'sunita.paul@abratravels.in',
        role: 'ACCOUNTS',
        status: 'DEACTIVATED',
        mfa: true,
        lastSeen: now.subtract(const Duration(days: 14)),
      ),
      StaffMember(
        id: 'SF8',
        name: 'Naveen Babu',
        email: 'naveen.babu@abratravels.in',
        role: 'SUPPORT',
        status: 'INVITED',
        mfa: false,
        lastSeen: now.subtract(const Duration(days: 2)),
      ),
    ];

    _sessions = [
      SessionRecord(
        id: 'SE1',
        who: 'Admin Super',
        device: 'Chrome on Windows 11',
        ip: '49.37.142.88',
        signedInAt: now.subtract(const Duration(hours: 1, minutes: 20)),
      ),
      SessionRecord(
        id: 'SE2',
        who: 'Divya Rao',
        device: 'Safari on Mac OS X',
        ip: '49.37.210.14',
        signedInAt: now.subtract(const Duration(hours: 3)),
      ),
      SessionRecord(
        id: 'SE3',
        who: 'Kiran Kumar',
        device: 'Chrome on Android',
        ip: '49.37.99.231',
        signedInAt: now.subtract(const Duration(hours: 4, minutes: 10)),
      ),
      SessionRecord(
        id: 'SE4',
        who: 'Ravi Teja',
        device: 'Chrome on Windows 11',
        ip: '49.37.18.52',
        signedInAt: now.subtract(const Duration(hours: 6)),
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  Tab(text: 'Staff (${_staff.length})'),
                  const Tab(text: 'Permission matrix'),
                  Tab(text: 'Sessions (${_sessions.length})'),
                ],
                onTap: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),

            IndexedStack(
              index: _tabController.index,
              children: [
                _buildStaffListTab(context),
                _buildPermissionMatrixTab(context),
                _buildSessionsTab(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffListTab(BuildContext context) {
    final filtered = _staff.where((s) {
      if (_roleFilter != 'ALL' && s.role != _roleFilter) return false;
      if (_statusFilter != 'ALL' && s.status != _statusFilter) return false;
      return true;
    }).toList();

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
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _roleFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All roles')),
                      DropdownMenuItem(
                          value: 'SUPER_ADMIN', child: Text('Super Admin')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                      DropdownMenuItem(
                          value: 'SUPPORT', child: Text('Support Agent')),
                      DropdownMenuItem(
                          value: 'ACCOUNTS', child: Text('Accountant')),
                    ],
                    onChanged: (v) => setState(() => _roleFilter = v ?? 'ALL'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'ALL'),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openAddStaffModal(context),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Staff Table
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Person')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Two-step')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Overrides')),
                  DataColumn(label: Text('Last seen')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filtered.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
                        Text(s.overrides > 0 ? '${s.overrides} custom' : '-'),
                      ),
                      DataCell(
                        Text(DateFormat('MMM dd, hh:mm a').format(s.lastSeen)),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: () =>
                                  _openAddStaffModal(context, member: s),
                            ),
                            if (s.status == 'ACTIVE')
                              TextButton(
                                onPressed: () {
                                  if (s.role == 'SUPER_ADMIN' &&
                                      _staff
                                              .where((x) =>
                                                  x.role == 'SUPER_ADMIN' &&
                                                  x.status == 'ACTIVE')
                                              .length <
                                          2) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Keep at least one active Super Admin',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => s.status = 'DEACTIVATED');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Deactivated ${s.name}',
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                ),
                                child: const Text('Deactivate'),
                              )
                            else if (s.status == 'DEACTIVATED')
                              TextButton(
                                onPressed: () {
                                  setState(() => s.status = 'ACTIVE');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Reactivated ${s.name}',
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green.shade700,
                                ),
                                child: const Text('Activate'),
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
        ),
      ],
    );
  }

  Widget _buildPermissionMatrixTab(BuildContext context) {
    final modules = [
      'Overview (Dashboard)',
      'Operators & Drivers',
      'Commercial & Payout',
      'Catalogue & Places',
      'Operations & Live GPS',
      'Sales & Bookings',
      'Customers & Support',
      'Marketing & Banners',
      'Safety & SOS',
      'Insights & Reports',
      'System & Settings',
    ];

    final matrix = {
      'SUPER_ADMIN': List.generate(11, (_) => 'FULL'),
      'ADMIN': [
        'FULL',
        'FULL',
        'EDIT',
        'FULL',
        'FULL',
        'FULL',
        'FULL',
        'FULL',
        'FULL',
        'FULL',
        'VIEW'
      ],
      'SUPPORT': [
        'VIEW',
        'VIEW',
        'VIEW',
        'VIEW',
        'VIEW',
        'EDIT',
        'FULL',
        'VIEW',
        'FULL',
        'VIEW',
        'NONE'
      ],
      'ACCOUNTS': [
        'VIEW',
        'VIEW',
        'FULL',
        'NONE',
        'NONE',
        'FULL',
        'VIEW',
        'NONE',
        'NONE',
        'FULL',
        'NONE'
      ],
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Role permission matrix',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AbraColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Permissions applied to portal staff based on their assigned role tier.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(Colors.grey.shade100),
                  columns: const [
                    DataColumn(label: Text('Module / Area')),
                    DataColumn(label: Text('Super Admin')),
                    DataColumn(label: Text('Admin')),
                    DataColumn(label: Text('Support Agent')),
                    DataColumn(label: Text('Accountant')),
                  ],
                  rows: List.generate(modules.length, (i) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            modules[i],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(_buildPermBadge(matrix['SUPER_ADMIN']![i])),
                        DataCell(_buildPermBadge(matrix['ADMIN']![i])),
                        DataCell(_buildPermBadge(matrix['SUPPORT']![i])),
                        DataCell(_buildPermBadge(matrix['ACCOUNTS']![i])),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            columns: const [
              DataColumn(label: Text('Person')),
              DataColumn(label: Text('Device')),
              DataColumn(label: Text('IP address')),
              DataColumn(label: Text('Signed in')),
              DataColumn(label: Text('Action')),
            ],
            rows: _sessions.map((ses) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      ses.who,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(Text(ses.device)),
                  DataCell(Text(ses.ip)),
                  DataCell(
                    Text(DateFormat('MMM dd, hh:mm a').format(ses.signedInAt)),
                  ),
                  DataCell(
                    TextButton(
                      onPressed: () {
                        setState(() => _sessions.remove(ses));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Session for ${ses.who} ended'),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      child: const Text('Sign out'),
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

  void _openAddStaffModal(BuildContext context, {StaffMember? member}) {
    final nameCtrl = TextEditingController(text: member?.name ?? '');
    final emailCtrl = TextEditingController(text: member?.email ?? '');
    String role = member?.role ?? 'SUPPORT';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMdlState) => AlertDialog(
          title: Text(member == null ? 'Add staff' : 'Edit staff'),
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
                  controller: emailCtrl,
                  enabled: member == null,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'SUPER_ADMIN', child: Text('Super Admin')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    DropdownMenuItem(
                        value: 'SUPPORT', child: Text('Support Agent')),
                    DropdownMenuItem(
                        value: 'ACCOUNTS', child: Text('Accountant')),
                  ],
                  onChanged: (v) => setMdlState(() => role = v ?? 'SUPPORT'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                if (member != null) {
                  setState(() {
                    member.name = nameCtrl.text.trim();
                    member.role = role;
                  });
                } else {
                  setState(() {
                    _staff.add(
                      StaffMember(
                        id: 'SF-${DateTime.now().millisecondsSinceEpoch % 1000}',
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        role: role,
                        status: 'INVITED',
                        mfa: false,
                        lastSeen: DateTime.now(),
                      ),
                    );
                  });
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      member == null
                          ? 'Invitation sent to ${emailCtrl.text.trim()}'
                          : 'Staff member updated',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AbraColors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(member == null ? 'Send invitation' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermBadge(String perm) {
    Color bg;
    Color fg;
    switch (perm) {
      case 'FULL':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'EDIT':
        bg = Colors.blue.shade50;
        fg = AbraColors.blue;
        break;
      case 'VIEW':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'NONE':
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        perm,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 10,
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
