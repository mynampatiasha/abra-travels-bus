import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/format/dates.dart';
import '../../core/format/rupees.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/tonal_button.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../discovery/controllers/travel_dates.dart';
import '../discovery/widgets/discovery_text.dart';
import 'controllers/ticket_actions.dart';
import 'controllers/url_launcher_provider.dart';
import 'models/ticket_models.dart';
import 'services/ticket_pdf.dart';
import 'widgets/ticket_widgets.dart';

/// What the ticket says, written for sharing.
String _shareText(AbraLocalizations l10n, Ticket ticket) {
  final text = DiscoveryText(l10n);
  final date = DateTime.tryParse(ticket.travelDate);
  return l10n.text(CustomerStrings.ticketShareText, <String, Object?>{
    'pnr': ticket.pnr,
    'route': text.route(ticket.originName, ticket.destinationName),
    'date': date == null
        ? ticket.travelDate
        : formatShortDate(l10n, TravelDates.asLocalDate(date)),
    'time': text.time(ticket.departureAt, ticket.timezone),
    'seats': ticket.seatIds.join(', '),
  });
}

/// The link that adds the journey to a calendar (opens in the browser, so it
/// works on every platform without a calendar plugin).
Uri _calendarUri(AbraLocalizations l10n, Ticket ticket) {
  String stamp(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  return Uri.https('calendar.google.com', '/calendar/render', <String, String>{
    'action': 'TEMPLATE',
    'text': l10n.text(CustomerStrings.ticketCalendarTitle, <String, Object?>{
      'destination': ticket.destinationName,
    }),
    'dates': '${stamp(ticket.departureAt)}/${stamp(ticket.arrivalAt)}',
    'details': l10n.text(CustomerStrings.ticketBarSubtitle, <String, Object?>{
      'pnr': ticket.pnr,
    }),
    'location': ticket.boarding.name,
  });
}

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text(message)),
      );

/// "Booking confirmed": the PNR, the journey, and the ways on (view the
/// ticket, share it, put it in a calendar).
class BookingConfirmedScreen extends ConsumerWidget {
  const BookingConfirmedScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(ticketProvider(bookingId));
    // The booking steps are over: back leads home, not into them.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: GradientAppBar(
          title: l10n.text(CustomerStrings.ticketConfirmedTitle),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.text(CustomerStrings.seatClose),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ),
        body: AsyncValueView<Ticket>(
          value: value,
          onRetry: () => ref.invalidate(ticketProvider(bookingId)),
          data: (context, ticket) => _ConfirmedBody(ticket: ticket),
        ),
      ),
    );
  }
}

class _ConfirmedBody extends ConsumerStatefulWidget {
  const _ConfirmedBody({required this.ticket});

  final Ticket ticket;

  @override
  ConsumerState<_ConfirmedBody> createState() => _ConfirmedBodyState();
}

class _ConfirmedBodyState extends ConsumerState<_ConfirmedBody> {
  Timer? _cleanup;

  @override
  void initState() {
    super.initState();
    // Clear the finished booking once the payment page has left the screen.
    _cleanup = Timer(const Duration(milliseconds: 700), () {
      if (mounted) finishBooking(ref, widget.ticket.tripId);
    });
  }

  @override
  void dispose() {
    _cleanup?.cancel();
    super.dispose();
  }

  Future<void> _copyPnr() async {
    await ref.read(copyTextProvider)(widget.ticket.pnr);
    if (!mounted) return;
    _toast(
      context,
      AbraLocalizations.of(context).text(CustomerStrings.ticketPnrCopied),
    );
  }

