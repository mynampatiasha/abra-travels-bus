import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/support_models.dart';
import '../repositories/support_repository.dart';

final faqsProvider = FutureProvider<List<FaqItem>>((ref) {
  return ref.watch(supportRepositoryProvider).getFaqs();
}, retry: (_, _) => null);

final contactInfoProvider = FutureProvider<ContactInfo>((ref) {
  return ref.watch(supportRepositoryProvider).getContactInfo();
}, retry: (_, _) => null);

final supportTicketsProvider =
    AsyncNotifierProvider<SupportTicketsNotifier, List<SupportTicket>>(
      SupportTicketsNotifier.new,
      retry: (_, _) => null,
    );

class SupportTicketsNotifier extends AsyncNotifier<List<SupportTicket>> {
  @override
  Future<List<SupportTicket>> build() async {
    return ref.watch(supportRepositoryProvider).getTickets(customerId: 'me');
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String message,
    String? bookingId,
    List<String> attachments = const <String>[],
  }) async {
    final repo = ref.read(supportRepositoryProvider);
    final ticket = await repo.createTicket(
      customerId: 'me',
      customerName: 'You',
      subject: subject,
      category: category,
      message: message,
      bookingId: bookingId,
      attachments: attachments,
    );
    ref.invalidateSelf();
    return ticket;
  }

  Future<void> reply({
    required String ticketId,
    required String message,
    List<String> attachments = const <String>[],
  }) async {
    final repo = ref.read(supportRepositoryProvider);
    await repo.replyToTicket(
      ticketId: ticketId,
      message: message,
      attachments: attachments,
    );
    ref.invalidateSelf();
  }
}

final ticketDetailProvider =
    FutureProvider.family<SupportTicket?, String>((ref, id) async {
  // Watch supportTicketsProvider so that ticket detail updates whenever a reply is sent
  ref.watch(supportTicketsProvider);
  return ref.watch(supportRepositoryProvider).getTicketById(id);
}, retry: (_, _) => null);
