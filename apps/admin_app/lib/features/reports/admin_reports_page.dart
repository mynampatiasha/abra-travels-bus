import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class ReportItem {
  ReportItem({
    required this.id,
    required this.label,
    required this.value, // numeric value (amount in paise, occupancy %, etc.)
    required this.formattedValue,
    this.secondary = '',
    this.bookingsCount = 0,
  });

  final String id;
  final String label;
  final double value;
  final String formattedValue;
  final String secondary;
  final int bookingsCount;
}

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _rangeDays = 30;
  ReportItem? _selectedItem;

  final List<String> _tabs = [
    'Sales',
    'Operators',
    'Routes',
    'Cancellations',
    'Refunds',
    'Occupancy',
    'Commission',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = _tabs[_tabController.index].toLowerCase();
    final items = _getItemsForTab(activeTab);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Performance and analytics for the last $_rangeDays days.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Period filters (7, 30, 90)
                    ...[7, 30, 90].map((d) {
                      final isSelected = _rangeDays == d;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _rangeDays = d;
                            _selectedItem = null;
                          }),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected
                                ? AbraColors.navy
                                : Colors.white,
                            foregroundColor: isSelected
                                ? Colors.white
                                : Colors.grey.shade800,
                            side: BorderSide(
                              color: isSelected
                                  ? AbraColors.navy
                                  : Colors.grey.shade300,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          child: Text('$d days'),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report ready for print / PDF'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AbraColors.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs Header
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AbraColors.blue,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AbraColors.blue,
                indicatorWeight: 3,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
                onTap: (_) => setState(() => _selectedItem = null),
              ),
            ),
            const SizedBox(height: 20),

            // Bar Chart Card
            Card(
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
                    Text(
                      _getChartTitle(activeTab),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click a bar to open detailed drilldown and bookings breakdown.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Render Bars
                    ...items.map((it) {
                      final maxVal = items.isNotEmpty
                          ? items.map((x) => x.value).reduce((a, b) => a > b ? a : b)
                          : 1.0;
                      final ratio = maxVal > 0 ? (it.value / maxVal) : 0.0;
                      final isSelected = _selectedItem?.id == it.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedItem = isSelected ? null : it;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AbraColors.skyBlue.withValues(alpha: 0.2)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AbraColors.blue
                                    : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      it.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      it.formattedValue,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AbraColors.navy,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio.clamp(0.02, 1.0),
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isSelected
                                          ? AbraColors.blue
                                          : Colors.blue.shade400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Drilldown Details Card (when a bar is clicked)
            if (_selectedItem != null) ...[
              _buildDetailDrilldownCard(context, _selectedItem!, activeTab, items),
              const SizedBox(height: 20),
            ],

            // Master Data Table for current tab
            Card(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Summary data table (${_tabs[_tabController.index]})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AbraColors.navy,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Exported ${activeTab}_report_$_rangeDays'
                                  'd.csv',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download, size: 15),
                          label: const Text('Excel (CSV)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AbraColors.navy,
                          ),
                        ),
                      ],
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
                            DataColumn(label: Text('Item / Segment')),
                            DataColumn(label: Text('Metric')),
                            DataColumn(label: Text('Bookings')),
                            DataColumn(label: Text('Secondary')),
                          ],
                          rows: items.map((it) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    it.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    it.formattedValue,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AbraColors.navy,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${it.bookingsCount}')),
                                DataCell(Text(it.secondary)),
                              ],
                            );
                          }).toList(),
                        ),
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
  }

  Widget _buildDetailDrilldownCard(
    BuildContext context,
    ReportItem item,
    String tab,
    List<ReportItem> allItems,
  ) {
    final total = allItems.map((x) => x.value).fold<double>(0, (a, b) => a + b);
    final share = total > 0 ? (item.value / total * 100).toStringAsFixed(1) : '0';
    final rank = allItems.indexWhere((x) => x.id == item.id) + 1;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AbraColors.blue, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getChartTitle(tab)}: ${item.label}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Exporting rows for ${item.label}...',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Export these rows'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _selectedItem = null),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stat Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildDrillStat(
                    'Value',
                    item.formattedValue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDrillStat(
                    'Share of total',
                    '$share%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDrillStat(
                    'Rank',
                    '$rank of ${allItems.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDrillStat(
                    'Bookings behind',
                    '${item.bookingsCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            const Text(
              'What this means',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.label} represents $share% of the total recorded metric during the last $_rangeDays days. Performance is ranked #$rank amongst comparable records.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AbraColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  String _getChartTitle(String tab) {
    switch (tab) {
      case 'sales':
        return 'Gross sales by day';
      case 'operators':
        return 'Sales by operator';
      case 'routes':
        return 'Sales by route';
      case 'cancellations':
        return 'Cancelled booking amounts';
      case 'refunds':
        return 'Refund amounts';
      case 'occupancy':
        return 'Occupancy by trip';
      case 'commission':
        return 'Commission earned by operator';
      default:
        return 'Report Performance';
    }
  }

  List<ReportItem> _getItemsForTab(String tab) {
    switch (tab) {
      case 'sales':
        return [
          ReportItem(
            id: 'S1',
            label: 'Today (Live)',
            value: 248000,
            formattedValue: '₹2,48,000',
            secondary: '210 bookings',
            bookingsCount: 210,
          ),
          ReportItem(
            id: 'S2',
            label: 'Yesterday',
            value: 312000,
            formattedValue: '₹3,12,000',
            secondary: '264 bookings',
            bookingsCount: 264,
          ),
          ReportItem(
            id: 'S3',
            label: '2 days ago',
            value: 285000,
            formattedValue: '₹2,85,000',
            secondary: '240 bookings',
            bookingsCount: 240,
          ),
          ReportItem(
            id: 'S4',
            label: '3 days ago',
            value: 260000,
            formattedValue: '₹2,60,000',
            secondary: '225 bookings',
            bookingsCount: 225,
          ),
          ReportItem(
            id: 'S5',
            label: '4 days ago',
            value: 340000,
            formattedValue: '₹3,40,000',
            secondary: '290 bookings',
            bookingsCount: 290,
          ),
        ];
      case 'operators':
        return [
          ReportItem(
            id: 'O1',
            label: 'Kaveri Express',
            value: 1420000,
            formattedValue: '₹14,20,000',
            secondary: '1,210 bookings • 4.8★',
            bookingsCount: 1210,
          ),
          ReportItem(
            id: 'O2',
            label: 'Godavari Lines',
            value: 1180000,
            formattedValue: '₹11,80,000',
            secondary: '980 bookings • 4.6★',
            bookingsCount: 980,
          ),
          ReportItem(
            id: 'O3',
            label: 'Deccan Voyager',
            value: 940000,
            formattedValue: '₹9,40,000',
            secondary: '810 bookings • 4.7★',
            bookingsCount: 810,
          ),
          ReportItem(
            id: 'O4',
            label: 'Charminar Tours',
            value: 820000,
            formattedValue: '₹8,20,000',
            secondary: '720 bookings • 4.5★',
            bookingsCount: 720,
          ),
          ReportItem(
            id: 'O5',
            label: 'Southern Star Travels',
            value: 650000,
            formattedValue: '₹6,50,000',
            secondary: '550 bookings • 4.3★',
            bookingsCount: 550,
          ),
        ];
      case 'routes':
        return [
          ReportItem(
            id: 'R1',
            label: 'Hyderabad to Bengaluru',
            value: 1850000,
            formattedValue: '₹18,50,000',
            secondary: '88% avg occupancy',
            bookingsCount: 1540,
          ),
          ReportItem(
            id: 'R2',
            label: 'Bengaluru to Chennai',
            value: 1240000,
            formattedValue: '₹12,40,000',
            secondary: '82% avg occupancy',
            bookingsCount: 1100,
          ),
          ReportItem(
            id: 'R3',
            label: 'Hyderabad to Visakhapatnam',
            value: 980000,
            formattedValue: '₹9,80,000',
            secondary: '79% avg occupancy',
            bookingsCount: 820,
          ),
          ReportItem(
            id: 'R4',
            label: 'Chennai to Coimbatore',
            value: 760000,
            formattedValue: '₹7,60,000',
            secondary: '75% avg occupancy',
            bookingsCount: 650,
          ),
          ReportItem(
            id: 'R5',
            label: 'Vijayawada to Hyderabad',
            value: 580000,
            formattedValue: '₹5,80,000',
            secondary: '71% avg occupancy',
            bookingsCount: 510,
          ),
        ];
      case 'cancellations':
        return [
          ReportItem(
            id: 'C1',
            label: 'Passenger cancelled (>24h prior)',
            value: 142000,
            formattedValue: '₹1,42,000',
            secondary: '90% refund disbursed',
            bookingsCount: 118,
          ),
          ReportItem(
            id: 'C2',
            label: 'Passenger cancelled (12-24h prior)',
            value: 84000,
            formattedValue: '₹84,000',
            secondary: '75% refund disbursed',
            bookingsCount: 68,
          ),
          ReportItem(
            id: 'C3',
            label: 'Operator breakdown / cancellation',
            value: 62000,
            formattedValue: '₹62,000',
            secondary: '100% full refund',
            bookingsCount: 45,
          ),
        ];
      case 'refunds':
        return [
          ReportItem(
            id: 'RF1',
            label: 'UPI Auto-reversal',
            value: 195000,
            formattedValue: '₹1,95,000',
            secondary: 'Instant credit via Razorpay',
            bookingsCount: 160,
          ),
          ReportItem(
            id: 'RF2',
            label: 'Card / Netbanking refund',
            value: 78000,
            formattedValue: '₹78,000',
            secondary: '3-5 business days',
            bookingsCount: 58,
          ),
          ReportItem(
            id: 'RF3',
            label: 'Abra Wallet credit',
            value: 34000,
            formattedValue: '₹34,000',
            secondary: 'Instant wallet cash',
            bookingsCount: 32,
          ),
        ];
      case 'occupancy':
        return [
          ReportItem(
            id: 'OC1',
            label: 'TRIP-1001 (HYD - BLR 9:30 PM)',
            value: 94,
            formattedValue: '94% full',
            secondary: '34 of 36 seats booked',
            bookingsCount: 34,
          ),
          ReportItem(
            id: 'OC2',
            label: 'TRIP-1002 (BLR - MAA 10:00 PM)',
            value: 88,
            formattedValue: '88% full',
            secondary: '32 of 36 seats booked',
            bookingsCount: 32,
          ),
          ReportItem(
            id: 'OC3',
            label: 'TRIP-1003 (HYD - VIZAG 8:30 PM)',
            value: 83,
            formattedValue: '83% full',
            secondary: '30 of 36 seats booked',
            bookingsCount: 30,
          ),
          ReportItem(
            id: 'OC4',
            label: 'TRIP-1004 (MAA - CJB 11:15 PM)',
            value: 75,
            formattedValue: '75% full',
            secondary: '27 of 36 seats booked',
            bookingsCount: 27,
          ),
        ];
      case 'commission':
      default:
        return [
          ReportItem(
            id: 'CM1',
            label: 'Kaveri Express',
            value: 142000,
            formattedValue: '₹1,42,000',
            secondary: '10% agreed commission',
            bookingsCount: 1210,
          ),
          ReportItem(
            id: 'CM2',
            label: 'Godavari Lines',
            value: 118000,
            formattedValue: '₹1,18,000',
            secondary: '10% agreed commission',
            bookingsCount: 980,
          ),
          ReportItem(
            id: 'CM3',
            label: 'Deccan Voyager',
            value: 94000,
            formattedValue: '₹94,000',
            secondary: '10% agreed commission',
            bookingsCount: 810,
          ),
          ReportItem(
            id: 'CM4',
            label: 'Charminar Tours',
            value: 82000,
            formattedValue: '₹82,000',
            secondary: '10% agreed commission',
            bookingsCount: 720,
          ),
        ];
    }
  }
}
