import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

import 'operations_mock_store.dart';

/// Live Bus Tracking page matching prototypes/admin_demo_model.html.
class AdminTrackingPage extends ConsumerStatefulWidget {
  const AdminTrackingPage({super.key});

  @override
  ConsumerState<AdminTrackingPage> createState() => _AdminTrackingPageState();
}

class _AdminTrackingPageState extends ConsumerState<AdminTrackingPage> {
  String _selectedOperator = 'ALL';
  String _selectedState = 'ALL';

  @override
  Widget build(BuildContext context) {
    final opsState = ref.watch(operationsStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF13222F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3E50) : const Color(0xFFE2E8F0);

    final buses = opsState.liveBuses;
    final attentionBuses = buses.where((b) => b.needsAttention).toList();

    final filtered = buses.where((b) {
      if (_selectedOperator != 'ALL' && b.operator != _selectedOperator) {
        return false;
      }
      if (_selectedState != 'ALL' && b.state != _selectedState) return false;
      return true;
    }).toList();

    final selectedBus = buses.firstWhere(
      (b) => b.tripId == opsState.selectedLiveBusId,
      orElse: () => buses.isNotEmpty ? buses.first : buses.first,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Row(
              children: [
                Text(
                  'Operations',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8BA2B9)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Live tracking',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header Row with Operator and State Filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live tracking',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every running bus. Real-time telemetry, location and speed.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _selectedOperator,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                            value: 'ALL', child: Text('All operators')),
                        ...{...buses.map((b) => b.operator)}.map((op) {
                          return DropdownMenuItem(value: op, child: Text(op));
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedOperator = val ?? 'ALL');
                      },
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedState,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: 'ALL', child: Text('All states')),
                        DropdownMenuItem(value: 'LIVE', child: Text('Live')),
                        DropdownMenuItem(
                            value: 'DELAYED', child: Text('Delayed')),
                        DropdownMenuItem(
                            value: 'SIGNAL_LOST', child: Text('Signal lost')),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedState = val ?? 'ALL');
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Attention Banner
            if (attentionBuses.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF381519)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${attentionBuses.length} bus(es) need a look: ${attentionBuses.map((b) => '${b.bus} (${b.state.replaceAll('_', ' ')})').join(', ')}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0E2E1D)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF166534)
                        : const Color(0xFF86EFAC),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'All running buses have healthy telemetry and live GPS locks.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // 2-Column Responsive Board (Map on Left, Buses list on Right)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 950;
                if (!isWide) {
                  return Column(
                    children: [
                      _buildMapCanvas(
                          filtered, selectedBus.tripId, isDark, borderColor),
                      const SizedBox(height: 20),
                      _buildBusesList(filtered, selectedBus.tripId, surfaceColor,
                          borderColor, isDark),
                      const SizedBox(height: 24),
                      _buildBusDetailPanel(
                          selectedBus, surfaceColor, borderColor, isDark),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Map Box
                        Expanded(
                          flex: 3,
                          child: _buildMapCanvas(
                              filtered, selectedBus.tripId, isDark, borderColor),
                        ),
                        const SizedBox(width: 20),
                        // Right Buses List
                        SizedBox(
                          width: 360,
                          child: _buildBusesList(filtered, selectedBus.tripId,
                              surfaceColor, borderColor, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Selected Bus Detail
                    _buildBusDetailPanel(
                        selectedBus, surfaceColor, borderColor, isDark),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCanvas(
    List<LiveTrackingRecord> buses,
    String? selectedTripId,
    bool isDark,
    Color borderColor,
  ) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1520) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          // Map routes lines
          Positioned.fill(
            child: CustomPaint(
              painter: _LiveTrackingMapPainter(isDark: isDark),
            ),
          ),

          // Bus pins on map
          ...buses.map((bus) {
            final isSelected = bus.tripId == selectedTripId;
            Color pinColor;
            switch (bus.state) {
              case 'LIVE':
                pinColor = const Color(0xFF16A34A);
              case 'DELAYED':
                pinColor = const Color(0xFFD97706);
              case 'SIGNAL_LOST':
              default:
                pinColor = const Color(0xFFDC2626);
            }

            return Positioned(
              left: (bus.x / 100) * 440 + 30,
              top: (bus.y / 100) * 300 + 40,
              child: GestureDetector(
                onTap: () {
                  ref
                      .read(operationsStoreProvider.notifier)
                      .selectLiveBus(bus.tripId);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: pinColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pinColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? AbraColors.blue : borderColor,
                        ),
                      ),
                      child: Text(
                        bus.bus,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Map overlay note
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black54 : Colors.white70,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Live tracking map  •  Updated every 15s',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusesList(
    List<LiveTrackingRecord> buses,
    String? selectedTripId,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      children: buses.map((bus) {
        final isSelected = bus.tripId == selectedTripId;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AbraColors.blue : borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ref
                    .read(operationsStoreProvider.notifier)
                    .selectLiveBus(bus.tripId);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bus.bus,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildStateChip(bus.state, isDark),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bus.route} - ${bus.operator}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF8BA2B9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (bus.progress / 100).clamp(0.0, 1.0),
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      color: AbraColors.blue,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${bus.speed} km/h',
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          'Last signal ${_formatRelativeTime(bus.ping)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF8BA2B9)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBusDetailPanel(
    LiveTrackingRecord bus,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Bus Name & Route + Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${bus.bus} - ${bus.route}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showReplayModal(context, bus),
                    icon: const Icon(Icons.history, size: 14),
                    label: const Text('Replay route'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening trip ${bus.tripId}')),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Open trip'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _simulateCall('Driver ${bus.driver}');
                    },
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text('Call driver'),
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

          // 3 KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildDetailKpi(
                  'ETA at destination',
                  '${bus.eta.hour}:${bus.eta.minute.toString().padLeft(2, '0')}',
                  Icons.access_time,
                  surfaceColor,
                  borderColor,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailKpi(
                  'Current speed',
                  '${bus.speed} km/h',
                  Icons.speed,
                  surfaceColor,
                  borderColor,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailKpi(
                  'Passengers checked in',
                  '${bus.checkedIn} / ${bus.pax}',
                  Icons.people_outline,
                  surfaceColor,
                  borderColor,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Key Value Metadata
          _buildDetailRow('Operator', bus.operator, isDark),
          _buildDetailRow('Driver', bus.driver, isDark),
          _buildDetailRow(
              'Last telemetry ping', _formatRelativeTime(bus.ping), isDark),
          _buildDetailRow('Telemetry state', bus.state.replaceAll('_', ' '), isDark),
          _buildDetailRow('Route progress', '${bus.progress}% completed', isDark),

          const SizedBox(height: 24),

          // Stops Timeline
          Text(
            'Route stops',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: bus.stops.asMap().entries.map((entry) {
              final idx = entry.key;
              final stop = entry.value;
              final reached = bus.progress > idx * 25;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached
                            ? const Color(0xFF16A34A)
                            : (isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stop,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              reached ? FontWeight.bold : FontWeight.normal,
                          color: reached
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark
                                  ? const Color(0xFF8BA2B9)
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: reached
                            ? (isDark
                                ? const Color(0xFF064E3B)
                                : const Color(0xFFDCFCE7))
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        reached ? 'Reached' : 'Ahead',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: reached
                              ? const Color(0xFF16A34A)
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailKpi(
    String label,
    String value,
    IconData icon,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AbraColors.blue),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF8BA2B9)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF8BA2B9)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStateChip(String state, bool isDark) {
    Color bg;
    Color fg;

    switch (state) {
      case 'LIVE':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
      case 'DELAYED':
        bg = isDark ? const Color(0xFF332005) : const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
      case 'SIGNAL_LOST':
      default:
        bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        state.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showReplayModal(BuildContext context, LiveTrackingRecord bus) {
    double progressVal = bus.progress.toDouble();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Route replay - ${bus.bus}'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: (progressVal / 100) * 440 + 20,
                            top: 85,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_bus,
                                    color: Colors.greenAccent, size: 24),
                                Text('Bus',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: progressVal,
                      min: 0,
                      max: 100,
                      onChanged: (val) {
                        setDialogState(() => progressVal = val);
                      },
                    ),
                    Text(
                      'Replay Position: ${progressVal.round()}% of route completed',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _simulateCall(String party) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.phone_in_talk, color: AbraColors.blue),
              const SizedBox(width: 8),
              Text('Calling $party'),
            ],
          ),
          content: Text(
            'Cellular bridge established to $party.\nAudio stream live. Tap End call when done.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('End call'),
            ),
          ],
        );
      },
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _LiveTrackingMapPainter extends CustomPainter {
  const _LiveTrackingMapPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final highwayPaint = Paint()
      ..color = isDark ? const Color(0xFF1E3246) : const Color(0xFFCBD5E1)
      ..strokeWidth = 3.0;

    // Highway route lines
    final p1 = Path()
      ..moveTo(size.width * 0.1, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.3,
        size.width * 0.85,
        size.height * 0.2,
      );
    canvas.drawPath(p1, highwayPaint);

    final p2 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.25)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.65,
        size.width * 0.8,
        size.height * 0.7,
      );
    canvas.drawPath(p2, highwayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
