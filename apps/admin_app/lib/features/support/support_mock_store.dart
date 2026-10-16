import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Models and state store for Support Tickets, Chat/WhatsApp Messages, and Content/Policies.
/// Matches prototypes/admin_demo_model.html lines 1009-1042.

class TicketMessage {
  TicketMessage({
    required this.sender, // 'agent' | 'customer'
    required this.senderName,
    required this.text,
    required this.at,
    this.attachments = const <String>[],
  });

  final String sender;
  final String senderName;
  final String text;
  final DateTime at;
  final List<String> attachments;
}

class TicketRecord {
  TicketRecord({
    required this.id,
    required this.subject,
    required this.customer,
    required this.customerId,
    required this.category, // BOOKING, PAYMENT, REFUND, SAFETY, APP
    required this.priority, // URGENT, HIGH, MEDIUM, LOW
    required this.status, // OPEN, IN_PROGRESS, RESOLVED, CLOSED
    this.assignee,
    required this.sla,
    this.bookingId,
    required this.at,
    required this.messages,
  });

  final String id;
  final String subject;
  final String customer;
  final String customerId;
  String category;
  String priority;
  String status;
  String? assignee;
  DateTime sla;
  final String? bookingId;
  final DateTime at;
  final List<TicketMessage> messages;

  bool get isPastSla =>
      (status == 'OPEN' || status == 'IN_PROGRESS') &&
      DateTime.now().isAfter(sla);
}

class ChatSessionRecord {
  ChatSessionRecord({
    required this.id,
    required this.customer,
    required this.phone,
    required this.channel, // WhatsApp, Live Chat
    required this.status, // ACTIVE, RESOLVED
    required this.lastMessage,
    required this.lastAt,
    this.unreadCount = 0,
    required this.messages,
  });

  final String id;
  final String customer;
  final String phone;
  final String channel;
  String status;
  String lastMessage;
  DateTime lastAt;
  int unreadCount;
  final List<TicketMessage> messages;
}

class FaqRecord {
  FaqRecord({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.status, // PUBLISHED, DRAFT
    this.views = 0,
    required this.updated,
  });

  final String id;
  String question;
  String answer;
  String category;
  String status;
  int views;
  DateTime updated;
}

class PolicyPageRecord {
  PolicyPageRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    required this.updated,
    required this.content,
  });

  final String id;
  String title;
  String status;
  int version;
  DateTime updated;
  String content;
}

class ContactConfig {
  ContactConfig({
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.hours,
    required this.emergency,
  });

  String phone;
  String whatsapp;
  String email;
  String hours;
  String emergency;

  ContactConfig copyWith({
    String? phone,
    String? whatsapp,
    String? email,
    String? hours,
    String? emergency,
  }) {
    return ContactConfig(
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      hours: hours ?? this.hours,
      emergency: emergency ?? this.emergency,
    );
  }
}

class SupportState {
  const SupportState({
    required this.tickets,
    required this.chatSessions,
    required this.faqs,
    required this.pages,
    required this.contact,
    required this.cannedReplies,
  });

  final List<TicketRecord> tickets;
  final List<ChatSessionRecord> chatSessions;
  final List<FaqRecord> faqs;
  final List<PolicyPageRecord> pages;
  final ContactConfig contact;
  final List<String> cannedReplies;

  SupportState copyWith({
    List<TicketRecord>? tickets,
    List<ChatSessionRecord>? chatSessions,
    List<FaqRecord>? faqs,
    List<PolicyPageRecord>? pages,
    ContactConfig? contact,
    List<String>? cannedReplies,
  }) {
    return SupportState(
      tickets: tickets ?? this.tickets,
      chatSessions: chatSessions ?? this.chatSessions,
      faqs: faqs ?? this.faqs,
      pages: pages ?? this.pages,
      contact: contact ?? this.contact,
      cannedReplies: cannedReplies ?? this.cannedReplies,
    );
  }
}

final supportStoreProvider =
    NotifierProvider<SupportStoreNotifier, SupportState>(
      SupportStoreNotifier.new,
    );

class SupportStoreNotifier extends Notifier<SupportState> {
  @override
  SupportState build() => _seedInitialData();

