import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../app/providers.dart';
import '../../core/browser_files.dart';
import '../../core/failure_text.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';
import '../routes/routes_client_manage_screen.dart';

String formatRs(int paise) => '₹${(paise / 100).toStringAsFixed(0)}';

// ===== 1. MODELS =====

class CustomerPaysBreakdownData {
  CustomerPaysBreakdownData({
    required this.fare,
    required this.cm,
    required this.gst,
    required this.fee,
    required this.total,
  });

  final int fare;
  final int cm;
  final int gst;
  final int fee;
  final int total;

  factory CustomerPaysBreakdownData.fromJson(Map<String, dynamic> json) {
    return CustomerPaysBreakdownData(
      fare: (json['fare'] as num?)?.toInt() ?? 0,
      cm: (json['cm'] as num?)?.toInt() ?? 0,
      gst: (json['gst'] as num?)?.toInt() ?? 0,
      fee: (json['fee'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

CustomerPaysBreakdownData calcCustomerPays(int fare) {
  final cm = (fare * 0.08).round();
  final gst = ((fare + cm) * 0.05).round();
  const fee = 500;
  final total = fare + cm + gst + fee;
  return CustomerPaysBreakdownData(fare: fare, cm: cm, gst: gst, fee: fee, total: total);
}

class ClientFareItem {
  ClientFareItem({
    required this.id,
    required this.operatorId,
    required this.routeId,
    required this.route,
    required this.seatType,
    required this.weekday,
    required this.weekend,
    required this.festival,
    required this.from,
    this.till,
    required this.status,
    required this.customerPaysWeekday,
  });

  final String id;
  final String operatorId;
  final String routeId;
  final String route;
  final String seatType;
  final int weekday;
  final int weekend;
  final int festival;
  final String from;
  final String? till;
  final String status;
  final CustomerPaysBreakdownData customerPaysWeekday;

  factory ClientFareItem.fromJson(Map<String, dynamic> json) {
    return ClientFareItem(
      id: json['id'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      route: json['route'] as String? ?? '',
      seatType: json['seatType'] as String? ?? '',
      weekday: (json['weekday'] as num?)?.toInt() ?? 0,
      weekend: (json['weekend'] as num?)?.toInt() ?? 0,
      festival: (json['festival'] as num?)?.toInt() ?? 0,
      from: json['from'] as String? ?? '',
      till: json['till'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      customerPaysWeekday: json['customerPaysWeekday'] is Map<String, dynamic>
          ? CustomerPaysBreakdownData.fromJson(json['customerPaysWeekday'] as Map<String, dynamic>)
          : calcCustomerPays((json['weekday'] as num?)?.toInt() ?? 0),
    );
  }
}

// ===== 2. PROVIDERS =====

final clientFaresProvider = FutureProvider.autoDispose
    .family<List<ClientFareItem>, (String, String)>((ref, args) async {
  final (statusFilter, search) = args;
  try {
    final client = ref.watch(appDependenciesProvider).apiClient;
    final query = <String, dynamic>{'pageSize': 100};
    if (statusFilter != 'ALL') {
      query['status'] = statusFilter;
    }
    if (search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    final response = await client.get('client/fares', query: query);
    final List<ClientFareItem> items = [];
    if (response.data is List) {
      for (final raw in response.data as List) {
        if (raw is Map) {
          items.add(ClientFareItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    } else if (response.data is Map && (response.data as Map)['items'] is List) {
      for (final raw in (response.data as Map)['items'] as List) {
        if (raw is Map) {
          items.add(ClientFareItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return items;
  } catch (_) {
    return <ClientFareItem>[];
  }
});

// ===== 3. SCREEN =====

class ClientFaresScreen extends ConsumerStatefulWidget {
  const ClientFaresScreen({super.key});

  @override
  ConsumerState<ClientFaresScreen> createState() => _ClientFaresScreenState();
}

class _ClientFaresScreenState extends ConsumerState<ClientFaresScreen> {
  String _statusFilter = 'ALL';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(clientFaresProvider);
  }

  void _exportCsv(List<ClientFareItem> fares) {
    final buffer = StringBuffer();
    buffer.writeln('Route,Seat Type,Weekday (Rs),Weekend (Rs),Festival (Rs),Customer Pays Weekday (Rs),Status,Valid From');
    for (final f in fares) {
      final route = f.route.replaceAll('"', '""');
      final seat = f.seatType.replaceAll('"', '""');
      final wk = f.weekday / 100.0;
      final we = f.weekend / 100.0;
      final fest = f.festival / 100.0;
      final cp = f.customerPaysWeekday.total / 100.0;
      buffer.writeln('"$route","$seat",$wk,$we,$fest,$cp,"${f.status}","${f.from}"');
    }
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    downloadTextFile('fares_$stamp.csv', buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The file is ready.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 768;
    final search = _searchCtrl.text.trim();
    final asyncFares = ref.watch(clientFaresProvider((_statusFilter, search)));

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
                onPressed: () => unawaited(_showFareDialog(context)),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),
          // Filter toolbar
          Container(
            padding: const EdgeInsets.all(AbraSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isNarrow ? double.infinity : 220,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search route or seat type',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: isNarrow ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                    ],
                    onChanged: (val) => setState(() => _statusFilter = val ?? 'ALL'),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear'),
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _statusFilter = 'ALL';
                    });
                  },
                ),
                asyncFares.maybeWhen(
                  data: (fares) => OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    onPressed: () => _exportCsv(fares),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: asyncFares.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AbraColors.danger),
                      const SizedBox(height: 12),
                      Text('Failed to load fares: $err', style: const TextStyle(color: AbraColors.danger)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
              data: (fares) => fares.isEmpty
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
                              onPressed: () => unawaited(_showFareDialog(context)),
                            ),
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
                            DataColumn(label: Text('Route')),
                            DataColumn(label: Text('Seat type')),
                            DataColumn(label: Text('Weekday')),
                            DataColumn(label: Text('Weekend')),
                            DataColumn(label: Text('Festival')),
                            DataColumn(label: Text('Customer pays (weekday)')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: fares.map((f) {
                            return DataRow(cells: [
                              DataCell(Text(f.route, style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text(f.seatType)),
                              DataCell(Text(formatRs(f.weekday))),
                              DataCell(Text(formatRs(f.weekend))),
                              DataCell(Text(formatRs(f.festival))),
                              DataCell(Text(formatRs(f.customerPaysWeekday.total), style: const TextStyle(fontWeight: FontWeight.w800, color: AbraColors.tealDark))),
                              DataCell(PortalStatusChip(status: f.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Edit fare',
                                      onPressed: () => unawaited(_showFareDialog(context, existingFare: f)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AbraColors.danger),
                                      tooltip: 'Delete fare',
                                      onPressed: () => _confirmDeleteFare(context, f),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// The names of the bus types Abra has switched on, from the server. A fare is priced per
  /// bus type, so the seat type can only be one of these.
  Future<List<String>> _loadSeatTypes() async {
    final response = await ref.read(appDependenciesProvider).apiClient.get(
      'catalogue/bus-types',
      query: <String, dynamic>{'active': true, 'pageSize': 100},
    );
    final data = response.data;
    final raw = data is Map && data['items'] is List
        ? data['items'] as List
        : data is List
            ? data
            : const <Object?>[];
    return <String>[
      for (final item in raw)
        if (item is Map && item['isActive'] != false && (item['name'] as String? ?? '').isNotEmpty)
          item['name'] as String,
    ];
  }

  Future<void> _showFareDialog(BuildContext context, {ClientFareItem? existingFare}) async {
    final isEdit = existingFare != null;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AbraLocalizations.of(context);
    final List<String> seatTypes;
    try {
      seatTypes = await _loadSeatTypes();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not load bus types: ${failureText(l10n, e)}')));
      return;
    }
    if (!context.mounted) return;
    if (seatTypes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Abra has not added any bus types yet. A fare needs a bus type, so please contact Abra support.'),
          backgroundColor: AbraColors.danger,
        ),
      );
      return;
    }
    int weekday = isEdit ? existingFare.weekday : 80000;
    int weekend = isEdit ? existingFare.weekend : 90000;
    int festival = isEdit ? existingFare.festival : 110000;
    String seatType = isEdit ? existingFare.seatType : seatTypes.first;
    // An old fare may use a name that is no longer an active bus type; keep it visible.
    final seatChoices = seatTypes.contains(seatType) ? seatTypes : <String>[seatType, ...seatTypes];
    String status = isEdit ? existingFare.status : 'ACTIVE';
    String? selectedRouteId = isEdit ? existingFare.routeId : null;

    // Load available routes
    final routesAsync = await ref.read(clientRoutesProvider(('ALL', '')).future);
    final availableRoutes = routesAsync.isNotEmpty ? routesAsync : <ClientRouteItem>[];

    if (selectedRouteId == null && availableRoutes.isNotEmpty) {
      selectedRouteId = availableRoutes.first.id;
    }

    if (!context.mounted) return;

    final weekdayCtrl = TextEditingController(text: '${weekday ~/ 100}');
    final weekendCtrl = TextEditingController(text: '${weekend ~/ 100}');
    final festivalCtrl = TextEditingController(text: '${festival ~/ 100}');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final calc = calcCustomerPays(weekday);

          return AlertDialog(
            title: Text(isEdit ? 'Edit fare' : 'New fare'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (availableRoutes.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedRouteId,
                        decoration: const InputDecoration(labelText: 'Route *'),
                        items: availableRoutes.map((r) {
                          return DropdownMenuItem(
                            value: r.id,
                            child: Text(r.name),
                          );
                        }).toList(),
                        onChanged: isEdit ? null : (v) => setDState(() => selectedRouteId = v),
                      )
                    else
                      TextFormField(
                        initialValue: isEdit ? existingFare.route : 'General Route',
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Route'),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: seatType,
                      decoration: const InputDecoration(labelText: 'Seat type *'),
                      items: [
                        for (final name in seatChoices) DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: (v) => setDState(() => seatType = v ?? seatType),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weekdayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Weekday fare (Rs) *', prefixText: 'Rs '),
                      onChanged: (v) {
                        setDState(() {
                          weekday = (int.tryParse(v) ?? 0) * 100;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weekendCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Weekend fare (Rs) *', prefixText: 'Rs '),
                      onChanged: (v) {
                        setDState(() {
                          weekend = (int.tryParse(v) ?? 0) * 100;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: festivalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Festival fare (Rs) *', prefixText: 'Rs '),
                      onChanged: (v) {
                        setDState(() {
                          festival = (int.tryParse(v) ?? 0) * 100;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setDState(() => status = v ?? status),
                    ),
                    const SizedBox(height: 16),
                    // Customer pays calculation breakdown
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
                              Text(formatRs(calc.fare), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Abra commission (8%):', style: TextStyle(fontSize: 11)),
                              Text(formatRs(calc.cm), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('GST (5%):', style: TextStyle(fontSize: 11)),
                              Text(formatRs(calc.gst), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Convenience fee:', style: TextStyle(fontSize: 11)),
                              Text(formatRs(calc.fee), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Customer pays:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              Text(formatRs(calc.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AbraColors.tealDark)),
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
                onPressed: () async {
                  if (weekday < 10000) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Weekday fare must be at least Rs 100'), backgroundColor: AbraColors.danger),
                    );
                    return;
                  }
                  if (weekend < (weekday * 0.5)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Weekend fare cannot be less than 50% of weekday fare'), backgroundColor: AbraColors.danger),
                    );
                    return;
                  }
                  if (festival < 10000) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Festival fare must be at least Rs 100'), backgroundColor: AbraColors.danger),
                    );
                    return;
                  }

                  try {
                    final client = ref.read(appDependenciesProvider).apiClient;
                    if (isEdit) {
                      await client.put('client/fares/${existingFare.id}', body: {
                        'seatType': seatType,
                        'weekday': weekday,
                        'weekend': weekend,
                        'festival': festival,
                        'status': status,
                      });
                    } else {
                      await client.post('client/fares', body: {
                        'routeId': selectedRouteId,
                        'seatType': seatType,
                        'weekday': weekday,
                        'weekend': weekend,
                        'festival': festival,
                        'from': DateTime.now().toIso8601String().split('T').first,
                        'status': status,
                      });
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fare saved successfully')),
                      );
                    }
                  } catch (err) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save fare: $err'), backgroundColor: AbraColors.danger),
                      );
                    }
                  }
                },
                child: const Text('Save fare'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteFare(BuildContext context, ClientFareItem fare) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete fare for ${fare.route}?'),
        content: Text('Are you sure you want to delete the ${fare.seatType} fare?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AbraColors.danger),
            onPressed: () async {
              try {
                final client = ref.read(appDependenciesProvider).apiClient;
                await client.delete('client/fares/${fare.id}');
                if (context.mounted) {
                  Navigator.pop(ctx);
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted fare for ${fare.route}')),
                  );
                }
              } catch (err) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete fare: $err'), backgroundColor: AbraColors.danger),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
