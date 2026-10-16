import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

// ===== ROUTE MAP PAINTER (matches demo SVG map) =====
class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.progress,
    required this.stops,
    required this.isDelayed,
  });

  final double progress; // 0.0 – 1.0
  final List<dynamic> stops;
  final bool isDelayed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Road path: slight S-curve, same shape as demo mapBox ──
    final path = Path();
    path.moveTo(w * 0.05, h * 0.75);
    path.cubicTo(
      w * 0.25, h * 0.15,
      w * 0.55, h * 0.90,
      w * 0.95, h * 0.25,
    );

    // Full road (grey)
    final roadPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, roadPaint);

    // Completed portion (blue or amber)
    final progressPaint = Paint()
      ..color = isDelayed ? const Color(0xFFF59E0B) : const Color(0xFF1677C8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathMetrics = path.computeMetrics().first;
    final completedPath = pathMetrics.extractPath(0, pathMetrics.length * progress.clamp(0.0, 1.0));
    canvas.drawPath(completedPath, progressPaint);

    // ── Intermediate stop dots ──
    final stopCount = stops.length;
    for (int i = 0; i < stopCount; i++) {
      final t = stopCount <= 1 ? 0.0 : i / (stopCount - 1).toDouble();
      final pos = pathMetrics.getTangentForOffset(pathMetrics.length * t);
      if (pos == null) continue;
      final passed = t <= progress;
      final dotPaint = Paint()
        ..color = passed ? const Color(0xFF1677C8) : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos.position, 5, dotPaint);
      canvas.drawCircle(
        pos.position,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // ── Origin dot (green) ──
    final originPos = pathMetrics.getTangentForOffset(0);
    if (originPos != null) {
      canvas.drawCircle(originPos.position, 7, Paint()..color = const Color(0xFF10B981));
      canvas.drawCircle(originPos.position, 7,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // ── Destination dot (red) ──
    final destPos = pathMetrics.getTangentForOffset(pathMetrics.length);
    if (destPos != null) {
      canvas.drawCircle(destPos.position, 7, Paint()..color = const Color(0xFFEF4444));
      canvas.drawCircle(destPos.position, 7,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // ── Bus marker at current progress ──
    final busProgress = progress.clamp(0.02, 0.98);
    final busTangent = pathMetrics.getTangentForOffset(pathMetrics.length * busProgress);
    if (busTangent != null) {
      final busPos = busTangent.position;
      // Shadow
      canvas.drawCircle(
        busPos + const Offset(1, 2),
        14,
        Paint()..color = Colors.black26,
      );
      // Circle bg
      canvas.drawCircle(busPos, 14,
          Paint()..color = isDelayed ? const Color(0xFFF59E0B) : const Color(0xFF12304A));
      // Bus icon (simplified rectangle)
      final busRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: busPos, width: 14, height: 10),
        const Radius.circular(2),
      );
      canvas.drawRRect(busRect, Paint()..color = Colors.white);
      // Wheels
      for (final dx in [-4.0, 4.0]) {
        canvas.drawCircle(Offset(busPos.dx + dx, busPos.dy + 6), 2,
            Paint()..color = isDelayed ? const Color(0xFF92400E) : const Color(0xFF12304A));
      }
    }
  }

  @override
  bool shouldRepaint(_RouteMapPainter old) =>
      old.progress != progress || old.isDelayed != isDelayed;
}

// ===== TRACKING WIDGET =====
class TrackingDriverWidget extends ConsumerWidget {
  const TrackingDriverWidget({
    required this.tripId,
    super.key,
  });

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(driverMockDbProvider);
    final gps = db.liveGps;
    final trip = db.trips.firstWhere(
      (t) => t['id'] == tripId,
      orElse: () => <String, dynamic>{},
    );
    final route = db.routeOfTrip(trip['routeId'] as String? ?? '');

    if (trip.isEmpty || route == null) return const SizedBox.shrink();

    final progress = ((gps?['progress'] as num?) ?? 0).toDouble();
    final speed = (gps?['speed'] as num?)?.toInt() ?? 0;
    final isDelayed = trip['status'] == 'DELAYED';
    final stops = (route['stops'] as List<dynamic>?) ?? [];
    final origin = stops.isNotEmpty ? stops.first['name'] as String : 'Origin';
    final dest = stops.isNotEmpty ? stops.last['name'] as String : 'Destination';
    final progressFraction = (progress / 100).clamp(0.0, 1.0);

    // Current stop index
    final currentStopIdx = stops.isEmpty
        ? 0
        : (progressFraction * (stops.length - 1)).floor().clamp(0, stops.length - 1);
    final nextStopIdx = min(currentStopIdx + 1, stops.length - 1);
    final nextStopName = stops.length > 1 ? stops[nextStopIdx]['name'] as String : dest;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _PulseDot(isDelayed: isDelayed),
                    const SizedBox(width: 8),
                    Text(
                      isDelayed
                          ? 'DELAYED  ${trip['delay']} min — ${trip['delayReason'] ?? ''}'
                          : 'Location Sharing  Active',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDelayed ? const Color(0xFFD97706) : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDelayed ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$speed km/h',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isDelayed ? const Color(0xFF92400E) : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Route Map (CustomPaint) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: const Color(0xFFF0F9FF),
                height: 130,
                child: CustomPaint(
                  size: const Size(double.infinity, 130),
                  painter: _RouteMapPainter(
                    progress: progressFraction,
                    stops: stops,
                    isDelayed: isDelayed,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Origin / Destination labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const CircleAvatar(radius: 5, backgroundColor: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(origin, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                ]),
                Row(children: [
                  Text(dest, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  const SizedBox(width: 6),
                  const CircleAvatar(radius: 5, backgroundColor: Color(0xFFEF4444)),
                ]),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDelayed ? const Color(0xFFF59E0B) : const Color(0xFF1677C8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.toInt()}% covered',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                Text(
                  'Next: $nextStopName',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                ),
                const Text(
                  'GPS • just now',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Animated pulsing dot
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.isDelayed});
  final bool isDelayed;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: (widget.isDelayed ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
              .withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
