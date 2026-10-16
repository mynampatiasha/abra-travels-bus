import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Models and state store for the Sales module matching prototypes/admin_demo_model.html.

class BookingRecord {
  BookingRecord({
    required this.id,
    required this.pnr,
    required this.customerId,
    required this.customer,
    required this.phone,
    required this.tripId,
    required this.route,
    required this.operator,
    required this.operatorId,
    required this.travelDate,
    required this.seatList,
    required this.seatsN,
    required this.amount, // in paise
    required this.commission, // in paise
    required this.gst, // in paise
    required this.fee, // in paise
    required this.discount, // in paise
    required this.status, // CONFIRMED, COMPLETED, CANCELLED
    required this.mode, // UPI, CARD, NETBANKING, WALLET
    required this.at,
    this.coupon = '',
    List<String>? notes,
  }) : notes = notes ?? <String>[];

  final String id;
  final String pnr;
  final String customerId;
  final String customer;
  final String phone;
  final String tripId;
  final String route;
  final String operator;
  final String operatorId;
  final DateTime travelDate;
  final String seatList;
  final int seatsN;
  final int amount;
  final int commission;
  final int gst;
  final int fee;
  final int discount;
  String status;
  final String mode;
  final DateTime at;
  final String coupon;
  final List<String> notes;
}

class PaymentRecord {
  PaymentRecord({
    required this.id,
    required this.bookingId,
    required this.pnr,
    required this.customer,
    required this.operator,
    required this.amount, // in paise
    required this.mode,
    required this.status, // SUCCESS, FAILED, PENDING, REFUNDED
    required this.gw,
    required this.at,
    this.reason = '',
    this.settled = false,
  });

  final String id;
  final String bookingId;
  final String pnr;
  final String customer;
  final String operator;
  final int amount;
  final String mode;
  String status;
  final String gw;
  final DateTime at;
  String reason;
  bool settled;
}

class ReconciliationCase {
  ReconciliationCase({
    required this.id,
    required this.paymentId,
    required this.pnr,
    required this.issue,
    required this.amount,
    required this.status, // OPEN, RESOLVED
  });

  final String id;
  final String paymentId;
  final String pnr;
  final String issue;
  final int amount;
  String status;
}

class RefundRecord {
  RefundRecord({
    required this.id,
    required this.bookingId,
    required this.pnr,
    required this.customer,
    required this.operator,
    required this.amount, // in paise
    required this.pct,
    required this.status, // INITIATED, PROCESSING, COMPLETED, FAILED
    this.utr = '',
    required this.at,
    required this.bearer, // Operator, Platform
    required this.reason,
    this.files = const <String>[],
  });

  final String id;
  final String bookingId;
  final String pnr;
  final String customer;
  final String operator;
  final int amount;
  final int pct;
  String status;
  String utr;
  final DateTime at;
  final String bearer;
  String reason;
  List<String> files;
}

class SettlementRecord {
  SettlementRecord({
    required this.id,
    required this.operatorId,
    required this.operator,
    required this.cycle,
    required this.gross, // in paise
    required this.commission, // in paise
    required this.refunds, // in paise
    this.adj = 0, // in paise
    required this.net, // in paise
    required this.status, // DRAFT, APPROVED, PAID, ON_HOLD
    required this.mode, // AUTO, MANUAL
    required this.lines,
    this.paidAt,
    this.query = '',
    this.holdReason = '',
  });

  final String id;
  final String operatorId;
  final String operator;
  final String cycle;
  final int gross;
  final int commission;
  final int refunds;
  int adj;
  int net;
  String status;
  final String mode;
  final int lines;
  DateTime? paidAt;
  String query;
  String holdReason;
}

class SalesState {
  const SalesState({
    required this.bookings,
    required this.payments,
    required this.reconCases,
    required this.refunds,
    required this.settlements,
  });

  final List<BookingRecord> bookings;
  final List<PaymentRecord> payments;
  final List<ReconciliationCase> reconCases;
  final List<RefundRecord> refunds;
  final List<SettlementRecord> settlements;

  SalesState copyWith({
    List<BookingRecord>? bookings,
    List<PaymentRecord>? payments,
    List<ReconciliationCase>? reconCases,
    List<RefundRecord>? refunds,
    List<SettlementRecord>? settlements,
  }) {
    return SalesState(
      bookings: bookings ?? this.bookings,
      payments: payments ?? this.payments,
      reconCases: reconCases ?? this.reconCases,
      refunds: refunds ?? this.refunds,
      settlements: settlements ?? this.settlements,
    );
  }
}

final salesStoreProvider = NotifierProvider<SalesStoreNotifier, SalesState>(
  SalesStoreNotifier.new,
);

