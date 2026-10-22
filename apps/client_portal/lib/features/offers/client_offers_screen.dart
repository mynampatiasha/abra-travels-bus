import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientOffersScreen extends StatefulWidget {
  const ClientOffersScreen({super.key});

  @override
  State<ClientOffersScreen> createState() => _ClientOffersScreenState();
}

class _ClientOffersScreenState extends State<ClientOffersScreen> {
  late List<Map<String, dynamic>> _offers;

  @override
  void initState() {
    super.initState();
    _offers = const [];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Offers',
            subtitle: 'Discounts you pay for, shown to customers on your buses. Abra approves each one.',
            breadcrumbs: const ['Sales', 'Offers'],
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Request an offer'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: () => _openRequestOfferDialog(context),
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
            child: _offers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.discount_outlined, size: 48, color: AbraColors.textDisabled),
                          SizedBox(height: 12),
                          Text('Not connected yet - built in Phase 3', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('When connected, your discount offers will appear here.', style: TextStyle(fontSize: 13, color: AbraColors.textSecondary)),
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
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Discount')),
                    DataColumn(label: Text('Valid till')),
                    DataColumn(label: Text('Used')),
                    DataColumn(label: Text('Cost to you')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _offers.map((o) {
                    final isPct = o['type'] == 'PERCENT';
                    final valPct = (o['value'] as int) ~/ 100;
                    final maxDiscStr = formatRs((o['maxDisc'] as int?) ?? 0);
                    final discStr = isPct ? '$valPct% up to $maxDiscStr' : formatRs(o['value'] as int);
                    final used = o['used'] as int? ?? 0;
                    final limit = o['limit'] as int? ?? 0;
                    final usedStr = limit > 0 ? '$used / $limit' : '$used';

                    final costPaise = isPct
                        ? used * ((o['maxDisc'] as int?) ?? 10000)
                        : used * (o['value'] as int);

                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${o['code']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              Text('${o['desc']}', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                            ],
                          ),
                        ),
                        DataCell(Text(discStr, style: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.tealDark))),
                        DataCell(Text('${o['to']}')),
                        DataCell(Text(usedStr)),
                        DataCell(Text(formatRs(costPaise), style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(PortalStatusChip(status: '${o['status']}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRequestOfferDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    final maxDiscCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '500');
    final validTillCtrl = TextEditingController(text: '2026-11-30');
    String type = 'FLAT';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isPercent = type == 'PERCENT';

          return AlertDialog(
            title: const Text('Request an offer'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Offer Code *',
                        hintText: 'e.g. FESTIVE10',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Discount Type'),
                      items: const [
                        DropdownMenuItem(value: 'FLAT', child: Text('Flat amount (₹)')),
                        DropdownMenuItem(value: 'PERCENT', child: Text('Percentage (%)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDlgState(() => type = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isPercent ? 'Value (percent %)' : 'Value (Rs ₹)',
                      ),
                    ),
                    if (isPercent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxDiscCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Maximum discount (Rs ₹)',
                          hintText: 'e.g. 200',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: validTillCtrl,
                      decoration: const InputDecoration(labelText: 'Valid till (YYYY-MM-DD)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total uses (0 = no limit)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (customers see it) *',
                        hintText: 'e.g. 10% off for all weekend trips to Bengaluru',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(AbraSpacing.sm),
                      decoration: BoxDecoration(
                        color: AbraColors.skyContainer,
                        borderRadius: BorderRadius.circular(AbraRadius.md),
                        border: Border.all(color: AbraColors.blue.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AbraColors.deepBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You pay the discount. Abra checks the terms and switches it on.',
                              style: TextStyle(fontSize: 12, color: AbraColors.deepBlue),
                            ),
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
              const Tooltip(
                message: 'Not connected yet',
                child: FilledButton(
                  onPressed: null,
                  child: Text('Send to Abra'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
