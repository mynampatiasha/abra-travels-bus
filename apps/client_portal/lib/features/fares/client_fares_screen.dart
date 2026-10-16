import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientFaresScreen extends StatefulWidget {
  const ClientFaresScreen({super.key});

  @override
  State<ClientFaresScreen> createState() => _ClientFaresScreenState();
}

class _ClientFaresScreenState extends State<ClientFaresScreen> {
  late List<Map<String, dynamic>> _fares;

  @override
  void initState() {
    super.initState();
    _fares = List.from(kMockFares);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Fares',
            subtitle: 'Your fare per seat. Customers pay your fare plus Abra commission, GST and a convenience fee.',
            breadcrumbs: const ['Sales setup', 'Fares'],
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New fare'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: () => _showAddFareDialog(context),
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
            child: _fares.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.local_offer_outlined, size: 48, color: AbraColors.textDisabled),
                          const SizedBox(height: 12),
                          const Text('No fares yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Set fares for your routes and bus types.', style: TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New fare'),
                            style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                            onPressed: () => _showAddFareDialog(context),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                      dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                      columns: const [
                        DataColumn(label: Text('Route')),
                        DataColumn(label: Text('Seat type')),
                        DataColumn(label: Text('Weekday')),
                        DataColumn(label: Text('Weekend')),
                        DataColumn(label: Text('Festival')),
                        DataColumn(label: Text('Customer pays (weekday)')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _fares.map((f) {
                        final calc = priceBreakdown(f['weekday'] as int);
                        final festivalPaise = ((f['weekend'] as int) * 1.15).round();

                        return DataRow(cells: [
                          DataCell(Text('${f['route']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text('${f['seatType']}')),
                          DataCell(Text(formatRs(f['weekday'] as int))),
                          DataCell(Text(formatRs(f['weekend'] as int))),
                          DataCell(Text(formatRs(festivalPaise))),
                          DataCell(Text(formatRs(calc['total'] as int), style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.tealDark))),
                          DataCell(PortalStatusChip(status: '${f['status']}')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFareDialog(BuildContext context) {
    int weekday = 80000;
    int weekend = 90000;
    int festival = 110000;
    String route = kMockRoutes.isNotEmpty ? kMockRoutes.first['name'] as String : 'General Route';
    String seatType = 'AC Sleeper';
    String status = 'ACTIVE';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final calc = priceBreakdown(weekday);
          return AlertDialog(
            title: const Text('New fare'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: route,
                      decoration: const InputDecoration(labelText: 'Route'),
                      items: (kMockRoutes.isNotEmpty
                          ? kMockRoutes.map((r) => DropdownMenuItem(value: '${r['name']}', child: Text('${r['name']}'))).toList()
                          : [const DropdownMenuItem(value: 'General Route', child: Text('General Route'))]),
                      onChanged: (v) => setDState(() => route = v ?? route),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: seatType,
                      decoration: const InputDecoration(labelText: 'Seat type'),
                      items: const [
                        DropdownMenuItem(value: 'AC Sleeper', child: Text('AC Sleeper')),
                        DropdownMenuItem(value: 'AC Seater', child: Text('AC Seater')),
                        DropdownMenuItem(value: 'Non-AC Sleeper', child: Text('Non-AC Sleeper')),
                      ],
                      onChanged: (v) => setDState(() => seatType = v ?? seatType),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Weekday fare (Rs) *'),
                      controller: TextEditingController(text: '${weekday ~/ 100}'),
                      onChanged: (v) => setDState(() => weekday = ((int.tryParse(v) ?? 0) * 100)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Weekend fare (Rs) *'),
                      controller: TextEditingController(text: '${weekend ~/ 100}'),
                      onChanged: (v) => setDState(() => weekend = ((int.tryParse(v) ?? 0) * 100)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Festival fare (Rs) *'),
                      controller: TextEditingController(text: '${festival ~/ 100}'),
                      onChanged: (v) => setDState(() => festival = ((int.tryParse(v) ?? 0) * 100)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setDState(() => status = v ?? status),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AbraColors.lightBlue, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('What the customer pays on a weekday', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AbraColors.deepBlue)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Your fare:', style: TextStyle(fontSize: 11)),
                              Text(formatRs(calc['fare'] as int), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Abra commission (7%):', style: TextStyle(fontSize: 11)),
                              Text(formatRs(calc['commission'] as int), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('GST (5%):', style: TextStyle(fontSize: 11)),
                              Text(formatRs(calc['gst'] as int), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Convenience fee:', style: TextStyle(fontSize: 11)),
                              Text(formatRs(calc['fee'] as int), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Customer pays:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              Text(formatRs(calc['total'] as int), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AbraColors.tealDark)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _fares.add({
                      'id': 'FR${_fares.length + 1}',
                      'operatorId': 'OP1',
                      'route': route,
                      'seatType': seatType,
                      'weekday': weekday,
                      'weekend': weekend,
                      'status': status,
                      'from': DateTime.now().toIso8601String().split('T').first,
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fare saved')));
                },
                child: const Text('Save fare'),
              ),
            ],
          );
        },
      ),
    );
  }
}
