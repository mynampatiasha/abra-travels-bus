import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class DriverReportRecord {
  DriverReportRecord({
    required this.id,
    required this.driverName,
    required this.operator,
    required this.busReg,
    required this.breathalyzerBac,
    required this.maxSpeed,
    required this.dutyHours,
    required this.status, // COMPLIANT, WARNING, SUSPENDED
    required this.lastTested,
    this.notes = '',
  });

  final String id;
  final String driverName;
  final String operator;
  final String busReg;
  final double breathalyzerBac;
  final int maxSpeed;
  final double dutyHours;
  String status;
  final DateTime lastTested;
  String notes;
}

class AdminDriverReportsPage extends ConsumerStatefulWidget {
  const AdminDriverReportsPage({super.key});

  @override
  ConsumerState<AdminDriverReportsPage> createState() =>
      _AdminDriverReportsPageState();
}

class _AdminDriverReportsPageState
    extends ConsumerState<AdminDriverReportsPage> {
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  late List<DriverReportRecord> _reports;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _reports = [
      DriverReportRecord(
        id: 'DRV-101',
        driverName: 'Rameshwar Yadav',
        operator: 'Kaveri Express',
        busReg: 'AP-28-Z-1001',
        breathalyzerBac: 0.00,
        maxSpeed: 74,
        dutyHours: 6.5,
        status: 'COMPLIANT',
        lastTested: now.subtract(const Duration(hours: 1)),
        notes: 'Pre-departure check passed at Miyapur hub.',
      ),
      DriverReportRecord(
        id: 'DRV-102',
        driverName: 'Suresh Babu',
        operator: 'Godavari Lines',
        busReg: 'TS-09-UB-4421',
        breathalyzerBac: 0.00,
        maxSpeed: 88, // Over speed limit
        dutyHours: 7.2,
        status: 'WARNING',
        lastTested: now.subtract(const Duration(hours: 3)),
        notes: 'Speed alert recorded on NH65 (88 km/h in 80 zone).',
      ),
      DriverReportRecord(
        id: 'DRV-103',
        driverName: 'Dharma Teja',
        operator: 'Deccan Voyager',
        busReg: 'KA-01-MJ-8877',
        breathalyzerBac: 0.00,
        maxSpeed: 68,
        dutyHours: 5.0,
        status: 'COMPLIANT',
        lastTested: now.subtract(const Duration(minutes: 40)),
      ),
      DriverReportRecord(
        id: 'DRV-104',
        driverName: 'Mohd. Farooq',
        operator: 'Charminar Tours',
        busReg: 'AP-16-TX-9900',
        breathalyzerBac: 0.02, // Failed BAC
        maxSpeed: 0,
        dutyHours: 0.0,
        status: 'SUSPENDED',
        lastTested: now.subtract(const Duration(hours: 8)),
        notes: 'Positive BAC test during depot check. Trip reassigned.',
      ),
      DriverReportRecord(
        id: 'DRV-105',
        driverName: 'Venkat Reddy',
        operator: 'Southern Star Travels',
        busReg: 'TN-01-AB-1234',
        breathalyzerBac: 0.00,
        maxSpeed: 72,
        dutyHours: 8.5, // High duty
        status: 'WARNING',
        lastTested: now.subtract(const Duration(hours: 2)),
        notes: 'Exceeded 8h continuous limit. Driver relay engaged.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _reports.where((r) {
      if (_selectedStatus != 'ALL' && r.status != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = r.driverName.toLowerCase().contains(q) ||
            r.operator.toLowerCase().contains(q) ||
            r.busReg.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver reports & compliance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Incident records, behavior complaints and breathalyzer compliance.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Driver compliance logs exported to CSV'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _openReportIncidentModal,
                      icon: const Icon(Icons.add_alert, size: 16),
                      label: const Text('Report incident'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AbraColors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Active Drivers',
                    value: '${_reports.length}',
                    icon: Icons.people_outline,
                    color: AbraColors.blue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Breathalyzer Compliance',
                    value: '99.2%',
                    icon: Icons.health_and_safety_outlined,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Speed Violations',
                    value: '1',
                    icon: Icons.speed,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Suspended Drivers',
                    value: '1',
                    icon: Icons.block,
                    color: Colors.red.shade700,
                    isAlert: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Bar
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
                      width: 240,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search driver, operator, bus...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        isDense: true,
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
                              value: 'COMPLIANT', child: Text('Compliant')),
                          DropdownMenuItem(
                              value: 'WARNING', child: Text('Warning')),
                          DropdownMenuItem(
                              value: 'SUSPENDED', child: Text('Suspended')),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedStatus = v ?? 'ALL'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Table
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
                    headingRowColor:
                        WidgetStateProperty.all(Colors.grey.shade100),
                    columns: const [
                      DataColumn(label: Text('Driver')),
                      DataColumn(label: Text('Operator')),
                      DataColumn(label: Text('Assigned Bus')),
                      DataColumn(label: Text('Breathalyzer (BAC)')),
                      DataColumn(label: Text('Top Speed')),
                      DataColumn(label: Text('Duty Hours')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filtered.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  r.driverName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  r.id,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(r.operator)),
                          DataCell(Text(r.busReg)),
                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  r.breathalyzerBac == 0.0
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 14,
                                  color: r.breathalyzerBac == 0.0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${r.breathalyzerBac.toStringAsFixed(2)}% BAC',
                                  style: TextStyle(
                                    color: r.breathalyzerBac == 0.0
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              '${r.maxSpeed} km/h',
                              style: TextStyle(
                                color: r.maxSpeed > 80
                                    ? Colors.orange.shade800
                                    : Colors.black87,
                                fontWeight: r.maxSpeed > 80
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          DataCell(Text('${r.dutyHours} h')),
                          DataCell(_buildStatusBadge(r.status)),
                          DataCell(
                            Row(
                              children: [
                                if (r.status != 'SUSPENDED')
                                  TextButton(
                                    onPressed: () {
                                      setState(() => r.status = 'SUSPENDED');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Driver ${r.driverName} has been suspended.',
                                          ),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                    child: const Text('Suspend'),
                                  )
                                else
                                  TextButton(
                                    onPressed: () {
                                      setState(() => r.status = 'COMPLIANT');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Driver ${r.driverName} reinstated.',
                                          ),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                    ),
                                    child: const Text('Reinstate'),
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
        ),
      ),
    );
  }

  void _openReportIncidentModal() {
    final driverCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Driver Incident'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: driverCtrl,
                decoration: const InputDecoration(
                  labelText: 'Driver name or ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Incident description & observations',
                  border: OutlineInputBorder(),
                ),
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
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Incident logged and forwarded to Safety lead'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AbraColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Incident'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? Colors.red.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAlert ? Colors.red.shade900 : Colors.grey.shade600,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.red.shade900 : AbraColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'COMPLIANT':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'WARNING':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'SUSPENDED':
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
