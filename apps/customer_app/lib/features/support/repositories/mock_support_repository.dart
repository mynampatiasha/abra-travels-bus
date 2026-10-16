import 'dart:math';
import '../models/support_models.dart';
import 'support_repository.dart';

class MockSupportRepository implements SupportRepository {
  MockSupportRepository() {
    _initSeeded();
  }

  static final List<FaqItem> _faqs = <FaqItem>[
    const FaqItem(
      id: 'FAQ1',
      question: 'How do I cancel a booking?',
      answer: 'Go to My Trips, open your upcoming booking, and tap "Cancel seats". You can select which seats to cancel and review the refund amount before confirming.',
      category: 'Bookings',
    ),
    const FaqItem(
      id: 'FAQ2',
      question: 'When will I get my refund?',
      answer: 'Refunds are initiated immediately upon cancellation. The amount typically reflects in your original payment method (UPI/card/bank) within 5 to 7 working days.',
      category: 'Refunds',
    ),
    const FaqItem(
      id: 'FAQ3',
      question: 'How do I change my boarding point?',
      answer: 'Boarding points can be updated up to 2 hours before the trip departure by calling the bus operator directly or contacting Abra Support.',
      category: 'Bookings',
    ),
    const FaqItem(
      id: 'FAQ4',
      question: 'Is my payment safe?',
      answer: 'Yes. All payments on Abra Travels are processed by PCI-DSS compliant banking partners with 256-bit encryption. Card details are never stored on our servers.',
      category: 'Payments',
    ),
    const FaqItem(
      id: 'FAQ5',
      question: 'What is the seat hold timer?',
      answer: 'When you select seats, they are held exclusively for you for 10 minutes. If payment is not completed before the timer ends, the seats are released back into inventory.',
      category: 'Bookings',
    ),
    const FaqItem(
      id: 'FAQ6',
      question: 'How does trip sharing work?',
      answer: 'From your active trip, tap "Share trip" to generate a live tracking link. Family members can open this link in any browser to follow your bus location in real time without downloading the app.',
      category: 'Safety',
    ),
    const FaqItem(
      id: 'FAQ7',
      question: 'What if my bus is late?',
      answer: 'Live tracking will show any delay status and updated ETA. If the bus is significantly delayed or cancelled by the operator, you are eligible for a 100% full refund.',
      category: 'Trips',
    ),
    const FaqItem(
      id: 'FAQ8',
      question: 'How do I use a coupon?',
      answer: 'On the Review Booking screen, enter your promo code in the Coupon field and tap "Apply". Eligible discounts will be deducted instantly from your total payable amount.',
      category: 'Offers',
    ),
  ];

  static const ContactInfo _contact = ContactInfo(
    phone: '+91 40 4000 1234',
    whatsapp: '+91 98480 12345',
    email: 'support@abratravels.in',
    hours: '6 AM to 11 PM, every day',
    emergency: '+91 98480 99999',
  );

  final List<SupportTicket> _tickets = <SupportTicket>[];

  void _initSeeded() {
    if (_tickets.isNotEmpty) return;
    final now = DateTime.now();
    _tickets.addAll(<SupportTicket>[
      SupportTicket(
        id: 'TKT-8001',
        customerId: 'me',
        customerName: 'You',
        subject: 'Refund status for Hyderabad trip',
        category: 'REFUND',
        priority: 'HIGH',
        status: 'IN_PROGRESS',
        createdAt: now.subtract(const Duration(hours: 3)),
        messages: <TicketMessage>[
          TicketMessage(
            sender: 'customer',
            text: 'Hello, I cancelled 2 seats on the Bengaluru to Hyderabad bus yesterday. When will the refund reflect in my UPI account?',
            timestamp: now.subtract(const Duration(hours: 3)),
          ),
          TicketMessage(
            sender: 'agent',
            text: 'Hi! Your refund was processed yesterday and the bank UTR is UTR92847192. It should credit to your account within 24–48 hours.',
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
        ],
      ),
      SupportTicket(
        id: 'TKT-8002',
        customerId: 'me',
        customerName: 'You',
        subject: 'Coupon WEEKEND15 inquiry',
        category: 'PAYMENT',
        priority: 'LOW',
        status: 'RESOLVED',
        createdAt: now.subtract(const Duration(days: 2)),
        messages: <TicketMessage>[
          TicketMessage(
            sender: 'customer',
            text: 'Is the WEEKEND15 coupon applicable for AC sleeper buses as well?',
            timestamp: now.subtract(const Duration(days: 2)),
          ),
          TicketMessage(
            sender: 'agent',
            text: 'Yes, WEEKEND15 is valid on all Friday to Sunday departures across all bus types. Enjoy your journey!',
            timestamp: now.subtract(const Duration(days: 2, hours: -1)),
          ),
        ],
      ),
    ]);
  }

  @override
  Future<List<FaqItem>> getFaqs() async => _faqs;

  @override
  Future<ContactInfo> getContactInfo() async => _contact;

  @override
  Future<List<SupportTicket>> getTickets({required String customerId}) async {
    return _tickets.toList();
  }

  @override
  Future<SupportTicket?> getTicketById(String id) async {
    try {
      return _tickets.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
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
    final id = 'TKT-${8000 + Random().nextInt(1999)}';
    final now = DateTime.now();
    final ticket = SupportTicket(
      id: id,
      customerId: customerId,
      customerName: customerName,
      subject: subject,
      category: category,
      priority: category == 'SAFETY' ? 'URGENT' : 'MEDIUM',
      status: 'OPEN',
      createdAt: now,
      bookingId: bookingId,
      messages: <TicketMessage>[
        TicketMessage(
          sender: 'customer',
          text: message,
          timestamp: now,
          attachments: attachments,
        ),
      ],
    );
    _tickets.insert(0, ticket);
    return ticket;
  }

  @override
  Future<SupportTicket> replyToTicket({
    required String ticketId,
    required String message,
    List<String> attachments = const <String>[],
  }) async {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) throw StateError('Ticket not found');
    final existing = _tickets[index];
    final updatedMessages = List<TicketMessage>.from(existing.messages)
      ..add(
        TicketMessage(
          sender: 'customer',
          text: message,
          timestamp: DateTime.now(),
          attachments: attachments,
        ),
      );
    final updated = existing.copyWith(
      status: existing.status == 'CLOSED' ? 'OPEN' : existing.status,
      messages: updatedMessages,
    );
    _tickets[index] = updated;

    // Simulate an agent reply after a short delay in demo mode
    Future<void>.delayed(const Duration(seconds: 4), () {
      final curIdx = _tickets.indexWhere((t) => t.id == ticketId);
      if (curIdx != -1) {
        final cur = _tickets[curIdx];
        _tickets[curIdx] = cur.copyWith(
          status: 'IN_PROGRESS',
          messages: List<TicketMessage>.from(cur.messages)
            ..add(
              TicketMessage(
                sender: 'agent',
                text: 'Thank you for your update. Our support executive has received your message and is investigating.',
                timestamp: DateTime.now(),
              ),
            ),
        );
      }
    });

    return updated;
  }
}
