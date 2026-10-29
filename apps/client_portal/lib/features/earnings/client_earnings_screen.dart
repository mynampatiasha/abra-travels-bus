import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';
import '../../routing/portal_routes.dart';

class ClientEarningsScreen extends StatelessWidget {
  const ClientEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalSectionTitle(
            title: 'Earnings and settlements',
            subtitle: 'Abra collects passenger payments, deducts agreed commission and disburses net earnings',
            breadcrumbs: ['Money', 'Earnings'],
          ),
          const SizedBox(height: AbraSpacing.xl),
          const Row(
            children: [
              Expanded(
                child: PortalKpiCard(
                  icon: Icons.confirmation_number_outlined,
                  value: 'Not connected yet - built in Phase 6',
                  label: 'Gross sales, 30 days',
                  iconColor: AbraColors.blue,
                ),
              ),
              SizedBox(width: AbraSpacing.md),
              Expanded(
                child: PortalKpiCard(
                  icon: Icons.percent,
                  value: 'Not connected yet - built in Phase 6',
                  label: 'Abra commission',
                  iconColor: AbraColors.orange,
                ),
              ),
              SizedBox(width: AbraSpacing.md),
              Expanded(
                child: PortalKpiCard(
                  icon: Icons.replay,
                  value: 'Not connected yet - built in Phase 6',
                  label: 'Refunds you bore',
                  iconColor: AbraColors.danger,
                ),
              ),
              SizedBox(width: AbraSpacing.md),
              Expanded(
                child: PortalKpiCard(
                  icon: Icons.account_balance_wallet,
                  value: 'Not connected yet - built in Phase 6',
                  label: 'Your net, 30 days',
                  iconColor: AbraColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.lg),
          // Bank & payout status banner matching prototype
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance, size: 18, color: AbraColors.deepBlue),
                    SizedBox(width: 8),
                    Text(
                      'Payout: Not connected yet - built in Phase 6',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 14),
                  label: const Text('Bank details', style: TextStyle(fontSize: 12)),
                  onPressed: () => context.go(PortalRoutes.companyProfile),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Chart
          Container(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily net earnings after commission (last 30 days)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart, size: 48, color: AbraColors.textDisabled),
                        SizedBox(height: 12),
                        Text(
                          'Not connected yet - built in Phase 6',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Daily earnings trends will appear here when connected.',
                          style: TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Settlements Table
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
                  child: Text('Settlement cycles to your bank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const Divider(height: 1, color: AbraColors.divider),
                if (kMockSettlements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.wallet_outlined, size: 48, color: AbraColors.textDisabled),
                          SizedBox(height: 12),
                          Text('Not connected yet - built in Phase 6', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('Settlements for completed trips appear here.', style: TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                      dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                      columns: const [
                        DataColumn(label: Text('Period')),
                        DataColumn(label: Text('Gross Ticket Sales')),
                        DataColumn(label: Text('Commission')),
                        DataColumn(label: Text('Net Credited')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('UTR / Reference')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: kMockSettlements.map((s) =>
                        DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => _showSettlementDetail(context, s),
                                child: Text('${s['period']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.deepBlue)),
                              ),
                            ),
                            DataCell(Text(formatRs(s['gross'] as int))),
                            DataCell(Text(formatRs(s['commission'] as int), style: const TextStyle(color: AbraColors.textSecondary))),
                            DataCell(Text(formatRs(s['net'] as int), style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.tealDark))),
                            DataCell(PortalStatusChip(status: '${s['status']}')),
                            DataCell(Text('${s['utr']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                            DataCell(
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                ),
                                onPressed: () => _showSettlementDetail(context, s),
                                child: const Text('View statement', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ).toList(),
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

  void _showSettlementDetail(BuildContext context, Map<String, dynamic> s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Settlement Statement: ${s['period']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Gross Passenger Bookings', formatRs(s['gross'] as int)),
              _row('Abra Platform Commission', '- ${formatRs(s['commission'] as int)}', isDeduct: true),
              _row('Refunds / Adjustments', '₹0'),
              const Divider(),
              _row('Net Credited to Bank', formatRs(s['net'] as int), isBold: true),
              _row('UTR Reference', '${s['utr']}'),
              _row('Settlement Status', '${s['status']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _raiseQuery(context, s),
            child: const Text('Raise a query'),
          ),
          const Tooltip(
            message: 'Not connected yet',
            child: FilledButton(
              onPressed: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, size: 16),
                  SizedBox(width: 8),
                  Text('Download CSV Statement'),
                ],
              ),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _raiseQuery(BuildContext context, Map<String, dynamic> s) {
    final queryCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Raise Query on Settlement ${s['period']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Describe any discrepancy in bookings, refunds, or commission deduction for this cycle.',
              style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: queryCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Refund charged on 3 Oct was not borne by us...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          const Tooltip(
            message: 'Not connected yet',
            child: FilledButton(
              onPressed: null,
              child: Text('Send to Abra'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isDeduct = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AbraColors.textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isDeduct ? AbraColors.danger : (isBold ? AbraColors.tealDark : AbraColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
