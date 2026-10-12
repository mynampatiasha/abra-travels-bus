import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/format/dates.dart';
import '../../../core/ui/route_label.dart';
import '../../../l10n/customer_strings.dart';
import '../../discovery/controllers/travel_dates.dart';
import '../../discovery/widgets/discovery_text.dart';
import '../models/ticket_models.dart';

/// The tick of "Booking confirmed": a ring and a check mark that draws
/// itself. With animations switched off it simply appears.
class TickAnimation extends StatefulWidget {
  const TickAnimation({this.size = 84, super.key});

  final double size;

  @override
  State<TickAnimation> createState() => _TickAnimationState();
}

class _TickAnimationState extends State<TickAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _TickPainter(
            // The ring first, then the tick from 25% on.
            tick: Curves.easeOut.transform(
              ((_controller.value - 0.25) / 0.75).clamp(0.0, 1.0),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TickPainter extends CustomPainter {
  const _TickPainter({required this.tick});

  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.45;
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()..color = AbraColors.white.withValues(alpha: 0.2),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = AbraColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.048,
      );
    final path = Path()
      ..moveTo(size.width * 0.31, size.height * 0.51)
      ..lineTo(size.width * 0.44, size.height * 0.64)
      ..lineTo(size.width * 0.69, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * tick),
      Paint()
        ..color = AbraColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) => oldDelegate.tick != tick;
}

/// A dashed line with a notch at each end, as on a torn ticket. The notches
/// take the colour of the page behind the card.
class TearLine extends StatelessWidget {
  const TearLine({super.key});

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: Size(constraints.maxWidth, 20),
          painter: _TearPainter(notch: page),
        ),
      ),
    );
  }
}

class _TearPainter extends CustomPainter {
  const _TearPainter({required this.notch});

  final Color notch;

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = AbraColors.border
      ..strokeWidth = 2;
    for (double x = 14; x < size.width - 14; x += 10) {
      canvas.drawLine(Offset(x, 10), Offset(x + 5, 10), dash);
    }
    canvas
      ..drawCircle(const Offset(0, 10), 10, Paint()..color = notch)
      ..drawCircle(Offset(size.width, 10), 10, Paint()..color = notch);
    final edge = Paint()
      ..color = AbraColors.border
      ..style = PaintingStyle.stroke;
    canvas
      ..drawArc(
        Rect.fromCircle(center: const Offset(0, 10), radius: 10),
        -1.5708,
        3.1416,
        false,
        edge,
      )
      ..drawArc(
        Rect.fromCircle(center: Offset(size.width, 10), radius: 10),
        1.5708,
        3.1416,
        false,
        edge,
      );
  }

  @override
  bool shouldRepaint(_TearPainter oldDelegate) => oldDelegate.notch != notch;
}

/// The e-ticket: gradient header with the journey, the QR code, the
/// passengers, the boarding point and the operator's phone.
class TicketCard extends StatelessWidget {
  const TicketCard({required this.ticket, required this.onCall, super.key});

  final Ticket ticket;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.tryParse(ticket.travelDate);
    final onBrand = textTheme.bodySmall?.copyWith(color: AbraColors.white);
    final time = textTheme.headlineSmall?.copyWith(
      color: AbraColors.white,
      fontWeight: FontWeight.w800,
    );
    final address = <String>[
      if (ticket.boarding.address != null) ticket.boarding.address!,
      l10n.text(CustomerStrings.ticketReportEarly),
    ].join('. ').replaceAll('..', '.');