class SalesStoreNotifier extends Notifier<SalesState> {
  @override
  SalesState build() => _seedInitialData();

  static SalesState _seedInitialData() {
    final now = DateTime.now();

    final operators = [
      ('OP1', 'Kaveri Express'),
      ('OP2', 'Godavari Lines'),
      ('OP3', 'Deccan Voyager'),
      ('OP4', 'Charminar Tours'),
      ('OP5', 'Southern Star Travels'),
    ];

    final routes = [
      'Hyderabad to Bengaluru',
      'Bengaluru to Chennai',
      'Chennai to Coimbatore',
      'Hyderabad to Visakhapatnam',
      'Vijayawada to Hyderabad',
    ];

    final customers = [
      ('CU1', 'Aarav Sharma', '+91 98450 11221'),
      ('CU2', 'Priya Nair', '+91 98450 11222'),
      ('CU3', 'Rohan Mehta', '+91 98450 11223'),
      ('CU4', 'Ananya Reddy', '+91 98450 11224'),
      ('CU5', 'Vikram Singh', '+91 98450 11225'),
      ('CU6', 'Divya Iyer', '+91 98450 11226'),
      ('CU7', 'Rahul Verma', '+91 98450 11227'),
      ('CU8', 'Meera Pillai', '+91 98450 11228'),
      ('CU9', 'Karthik Rao', '+91 98450 11229'),
      ('CU10', 'Pooja Shah', '+91 98450 11230'),
    ];

    final bookings = <BookingRecord>[];
    final payments = <PaymentRecord>[];
    final refunds = <RefundRecord>[];

    for (var i = 0; i < 48; i++) {
      final op = operators[i % operators.length];
      final rt = routes[i % routes.length];
      final cust = customers[i % customers.length];
      final seatCount = (i % 3) + 1;
      const seatFare = 120000; // Rs 1200 in paise
      final fareTotal = seatFare * seatCount;
      final commission = (fareTotal * 0.1).round();
      final gst = (fareTotal * 0.05).round();
      const fee = 4900;
      final discount = i % 4 == 0 ? 10000 : 0;
      final status = i % 12 == 3 ? 'CANCELLED' : (i < 10 ? 'COMPLETED' : 'CONFIRMED');
      final mode = ['UPI', 'UPI', 'CARD', 'NETBANKING', 'WALLET'][i % 5];
      final bookingDate = now.subtract(Duration(days: i ~/ 2, hours: (i * 3) % 24));
      final travelDate = now.add(Duration(days: (i % 10) - 2, hours: 20));

      final seats = List.generate(seatCount, (s) => '${(i % 10) + 1}${['A', 'B', 'C', 'D'][s % 4]}').join(', ');
      final id = 'BK-${7001 + i}';
      final pnr = 'ABR${['K', 'M', 'Q', 'T', 'X'][i % 5]}${1000 + i}${['A', 'B', 'C'][i % 3]}';

      final bk = BookingRecord(
        id: id,
        pnr: pnr,
        customerId: cust.$1,
        customer: cust.$2,
        phone: cust.$3,
        tripId: 'TRP-${3001 + (i % 12)}',
        route: rt,
        operator: op.$2,
        operatorId: op.$1,
        travelDate: travelDate,
        seatList: seats,
        seatsN: seatCount,
        amount: fareTotal,
        commission: commission,
        gst: gst,
        fee: fee,
        discount: discount,
        status: status,
        mode: mode,
        at: bookingDate,
        coupon: discount > 0 ? 'ABRA100' : '',
      );
      bookings.add(bk);

      // Payment for booking
      final payStatus = i % 15 == 4
          ? 'FAILED'
          : (i % 20 == 7 ? 'PENDING' : (status == 'CANCELLED' ? 'REFUNDED' : 'SUCCESS'));
      final pay = PaymentRecord(
        id: 'PAY-${9001 + i}',
        bookingId: id,
        pnr: pnr,
        customer: cust.$2,
        operator: op.$2,
        amount: fareTotal + gst + fee - discount,
        mode: mode,
        status: payStatus,
        gw: 'pay_${100000 + i}xK',
        at: bookingDate,
        reason: payStatus == 'FAILED' ? 'Bank server timeout / card declined' : '',
        settled: i < 30,
      );
      payments.add(pay);

      // Refund if cancelled
      if (status == 'CANCELLED') {
        final refundPct = [100, 90, 75, 50][i % 4];
        final refStatus = ['INITIATED', 'PROCESSING', 'COMPLETED', 'FAILED'][i % 4];
        final ref = RefundRecord(
          id: 'RF-${4001 + refunds.length}',
          bookingId: id,
          pnr: pnr,
          customer: cust.$2,
          operator: op.$2,
          amount: (fareTotal * refundPct / 100).round(),
          pct: refundPct,
          status: refStatus,
          utr: refStatus == 'COMPLETED' ? 'UTR${20000000 + i}' : '',
          at: bookingDate.add(const Duration(hours: 2)),
          bearer: i % 2 == 0 ? 'Platform' : 'Operator',
          reason: i % 2 == 0 ? 'Customer requested cancellation' : 'Trip rescheduled by operator',
        );
        refunds.add(ref);
      }
    }

    final reconCases = <ReconciliationCase>[
      ReconciliationCase(
        id: 'RC-101',
        paymentId: 'PAY-9004',
        pnr: 'ABRK1004B',
        issue: 'Gateway shows paid, booking status was not updated automatically',
        amount: 244900,
        status: 'OPEN',
      ),
      ReconciliationCase(
        id: 'RC-102',
        paymentId: 'PAY-9019',
        pnr: 'ABRM1019A',
        issue: 'Amount mismatch by ₹49 (convenience fee webhook delay)',
        amount: 124900,
        status: 'OPEN',
      ),
      ReconciliationCase(
        id: 'RC-103',
        paymentId: 'PAY-9011',
        pnr: 'ABRQ1011C',
        issue: 'Refund webhook confirmed at Razorpay but unrecorded in DB',
        amount: 108000,
        status: 'RESOLVED',
      ),
    ];

    final settlements = <SettlementRecord>[
      SettlementRecord(
        id: 'ST-6001',
        operatorId: 'OP1',
        operator: 'Kaveri Express',
        cycle: '1 Oct to 7 Oct 2026',
        gross: 48200000, // ₹4.82 L
        commission: 4820000,
        refunds: 1240000,
        adj: -50000,
        net: 42090000,
        status: 'APPROVED',
        mode: 'AUTO',
        lines: 38,
      ),
      SettlementRecord(
        id: 'ST-6002',
        operatorId: 'OP2',
        operator: 'Godavari Lines',
        cycle: '1 Oct to 7 Oct 2026',
        gross: 36400000,
        commission: 3640000,
        refunds: 820000,
        net: 31940000,
        status: 'DRAFT',
        mode: 'MANUAL',
        lines: 29,
        query: 'Operator disputes 2 refunds from 3 Oct',
      ),
      SettlementRecord(
        id: 'ST-6003',
        operatorId: 'OP3',
        operator: 'Deccan Voyager',
        cycle: '1 Oct to 7 Oct 2026',
        gross: 24500000,
        commission: 2450000,
        refunds: 600000,
        net: 21450000,
        status: 'ON_HOLD',
        mode: 'MANUAL',
        lines: 22,
        holdReason: 'Awaiting bank IFSC verification update from owner',
      ),
      SettlementRecord(
        id: 'ST-6004',
        operatorId: 'OP4',
        operator: 'Charminar Tours',
        cycle: '24 Sep to 30 Sep 2026',
        gross: 19800000,
        commission: 1980000,
        refunds: 450000,
        net: 17370000,
        status: 'PAID',
        mode: 'AUTO',
        lines: 16,
        paidAt: now.subtract(const Duration(days: 4)),
      ),
      SettlementRecord(
        id: 'ST-6005',
        operatorId: 'OP5',
        operator: 'Southern Star Travels',
        cycle: '1 Oct to 7 Oct 2026',
        gross: 15400000,
        commission: 1540000,
        refunds: 200000,
        net: 13660000,
        status: 'DRAFT',
        mode: 'MANUAL',
        lines: 14,
      ),
    ];

    return SalesState(
      bookings: bookings,
      payments: payments,
      reconCases: reconCases,
      refunds: refunds,
      settlements: settlements,
    );
  }

