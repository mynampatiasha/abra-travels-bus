import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';

class ClientSeatLayoutScreen extends StatefulWidget {
  const ClientSeatLayoutScreen({super.key});

  @override
  State<ClientSeatLayoutScreen> createState() => _ClientSeatLayoutScreenState();
}

class _ClientSeatLayoutScreenState extends State<ClientSeatLayoutScreen> {
  late String _selectedBusId;
  String _selectedTool = 'S'; // 'S' (Seat), 'B' (Sleeper), 'L' (Ladies), '_' (Aisle), '.' (Empty)
  late List<List<String>> _grid;

  @override
  void initState() {
    super.initState();
    final buses = kMockBuses.where((b) => b['status'] != 'RETIRED').toList();
    _selectedBusId = buses.isNotEmpty ? buses.first['id'] as String : '';
    _initGridForSelectedBus();
  }

  Map<String, dynamic>? get _currentBus {
    try {
      return kMockBuses.firstWhere((b) => b['id'] == _selectedBusId);
    } catch (_) {
      return null;
    }
  }

  void _initGridForSelectedBus() {
    final bus = _currentBus;
    if (bus == null) {
      _grid = [];
      return;
    }

    final isSleeper = (bus['layout'] as String? ?? '').contains('Sleeper');
    final cols = isSleeper ? ['S', 'S', '_', 'S'] : ['S', 'S', '_', 'S', 'S'];
    final seats = (bus['seats'] as int?) ?? 36;
    final rowCount = (seats / (isSleeper ? 3 : 4)).ceil();

    _grid = List.generate(
      rowCount,
      (_) => List<String>.from(cols),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buses = kMockBuses.where((b) => b['status'] != 'RETIRED').toList();
    final bus = _currentBus;

    if (bus == null) {
      return const Padding(
        padding: EdgeInsets.all(AbraSpacing.xxl),
        child: Center(child: Text('No buses available to design layout.')),
      );
    }

    int seatCount = 0;
    int sleeperCount = 0;
    int ladiesCount = 0;

    for (final row in _grid) {
      for (final cell in row) {
        if (cell == 'S') seatCount++;
        if (cell == 'B') sleeperCount++;
        if (cell == 'L') ladiesCount++;
      }
    }

    final totalMapSeats = seatCount + sleeperCount + ladiesCount;
    final recordSeats = bus['seats'] as int? ?? totalMapSeats;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AbraSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalSectionTitle(
                title: 'Seat layouts',
                subtitle: 'Draw the real seat map. Customers pick seats from this map.',
                breadcrumbs: const ['Fleet', 'Seat layouts'],
                actions: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AbraRadius.md),
                      border: Border.all(color: AbraColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBusId,
                        icon: const Icon(Icons.arrow_drop_down, color: AbraColors.navy),
                        items: buses.map((b) {
                          return DropdownMenuItem<String>(
                            value: b['id'] as String,
                            child: Text(
                              '${b['reg']} · ${b['layout']}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBusId = val;
                              _initGridForSelectedBus();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AbraSpacing.xl),

              // Tool picker
              Container(
                padding: const EdgeInsets.all(AbraSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AbraRadius.lg),
                  border: Border.all(color: AbraColors.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Paint tool:', style: TextStyle(fontWeight: FontWeight.w700)),
                    _toolChip('S', 'Seat', Icons.event_seat, AbraColors.blue),
                    _toolChip('B', 'Sleeper berth', Icons.bed, AbraColors.deepBlue),
                    _toolChip('L', 'Ladies seat', Icons.female, Colors.pink),
                    _toolChip('_', 'Aisle', Icons.space_bar, Colors.grey),
                    _toolChip('.', 'Empty', Icons.close, Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildCanvas(bus)),
                    const SizedBox(width: AbraSpacing.xl),
                    Expanded(flex: 2, child: _buildSummaryCard(bus, totalMapSeats, recordSeats, seatCount, sleeperCount, ladiesCount)),
                  ],
                )
              else ...[
                _buildCanvas(bus),
                const SizedBox(height: AbraSpacing.lg),
                _buildSummaryCard(bus, totalMapSeats, recordSeats, seatCount, sleeperCount, ladiesCount),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCanvas(Map<String, dynamic> bus) {
    return Container(
      padding: const EdgeInsets.all(AbraSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        border: Border.all(color: AbraColors.border),
        boxShadow: AbraShadows.soft,
      ),
      child: Column(
        children: [
          Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AbraColors.navyContainer,
              borderRadius: BorderRadius.circular(AbraRadius.md),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus, size: 16, color: AbraColors.navy),
                  SizedBox(width: 8),
                  Text('Front / Driver Cabin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AbraColors.navy)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var r = 0; r < _grid.length; r++) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${r + 1}', style: const TextStyle(fontSize: 10, color: AbraColors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                for (var c = 0; c < _grid[r].length; c++) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _grid[r][c] = _selectedTool;
                      });
                    },
                    child: _cellWidget(_grid[r][c]),
                  ),
                  if (c < _grid[r].length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          // Row management buttons matching prototype: + Add row, - Remove row, Reset
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add row'),
                onPressed: () {
                  setState(() {
                    final cols = _grid.isNotEmpty ? _grid.last.length : 5;
                    _grid.add(List.generate(cols, (i) => i == 2 ? '_' : 'S'));
                  });
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.remove, size: 14),
                label: const Text('Remove row'),
                onPressed: _grid.length > 1
                    ? () {
                        setState(() {
                          _grid.removeLast();
                        });
                      }
                    : null,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reset'),
                onPressed: () {
                  setState(_initGridForSelectedBus);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> bus, int totalMapSeats, int recordSeats, int seatCount, int sleeperCount, int ladiesCount) {
    final hasDiscrepancy = totalMapSeats != recordSeats;

    return Container(
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
          Text('Summary', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AbraSpacing.md),
          _statRow('Bus', '${bus['reg']}'),
          _statRow('Seats in the map', '$totalMapSeats'),
          _statRow('Seats on record', '$recordSeats'),
          _statRow('Regular seats', '$seatCount'),
          _statRow('Sleeper berths', '$sleeperCount'),
          _statRow('Ladies seats', '$ladiesCount'),
          _statRow('Rows', '${_grid.length}'),
          const Divider(height: 24),
          if (hasDiscrepancy) ...[
            Container(
              padding: const EdgeInsets.all(AbraSpacing.sm),
              decoration: BoxDecoration(
                color: AbraColors.orangeContainer,
                borderRadius: BorderRadius.circular(AbraRadius.md),
                border: Border.all(color: AbraColors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AbraColors.orangeDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The map has $totalMapSeats seats, the bus record says $recordSeats. Saving updates the bus to $totalMapSeats seats.',
                      style: const TextStyle(fontSize: 12, color: AbraColors.orangeDark, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save layout'),
              style: FilledButton.styleFrom(backgroundColor: AbraColors.blue),
              onPressed: () {
                setState(() {
                  bus['seats'] = totalMapSeats;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Layout saved: $totalMapSeats seats for ${bus['reg']}')),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tip: Choose a seat type from the toolbar, then tap any cell to apply it. Front of the bus is at the top.',
            style: TextStyle(fontSize: 12, color: AbraColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _toolChip(String type, String label, IconData icon, Color color) {
    final isSel = _selectedTool == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSel ? Colors.white : color),
      label: Text(label),
      selected: isSel,
      selectedColor: color,
      labelStyle: TextStyle(color: isSel ? Colors.white : AbraColors.textPrimary, fontWeight: FontWeight.w600),
      onSelected: (_) => setState(() => _selectedTool = type),
    );
  }

  Widget _cellWidget(String type) {
    final (bg, icon, col) = switch (type) {
      'S' => (AbraColors.skyContainer, Icons.event_seat, AbraColors.deepBlue),
      'B' => (const Color(0xFFD6E4FF), Icons.bed, AbraColors.deepBlue),
      'L' => (const Color(0xFFFFD6E7), Icons.female, Colors.pink),
      '_' => (Colors.transparent, null, Colors.transparent),
      _ => (AbraColors.lightGray, Icons.close, Colors.grey),
    };

    if (type == '_') {
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: const Text('Aisle', style: TextStyle(fontSize: 9, color: AbraColors.textSecondary)),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Center(child: Icon(icon, size: 20, color: col)),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