  static SupportState _seedInitialData() {
    final now = DateTime.now();

    final cannedReplies = <String>[
      'We have received your request and our support team is currently looking into your booking details.',
      'The refund has been initiated and should reflect in your source payment account within 3-5 business days.',
      'We apologize for the inconvenience caused by the trip delay. The bus has resumed journey.',
      'Your boarding point details have been sent via SMS and WhatsApp.',
      'Please share the transaction ID or screenshot from your bank statement so we can trace the payment.',
      'The AC issue reported on your coach has been flagged to the operator for immediate inspection.',
    ];

    final tickets = <TicketRecord>[
      TicketRecord(
        id: 'TK-1001',
        subject: 'Amount deducted twice but seat not confirmed',
        customer: 'Aarav Sharma',
        customerId: 'CU1',
        category: 'PAYMENT',
        priority: 'URGENT',
        status: 'OPEN',
        assignee: 'Divya (Support)',
        sla: now.subtract(const Duration(minutes: 45)), // Overdue
        bookingId: 'BK-7001',
        at: now.subtract(const Duration(hours: 4)),
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Aarav Sharma',
            text:
                'I paid ₹1,290 twice via UPI due to a timeout. First transaction was debited from HDFC account ending 4821.',
            at: now.subtract(const Duration(hours: 4)),
            attachments: ['payment_receipt_hdfc.pdf'],
          ),
          TicketMessage(
            sender: 'agent',
            senderName: 'Divya (Support)',
            text:
                'Checking payment gateway reconciliation for transaction ref UPI-984210. We will process auto-reversal.',
            at: now.subtract(const Duration(hours: 2, minutes: 30)),
          ),
        ],
      ),
      TicketRecord(
        id: 'TK-1002',
        subject: 'Bus departed without boarding at Gachibowli stop',
        customer: 'Priya Nair',
        customerId: 'CU2',
        category: 'SAFETY',
        priority: 'HIGH',
        status: 'IN_PROGRESS',
        assignee: 'Kiran (Support)',
        sla: now.add(const Duration(minutes: 30)),
        bookingId: 'BK-7002',
        at: now.subtract(const Duration(hours: 1, minutes: 20)),
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Priya Nair',
            text:
                'I reached Gachibowli pickup at 9:15 PM as instructed. The driver did not answer calls and left at 9:10 PM!',
            at: now.subtract(const Duration(hours: 1, minutes: 20)),
          ),
          TicketMessage(
            sender: 'agent',
            senderName: 'Kiran (Support)',
            text:
                'We have contacted Kaveri Express operations lead. A cab transfer to the next toll plaza pickup is being arranged.',
            at: now.subtract(const Duration(minutes: 50)),
          ),
        ],
      ),
      TicketRecord(
        id: 'TK-1003',
        subject: 'Requesting invoice with company GSTIN',
        customer: 'Rohan Mehta',
        customerId: 'CU3',
        category: 'BOOKING',
        priority: 'MEDIUM',
        status: 'OPEN',
        assignee: null,
        sla: now.add(const Duration(hours: 3)),
        bookingId: 'BK-7003',
        at: now.subtract(const Duration(hours: 5)),
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Rohan Mehta',
            text:
                'Need tax invoice updated with GSTIN 36AAAAA1234A1Z9 for my travel from Hyderabad to Bangalore.',
            at: now.subtract(const Duration(hours: 5)),
          ),
        ],
      ),
      TicketRecord(
        id: 'TK-1004',
        subject: 'Refund not received after trip cancellation',
        customer: 'Ananya Reddy',
        customerId: 'CU4',
        category: 'REFUND',
        priority: 'HIGH',
        status: 'IN_PROGRESS',
        assignee: 'Divya (Support)',
        sla: now.subtract(const Duration(hours: 1)), // Overdue
        bookingId: 'BK-7004',
        at: now.subtract(const Duration(days: 1)),
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Ananya Reddy',
            text:
                'The operator cancelled the trip due to a breakdown yesterday. When will my refund of ₹1,850 reflect?',
            at: now.subtract(const Duration(days: 1)),
          ),
          TicketMessage(
            sender: 'agent',
            senderName: 'Divya (Support)',
            text:
                'Refund ARN 784210984 has been generated. The amount was credited to your UPI VPA.',
            at: now.subtract(const Duration(hours: 3)),
          ),
        ],
      ),
      TicketRecord(
        id: 'TK-1005',
        subject: 'App crashing on seat selection screen on iOS 18',
        customer: 'Vikram Singh',
        customerId: 'CU5',
        category: 'APP',
        priority: 'LOW',
        status: 'OPEN',
        assignee: null,
        sla: now.add(const Duration(hours: 8)),
        at: now.subtract(const Duration(hours: 2)),
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Vikram Singh',
            text:
                'Whenever I tap on lower deck sleeper berth 14B, the app freezes and closes immediately.',
            at: now.subtract(const Duration(hours: 2)),
          ),
        ],
      ),
      TicketRecord(
        id: 'TK-1006',
        subject: 'Luggage tag dispute at dropping point',
        customer: 'Divya Iyer',
        customerId: 'CU6',
        category: 'BOOKING',
        priority: 'MEDIUM',
        status: 'RESOLVED',
        assignee: 'Kiran (Support)',
        sla: now.subtract(const Duration(days: 2)),
        bookingId: 'BK-7006',
        at: now.subtract(const Duration(days: 2, hours: 4)),
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Divya Iyer',
            text:
                'Conductor asked for an extra ₹100 for luggage. Is this allowable?',
            at: now.subtract(const Duration(days: 2, hours: 4)),
          ),
          TicketMessage(
            sender: 'agent',
            senderName: 'Kiran (Support)',
            text:
                'Standard luggage up to 2 bags (20kg total) is free. We have penalized the operator and credited ₹100 Abra wallet cash.',
            at: now.subtract(const Duration(days: 2, hours: 1)),
          ),
        ],
      ),
      TicketRecord(
        id: 'TK-1007',
        subject: 'AC cooling inadequate in coach KA-01-AB-1234',
        customer: 'Rahul Verma',
        customerId: 'CU7',
        category: 'SAFETY',
        priority: 'MEDIUM',
        status: 'RESOLVED',
        assignee: 'Divya (Support)',
        sla: now.subtract(const Duration(days: 3)),
        bookingId: 'BK-7007',
        at: now.subtract(const Duration(days: 3)),
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Rahul Verma',
            text:
                'The AC was blowing warm air throughout the 10 hour overnight trip.',
            at: now.subtract(const Duration(days: 3)),
          ),
          TicketMessage(
            sender: 'agent',
            senderName: 'Divya (Support)',
            text:
                'Apologies! We have issued a 25% courtesy refund of ₹350 to your wallet.',
            at: now.subtract(const Duration(days: 2, hours: 22)),
          ),
        ],
      ),
    ];

    final chatSessions = <ChatSessionRecord>[
      ChatSessionRecord(
        id: 'CHAT-501',
        customer: 'Meera Pillai',
        phone: '+91 98450 11228',
        channel: 'WhatsApp',
        status: 'ACTIVE',
        lastMessage: 'Is my bus running on time today?',
        lastAt: now.subtract(const Duration(minutes: 8)),
        unreadCount: 2,
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Meera Pillai',
            text: 'Hello, I have a booking for Hyderabad to Bangalore tonight.',
            at: now.subtract(const Duration(minutes: 15)),
          ),
          TicketMessage(
            sender: 'agent',
            senderName: 'Abra Bot',
            text:
                'Welcome to Abra Travels! Your PNR is ABRK9821. Trip departs at 10:15 PM.',
            at: now.subtract(const Duration(minutes: 14)),
          ),
          TicketMessage(
            sender: 'customer',
            senderName: 'Meera Pillai',
            text: 'Is my bus running on time today?',
            at: now.subtract(const Duration(minutes: 8)),
          ),
        ],
      ),
      ChatSessionRecord(
        id: 'CHAT-502',
        customer: 'Karthik Rao',
        phone: '+91 98450 11229',
        channel: 'Live Chat',
        status: 'ACTIVE',
        lastMessage: 'Can I change my pickup point to Miyapur?',
        lastAt: now.subtract(const Duration(minutes: 24)),
        unreadCount: 1,
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Karthik Rao',
            text: 'Hi, I selected Ameerpet pickup by mistake.',
            at: now.subtract(const Duration(minutes: 26)),
          ),
          TicketMessage(
            sender: 'customer',
            senderName: 'Karthik Rao',
            text: 'Can I change my pickup point to Miyapur?',
            at: now.subtract(const Duration(minutes: 24)),
          ),
        ],
      ),
      ChatSessionRecord(
        id: 'CHAT-503',
        customer: 'Pooja Shah',
        phone: '+91 98450 11230',
        channel: 'WhatsApp',
        status: 'RESOLVED',
        lastMessage: 'Thank you for the quick help!',
        lastAt: now.subtract(const Duration(hours: 3)),
        unreadCount: 0,
        messages: [
          TicketMessage(
            sender: 'customer',
            senderName: 'Pooja Shah',
            text: 'I lost my umbrella on seat 4A Kaveri Express.',
            at: now.subtract(const Duration(hours: 4)),
          ),
          TicketMessage(
            sender: 'agent',
            senderName: 'Divya (Support)',
            text:
                'We contacted the conductor. The item has been deposited at the Majestic counter.',
            at: now.subtract(const Duration(hours: 3, minutes: 10)),
          ),
          TicketMessage(
            sender: 'customer',
            senderName: 'Pooja Shah',
            text: 'Thank you for the quick help!',
            at: now.subtract(const Duration(hours: 3)),
          ),
        ],
      ),
    ];

    final faqs = <FaqRecord>[
      FaqRecord(
        id: 'FAQ-1',
        question: 'How do I cancel my bus ticket and what are the refund rules?',
        answer:
            'You can cancel your booking directly from the My Bookings section in the app. Cancellations made 24h+ before departure receive a 90% refund, 12-24h receive 75%, and 6-12h receive 50%.',
        category: 'Refunds',
        status: 'PUBLISHED',
        views: 1420,
        updated: now.subtract(const Duration(days: 5)),
      ),
      FaqRecord(
        id: 'FAQ-2',
        question: 'What luggage can I bring on board without extra charges?',
        answer:
            'Each passenger is allowed up to 2 items of personal luggage not exceeding 20 kg in total. Excess baggage charges may apply at the operator’s discretion.',
        category: 'Trips',
        status: 'PUBLISHED',
        views: 890,
        updated: now.subtract(const Duration(days: 12)),
      ),
      FaqRecord(
        id: 'FAQ-3',
        question: 'How does live GPS bus tracking work on Abra Travels?',
        answer:
            'Track your bus in real time via the Track Bus link in your booking confirmation SMS or on the Trips screen in the app. Updates refresh every 30 seconds.',
        category: 'Trips',
        status: 'PUBLISHED',
        views: 2150,
        updated: now.subtract(const Duration(days: 3)),
      ),
      FaqRecord(
        id: 'FAQ-4',
        question: 'What safety features are provided for women solo travelers?',
        answer:
            'We provide live trip sharing, emergency SOS triggers, 24/7 safety command center escalation, and female-only adjacent seat allocation.',
        category: 'Safety',
        status: 'PUBLISHED',
        views: 940,
        updated: now.subtract(const Duration(days: 8)),
      ),
      FaqRecord(
        id: 'FAQ-5',
        question: 'How do I apply coupon codes or discount vouchers?',
        answer:
            'During checkout on the review booking screen, enter your promo code in the "Apply Coupon" field and click Apply before completing payment.',
        category: 'Offers',
        status: 'PUBLISHED',
        views: 1680,
        updated: now.subtract(const Duration(days: 20)),
      ),
      FaqRecord(
        id: 'FAQ-6',
        question: 'Do I need to carry a printed copy of the m-ticket?',
        answer:
            'No physical printout is required. Showing the SMS or WhatsApp confirmation with a valid government ID (Aadhaar, DL, Passport) is sufficient.',
        category: 'Bookings',
        status: 'DRAFT',
        views: 120,
        updated: now.subtract(const Duration(days: 1)),
      ),
    ];

    final pages = <PolicyPageRecord>[
      PolicyPageRecord(
        id: 'terms',
        title: 'Terms of Service',
        status: 'PUBLISHED',
        version: 5,
        updated: now.subtract(const Duration(days: 15)),
        content:
            'These Terms of Service govern your use of the Abra Travels bus ticketing platform and services.',
      ),
      PolicyPageRecord(
        id: 'privacy',
        title: 'Privacy Policy',
        status: 'PUBLISHED',
        version: 4,
        updated: now.subtract(const Duration(days: 30)),
        content:
            'Abra Travels respects your privacy. We collect data required for ticketing, live GPS updates, and customer support.',
      ),
      PolicyPageRecord(
        id: 'cancellation',
        title: 'Cancellation and Refund Policy',
        status: 'PUBLISHED',
        version: 7,
        updated: now.subtract(const Duration(days: 4)),
        content:
            'Cancellation fees depend on departure hours and operator slabs. Convenience fees are non-refundable.',
      ),
      PolicyPageRecord(
        id: 'women-safety',
        title: 'Women Safety & Conduct Guidelines',
        status: 'PUBLISHED',
        version: 2,
        updated: now.subtract(const Duration(days: 60)),
        content:
            'Zero tolerance for harassment. All distress alerts are immediately shared with local law enforcement.',
      ),
    ];

    final contact = ContactConfig(
      phone: '+91 40 4000 1234',
      whatsapp: '+91 98765 43210',
      email: 'support@abratravels.in',
      hours: '24/7 all days (including public holidays)',
      emergency: '+91 100 / +91 40 4000 9999',
    );

    return SupportState(
      tickets: tickets,
      chatSessions: chatSessions,
      faqs: faqs,
      pages: pages,
      contact: contact,
      cannedReplies: cannedReplies,
    );
  }

  void addTicketReply(String ticketId, String text, {List<String>? files}) {
    final tickets = [...state.tickets];
    final idx = tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;

    final t = tickets[idx];
    final updatedMsgs = [
      ...t.messages,
      TicketMessage(
        sender: 'agent',
        senderName: t.assignee ?? 'Divya (Support)',
        text: text,
        at: DateTime.now(),
        attachments: files ?? const [],
      ),
    ];

    t.status = t.status == 'OPEN' ? 'IN_PROGRESS' : t.status;
    t.assignee ??= 'Divya (Support)';

    final updatedTicket = TicketRecord(
      id: t.id,
      subject: t.subject,
      customer: t.customer,
      customerId: t.customerId,
      category: t.category,
      priority: t.priority,
      status: t.status,
      assignee: t.assignee,
      sla: t.sla,
      bookingId: t.bookingId,
      at: t.at,
      messages: updatedMsgs,
    );

    tickets[idx] = updatedTicket;
    state = state.copyWith(tickets: tickets);
  }

  void assignTicket(String ticketId, String? assignee) {
    final tickets = [...state.tickets];
    final idx = tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;

    final t = tickets[idx];
    t.assignee = assignee;
    state = state.copyWith(tickets: tickets);
  }

  void setTicketStatus(String ticketId, String newStatus) {
    final tickets = [...state.tickets];
    final idx = tickets.indexWhere((t) => t.id == ticketId);
    if (idx == -1) return;

    final t = tickets[idx];
    t.status = newStatus;
    state = state.copyWith(tickets: tickets);
  }

  void addChatReply(String sessionId, String text) {
    final chats = [...state.chatSessions];
    final idx = chats.indexWhere((c) => c.id == sessionId);
    if (idx == -1) return;

    final c = chats[idx];
    final now = DateTime.now();
    final updatedMsgs = [
      ...c.messages,
      TicketMessage(
        sender: 'agent',
        senderName: 'Abra Support',
        text: text,
        at: now,
      ),
    ];

    c.lastMessage = text;
    c.lastAt = now;
    c.unreadCount = 0;

    final updatedChat = ChatSessionRecord(
      id: c.id,
      customer: c.customer,
      phone: c.phone,
      channel: c.channel,
      status: c.status,
      lastMessage: text,
      lastAt: now,
      unreadCount: 0,
      messages: updatedMsgs,
    );

    chats[idx] = updatedChat;
    state = state.copyWith(chatSessions: chats);
  }

  void addFaq(FaqRecord faq) {
    state = state.copyWith(faqs: [faq, ...state.faqs]);
  }

  void updateFaq(FaqRecord faq) {
    final faqs = [...state.faqs];
    final idx = faqs.indexWhere((f) => f.id == faq.id);
    if (idx == -1) return;
    faqs[idx] = faq;
    state = state.copyWith(faqs: faqs);
  }

  void toggleFaqPublish(String id) {
    final faqs = [...state.faqs];
    final idx = faqs.indexWhere((f) => f.id == id);
    if (idx == -1) return;
    final f = faqs[idx];
    f.status = f.status == 'PUBLISHED' ? 'DRAFT' : 'PUBLISHED';
    f.updated = DateTime.now();
    state = state.copyWith(faqs: faqs);
  }

  void updatePolicyPage(String id, String content, String status) {
    final pages = [...state.pages];
    final idx = pages.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final p = pages[idx];
    p.content = content;
    p.status = status;
    if (status == 'PUBLISHED') {
      p.version++;
    }
    p.updated = DateTime.now();
    state = state.copyWith(pages: pages);
  }

  void updateContact(ContactConfig contact) {
    state = state.copyWith(contact: contact);
  }
}
