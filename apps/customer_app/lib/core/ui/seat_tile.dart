import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// How a seat looks. Not the booking status itself: the screen maps its
/// seat status and selection to one of these.
enum SeatTileState { available, selected, booked, ladiesOnly, blocked }

/// The shape of a seat: an upright seat or a lying berth (wider, with the
/// pillow side marked).
enum SeatTileShape { seat, berth }

/// Colours of seats and of their legend, kept here so that the seat map and
/// its legend always agree. They follow the approved design.
abstract final class SeatColors {
  static const Color border = Color(0xFF9FB3C3);
  static const Color booked = Color(0xFFE5EAEE);
  static const Color bookedText = Color(0xFF8A9AA7);
  static const Color blockedText = Color(0xFFB7C4CF);

  /// The outline of ladies-only seats.
  static const Color ladies = Color(0xFFE0559A);
}

/// One seat or berth of a bus. Selected, booked, ladies-only and blocked
/// differ by more than colour: a selected seat is filled and shows a check,
/// a blocked one is hatched with a dashed outline, a ladies-only one has a
/// thick outline, and every one has a text label for screen readers.
///
/// [width] and [height] come from the available width of the seat map, so
/// the grid always fits. A booked seat answers a tap with a tooltip
/// ([bookedMessage]); a blocked seat does not react.
class SeatTile extends StatefulWidget {
  const SeatTile({
    required this.id,
    required this.state,
    required this.width,
    required this.height,
    required this.semanticsLabel,
    this.price,
    this.shape = SeatTileShape.seat,
    this.bookedMessage,
    this.onTap,
    this.minHitSize = AbraSizes.minTouchTarget,
    super.key,
  });

  final String id;
  final SeatTileState state;
  final double width;
  final double height;

  /// "Seat L6, available, 1,150 rupees" in the user's language.
  final String semanticsLabel;

  /// The formatted fare; not shown on booked and blocked seats.
  final String? price;
  final SeatTileShape shape;

  /// Shown above a booked seat when it is tapped.
  final String? bookedMessage;

  /// Called when an available, selected or ladies-only seat is tapped.
  final VoidCallback? onTap;

  /// Smallest width and height of the area that reacts to a tap, even when
  /// the seat is drawn smaller. 0 for decorations that are not tapped.
  final double minHitSize;

  @override
  State<SeatTile> createState() => _SeatTileState();
}

class _SeatTileState extends State<SeatTile> {
  final GlobalKey<TooltipState> _tooltip = GlobalKey<TooltipState>();

  static const double _radius = 8;

  void _tap() {
    if (widget.state == SeatTileState.booked) {
      _tooltip.currentState?.ensureTooltipVisible();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;
    final (
      Color background,
      Color foreground,
      Color border,
      double thickness,
    ) = switch (state) {
      SeatTileState.available => (
        AbraColors.white,
        AbraColors.navy,
        SeatColors.border,
        1.5,
      ),
      SeatTileState.selected => (
        AbraColors.blue,
        AbraColors.white,
        AbraColors.deepBlue,
        1.5,
      ),
      SeatTileState.booked => (
        SeatColors.booked,
        SeatColors.bookedText,
        SeatColors.booked,
        1.5,
      ),
      SeatTileState.ladiesOnly => (
        AbraColors.white,
        AbraColors.navy,
        SeatColors.ladies,
        2,
      ),
      SeatTileState.blocked => (
        AbraColors.white,
        SeatColors.blockedText,
        SeatColors.border,
        1.5,
      ),
    };
    final isBlocked = state == SeatTileState.blocked;
    final showsPrice =
        widget.price != null && state != SeatTileState.booked && !isBlocked;
    final radius = BorderRadius.circular(_radius);

    // The seat is drawn at its own size; the area that reacts to a tap is at
    // least [minHitSize] square, centred on it. The grid leaves room for it,
    // so the areas of neighbouring seats never overlap.
    final hitWidth = math.max(widget.width, widget.minHitSize);
    final hitHeight = math.max(widget.height, widget.minHitSize);

    Widget tile = SizedBox(
      width: hitWidth,
      height: hitHeight,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: Ink(
                decoration: BoxDecoration(
                  color: isBlocked ? null : background,
                  borderRadius: radius,
                  border: isBlocked
                      ? null
                      : Border.all(color: border, width: thickness),
                ),
                child: CustomPaint(
                  painter: isBlocked
                      ? _BlockedPainter(border: border, radius: _radius)
                      : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (widget.shape == SeatTileShape.berth)
                        PositionedDirectional(
                          start: 5,
                          top: 9,
                          bottom: 9,
                          width: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: foreground.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (state == SeatTileState.selected)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 12,
                                      color: foreground,
                                    ),
                                  Text(
                                    widget.id,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: foreground,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              if (showsPrice)
                                Text(
                                  widget.price!,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: foreground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: InkWell(
                borderRadius: radius,
                onTap: isBlocked ? null : _tap,
              ),
            ),
          ],
        ),
      ),
    );

    if (state == SeatTileState.booked && widget.bookedMessage != null) {
      tile = Tooltip(
        key: _tooltip,
        message: widget.bookedMessage,
        triggerMode: TooltipTriggerMode.manual,
        showDuration: const Duration(milliseconds: 1600),
        child: tile,
      );
    }

    return Semantics(
      container: true,
      button: !isBlocked,
      enabled: !isBlocked,
      selected: state == SeatTileState.selected,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      onTap: isBlocked ? null : _tap,
      child: tile,
    );
  }
}

/// Diagonal stripes and a dashed outline: "not for sale".
class _BlockedPainter extends CustomPainter {
  const _BlockedPainter({required this.border, required this.radius});

  final Color border;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas
      ..save()
      ..clipRRect(rrect);
    final stripe = Paint()
      ..color = SeatColors.booked
      ..strokeWidth = 3;
    for (double x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
    canvas.restore();

    final outline = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect.deflate(0.75));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), outline);
      }
    }
  }

  @override
  bool shouldRepaint(_BlockedPainter oldDelegate) =>
      oldDelegate.border != border || oldDelegate.radius != radius;
}
