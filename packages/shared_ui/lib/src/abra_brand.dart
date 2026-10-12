import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// A surface filled with the brand gradient and a quiet travel motif (a
/// route arc with stops). For major brand surfaces only: sign-in and
/// onboarding branding and hero headers. Text placed on it should be white
/// and sit on the darker, leading side.
class AbraBrandSurface extends StatelessWidget {
  const AbraBrandSurface({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.gradient = AbraGradients.brand,
    this.showMotif = true,
    super.key,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final Gradient gradient;
  final bool showMotif;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: showMotif
          ? CustomPaint(
              painter: _RouteMotifPainter(
                isRtl: Directionality.of(context) == TextDirection.rtl,
              ),
              child: child,
            )
          : child,
    ),
  );
}

/// Soft circles and a dashed route arc with two stops, on the trailing side.
class _RouteMotifPainter extends CustomPainter {
  const _RouteMotifPainter({required this.isRtl});

  final bool isRtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    if (isRtl) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final glow = Paint()..color = const Color(0x12FFFFFF);
    // Sized from the shorter side, so the motif stays at the trailing
    // edge and clear of the text on wide and on tall surfaces alike.
    final unit = math.min(math.max(size.height, 160.0), size.width * 0.55);
    canvas
      ..drawCircle(
        Offset(size.width - unit * 0.1, -unit * 0.15),
        unit * 0.6,
        glow,
      )
      ..drawCircle(
        Offset(size.width - unit * 0.75, size.height + unit * 0.2),
        unit * 0.45,
        glow,
      );

    final start = Offset(size.width - unit * 1.05, size.height * 0.82);
    final end = Offset(size.width - unit * 0.12, size.height * 0.3);
    final control = Offset(size.width - unit * 0.7, size.height * 0.05);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    final line = Paint()
      ..color = const Color(0x47FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      const dash = 6.0;
      const gap = 6.0;
      for (var at = 0.0; at < metric.length; at += dash + gap) {
        canvas.drawPath(
          metric.extractPath(at, math.min(at + dash, metric.length)),
          line,
        );
      }
    }
    final stopFill = Paint()..color = const Color(0x66FFFFFF);
    final stopCore = Paint()..color = AbraColors.white;
    for (final stop in <Offset>[start, end]) {
      canvas
        ..drawCircle(stop, 7, stopFill)
        ..drawCircle(stop, 3, stopCore);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RouteMotifPainter oldDelegate) =>
      oldDelegate.isRtl != isRtl;
}

/// The Abra Travels logo on a white disc, so it reads the same on navy,
/// on the brand gradient and on light surfaces. Decorative: the product
/// name is always written next to it or announced by the screen.
class AbraLogo extends StatelessWidget {
  const AbraLogo({this.size = 40, super.key});

  static const assetName = 'assets/abra_logo.png';

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.white,
        shape: BoxShape.circle,
        boxShadow: AbraShadows.soft,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset(
            assetName,
            package: 'shared_ui',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            // Never an empty disc: the bus stands in if the file is
            // missing.
            errorBuilder: (context, _, _) => Icon(
              Icons.directions_bus_filled_rounded,
              color: AbraColors.blue,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The product mark: the logo, with the product name and an optional
/// second line next to it.
class AbraBrandMark extends StatelessWidget {
  const AbraBrandMark({
    required this.name,
    this.caption,
    this.onDark = true,
    this.size = 40,
    super.key,
  });

  final String name;
  final String? caption;

  /// True on navy and gradient surfaces (white text).
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final foreground = onDark ? AbraColors.white : AbraColors.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AbraLogo(size: size),
        const SizedBox(width: AbraSpacing.md),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: onDark
                        ? AbraColors.onNavyMuted
                        : AbraColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The line between departure and arrival: two stops joined by a dashed
/// track with a bus on it. Decorative; the times are read from the text
/// around it.
class AbraJourneyLine extends StatelessWidget {
  const AbraJourneyLine({
    this.label,
    this.color = AbraColors.blue,
    this.labelColor = AbraColors.textSecondary,
    this.iconBackground,
    super.key,
  });

  /// Shown above the track, usually the journey time.
  final String? label;
  final Color color;
  final Color labelColor;

  /// What the bus sits on, so the track does not show through it.
  /// Defaults to the card colour.
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (label != null)
        Text(
          label!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: labelColor),
        ),
      const SizedBox(height: AbraSpacing.xxs),
      ExcludeSemantics(
        child: SizedBox(
          height: 20,
          child: CustomPaint(
            painter: _JourneyLinePainter(color),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      iconBackground ??
                      Theme.of(context).cardTheme.color ??
                      AbraColors.white,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AbraSpacing.xxs),
                  child: Icon(
                    Icons.directions_bus_filled_rounded,
                    size: AbraSizes.iconSmall,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _JourneyLinePainter extends CustomPainter {
  const _JourneyLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    for (var x = 6.0; x < size.width - 6; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width - 6), y),
        paint,
      );
    }
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas
      ..drawCircle(Offset(4, y), 3, ring)
      ..drawCircle(Offset(size.width - 4, y), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_JourneyLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
