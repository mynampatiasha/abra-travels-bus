import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientStaffRolesScreen extends StatefulWidget {
  const ClientStaffRolesScreen({super.key});

  @override
  State<ClientStaffRolesScreen> createState() => _ClientStaffRolesScreenState();
}

class _ClientStaffRolesScreenState extends State<ClientStaffRolesScreen> {
  late List<Map<String, dynamic>> _staff;
  String _activeTab = 'list'; // 'list' (Portal users), 'mat' (Permission matrix)

  @override
  void initState() {
    super.initState();
    _staff = List.from(kMockStaff);
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
            subtitle: 'Who in your company can use this portal, and what they can do.',
            breadcrumbs: const ['System', 'Staff and roles'],
            actions: [
              if (_activeTab == 'list')
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add user'),
                  style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                  onPressed: () => _showAddStaffDialog(context),
                ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),

          // Prototype Tabs: [Portal users (3) | Permission matrix]
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
                _tabChip('list', 'Portal users (${_staff.length})'),
                const SizedBox(width: 4),
                _tabChip('mat', 'Permission matrix'),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),

          if (_activeTab == 'list') _buildUsersTable() else _buildMatrixView(),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) {
    final isSel = _activeTab == key;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = key),
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

  Widget _buildUsersTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: _staff.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.manage_accounts_outlined, size: 48, color: AbraColors.textDisabled),
                    SizedBox(height: 12),
                    Text('No staff members yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Invite team members to help manage your operations.', style: TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                  ],
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
            dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
            columns: const [
              DataColumn(label: Text('Person')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Last seen')),
            ],
            rows: _staff.map((s) =>
              DataRow(cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${s['email']}', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                    ],
                  ),
                ),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AbraColors.skyContainer, borderRadius: BorderRadius.circular(4)),
                  child: Text('${s['roleLabel'] ?? s['role']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AbraColors.deepBlue)),
                )),
                DataCell(PortalStatusChip(status: '${s['status']}')),
                DataCell(Text(relativeTime(s['last'] as String? ?? ''))),
              ]),
            ).toList(),
          ),
        ),
      ),
    );
  }

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
          const Text('Permission matrix', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('What each role can view and manage in the operator portal:', style: TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 650,
              child: Table(
                border: TableBorder.all(color: AbraColors.divider),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: AbraColors.lightGray),
                    children: [
                      Padding(padding: EdgeInsets.all(10), child: Text('Section', style: TextStyle(fontWeight: FontWeight.w700))),
                      Padding(padding: EdgeInsets.all(10), child: Center(child: Text('Owner', style: TextStyle(fontWeight: FontWeight.w700)))),
                      Padding(padding: EdgeInsets.all(10), child: Center(child: Text('Manager', style: TextStyle(fontWeight: FontWeight.w700)))),
                      Padding(padding: EdgeInsets.all(10), child: Center(child: Text('Booking staff', style: TextStyle(fontWeight: FontWeight.w700)))),
                    ],
                  ),
                  _MatrixRow('Dashboard & Analytics', true, true, false),
                  _MatrixRow('Company Profile & Bank Payout', true, false, false),
                  _MatrixRow('Fleet & Buses', true, true, false),
                  _MatrixRow('Drivers & Crew Assignment', true, true, false),
                  _MatrixRow('Routes & Stops', true, true, false),
                  _MatrixRow('Schedules & Trips Creation', true, true, false),
                  _MatrixRow('Customer Bookings', true, true, true),
                  _MatrixRow('Offers & Discounts', true, true, false),
                  _MatrixRow('Earnings, Settlements & Bank Statements', true, false, false),
                  _MatrixRow('Staff & Roles Management', true, false, false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'SUPPORT';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add user'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name *')),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *', hintText: 'name@kaveriexpress.in')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Manager (Admin)')),
                    DropdownMenuItem(value: 'SUPPORT', child: Text('Booking staff (Support)')),
                    DropdownMenuItem(value: 'ACCOUNTS', child: Text('Accounts')),
                  ],
                  onChanged: (v) => setDState(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                  setState(() {
                    _staff.add({
                      'id': 'OU${_staff.length + 1}',
                      'operatorId': 'OP1',
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': role,
                      'roleLabel': role == 'ADMIN' ? 'Manager' : role == 'ACCOUNTS' ? 'Accounts' : 'Booking staff',
                      'status': 'INVITED',
                      'last': DateTime.now().toIso8601String(),
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent')));
                }
              },
              child: const Text('Send invitation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatrixRow extends TableRow {
  _MatrixRow(String section, bool owner, bool manager, bool support)
      : super(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(section, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                owner ? Icons.check_circle : Icons.remove,
                size: 18,
                color: owner ? AbraColors.teal : AbraColors.textDisabled,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                manager ? Icons.check_circle : Icons.remove,
                size: 18,
                color: manager ? AbraColors.teal : AbraColors.textDisabled,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                support ? Icons.check_circle : Icons.remove,
                size: 18,
                color: support ? AbraColors.teal : AbraColors.textDisabled,
              ),
            ),
          ),
        ]);
}
