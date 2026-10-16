import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/support_models.dart';
import 'mock_support_repository.dart';

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

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => MockSupportRepository(),
);