  Future<void> _calendar() async {
    final l10n = AbraLocalizations.of(context);
    final opened = await ref.read(urlLauncherProvider)(
      _calendarUri(l10n, widget.ticket),
    );
    if (!opened && mounted) {
      _toast(context, l10n.text(CustomerStrings.ticketCalendarFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ticket = widget.ticket;
    final paid = formatRupees(
      l10n,
      ticket.paidPaise,
      currencyCode: ticket.currency,
    );
    final share = TonalButton(
      label: l10n.text(CustomerStrings.ticketShare),
      icon: Icons.share_rounded,
      expand: CustomerLayout.shouldStack(context),
      onPressed: () => ref.read(shareTextProvider)(_shareText(l10n, ticket)),
    );
    final calendar = TonalButton(
      label: l10n.text(CustomerStrings.ticketAddToCalendar),
      icon: Icons.calendar_month_rounded,
      expand: CustomerLayout.shouldStack(context),
      onPressed: _calendar,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: AbraResponsive.pagePadding(context),
          children: <Widget>[
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AbraGradients.brand,
                borderRadius: AbraRadius.large,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AbraSpacing.xl),
                child: Column(
                  children: <Widget>[
                    const TickAnimation(),
                    const SizedBox(height: AbraSpacing.md),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        l10n.text(CustomerStrings.ticketConfirmedTitle),
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: AbraColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xs),
                    Text(
                      ticket.contactEmail == null
                          ? l10n.text(CustomerStrings.ticketReady)
                          : l10n.text(
                              CustomerStrings.ticketSentTo,
                              <String, Object?>{'email': ticket.contactEmail},
                            ),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AbraColors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    Semantics(
                      button: true,
                      label: l10n.text(CustomerStrings.ticketPnrCopyHint),
                      excludeSemantics: true,
                      onTap: _copyPnr,
                      child: ActionChip(
                        onPressed: _copyPnr,
                        backgroundColor: AbraColors.white,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        label: Text(
                          l10n.text(
                            CustomerStrings.ticketPnrChip,
                            <String, Object?>{'pnr': ticket.pnr},
                          ),
                          style: textTheme.labelLarge?.copyWith(
                            color: AbraColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        avatar: const Icon(
                          Icons.content_copy_rounded,
                          size: 16,
                          color: AbraColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AbraSpacing.md),
            ConfirmedSummaryCard(ticket: ticket, paid: paid),
            const SizedBox(height: AbraSpacing.md),
            AbraButton(
              label: l10n.text(CustomerStrings.ticketViewTicket),
              icon: Icons.confirmation_number_outlined,
              variant: AbraButtonVariant.primary,
              expand: true,
              onPressed: () => context.push(AppRoutes.ticket(ticket.bookingId)),
            ),
            const SizedBox(height: AbraSpacing.md),
            if (CustomerLayout.shouldStack(context))
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  share,
                  const SizedBox(height: AbraSpacing.sm),
                  calendar,
                ],
              )
            else
              Row(
                children: <Widget>[
                  Expanded(child: _Stretch(child: share)),
                  const SizedBox(width: AbraSpacing.md),
                  Expanded(child: _Stretch(child: calendar)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Makes a button fill the cell it is placed in.
class _Stretch extends StatelessWidget {
  const _Stretch({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: double.infinity, child: child);
}

/// The e-ticket with "Download PDF" and "Share".
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  bool _preparingPdf = false;

  Future<void> _call(Ticket ticket) async {
    final phone = ticket.operatorPhone;
    if (phone == null) return;
    await ref.read(urlLauncherProvider)(
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')),
    );
  }

  Future<void> _downloadPdf(Ticket ticket) async {
    if (_preparingPdf) return;
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final date = DateTime.tryParse(ticket.travelDate);
    setState(() => _preparingPdf = true);
    try {
      final pdfText = TicketPdfText(
        title: l10n.text(CustomerStrings.ticketBarTitle),
        pnrLine: l10n.text(CustomerStrings.ticketBarSubtitle, <String, Object?>{
          'pnr': ticket.pnr,
        }),
        departureTime: text.time(ticket.departureAt, ticket.timezone),
        arrivalTime: text.time(ticket.arrivalAt, ticket.timezone),
        date: date == null
            ? ticket.travelDate
            : formatShortDate(l10n, TravelDates.asLocalDate(date)),
        duration: text.duration(ticket.durationMinutes),
        qrHint: l10n.text(CustomerStrings.ticketQrHint),
        passengersTitle: l10n.text(CustomerStrings.ticketPassengersTitle),
        passengerLines: <(String, String)>[
          for (final p in ticket.passengers)
            (
              p.name.isEmpty ? '-' : p.name,
              l10n.text(CustomerStrings.ticketSeat, <String, Object?>{
                'seat': p.seatId,
              }),
            ),
        ],
        boardingTitle: l10n.text(CustomerStrings.ticketBoardingPoint),
        boardingLine:
            '${ticket.boarding.name}, '
            '${text.time(ticket.boarding.time, ticket.timezone)}',
        boardingAddress: ticket.boarding.address ?? '',
        reportEarly: l10n.text(CustomerStrings.ticketReportEarly),
        contactTitle: l10n.text(CustomerStrings.ticketOperatorContact),
        contactValue: ticket.operatorPhone ?? '-',
        paidLine: l10n.text(CustomerStrings.ticketPaid, <String, Object?>{
          'amount': formatRupees(
            l10n,
            ticket.paidPaise,
            currencyCode: ticket.currency,
          ),
        }),
      );
      final bytes = await buildTicketPdf(ticket, pdfText);
      await ref.read(pdfSaverProvider)(bytes, 'abra-ticket-${ticket.pnr}.pdf');
    } on Object {
      if (mounted) _toast(context, l10n.text(CustomerStrings.ticketPdfFailed));
    } finally {
      if (mounted) setState(() => _preparingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(ticketProvider(widget.bookingId));
    final ticket = value.value;
    final gutter = AbraResponsive.gutter(context);
    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.ticketBarTitle),
        subtitle: ticket == null
            ? null
            : l10n.text(CustomerStrings.ticketBarSubtitle, <String, Object?>{
                'pnr': ticket.pnr,
              }),
      ),
      bottomNavigationBar: ticket == null
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: AbraColors.white,
                boxShadow: AbraShadows.raised,
              ),
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.center,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        AbraSpacing.md,
                        gutter,
                        AbraSpacing.md,
                      ),
                      child: CustomerLayout.shouldStack(context)
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _downloadButton(l10n, ticket),
                                const SizedBox(height: AbraSpacing.sm),
                                _shareButton(l10n, ticket),
                              ],
                            )
                          : Row(
                              children: <Widget>[
                                Expanded(child: _downloadButton(l10n, ticket)),
                                const SizedBox(width: AbraSpacing.md),
                                Expanded(
                                  child: _Stretch(
                                    child: _shareButton(l10n, ticket),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
      body: AsyncValueView<Ticket>(
        value: value,
        onRetry: () => ref.invalidate(ticketProvider(widget.bookingId)),
        data: (context, ticket) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: AbraResponsive.pagePadding(context),
              children: <Widget>[
                TicketCard(
                  ticket: ticket,
                  onCall: ticket.operatorPhone == null
                      ? null
                      : () => _call(ticket),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _downloadButton(AbraLocalizations l10n, Ticket ticket) => AbraButton(
    label: l10n.text(CustomerStrings.ticketDownloadPdf),
    icon: Icons.download_rounded,
    variant: AbraButtonVariant.callToAction,
    expand: true,
    isLoading: _preparingPdf,
    onPressed: () => _downloadPdf(ticket),
  );

  Widget _shareButton(AbraLocalizations l10n, Ticket ticket) => TonalButton(
    label: l10n.text(CustomerStrings.ticketShare),
    icon: Icons.share_rounded,
    expand: true,
    onPressed: () => ref.read(shareTextProvider)(_shareText(l10n, ticket)),
  );
}
