import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientCommissionScreen extends StatefulWidget {
  const ClientCommissionScreen({super.key});

  @override
  State<ClientCommissionScreen> createState() => _ClientCommissionScreenState();
}

class _ClientCommissionScreenState extends State<ClientCommissionScreen> {
  int _sampleFare = 95000;

  @override
  Widget build(BuildContext context) {
    final calc = priceBreakdown(_sampleFare);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalSectionTitle(
            title: 'Commission rules',
            subtitle: 'Rules agreed with Abra Travels for platform ticketing',
            breadcrumbs: ['Money', 'Commission'],
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
                const Padding(
                  padding: EdgeInsets.all(AbraSpacing.lg),
                  child: Text('Active commission rule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const Divider(height: 1, color: AbraColors.divider),
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                      dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                      columns: const [
                        DataColumn(label: Text('Scope')),
                        DataColumn(label: Text('Target')),
                        DataColumn(label: Text('Commission Rate')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Note')),
                      ],
                      rows: kMockCommissions.map((c) =>
                        DataRow(cells: [
                          DataCell(Text('${c['scope']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text('${c['target']}')),
                          DataCell(Text('${(c['value'] as int) / 100}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue))),
                          DataCell(PortalStatusChip(status: '${c['status']}')),
                          DataCell(Text('${c['note']}')),
                        ]),
                      ).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Interactive calculator
          Container(
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
                const Text('Live fare & payout calculator', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Type any base ticket fare to see the commission, taxes and your final net earnings.',
                  style: TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 300,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Base Ticket Fare (₹)', border: OutlineInputBorder()),
                    controller: TextEditingController(text: '${_sampleFare ~/ 100}'),
                    onChanged: (v) => setState(() => _sampleFare = ((int.tryParse(v) ?? 0) * 100)),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AbraColors.lightBlue, borderRadius: BorderRadius.circular(AbraRadius.md)),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _calcCol('Base Fare', formatRs(calc['fare'] as int), AbraColors.textPrimary),
                        const SizedBox(width: 24),
                        _calcCol('Abra Commission (7%)', '- ${formatRs(calc['commission'] as int)}', AbraColors.orangeDark),
                        const SizedBox(width: 24),
                        _calcCol('GST (5%)', formatRs(calc['gst'] as int), AbraColors.textSecondary),
                        const SizedBox(width: 24),
                        _calcCol('Platform Fee', formatRs(calc['fee'] as int), AbraColors.textSecondary),
                        const SizedBox(width: 24),
                        _calcCol('Your Net Earning', formatRs((calc['fare'] as int) - (calc['commission'] as int)), AbraColors.tealDark),
                        const SizedBox(width: 24),
                        _calcCol('Customer Pays', formatRs(calc['total'] as int), AbraColors.deepBlue),
                      ],
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

  Widget _calcCol(String title, String val, Color col) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: col)),
      ],
    );
  }
}
