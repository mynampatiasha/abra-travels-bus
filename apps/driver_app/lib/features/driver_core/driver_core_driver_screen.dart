import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/l10n/driver_strings.dart';
import '../../routing/driver_routes.dart';
import '../tracking/tracking_driver_screen.dart';

class DriverCoreController {
  DriverCoreController(this.ref);
  final Ref ref;

  Map<String, dynamic>? get currentTrip => ref.watch(driverMockDbProvider).currentTrip;
  List<Map<String, dynamic>> get myTrips => ref.watch(driverMockDbProvider).myTrips;
  Map<String, dynamic>? get profile => ref.watch(driverMockDbProvider).myProfile;

  void startBoarding(BuildContext context, String tripId) {
    ref.read(driverMockDbProvider).setTripStatus(tripId, 'BOARDING');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Boarding started! Passenger check-in is now open.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void resumeTrip(BuildContext context, String tripId) {
    ref.read(driverMockDbProvider).setTripStatus(tripId, 'IN_TRANSIT');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip resumed. Live location sharing active.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void checkInPassenger(BuildContext context, String tripId, String bookingId, String name) {
    ref.read(driverMockDbProvider).checkInPassenger(tripId, bookingId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name checked in successfully.'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }
}

final driverCoreControllerProvider =
    Provider<DriverCoreController>((ref) => DriverCoreController(ref));

// ===== 2. HOME SCREEN (TAB 1) =====
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(driverCoreControllerProvider);
    final db = ref.watch(driverMockDbProvider);
    final driverName = ref.watch(currentDriverProvider);
    final current = controller.currentTrip;
    final allTrips = controller.myTrips;
    final nextTrips = allTrips.where((t) => t != current && t['status'] == 'SCHEDULED').toList();

    final dueReports = db.driverReports.where((r) => ['DUE', 'OVERDUE', 'RETURNED'].contains(r['status'] as String)).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          driverName.isEmpty ? 'Hello, Driver' : 'Hello, ${driverName.split(' ')[0]}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(DriverRoutes.alerts),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Due Reports Banner
            if (dueReports > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go(DriverRoutes.reports),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$dueReports report(s) need attention',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                              ),
                              const Text(
                                'Tap to open your daily & weekly checklists.',
                                style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFFD97706)),
                      ],
                    ),
                  ),
                ),
              ),

            // Current Trip Hero Card
            if (current != null) ...[
              _buildTripHeroCard(context, ref, current),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Color(0xFF1677C8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.directions_bus, color: Color(0xFF1677C8)),
                label: const Text(
                  'Open Trip Details & Passengers',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1677C8)),
                ),
                onPressed: () => context.go(DriverRoutes.trip),
              ),
            ] else ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Column(
                    children: [
                      Icon(Icons.directions_bus_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No Active Trip Today',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Not connected yet - built in Phase 5',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text(
              'Upcoming Assigned Trips',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),

            if (nextTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Not connected yet - built in Phase 5',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              )
            else
              for (final t in nextTrips) ...[
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(Icons.calendar_today_outlined, color: Color(0xFF475569), size: 18),
                    ),
                    title: Text(t['route'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('Departs: ${t['depart'].toString().substring(0, 16).replaceAll('T', ' ')} · ${t['bus']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: const Text('SCHEDULED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeroCard(BuildContext context, WidgetRef ref, Map<String, dynamic> trip) {
    final status = trip['status'] as String;
    final checkedIn = (trip['checkedIn'] as List).length;
    final booked = trip['booked'] as int;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12304A), Color(0xFF1677C8)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trip['id'] as String,
                style: const TextStyle(color: Color(0xFFDDF3FC), fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            trip['route'] as String,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Color(0xFFDDF3FC), size: 14),
              const SizedBox(width: 6),
              Text(
                'Departs ${trip['depart'].toString().substring(11, 16)}',
                style: const TextStyle(color: Color(0xFFDDF3FC), fontSize: 13),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.directions_bus_rounded, color: Color(0xFFDDF3FC), size: 14),
              const SizedBox(width: 6),
              Text(
                trip['bus'] as String,
                style: const TextStyle(color: Color(0xFFDDF3FC), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$checkedIn of $booked passengers checked in',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          if (status == 'DELAYED') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Delayed by ${trip['delay']} min (${trip['delayReason']})',
                style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Actions per state
          _buildActionButtons(context, ref, trip),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Map<String, dynamic> trip) {
    final status = trip['status'] as String;

    if (status == 'SCHEDULED') {
      return Tooltip(
        message: 'Not connected yet',
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF12304A),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.group_add_rounded),
          label: const Text('Start Boarding', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          onPressed: null,
        ),
      );
    }

    if (status == 'BOARDING') {
      return Tooltip(
        message: 'Not connected yet',
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 24),
          label: const Text('Start Trip (Pre-Trip Check)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          onPressed: null,
        ),
      );
    }

    if (status == 'IN_TRANSIT') {
      return Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Not connected yet',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.access_time_rounded, size: 18),
                label: const Text('Report Delay'),
                onPressed: null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: 'Not connected yet',
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('End Trip'),
                onPressed: null,
              ),
            ),
          ),
        ],
      );
    }

    if (status == 'DELAYED') {
      return Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Not connected yet',
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Resume Trip'),
                onPressed: null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: 'Not connected yet',
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('End Trip'),
                onPressed: null,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ignore: unused_element
  void _showDelaySheet(BuildContext context, WidgetRef ref, String tripId) {
    int selectedMins = 30;
    String selectedReason = 'Traffic';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Report Trip Delay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 14),
                  const Text('How late are you? (minutes)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [15, 30, 45, 60, 90].map((m) {
                      return ChoiceChip(
                        label: Text('$m min'),
                        selected: selectedMins == m,
                        onSelected: (_) => setState(() => selectedMins = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Reason for delay', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Traffic', 'Breakdown', 'Weather', 'Police check'].map((r) {
                      return ChoiceChip(
                        label: Text(r),
                        selected: selectedReason == r,
                        onSelected: (_) => setState(() => selectedReason = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1677C8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ref.read(driverMockDbProvider).reportDelay(tripId, selectedMins, selectedReason);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delay of $selectedMins min reported. Passengers notified.'),
                          backgroundColor: const Color(0xFFF59E0B),
                        ),
                      );
                    },
                    child: const Text('Confirm & Notify Passengers', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ===== 3. YOUR TRIP SCREEN (TAB 2) =====
class DriverTripScreen extends ConsumerWidget {
  const DriverTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(driverCoreControllerProvider);
    final db = ref.watch(driverMockDbProvider);
    final trip = controller.currentTrip;

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Trip', style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF12304A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Not connected yet - built in Phase 5'),
        ),
      );
    }

    final route = db.routeOfTrip(trip['routeId'] as String? ?? '');
    final stops = (route?['stops'] as List<dynamic>?) ?? [];
    final passengers = db.passengersOfTrip(trip['id'] as String);
    final checkedIn = List<String>.from(trip['checkedIn'] as List);

    return Scaffold(
      appBar: AppBar(
        title: Text('${trip['code'] ?? trip['id']} · ${trip['route']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Tracking Progress Widget
            TrackingDriverWidget(tripId: trip['id'] as String),
            const SizedBox(height: 16),

            // Route Stops Section
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Route & Stops Timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 12),
                    for (int i = 0; i < stops.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 7,
                                backgroundColor: i == 0 ? const Color(0xFF10B981) : const Color(0xFF1677C8),
                              ),
                              if (i < stops.length - 1)
                                Container(width: 2, height: 28, color: const Color(0xFFCBD5E1)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stops[i]['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  '${stops[i]['city']} · ${stops[i]['type']} · +${stops[i]['offset']} min',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Passengers Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Passengers (${passengers.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Tooltip(
                  message: 'Not connected yet',
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1677C8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan Ticket'),
                    onPressed: null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Passengers Manifest List
            if (passengers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Not connected yet - built in Phase 5',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ),
              )
            else
              for (final p in passengers) ...[
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFE0F2FE),
                          child: Text(
                            p['customer'][0] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['customer'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(
                                'PNR: ${p['pnr']} · Seats: ${p['seatList']}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                              Text(
                                'Boarding: ${p['board']}',
                                style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (checkedIn.contains(p['id']))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Checked In', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w700, fontSize: 12)),
                          )
                        else
                          Tooltip(
                            message: 'Not connected yet',
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: null,
                              child: const Text('Check In'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showScanTicketSheet(BuildContext context, WidgetRef ref, String tripId) {
    final pnrController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Icon(Icons.qr_code_scanner, size: 54, color: Color(0xFF1677C8))),
              const SizedBox(height: 8),
              const Center(
                child: Text('Scan Ticket QR Code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Point camera at passenger ticket QR or enter PNR',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pnrController,
                decoration: InputDecoration(
                  hintText: 'Enter PNR',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
               const SizedBox(height: 20),
              Tooltip(
                message: 'Not connected yet',
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1677C8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: null,
                  child: const Text('Verify & Check In', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===== 4. PROFILE SCREEN (TAB 5) =====
class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(driverCoreControllerProvider);
    final driver = controller.profile;
    final driverName = ref.watch(currentDriverProvider);
    final lang = ref.watch(driverLanguageProvider);
    final themeMode = ref.watch(driverThemeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final licenceNo = driver?['licence'] as String? ?? 'Not connected yet - built in Phase 5';
    final licExp = driver?['licExp'] as String? ?? 'Not connected yet - built in Phase 5';
    final operatorName = driver?['operatorName'] as String? ?? 'Not connected yet - built in Phase 5';
    final phone = driver?['phone'] as String? ?? 'Not connected yet - built in Phase 5';

    final tripsDoneCount = controller.myTrips.where((t) => t['status'] == 'ARRIVED').length;
    final upcomingCount = controller.myTrips.where((t) => t['status'] == 'SCHEDULED').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('profile', lang), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Avatar + Name card ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF12304A),
                      child: Text(
                        driverName.isNotEmpty ? driverName[0] : '?',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName.isNotEmpty ? driverName : 'Driver',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            operatorName,
                            style: const TextStyle(color: Color(0xFF1677C8), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(phone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Licence card ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('licence', lang),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _kv(t('licence', lang), licenceNo),
                    const SizedBox(height: 8),
                    _kv(t('valid_till', lang), licExp),
                    const SizedBox(height: 8),
                    _kv(t('company', lang), operatorName),
                    const SizedBox(height: 8),
                    _kv(t('phone', lang), phone),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats card ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('$tripsDoneCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                        const SizedBox(height: 2),
                        Text(t('trips_done', lang), style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                    Container(height: 36, width: 1, color: const Color(0xFFCBD5E1)),
                    Column(
                      children: [
                        Text('$upcomingCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1677C8))),
                        const SizedBox(height: 2),
                        Text(t('upcoming', lang), style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Language switcher ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('language', lang),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _langChip(ref, lang, 'en', '🇬🇧  English'),
                        const SizedBox(width: 8),
                        _langChip(ref, lang, 'te', '🇮🇳  తెలుగు'),
                        const SizedBox(width: 8),
                        _langChip(ref, lang, 'hi', '🇮🇳  हिंदी'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Dark mode toggle ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? const Color(0xFF36BDF5) : const Color(0xFF1677C8)),
                value: isDark,
                activeThumbColor: const Color(0xFF1677C8),
                onChanged: (_) => ref.read(driverThemeModeProvider.notifier).toggle(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Sign out ──
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: Text(t('sign_out', lang), style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => context.go(DriverRoutes.signIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _langChip(WidgetRef ref, String current, String code, String label) {
    final selected = current == code;
    return GestureDetector(
      onTap: () => ref.read(driverLanguageProvider.notifier).set(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF12304A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1677C8) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

