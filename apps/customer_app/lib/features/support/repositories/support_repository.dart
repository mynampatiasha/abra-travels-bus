import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/support_models.dart';

abstract class SupportRepository {
  Future<List<FaqItem>> getFaqs();
  Future<ContactInfo> getContactInfo();
  Future<List<SupportTicket>> getTickets({required String customerId});
  Future<SupportTicket?> getTicketById(String id);
  Future<SupportTicket> createTicket({
    required String customerId,
    required String customerName,
    required String subject,
    required String category,
    required String message,
    String? bookingId,
    List<String> attachments = const <String>[],
  });
  Future<SupportTicket> replyToTicket({
    required String ticketId,
    required String message,
    List<String> attachments = const <String>[],
  });
}

/// Not connected yet - built in Phase 4.
class NotConnectedSupportRepository implements SupportRepository {
  const NotConnectedSupportRepository();

  @override
  Future<List<FaqItem>> getFaqs() async => const <FaqItem>[];

  @override
  Future<ContactInfo> getContactInfo() async => const ContactInfo(
        phone: 'Not connected yet',
        whatsapp: 'Not connected yet',
        email: 'Not connected yet',
        hours: 'Not connected yet - built in Phase 4',
        emergency: 'Not connected yet',
      );

  @override
  Future<List<SupportTicket>> getTickets({required String customerId}) async =>
      const <SupportTicket>[];

  @override
  Future<SupportTicket?> getTicketById(String id) async => null;

  @override
  Future<SupportTicket> createTicket({
    required String customerId,
    required String customerName,
    required String subject,
    required String category,
    required String message,
    String? bookingId,
    List<String> attachments = const <String>[],
  }) async =>
      throw StateError('Not connected yet - built in Phase 4');

  @override
  Future<SupportTicket> replyToTicket({
    required String ticketId,
    required String message,
    List<String> attachments = const <String>[],
  }) async =>
      throw StateError('Not connected yet - built in Phase 4');
}

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => const NotConnectedSupportRepository(),
);