    return Material(
      color: AbraColors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: AbraRadius.large,
        side: BorderSide(color: AbraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(gradient: AbraGradients.brand),
            child: Padding(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AbraSpacing.md,
                    children: <Widget>[
                      Text(
                        ticket.operatorName,
                        style: textTheme.titleMedium?.copyWith(
                          color: AbraColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.text(
                          CustomerStrings.ticketBarSubtitle,
                          <String, Object?>{'pnr': ticket.pnr},
                        ),
                        style: onBrand,
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              text.time(ticket.departureAt, ticket.timezone),
                              style: time,
                            ),
                            Text(ticket.originName, style: onBrand),
                          ],
                        ),
                      ),
                      Column(
                        children: <Widget>[
                          Text(
                            text.duration(ticket.durationMinutes),
                            textAlign: TextAlign.center,
                            style: onBrand,
                          ),
                          if (date != null)
                            Text(
                              formatShortDate(
                                l10n,
                                TravelDates.asLocalDate(date),
                              ),
                              textAlign: TextAlign.center,
                              style: onBrand,
                            ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              text.time(ticket.arrivalAt, ticket.timezone),
                              style: time,
                            ),
                            Text(
                              ticket.destinationName,
                              textAlign: TextAlign.end,
                              style: onBrand,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AbraSpacing.lg,
              AbraSpacing.lg,
              AbraSpacing.lg,
              0,
            ),
            child: Column(
              children: <Widget>[
                Semantics(
                  image: true,
                  label: l10n.text(CustomerStrings.ticketQrLabel),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AbraColors.white,
                      borderRadius: AbraRadius.medium,
                      border: Border.all(color: AbraColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AbraSpacing.md - 2),
                      child: QrImageView(
                        data: ticket.qrPayload,
                        size: 168,
                        padding: EdgeInsets.zero,
                        backgroundColor: AbraColors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AbraColors.navy,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AbraColors.navy,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AbraSpacing.sm),
                Text(
                  l10n.text(CustomerStrings.ticketQrHint),
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AbraSpacing.md),
            child: TearLine(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AbraSpacing.lg,
              0,
              AbraSpacing.lg,
              AbraSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.text(CustomerStrings.ticketPassengersTitle),
                  style: textTheme.bodySmall,
                ),
                for (final passenger in ticket.passengers)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AbraSpacing.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            passenger.name.isEmpty ? '-' : passenger.name,
                            style: textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          l10n.text(
                            CustomerStrings.ticketSeat,
                            <String, Object?>{'seat': passenger.seatId},
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AbraSpacing.md),
                Text(
                  l10n.text(CustomerStrings.ticketBoardingPoint),
                  style: textTheme.bodySmall,
                ),
                Text(
                  '${ticket.boarding.name}, '
                  '${text.time(ticket.boarding.time, ticket.timezone)}',
                  style: textTheme.titleSmall,
                ),
                Text(address, style: textTheme.bodySmall),
                const SizedBox(height: AbraSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.text(CustomerStrings.ticketOperatorContact),
                            style: textTheme.bodySmall,
                          ),
                          Text(
                            ticket.operatorPhone ?? '-',
                            style: textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    if (onCall != null)
                      IconButton.filled(
                        tooltip: l10n.text(CustomerStrings.ticketCallOperator),
                        style: IconButton.styleFrom(
                          backgroundColor: AbraColors.lightBlue,
                          foregroundColor: AbraColors.blue,
                          minimumSize: const Size.square(
                            AbraSizes.minTouchTarget,
                          ),
                        ),
                        onPressed: onCall,
                        icon: const Icon(Icons.call_rounded),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bengaluru → Hyderabad" and the amount paid, for the confirmation card.
class ConfirmedSummaryCard extends StatelessWidget {
  const ConfirmedSummaryCard({
    required this.ticket,
    required this.paid,
    super.key,
  });

  final Ticket ticket;
  final String paid;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.tryParse(ticket.travelDate);
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            children: <Widget>[
              RouteLabel(
                from: ticket.originName,
                to: ticket.destinationName,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.text(CustomerStrings.ticketPaid, <String, Object?>{
                  'amount': paid,
                }),
                style: textTheme.labelLarge?.copyWith(
                  color: AbraColors.tealDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.sm - 2),
          Text(
            l10n.text(CustomerStrings.ticketSummaryLine, <String, Object?>{
              'operator': ticket.operatorName,
              'date': date == null
                  ? ticket.travelDate
                  : formatShortDate(l10n, TravelDates.asLocalDate(date)),
              'time': text.time(ticket.departureAt, ticket.timezone),
            }),
            style: textTheme.bodySmall,
          ),
          Text(
            l10n.text(CustomerStrings.ticketSummarySeats, <String, Object?>{
              'seats': ticket.seatIds.join(', '),
              'point': ticket.boarding.name,
            }),
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
