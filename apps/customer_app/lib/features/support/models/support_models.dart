import 'package:flutter/foundation.dart';

@immutable
class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  final String id;
  final String question;
  final String answer;
  final String category;
}

@immutable
class ContactInfo {
  const ContactInfo({
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.hours,
    required this.emergency,
  });

  final String phone;
  final String whatsapp;
  final String email;
  final String hours;
  final String emergency;
}

@immutable
class TicketMessage {
  const TicketMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.attachments = const <String>[],
  });

  final String sender; // 'customer' or 'agent'
  final String text;
  final DateTime timestamp;
  final List<String> attachments;
}

@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.subject,
    this.number = '',
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.bookingId,
    this.messages = const <TicketMessage>[],
  });

  final String id;

  /// `TK-12`: what people read and say; the id is only for the app.
  final String number;
  final String customerId;
  final String customerName;
  final String subject;
  final String category; // 'BOOKING', 'PAYMENT', 'REFUND', 'SAFETY', 'APP'
  final String priority; // 'LOW', 'MEDIUM', 'HIGH', 'URGENT'
  final String status; // 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'
  final DateTime createdAt;
  final String? bookingId;
  final List<TicketMessage> messages;

  SupportTicket copyWith({
    String? status,
    List<TicketMessage>? messages,
  }) => SupportTicket(
    id: id,
    number: number,
    customerId: customerId,
    customerName: customerName,
    subject: subject,
    category: category,
    priority: priority,
    status: status ?? this.status,
    createdAt: createdAt,
    bookingId: bookingId,
    messages: messages ?? this.messages,
  );
}
