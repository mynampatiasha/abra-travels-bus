import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../routing/driver_routes.dart';

// ===== 1. MODELS =====
enum CheckItemLevel { block, warn }
enum CheckItemState { pass, fail, pending }

class PreTripItem {
  PreTripItem({
    required this.id,
    required this.label,
    required this.isAuto,
    required this.level,
    required this.requiresPhoto,
    this.autoMsg,
    this.value,
    this.state = CheckItemState.pending,
  });

  final String id;
  final String label;
  final bool isAuto;
  final CheckItemLevel level;
  final bool requiresPhoto;
  String? autoMsg;
  String? value;
  CheckItemState state;
}

// ===== 2. PRE-TRIP CHECKLIST SCREEN =====
class DriverPreTripChecklistScreen extends ConsumerStatefulWidget {
  const DriverPreTripChecklistScreen({
    required this.tripId,
    super.key,
  });

  final String tripId;

  @override
  ConsumerState<DriverPreTripChecklistScreen> createState() => _DriverPreTripChecklistScreenState();
}

class _DriverPreTripChecklistScreenState extends ConsumerState<DriverPreTripChecklistScreen> {
  final TextEditingController _odoController = TextEditingController();
  final TextEditingController _overrideReasonController = TextEditingController();
  bool _overridePhotoAttached = false;
  late List<PreTripItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      PreTripItem(
        id: 'licence',
        label: 'Driver Licence Verification',
        isAuto: true,
        autoMsg: 'Check driver licence on file',
        level: CheckItemLevel.block,
        requiresPhoto: false,
        state: CheckItemState.pending,
      ),
      PreTripItem(
        id: 'bus_docs',
        label: 'Bus Fitness & Insurance Papers',
        isAuto: true,
        autoMsg: 'Check bus fitness & insurance papers',
        level: CheckItemLevel.block,
        requiresPhoto: false,
        state: CheckItemState.pending,
      ),
      PreTripItem(
        id: 'rest',
        label: 'Mandatory Driver Rest (8h Rule)',
        isAuto: true,
        autoMsg: 'Check driver duty rest compliance',
        level: CheckItemLevel.block,
        requiresPhoto: false,
        state: CheckItemState.pending,
      ),
      PreTripItem(
        id: 'location',
        label: 'GPS & Location Sharing',
        isAuto: true,
        autoMsg: 'Device location sharing required',
        level: CheckItemLevel.block,
        requiresPhoto: false,
        state: CheckItemState.pending,
      ),
      PreTripItem(
        id: 'tyres',
        label: 'Tyres & Pressure Condition',
        isAuto: false,
        level: CheckItemLevel.block,
        requiresPhoto: false,
        value: 'Yes',
        state: CheckItemState.pass,
      ),
      PreTripItem(
        id: 'lights',
        label: 'Headlights & Indicators Check',
        isAuto: false,
        level: CheckItemLevel.warn,
        requiresPhoto: false,
        value: 'Yes',
        state: CheckItemState.pass,
      ),
      PreTripItem(
        id: 'clean',
        label: 'Bus Cleanliness & Sanitization',
        isAuto: false,
        level: CheckItemLevel.warn,
        requiresPhoto: false,
        value: 'Yes',
        state: CheckItemState.pass,
      ),
    ];
  }

  bool get _hasBlockingFailure =>
      _items.any((i) => i.state == CheckItemState.fail && i.level == CheckItemLevel.block);

  bool get _hasPending => _items.any((i) => i.state == CheckItemState.pending);

  void _submitTripStart() {
    if (_hasBlockingFailure && _overrideReasonController.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write why you are overriding the failed checks.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final db = ref.read(driverMockDbProvider);
    db.setTripStatus(widget.tripId, 'IN_TRANSIT');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip started successfully! Location sharing is now live.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
    context.go(DriverRoutes.trip);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(driverMockDbProvider);
    final trip = db.trips.firstWhere(
      (t) => t['id'] == widget.tripId,
      orElse: () => <String, dynamic>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Before You Start', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trip Hero Info
            Card(
              color: const Color(0xFF12304A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip['id']} · ${trip['route']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bus: ${trip['bus']} · ${trip['type']}',
                      style: const TextStyle(color: Color(0xFFDDF3FC), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Odometer card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Starting Odometer Reading (km) *',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _odoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixText: 'km',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Mandatory Checklist Items',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),

            // Item cards
            for (int i = 0; i < _items.length; i++) ...[
              _buildItemCard(_items[i], i),
              const SizedBox(height: 10),
            ],

            // Override section if any block failed
            if (_hasBlockingFailure) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text(
                            'Start with Override',
                            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'One or more checks failed. You can only start if you state the reason and provide proof. Your operator and Abra are alerted.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _overrideReasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Why are you starting anyway? *',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: Icon(
                          _overridePhotoAttached ? Icons.check_circle : Icons.camera_alt,
                          color: _overridePhotoAttached ? Colors.green : Colors.grey,
                        ),
                        label: Text(
                          _overridePhotoAttached
                              ? 'Proof Photo Attached (override.jpg)'
                              : 'Attach Photo Evidence *',
                        ),
                        onPressed: () {
                          setState(() => _overridePhotoAttached = !_overridePhotoAttached);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                _hasBlockingFailure ? 'Start Trip with Override' : 'Start Trip & Share GPS',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              onPressed: _hasPending ? null : _submitTripStart,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(PreTripItem item, int index) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.state == CheckItemState.pass
              ? const Color(0xFFE2E8F0)
              : item.level == CheckItemLevel.block
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFFDE68A),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.state == CheckItemState.pass
                        ? const Color(0xFFDCFCE7)
                        : item.level == CheckItemLevel.block
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.state == CheckItemState.pass
                        ? 'PASS'
                        : item.level == CheckItemLevel.block
                            ? 'BLOCK'
                            : 'WARN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.state == CheckItemState.pass
                          ? const Color(0xFF166534)
                          : item.level == CheckItemLevel.block
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            if (item.isAuto) ...[
              const SizedBox(height: 6),
              Text(
                item.autoMsg ?? '',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Yes (All Good)'),
                    selected: item.value == 'Yes',
                    onSelected: (selected) {
                      setState(() {
                        item.value = 'Yes';
                        item.state = CheckItemState.pass;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('No (Issue Found)'),
                    selected: item.value == 'No',
                    selectedColor: const Color(0xFFFEE2E2),
                    onSelected: (selected) {
                      setState(() {
                        item.value = 'No';
                        item.state = CheckItemState.fail;
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===== 3. END-OF-TRIP CHECKLIST SCREEN =====
class DriverEndTripChecklistScreen extends ConsumerStatefulWidget {
  const DriverEndTripChecklistScreen({
    required this.tripId,
    super.key,
  });

  final String tripId;

  @override
  ConsumerState<DriverEndTripChecklistScreen> createState() => _DriverEndTripChecklistScreenState();
}

class _DriverEndTripChecklistScreenState extends ConsumerState<DriverEndTripChecklistScreen> {
  final TextEditingController _endOdoController = TextEditingController();
  bool _lostItemsChecked = true;
  bool _busParkedLocked = true;

  void _finishTrip() {
    final db = ref.read(driverMockDbProvider);
    db.setTripStatus(widget.tripId, 'ARRIVED');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip completed! All passenger bookings marked as arrived.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
    context.go(DriverRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('End of Trip Check', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End Odometer Reading (km) *',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _endOdoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixText: 'km',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Interior Checked for Lost Items',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('No luggage or items left behind by passengers'),
                    value: _lostItemsChecked,
                    onChanged: (v) => setState(() => _lostItemsChecked = v ?? false),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    title: const Text('Bus Parked & Safely Locked',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Parked at authorized terminal bay'),
                    value: _busParkedLocked,
                    onChanged: (v) => setState(() => _busParkedLocked = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12304A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.flag_rounded),
              label: const Text('Submit & Finish Trip',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              onPressed: _finishTrip,
            ),
          ],
        ),
      ),
    );
  }
}
