import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';
import '../../core/widgets/portal_status_chip.dart';

class ClientPlacesScreen extends StatefulWidget {
  const ClientPlacesScreen({super.key});

  @override
  State<ClientPlacesScreen> createState() => _ClientPlacesScreenState();
}

class _ClientPlacesScreenState extends State<ClientPlacesScreen> {
  late List<Map<String, dynamic>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = List.from(kMockPlaceRequests);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Places',
            subtitle: 'Abra keeps one list of boarding and dropping points. Ask Abra to add a place you need.',
            breadcrumbs: const ['Network', 'Places'],
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Request a place'),
                style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
                onPressed: () => _showRequestPlaceDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),

          // 1. Your requests (Prototype order: requests first)
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
                  child: Text('Your requests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const Divider(height: 1, color: AbraColors.divider),
                if (_requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('No requests\nRequests you send to Abra appear here with their status.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AbraColors.textSecondary),
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
                          DataColumn(label: Text('Place')),
                          DataColumn(label: Text('City')),
                          DataColumn(label: Text('Requested')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: _requests.map((r) =>
                          DataRow(cells: [
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${r['address']}', style: const TextStyle(fontSize: 11, color: AbraColors.textSecondary)),
                              ],
                            )),
                            DataCell(Text('${r['city']}')),
                            DataCell(Text(relativeTime(r['at'] as String? ?? ''))),
                            DataCell(PortalStatusChip(status: '${r['status']}')),
                          ]),
                        ).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xxl),

          // 2. Places you can use (Prototype order: places second)
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
                  child: Text('Places you can use', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                        DataColumn(label: Text('Place')),
                        DataColumn(label: Text('City')),
                        DataColumn(label: Text('Used for')),
                        DataColumn(label: Text('Landmark')),
                      ],
                      rows: kMockPlaces.map((pl) =>
                        DataRow(cells: [
                          DataCell(Text('${pl['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text('${pl['city']}')),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AbraColors.skyContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${pl['type']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AbraColors.deepBlue)),
                          )),
                          DataCell(Text('${pl['landmark']}')),
                        ]),
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

  void _showRequestPlaceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final landmarkCtrl = TextEditingController();
    String city = kMockCities.first['name'] as String;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Request a place'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: city,
                  decoration: const InputDecoration(labelText: 'City *'),
                  items: kMockCities.map((c) => DropdownMenuItem(value: c['name'] as String, child: Text('${c['name']}'))).toList(),
                  onChanged: (v) => setDlgState(() => city = v ?? city),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Place name *', hintText: 'Miyapur Metro Pickup')),
                const SizedBox(height: 12),
                TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address *')),
                const SizedBox(height: 12),
                TextField(controller: landmarkCtrl, decoration: const InputDecoration(labelText: 'Landmark')),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(AbraSpacing.sm),
                  decoration: BoxDecoration(
                    color: AbraColors.skyContainer,
                    borderRadius: BorderRadius.circular(AbraRadius.sm),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AbraColors.deepBlue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Abra checks it is not too close to an existing point, then adds it for every operator.',
                          style: TextStyle(fontSize: 12, color: AbraColors.deepBlue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && addrCtrl.text.isNotEmpty) {
                  setState(() {
                    _requests.insert(0, {
                      'id': 'PR${_requests.length + 1}',
                      'operator': 'Kaveri Express',
                      'city': city,
                      'name': nameCtrl.text.trim(),
                      'address': addrCtrl.text.trim(),
                      'status': 'PENDING',
                      'at': DateTime.now().toIso8601String(),
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent to Abra for approval')));
                }
              },
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
  }
}
