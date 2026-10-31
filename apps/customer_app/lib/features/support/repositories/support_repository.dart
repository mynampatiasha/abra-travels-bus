import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../../app/providers.dart';
import '../../info/info_repository.dart' as info;
import '../../profile/profile_repository.dart' show ProfileProblem;
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

  /// Stores a proof file and returns its id, to be sent with `createTicket`.
  Future<String> uploadProof({required String name, required Uint8List bytes});
}

/// The real help centre and tickets: FAQs and contact details are the public content, tickets
/// are the signed-in customer's own (`/customer/support`). Failures from the changes arrive as
/// [ProfileProblem] with words the person can act on.
class ApiSupportRepository implements SupportRepository {
  ApiSupportRepository(this._client) : _info = info.InfoRepository(_client);

  final ApiClient _client;
  final info.InfoRepository _info;

  @override
  Future<List<FaqItem>> getFaqs() async => [
    for (final faq in await _info.faqs())
      FaqItem(id: faq.id, question: faq.question, answer: faq.answer, category: faq.category),
  ];

  @override
  Future<ContactInfo> getContactInfo() async {
    final contact = await _info.contact();
    return ContactInfo(
      phone: contact.phone,
      whatsapp: '',
      email: contact.email,
      hours: contact.hours,
      emergency: '',
    );
  }

  @override
  Future<List<SupportTicket>> getTickets({required String customerId}) async {
    final response = await _client.get('customer/support/tickets');
    final data = response.data;
    if (data is! List) return const <SupportTicket>[];
    return [for (final item in data) if (item is Map) _ticketFrom(asJsonMap(item))];
  }

  @override
  Future<SupportTicket?> getTicketById(String id) async {
    final response = await _client.get('customer/support/tickets/$id');
    final data = response.data;
    return data is Map ? _ticketFrom(asJsonMap(data)) : null;
  }

  @override
  Future<SupportTicket> createTicket({
    required String customerId,
    required String customerName,
    required String subject,
    required String category,
    required String message,
    String? bookingId,
    List<String> attachments = const <String>[],
  }) async {
    try {
      final response = await _client.post(
        'customer/support/tickets',
        body: <String, Object?>{
          'category': category == 'APP' ? 'OTHER' : category,
          'subject': subject,
          'message': message,
          if (bookingId != null && bookingId.isNotEmpty) 'bookingRef': bookingId,
          if (attachments.isNotEmpty) 'proofFileIds': attachments,
        },
      );
      return _ticketFrom(asJsonMap(response.data! as Map));
    } on Object catch (error) {
      throw ProfileProblem.from(error);
    }
  }

  @override
  Future<SupportTicket> replyToTicket({
    required String ticketId,
    required String message,
    List<String> attachments = const <String>[],
  }) async {
    try {
      final response = await _client.post(
        'customer/support/tickets/$ticketId/replies',
        body: <String, Object?>{'message': message},
      );
      return _ticketFrom(asJsonMap(response.data! as Map));
    } on Object catch (error) {
      throw ProfileProblem.from(error);
    }
  }

  @override
  Future<String> uploadProof({required String name, required Uint8List bytes}) async {
    try {
      final response = await _client.postForm(
        'files/proofs',
        FormData.fromMap(<String, Object?>{'file': MultipartFile.fromBytes(bytes, filename: name)}),
      );
      return JsonReader(asJsonMap(response.data! as Map)).string('id');
    } on Object catch (error) {
      throw ProfileProblem.from(error);
    }
  }

  /// A ticket as the screens read it: the customer's message first, then the replies.
  SupportTicket _ticketFrom(JsonMap json) {
    final reader = JsonReader(json);
    final created = reader.dateTimeOrNull('createdAt') ?? DateTime.now();
    final proofs = [
      for (final proof in json['proofs'] as List? ?? const <Object?>[])
        if (proof is Map && proof['originalName'] is String) proof['originalName'] as String,
    ];
    final replies = [
      for (final reply in json['replies'] as List? ?? const <Object?>[])
        if (reply is Map)
          TicketMessage(
            sender: reply['authorType'] == 'STAFF' ? 'agent' : 'customer',
            text: '${reply['body']}',
            timestamp: DateTime.tryParse('${reply['at']}')?.toLocal() ?? created,
          ),
    ];
    final category = reader.string('category');
    final priority = reader.stringOrNull('priority') ?? 'NORMAL';
    return SupportTicket(
      id: reader.string('id'),
      number: reader.stringOrNull('ticketNumber') ?? '',
      customerId: reader.stringOrNull('customerId') ?? '',
      customerName: reader.stringOrNull('customerName') ?? '',
      subject: reader.stringOrNull('subject') ?? '',
      category: category == 'OTHER' ? 'APP' : category,
      priority: priority == 'NORMAL' ? 'MEDIUM' : priority,
      status: reader.string('status'),
      createdAt: created.toLocal(),
      bookingId: (reader.stringOrNull('bookingRef') ?? '').isEmpty ? null : reader.stringOrNull('bookingRef'),
      messages: [
        if (json['message'] is String)
          TicketMessage(
            sender: 'customer',
            text: json['message'] as String,
            timestamp: created.toLocal(),
            attachments: proofs,
          ),
        ...replies,
      ],
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => ApiSupportRepository(ref.watch(appDependenciesProvider).apiClient),
);