  // ===== ACTIONS =====

  void cancelBooking(String bookingId, String reason, int refundPct) {
    final bookings = state.bookings.map((b) {
      if (b.id == bookingId) {
        b.status = 'CANCELLED';
        b.notes.add('Cancelled by staff: $reason (Refund: $refundPct%)');
      }
      return b;
    }).toList();

    final target = state.bookings.firstWhere((b) => b.id == bookingId);
    final refundAmount = (target.amount * refundPct / 100).round();
    final newRefund = RefundRecord(
      id: 'RF-${4001 + state.refunds.length}',
      bookingId: target.id,
      pnr: target.pnr,
      customer: target.customer,
      operator: target.operator,
      amount: refundAmount,
      pct: refundPct,
      status: 'INITIATED',
      at: DateTime.now(),
      bearer: 'Platform',
      reason: reason,
    );

    state = state.copyWith(
      bookings: bookings,
      refunds: [newRefund, ...state.refunds],
    );
  }

  void addBookingNote(String bookingId, String note) {
    final bookings = state.bookings.map((b) {
      if (b.id == bookingId) {
        b.notes.add(note);
      }
      return b;
    }).toList();
    state = state.copyWith(bookings: bookings);
  }

  void checkPaymentGateway(String paymentId) {
    final payments = state.payments.map((p) {
      if (p.id == paymentId && p.status == 'PENDING') {
        p.status = 'SUCCESS';
        p.reason = 'Verified by Razorpay gateway query';
      }
      return p;
    }).toList();
    state = state.copyWith(payments: payments);
  }

