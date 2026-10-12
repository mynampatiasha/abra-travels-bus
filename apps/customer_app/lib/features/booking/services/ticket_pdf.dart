import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ticket_models.dart';

/// The words and values printed on the ticket PDF, already written in the
/// customer's language (the PDF builder never formats anything itself).
class TicketPdfText {
  const TicketPdfText({
    required this.title,
    required this.pnrLine,
    required this.departureTime,
    required this.arrivalTime,
    required this.date,
    required this.duration,
    required this.qrHint,
    required this.passengersTitle,
    required this.passengerLines,
    required this.boardingTitle,
    required this.boardingLine,
    required this.boardingAddress,
    required this.reportEarly,
    required this.contactTitle,
    required this.contactValue,
    required this.paidLine,
  });

  final String title;
  final String pnrLine;
  final String departureTime;
  final String arrivalTime;
  final String date;
  final String duration;
  final String qrHint;
  final String passengersTitle;

  /// "Sagar Kumar" and "Seat L6", one pair per passenger.
  final List<(String name, String seat)> passengerLines;
  final String boardingTitle;
  final String boardingLine;
  final String boardingAddress;
  final String reportEarly;
  final String contactTitle;
  final String contactValue;
  final String paidLine;
}

/// Builds the ticket as a one-page PDF. The fonts come from the printing
/// package's font service so that the rupee sign prints; when they cannot be
/// fetched (offline) the built-in fonts are used and [rupeeSafe] turns the
/// sign into "Rs" so nothing prints as a blank box.
Future<Uint8List> buildTicketPdf(Ticket ticket, TicketPdfText text) async {
  pw.Font? regular;
  pw.Font? bold;
  try {
    regular = await PdfGoogleFonts.robotoRegular();
    bold = await PdfGoogleFonts.robotoBold();
  } on Object {
    regular = null;
    bold = null;
  }
  final hasUnicode = regular != null && bold != null;
  String safe(String value) => hasUnicode
      ? value
      : value.replaceAll('₹', 'Rs ').replaceAll('•', '-').replaceAll('–', '-');

  final base = pw.TextStyle(font: regular, fontSize: 11);
  final strong = pw.TextStyle(font: bold, fontSize: 11);
  const navy = PdfColor.fromInt(0xFF12304A);
  const blue = PdfColor.fromInt(0xFF1677C8);
  const muted = PdfColor.fromInt(0xFF66798A);

  final document = pw.Document(title: safe(text.title), author: 'Abra Travels');
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Center(
        child: pw.Container(
          width: 420,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: navy,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(10),
                    topRight: pw.Radius.circular(10),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: <pw.Widget>[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: <pw.Widget>[
                        pw.Text(
                          safe(ticket.operatorName),
                          style: strong.copyWith(
                            color: PdfColors.white,
                            fontSize: 14,
                          ),
                        ),
                        pw.Text(
                          safe(text.pnrLine),
                          style: base.copyWith(color: PdfColors.white),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 14),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        _timeBlock(
                          safe(text.departureTime),
                          safe(ticket.originName),
                          base,
                          strong,
                          pw.CrossAxisAlignment.start,
                        ),
                        pw.Column(
                          children: <pw.Widget>[
                            pw.Text(
                              safe(text.duration),
                              style: base.copyWith(color: PdfColors.white),
                            ),
                            pw.Text(
                              safe(text.date),
                              style: base.copyWith(color: PdfColors.white),
                            ),
                          ],
                        ),
                        _timeBlock(
                          safe(text.arrivalTime),
                          safe(ticket.destinationName),
                          base,
                          strong,
                          pw.CrossAxisAlignment.end,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: <pw.Widget>[
                    pw.Center(
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: ticket.qrPayload,
                        width: 150,
                        height: 150,
                        color: navy,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Center(
                      child: pw.Text(
                        safe(text.qrHint),
                        style: base.copyWith(color: muted, fontSize: 9),
                      ),
                    ),
                    pw.Divider(color: PdfColors.grey400),
                    pw.Text(
                      safe(text.passengersTitle),
                      style: base.copyWith(color: muted, fontSize: 9),
                    ),
                    for (final (name, seat) in text.passengerLines)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: <pw.Widget>[
                            pw.Text(safe(name), style: strong),
                            pw.Text(safe(seat), style: base),
                          ],
                        ),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      safe(text.boardingTitle),
                      style: base.copyWith(color: muted, fontSize: 9),
                    ),
                    pw.Text(safe(text.boardingLine), style: strong),
                    pw.Text(
                      safe('${text.boardingAddress} ${text.reportEarly}'),
                      style: base.copyWith(color: muted),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      safe(text.contactTitle),
                      style: base.copyWith(color: muted, fontSize: 9),
                    ),
                    pw.Text(
                      safe(text.contactValue),
                      style: strong.copyWith(color: blue),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(safe(text.paidLine), style: strong),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return document.save();
}

pw.Widget _timeBlock(
  String time,
  String city,
  pw.TextStyle base,
  pw.TextStyle strong,
  pw.CrossAxisAlignment alignment,
) => pw.Column(
  crossAxisAlignment: alignment,
  children: <pw.Widget>[
    pw.Text(time, style: strong.copyWith(color: PdfColors.white, fontSize: 20)),
    pw.Text(city, style: base.copyWith(color: PdfColors.white)),
  ],
);
