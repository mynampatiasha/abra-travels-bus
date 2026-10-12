import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../discovery/controllers/trip_selection_controller.dart';
import '../models/ticket_models.dart';
import '../repositories/ticket_repository.dart';
import 'booking_draft_controller.dart';

/// The ticket of a booking.
final ticketProvider = FutureProvider.autoDispose.family<Ticket, String>(
  (ref, bookingId) => ref.watch(ticketRepositoryProvider).ticket(bookingId),
);

/// Shares [text] through the system share sheet. A provider, so a test can
/// replace it and see what would have been shared.
final shareTextProvider = Provider<Future<void> Function(String text)>(
  (ref) => (text) async {
    await Share.share(text);
  },
);

/// Copies [text] to the clipboard.
final copyTextProvider = Provider<Future<void> Function(String text)>(
  (ref) =>
      (text) => Clipboard.setData(ClipboardData(text: text)),
);

/// Hands a PDF to the system to save or share (a download in the browser).
final pdfSaverProvider =
    Provider<Future<void> Function(Uint8List bytes, String filename)>(
      (ref) => (bytes, filename) async {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      },
    );

/// Clears what the customer chose for [tripId] once the booking is paid, so
/// a new booking starts empty.
void finishBooking(WidgetRef ref, String tripId) {
  ref.read(tripSelectionProvider(tripId).notifier).setSeats(const <String>[]);
  ref.read(bookingDraftProvider(tripId).notifier).reset();
}