  void resolveReconCase(String caseId) {
    final cases = state.reconCases.map((c) {
      if (c.id == caseId) c.status = 'RESOLVED';
      return c;
    }).toList();
    state = state.copyWith(reconCases: cases);
  }

  void approveRefund(String refundId) {
    final refunds = state.refunds.map((r) {
      if (r.id == refundId) r.status = 'PROCESSING';
      return r;
    }).toList();
    state = state.copyWith(refunds: refunds);
  }

  void rejectRefund(String refundId, String reason) {
    final refunds = state.refunds.map((r) {
      if (r.id == refundId) {
        r.status = 'FAILED';
        r.reason = 'Rejected: $reason';
      }
      return r;
    }).toList();
    state = state.copyWith(refunds: refunds);
  }

  void completeRefund(String refundId, String utr) {
    final refunds = state.refunds.map((r) {
      if (r.id == refundId) {
        r.status = 'COMPLETED';
        r.utr = utr;
      }
      return r;
    }).toList();
    state = state.copyWith(refunds: refunds);
  }

  void approveSettlement(String settlementId) {
    final settlements = state.settlements.map((s) {
      if (s.id == settlementId) s.status = 'APPROVED';
      return s;
    }).toList();
    state = state.copyWith(settlements: settlements);
  }

  void paySettlement(String settlementId) {
    final settlements = state.settlements.map((s) {
      if (s.id == settlementId) {
        s.status = 'PAID';
        s.paidAt = DateTime.now();
      }
      return s;
    }).toList();
    state = state.copyWith(settlements: settlements);
  }

  void holdSettlement(String settlementId, String reason) {
    final settlements = state.settlements.map((s) {
      if (s.id == settlementId) {
        s.status = 'ON_HOLD';
        s.holdReason = reason;
      }
      return s;
    }).toList();
    state = state.copyWith(settlements: settlements);
  }

  void releaseSettlementHold(String settlementId) {
    final settlements = state.settlements.map((s) {
      if (s.id == settlementId) {
        s.status = 'DRAFT';
        s.holdReason = '';
      }
      return s;
    }).toList();
    state = state.copyWith(settlements: settlements);
  }

  void addSettlementAdjustment(String settlementId, int amountPaise, String reason) {
    final settlements = state.settlements.map((s) {
      if (s.id == settlementId) {
        s.adj += amountPaise;
        s.net += amountPaise;
      }
      return s;
    }).toList();
    state = state.copyWith(settlements: settlements);
  }

  void resolveSettlementQuery(String settlementId) {
    final settlements = state.settlements.map((s) {
      if (s.id == settlementId) s.query = '';
      return s;
    }).toList();
    state = state.copyWith(settlements: settlements);
  }
}

// ===== FORMATTING HELPERS =====

String formatRupees(int paise) {
  final isNegative = paise < 0;
  final absPaise = paise.abs();
  final rupees = absPaise ~/ 100;
  final rem = absPaise % 100;

  final s = rupees.toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }

  final decimalPart = rem == 0 ? '' : '.${rem.toString().padLeft(2, '0')}';
  return '${isNegative ? '-' : ''}₹$grouped$decimalPart';
}

String formatLakhsOrRupees(int paise) {
  final rupees = paise / 100;
  if (rupees >= 10000000) {
    return '₹${(rupees / 10000000).toStringAsFixed(2)} Cr';
  }
  if (rupees >= 100000) {
    return '₹${(rupees / 100000).toStringAsFixed(2)} L';
  }
  return formatRupees(paise);
}

String formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatDateTime(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
}

String formatRelativeTime(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.isNegative) {
    final f = diff.abs();
    if (f.inMinutes < 60) return 'in ${f.inMinutes} min';
    if (f.inHours < 24) return 'in ${f.inHours} h';
    return 'in ${f.inDays} d';
  }
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
