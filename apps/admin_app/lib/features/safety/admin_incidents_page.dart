import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'safety_mock_store.dart';

/// Incidents and Trip Sharing Audit page matching prototypes/admin_demo_model.html.
class AdminIncidentsPage extends ConsumerStatefulWidget {
  const AdminIncidentsPage({super.key});

  @override
  ConsumerState<AdminIncidentsPage> createState() => _AdminIncidentsPageState();
}

class _AdminIncidentsPageState extends ConsumerState<AdminIncidentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Incident filters
  final _searchIncidentsController = TextEditingController();
  String _incidentsSearchQuery = '';
  String _selectedIncidentStatus = 'ALL';
  String _selectedIncidentSeverity = 'ALL';

  // Sharing filters
  final _searchSharingController = TextEditingController();
  String _sharingSearchQuery = '';
  String _selectedSharingStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchIncidentsController.dispose();
    _searchSharingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safetyState = ref.watch(safetyStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: [
                Text(
                  'Safety',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Incidents',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incidents and trip sharing',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Safety complaints and who customers share their trips with.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showLogIncidentDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log incident'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AbraColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs Header
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AbraColors.blue,
                unselectedLabelColor:
                    isDark ? const Color(0xFF8BA2B9) : const Color(0xFF64748B),
                indicatorColor: AbraColors.blue,
                indicatorWeight: 2,
                tabs: [
                  Tab(
                    child: Row(
                      children: [
                        const Text('Incidents'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${safetyState.incidents.length}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        const Text('Trip sharing audit'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${safetyState.sharing.length}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab View Body
            SizedBox(
              height: 680,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIncidentsTab(safetyState, surfaceColor, borderColor, isDark),
                  _buildTripSharingTab(safetyState, surfaceColor, borderColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentsTab(
    SafetyState safetyState,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    // Filter incidents
    final filtered = safetyState.incidents.where((i) {
      if (_selectedIncidentStatus != 'ALL' && i.status != _selectedIncidentStatus) {
        return false;
      }
      if (_selectedIncidentSeverity != 'ALL' &&
          i.severity != _selectedIncidentSeverity) {
        return false;
      }
      if (_incidentsSearchQuery.isNotEmpty) {
        final q = _incidentsSearchQuery.toLowerCase();
        final matches = i.id.toLowerCase().contains(q) ||
            i.title.toLowerCase().contains(q) ||
            i.customer.toLowerCase().contains(q) ||
            i.trip.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchIncidentsController,
                    onChanged: (val) {
                      setState(() {
                        _incidentsSearchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search incidents by ID, title, customer, trip...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _incidentsSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchIncidentsController.clear();
                                setState(() {
                                  _incidentsSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status filter
              DropdownButton<String>(
                value: _selectedIncidentStatus,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                  DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In progress')),
                  DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedIncidentStatus = val ?? 'ALL';
                  });
                },
              ),
              const SizedBox(width: 12),
              // Severity filter
              DropdownButton<String>(
                value: _selectedIncidentSeverity,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Severity: All')),
                  DropdownMenuItem(value: 'HIGH', child: Text('High')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                  DropdownMenuItem(value: 'LOW', child: Text('Low')),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedIncidentSeverity = val ?? 'ALL';
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No incidents match the selected filters'),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      ),
                      columns: const [
                        DataColumn(label: Text('Incident')),
                        DataColumn(label: Text('Reported by')),
                        DataColumn(label: Text('About')),
                        DataColumn(label: Text('Severity')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Trip')),
                        DataColumn(label: Text('Reported')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((inc) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    inc.id,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    inc.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF8BA2B9)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(inc.customer)),
                            DataCell(Text(inc.against)),
                            DataCell(_buildSeverityChip(inc.severity, isDark)),
                            DataCell(_buildIncidentStatusChip(inc.status, isDark)),
                            DataCell(
                              Text(
                                inc.trip,
                                style: const TextStyle(
                                  color: AbraColors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            DataCell(Text(formatRelativeTime(inc.at))),
                            DataCell(
                              OutlinedButton(
                                onPressed: () => _showIncidentDetailModal(context, inc),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('View'),
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

  Widget _buildTripSharingTab(
    SafetyState safetyState,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    final filtered = safetyState.sharing.where((s) {
      if (_selectedSharingStatus != 'ALL' && s.status != _selectedSharingStatus) {
        return false;
      }
      if (_sharingSearchQuery.isNotEmpty) {
        final q = _sharingSearchQuery.toLowerCase();
        final matches = s.customer.toLowerCase().contains(q) ||
            s.trip.toLowerCase().contains(q) ||
            s.link.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchSharingController,
                    onChanged: (val) {
                      setState(() {
                        _sharingSearchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by customer, trip ID, or link...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _sharingSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchSharingController.clear();
                                setState(() {
                                  _sharingSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedSharingStatus,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedSharingStatus = val ?? 'ALL';
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No trip sharing links match filters'),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      ),
                      columns: const [
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Trip')),
                        DataColumn(label: Text('Sharing Link')),
                        DataColumn(label: Text('Times opened')),
                        DataColumn(label: Text('Shared')),
                        DataColumn(label: Text('Expires')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((shr) {
                        final isActive = shr.status == 'ACTIVE';
                        return DataRow(
                          cells: [
                            DataCell(Text(shr.customer, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(shr.trip)),
                            DataCell(
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: 'https://${shr.link}'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Link copied to clipboard')),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      shr.link,
                                      style: const TextStyle(
                                        color: AbraColors.blue,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy, size: 14, color: AbraColors.blue),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text('${shr.opened} times')),
                            DataCell(Text(formatRelativeTime(shr.created))),
                            DataCell(Text(formatDateTime(shr.expires))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  shr.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? const Color(0xFF16A34A)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              isActive
                                  ? OutlinedButton.icon(
                                      onPressed: () {
                                        ref
                                            .read(safetyStoreProvider.notifier)
                                            .revokeSharingLink(shr.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Link revoked')),
                                        );
                                      },
                                      icon: const Icon(Icons.link_off, size: 14),
                                      label: const Text('Revoke link'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFDC2626),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    )
                                  : const Text('-', style: TextStyle(color: Colors.grey)),
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

  Widget _buildSeverityChip(String severity, bool isDark) {
    Color bg;
    Color fg;

    switch (severity) {
      case 'HIGH':
        bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
      case 'MEDIUM':
        bg = isDark ? const Color(0xFF332005) : const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
      case 'LOW':
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        severity,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildIncidentStatusChip(String status, bool isDark) {
    Color bg;
    Color fg;

    switch (status) {
      case 'OPEN':
        bg = isDark ? const Color(0xFF332005) : const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
      case 'IN_PROGRESS':
        bg = isDark ? const Color(0xFF0C2237) : const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
      case 'CLOSED':
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showLogIncidentDialog(BuildContext context) {
    final titleController = TextEditingController();
    final customerController = TextEditingController(text: 'Aarav Sharma');
    final tripController = TextEditingController(text: 'TRP-3003');
    final noteController = TextEditingController();
    String against = 'Driver';
    String severity = 'MEDIUM';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Log incident'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'What happened *',
                          hintText: 'Brief summary of the incident',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: customerController,
                        decoration: const InputDecoration(
                          labelText: 'Reported by (Customer name) *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: against,
                        decoration: const InputDecoration(
                          labelText: 'About',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Driver', child: Text('Driver')),
                          DropdownMenuItem(value: 'Conductor', child: Text('Conductor')),
                          DropdownMenuItem(value: 'Co-passenger', child: Text('Co-passenger')),
                          DropdownMenuItem(value: 'Operator', child: Text('Operator')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => against = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: severity,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'HIGH', child: Text('High')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                          DropdownMenuItem(value: 'LOW', child: Text('Low')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => severity = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tripController,
                        decoration: const InputDecoration(
                          labelText: 'Trip ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Initial notes',
                          hintText: 'Action taken or safety team log',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final customer = customerController.text.trim();
                    if (title.isEmpty || customer.isEmpty) return;
                    ref.read(safetyStoreProvider.notifier).logIncident(
                      title: title,
                      customer: customer,
                      against: against,
                      severity: severity,
                      trip: tripController.text.trim(),
                      notes: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : 'Logged by Super Admin',
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Incident logged')),
                    );
                  },
                  child: const Text('Log'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showIncidentDetailModal(BuildContext context, IncidentRecord inc) {
    String currentStatus = inc.status;
    final noteController = TextEditingController();
    final proofController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('${inc.id} - ${inc.title}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModalRow('Reporter', inc.customer),
                      _buildModalRow('About', inc.against),
                      _buildModalRow('Trip', inc.trip),
                      _buildModalRow('Severity', inc.severity),
                      _buildModalRow('Reported at', formatDateTime(inc.at)),
                      _buildModalRow('Current Notes', inc.notes),
                      if (inc.files.isNotEmpty)
                        _buildModalRow('Attached Proof', inc.files.join(', ')),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: currentStatus,
                        decoration: const InputDecoration(
                          labelText: 'Change status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                          DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In progress')),
                          DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => currentStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Add note',
                          hintText: 'Enter internal notes...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: proofController,
                        decoration: const InputDecoration(
                          labelText: 'Attach proof filename (optional)',
                          hintText: 'e.g. proof_photo.jpg',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_file),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final note = noteController.text.trim();
                    final proof = proofController.text.trim();
                    ref.read(safetyStoreProvider.notifier).updateIncident(
                      id: inc.id,
                      status: currentStatus,
                      note: note.isNotEmpty ? note : null,
                      newProofFiles: proof.isNotEmpty ? [proof] : null,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Incident updated')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
