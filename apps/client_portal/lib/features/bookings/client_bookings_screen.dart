import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_kpi_card.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientBookingsScreen extends StatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen> {
  late List<Map<String, dynamic>> _bookings;
  String _statusFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _bookings = const [];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _bookings.where((b) {
      if (_statusFilter != 'ALL' && b['status'] != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final pnr = '${b['pnr']}'.toLowerCase();
        final name = '${b['customer']}'.toLowerCase();
        final phone = '${b['phone']}'.toLowerCase();
        if (!pnr.contains(q) && !name.contains(q) && !phone.contains(q)) return false;
      }
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PortalSectionTitle(
                title: 'Bookings',
                subtitle: 'Bookings on your trips from the Abra customer app.',
                breadcrumbs: ['Sales', 'Bookings'],
                actions: [
                  Tooltip(
                    message: 'Not connected yet',
                    child: OutlinedButton(
                      onPressed: null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download, size: 16),
                          SizedBox(width: 8),
                          Text('Export CSV'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),

              // 4 Prototype KPI Cards (Responsive)
              if (isNarrow)
                const Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: PortalKpiCard(icon: Icons.confirmation_number_outlined, value: 'Not connected yet - built in Phase 3', label: 'Bookings')),
                        SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: 'Not connected yet - built in Phase 3', label: 'Confirmed', iconColor: AbraColors.teal)),
                      ],
                    ),
                    SizedBox(height: AbraSpacing.md),
                    Row(
                      children: [
                        Expanded(child: PortalKpiCard(icon: Icons.cancel_outlined, value: 'Not connected yet - built in Phase 3', label: 'Cancelled', iconColor: AbraColors.danger)),
                        SizedBox(width: AbraSpacing.md),
                        Expanded(child: PortalKpiCard(icon: Icons.account_balance_wallet_outlined, value: 'Not connected yet - built in Phase 3', label: 'Your share', iconColor: AbraColors.deepBlue)),
                      ],
                    ),
                  ],
                )
              else
                const Row(
                  children: [
                    Expanded(child: PortalKpiCard(icon: Icons.confirmation_number_outlined, value: 'Not connected yet - built in Phase 3', label: 'Bookings')),
                    SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.check_circle_outline, value: 'Not connected yet - built in Phase 3', label: 'Confirmed', iconColor: AbraColors.teal)),
                    SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.cancel_outlined, value: 'Not connected yet - built in Phase 3', label: 'Cancelled', iconColor: AbraColors.danger)),
                    SizedBox(width: AbraSpacing.md),
                    Expanded(child: PortalKpiCard(icon: Icons.account_balance_wallet_outlined, value: 'Not connected yet - built in Phase 3', label: 'Your share', iconColor: AbraColors.deepBlue)),
                  ],
                ),
              const SizedBox(height: AbraSpacing.xl),

              // Filter & Search bar (Wrap to avoid overflow)
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
                    Padding(
                      padding: const EdgeInsets.all(AbraSpacing.md),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: isNarrow ? double.infinity : 340,
                            child: TextField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                hintText: 'Search by PNR, customer or phone...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbraRadius.md), borderSide: const BorderSide(color: AbraColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: ['ALL', 'CONFIRMED', 'COMPLETED', 'CANCELLED'].map((st) =>
                              ChoiceChip(
                                label: Text(st),
                                selected: _statusFilter == st,
                                onSelected: (_) => setState(() => _statusFilter = st),
                                selectedColor: AbraColors.skyContainer,
                              ),
                            ).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AbraColors.divider),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.confirmation_number_outlined, size: 48, color: AbraColors.textDisabled),
                              const SizedBox(height: 12),
                              const Text(
                                'Not connected yet - built in Phase 3',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AbraColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty || _statusFilter != 'ALL'
                                    ? 'Try clearing the search or filter'
                                    : 'When connected, customer bookings will appear here.',
                                style: const TextStyle(fontSize: 13, color: AbraColors.textSecondary),
                              ),
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
                            showCheckboxColumn: false,
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.textPrimary, fontSize: 13),
                            dataTextStyle: const TextStyle(color: AbraColors.textPrimary, fontSize: 13),
                            columns: const [
                              DataColumn(label: Text('PNR')),
                              DataColumn(label: Text('Passenger')),
                              DataColumn(label: Text('Route')),
                              DataColumn(label: Text('Travel')),
                              DataColumn(label: Text('Seats')),
                              DataColumn(label: Text('Fare')),
                              DataColumn(label: Text('You get')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: filtered.map((b) {
                              final fare = b['amount'] as int;
                              final comm = b['commission'] as int;
                              final youGet = fare - comm;

                              return DataRow(
                                onSelectChanged: (_) => _showBookingDetailModal(context, b),
                                cells: [
                                  DataCell(Text('${b['pnr']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.blue))),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('${b['customer']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text('${b['phone']}', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('${b['route']}'),
                                        Text('${b['tripId']}', style: const TextStyle(fontSize: 10, color: AbraColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text('${b['travelDate']}')),
                                  DataCell(Text('${b['seatList']}')),
                                  DataCell(Text(formatRs(fare), style: const TextStyle(fontWeight: FontWeight.w700))),
                                  DataCell(Text(formatRs(youGet), style: const TextStyle(fontWeight: FontWeight.w700, color: AbraColors.tealDark))),
                                  DataCell(PortalStatusChip(status: '${b['status']}')),
                                ],
                              );
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
      },
    );
  }

  void _showBookingDetailModal(BuildContext context, Map<String, dynamic> b) {
    final fare = b['amount'] as int;
    final comm = b['commission'] as int;
    final youGet = fare - comm;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${b['pnr']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            PortalStatusChip(status: '${b['status']}'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modalRow('Passenger', '${b['customer']}'),
              _modalRow('Phone', '${b['phone']}'),
              _modalRow('Trip', '${b['tripId']} · ${b['route']}'),
              _modalRow('Travel date', '${b['travelDate']}'),
              _modalRow('Seats', '${b['seatList']} (${b['seatsN']} seats)'),
              const Divider(height: 16),
              _modalRow('Fare paid', formatRs(fare)),
              _modalRow('Abra commission', '- ${formatRs(comm)}'),
              _modalRow('You get', formatRs(youGet), isBold: true, color: AbraColors.tealDark),
              _modalRow('Paid by', '${b['mode']}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          const Tooltip(
            message: 'Not connected yet',
            child: OutlinedButton(
              onPressed: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone, size: 14),
                  SizedBox(width: 8),
                  Text('Call passenger'),
                ],
              ),
            ),
          ),
          if (b['status'] == 'CONFIRMED') ...[
            const Tooltip(
              message: 'Not connected yet',
              child: FilledButton(
                onPressed: null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, size: 14),
                    SizedBox(width: 8),
                    Text('Cancel & refund'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
              color: color ?? AbraColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
