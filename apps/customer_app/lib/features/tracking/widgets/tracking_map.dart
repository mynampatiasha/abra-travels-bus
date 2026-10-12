import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

/// What the map has to show: the route is drawn from its start to its end,
/// the bus and the customer's stop sit at a point along it.
@immutable
class MapSpec {
  const MapSpec({
    required this.busProgress,
    required this.stopProgress,
    required this.isStale,
    required this.stopLabel,
    required this.semanticsLabel,
  });

  /// 0 (start of the route) to 1 (end).
  final double busProgress;
  final double stopProgress;

  /// The position is old: the bus is drawn grey and the route dotted.
  final bool isStale;
  final String stopLabel;
  final String semanticsLabel;
}

/// Builds the map for [MapSpec]. The app's map SDK (Google Maps or Mappls)
/// is provided here when it is chosen and its key is available; until then
/// [RouteMapPlaceholder] stands in. Everything that shows a map goes through
/// this provider, so connecting the SDK changes one place.
final mapBuilderProvider =
    Provider<Widget Function(BuildContext context, MapSpec spec)>(
      (ref) =>
          (context, spec) => RouteMapPlaceholder(spec: spec),
    );

/// The map of a trip, from [mapBuilderProvider], filling the space it gets.
class TrackingMap extends ConsumerWidget {
  const TrackingMap({required this.spec, super.key});

  final MapSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(mapBuilderProvider)(context, spec);
}

/// A drawn stand-in for the map: streets, the route, the customer's stop and
/// the bus. It is not a real map (listed in MISSING_ASSETS.md).
class RouteMapPlaceholder extends StatefulWidget {
  const RouteMapPlaceholder({required this.spec, super.key});

  final MapSpec spec;

  @override
  State<RouteMapPlaceholder> createState() => _RouteMapPlaceholderState();
}

class _RouteMapPlaceholderState extends State<RouteMapPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        MediaQuery.disableAnimationsOf(context) || widget.spec.isStale;
    if (still) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(RouteMapPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: widget.spec.semanticsLabel,
    child: ClipRect(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _MapPainter(
            spec: widget.spec,
            pulse: _pulse.value,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AbraColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.spec,
    required this.pulse,
    required this.labelStyle,
  });

  final MapSpec spec;
  final double pulse;
  final TextStyle? labelStyle;

  static const double _w = 360;
  static const double _h = 250;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw on a 360 x 250 sheet, scaled to fit the space (the map colour
    // continues beyond it).
    final scale = math.min(size.width / _w, size.height / _h);
    canvas
      ..save()
      ..translate((size.width - _w * scale) / 2, (size.height - _h * scale) / 2)
      ..scale(scale);

    canvas.drawRect(
      const Rect.fromLTWH(-3000, -3000, _w + 6000, _h + 6000),
      Paint()..color = AbraColors.lightBlue,
    );
    final road = Paint()
      ..color = AbraColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(-40, 60)
          ..cubicTo(80, 70, 140, 30, 220, 50)
          ..cubicTo(300, 70, 320, 90, 400, 70)
          ..moveTo(-40, 170)
          ..cubicTo(90, 150, 150, 200, 240, 180)
          ..cubicTo(320, 160, 330, 140, 400, 160)
          ..moveTo(70, -40)
          ..cubicTo(80, 80, 60, 150, 90, 290)
          ..moveTo(250, -40)
          ..cubicTo(240, 90, 270, 160, 250, 290),
        road,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(278, 92, 58, 44),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFFCFEBDD),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 190, 70, 40),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFFCFEBDD),
      );

    final route = Path()
      ..moveTo(40, 205)
      ..cubicTo(90, 190, 120, 140, 175, 125)
      ..cubicTo(230, 110, 270, 90, 322, 40);
    final metric = route.computeMetrics().first;
    Offset at(double t) =>
        metric.getTangentForOffset(metric.length * t.clamp(0.0, 1.0))!.position;

    final live = spec.isStale ? const Color(0xFF8A9AA7) : AbraColors.blue;
    final done = metric.extractPath(0, metric.length * spec.busProgress);
    final rest = metric.extractPath(
      metric.length * spec.busProgress,
      metric.length,
    );
    if (spec.isStale) {
      _dashed(canvas, metric.extractPath(0, metric.length), live, 5);
    } else {
      canvas.drawPath(
        done,
        Paint()
          ..color = live
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      _dashed(canvas, rest, const Color(0xFF9FB3C3), 5);
    }

    final start = at(0);
    final end = at(1);
    final stop = at(spec.stopProgress);
    final bus = at(spec.busProgress);
    canvas
      ..drawCircle(start, 7, Paint()..color = AbraColors.white)
      ..drawCircle(
        start,
        7,
        Paint()
          ..color = live
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      )
      ..drawCircle(end, 8, Paint()..color = AbraColors.navy)
      ..drawCircle(stop, 8, Paint()..color = AbraColors.white)
      ..drawCircle(
        stop,
        8,
        Paint()
          ..color = AbraColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    final label = TextPainter(
      text: TextSpan(text: spec.stopLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 150);
    label.paint(canvas, stop + const Offset(11, 8));

    if (!spec.isStale) {
      canvas.drawCircle(
        bus,
        16 + 10 * pulse,
        Paint()
          ..color = AbraColors.skyBlue.withValues(alpha: 0.5 * (1 - pulse)),
      );
    }
    canvas
      ..drawCircle(
        bus,
        12,
        Paint()
          ..color = spec.isStale ? const Color(0xFF8A9AA7) : AbraColors.blue,
      )
      ..drawCircle(
        bus,
        12,
        Paint()
          ..color = AbraColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    // The bus: a small body with a line through it.
    final body = Paint()
      ..color = AbraColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas
      ..drawRect(Rect.fromCenter(center: bus, width: 10, height: 8), body)
      ..drawLine(bus + const Offset(-5, 0), bus + const Offset(5, 0), body);
    canvas.restore();
  }

  void _dashed(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 11) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 2, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.spec != spec ||
      oldDelegate.labelStyle != labelStyle;
}
