import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Models and state store for the Marketing module matching prototypes/admin_demo_model.html.

class OfferRecord {
  OfferRecord({
    required this.id,
    required this.code,
    required this.desc,
    required this.type, // 'PERCENT', 'FLAT'
    required this.value, // in paise for flat, or bps (1500 = 15%) for percent
    required this.maxDisc, // in paise
    required this.minAmt, // in paise
    required this.status, // 'ACTIVE', 'PAUSED', 'EXPIRED', 'DRAFT'
    required this.funder, // 'PLATFORM', 'OPERATOR'
    required this.perUser,
    required this.limit,
    required this.used,
    required this.from,
    required this.to,
    required this.scope,
    required this.newOnly,
    List<String>? terms,
  }) : terms = terms ?? <String>[];

  final String id;
  String code;
  String desc;
  String type;
  int value;
  int maxDisc;
  int minAmt;
  String status;
  String funder;
  int perUser;
  int limit;
  int used;
  DateTime from;
  DateTime to;
  String scope;
  bool newOnly;
  List<String> terms;

  OfferRecord copyWith({
    String? code,
    String? desc,
    String? type,
    int? value,
    int? maxDisc,
    int? minAmt,
    String? status,
    String? funder,
    int? perUser,
    int? limit,
    int? used,
    DateTime? from,
    DateTime? to,
    String? scope,
    bool? newOnly,
    List<String>? terms,
  }) {
    return OfferRecord(
      id: id,
      code: code ?? this.code,
      desc: desc ?? this.desc,
      type: type ?? this.type,
      value: value ?? this.value,
      maxDisc: maxDisc ?? this.maxDisc,
      minAmt: minAmt ?? this.minAmt,
      status: status ?? this.status,
      funder: funder ?? this.funder,
      perUser: perUser ?? this.perUser,
      limit: limit ?? this.limit,
      used: used ?? this.used,
      from: from ?? this.from,
      to: to ?? this.to,
      scope: scope ?? this.scope,
      newOnly: newOnly ?? this.newOnly,
      terms: terms ?? List<String>.from(this.terms),
    );
  }
}

class AnnouncementRecord {
  AnnouncementRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.channel,
    required this.status, // 'SENT', 'SCHEDULED', 'DRAFT'
    required this.at,
    required this.reach,
  });

  final String id;
  String title;
  String body;
  String audience;
  String channel;
  String status;
  DateTime at;
  int reach;
}

class PopularRouteRecord {
  PopularRouteRecord({
    required this.id,
    required this.route,
    required this.order,
    required this.active,
    required this.searches,
    required this.bookings,
  });

  final String id;
  String route;
  int order;
  bool active;
  int searches;
  int bookings;
}

class CouponTestResult {
  CouponTestResult({
    required this.isApplied,
    required this.reasons,
    required this.discountPaise,
    required this.finalAmountPaise,
    required this.funder,
  });

  final bool isApplied;
  final List<String> reasons;
  final int discountPaise;
  final int finalAmountPaise;
  final String funder;
}

class MarketingState {
  MarketingState({
    required this.offers,
    required this.announcements,
    required this.popularRoutes,
  });

  final List<OfferRecord> offers;
  final List<AnnouncementRecord> announcements;
  final List<PopularRouteRecord> popularRoutes;

  MarketingState copyWith({
    List<OfferRecord>? offers,
    List<AnnouncementRecord>? announcements,
    List<PopularRouteRecord>? popularRoutes,
  }) {
    return MarketingState(
      offers: offers ?? this.offers,
      announcements: announcements ?? this.announcements,
      popularRoutes: popularRoutes ?? this.popularRoutes,
    );
  }
}

class MarketingStoreNotifier extends Notifier<MarketingState> {
  @override
  MarketingState build() {
    return _seedInitialData();
  }

  static MarketingState _seedInitialData() {
    final now = DateTime.now();

    final offers = <OfferRecord>[
      OfferRecord(
        id: 'OF1',
        code: 'ABRA100',
        desc: '₹100 off your first booking',
        type: 'FLAT',
        value: 10000,
        maxDisc: 30000,
        minAmt: 0,
        status: 'ACTIVE',
        funder: 'PLATFORM',
        perUser: 1,
        limit: 3200,
        used: 120,
        from: now.subtract(const Duration(days: 20)),
        to: now.add(const Duration(days: 25)),
        scope: 'All',
        newOnly: true,
        terms: const [
          'Valid on bus bookings made in the Abra Travels app.',
          'One coupon per customer on their first booking.',
          'Cannot be combined with any other offer.',
          'Abra Travels may withdraw the offer at any time.',
        ],
      ),
      OfferRecord(
        id: 'OF2',
        code: 'WEEKEND15',
        desc: '15% off up to ₹250, Friday to Sunday',
        type: 'PERCENT',
        value: 1500,
        maxDisc: 25000,
        minAmt: 50000,
        status: 'ACTIVE',
        funder: 'PLATFORM',
        perUser: 1,
        limit: 5000,
        used: 812,
        from: now.subtract(const Duration(days: 19)),
        to: now.add(const Duration(days: 30)),
        scope: 'All',
        newOnly: false,
        terms: const [
          'Valid only on journeys starting on Friday, Saturday or Sunday.',
          'Minimum booking amount of ₹500 required.',
          'Maximum discount capped at ₹250.',
        ],
      ),
      OfferRecord(
        id: 'OF3',
        code: 'UPIFEST',
        desc: '₹75 cashback with UPI payment',
        type: 'FLAT',
        value: 7500,
        maxDisc: 7500,
        minAmt: 40000,
        status: 'ACTIVE',
        funder: 'PLATFORM',
        perUser: 2,
        limit: 2000,
        used: 1688,
        from: now.subtract(const Duration(days: 18)),
        to: now.add(const Duration(days: 15)),
        scope: 'All',
        newOnly: false,
        terms: const [
          'Applicable on all UPI payment modes (GPay, PhonePe, Paytm).',
          'Minimum transaction amount ₹400.',
          'Valid up to 2 times per user.',
        ],
      ),
      OfferRecord(
        id: 'OF4',
        code: 'WOMEN10',
        desc: '10% off for women travellers',
        type: 'PERCENT',
        value: 1000,
        maxDisc: 20000,
        minAmt: 30000,
        status: 'ACTIVE',
        funder: 'PLATFORM',
        perUser: 1,
        limit: 1500,
        used: 210,
        from: now.subtract(const Duration(days: 17)),
        to: now.add(const Duration(days: 40)),
        scope: 'Women travellers',
        newOnly: false,
        terms: const [
          'Applicable when at least one passenger is female.',
          'Maximum discount of ₹200 applies.',
        ],
      ),
      OfferRecord(
        id: 'OF5',
        code: 'KAVERI50',
        desc: '₹50 off Kaveri Express buses',
        type: 'FLAT',
        value: 5000,
        maxDisc: 5000,
        minAmt: 0,
        status: 'ACTIVE',
        funder: 'OPERATOR',
        perUser: 3,
        limit: 800,
        used: 330,
        from: now.subtract(const Duration(days: 16)),
        to: now.add(const Duration(days: 35)),
        scope: 'Operator: Kaveri Express',
        newOnly: false,
        terms: const [
          'Valid exclusively on Kaveri Express bus schedules.',
          'Funded directly by Kaveri Express.',
        ],
      ),
      OfferRecord(
        id: 'OF6',
        code: 'DIWALI20',
        desc: '20% off up to ₹400 festive special',
        type: 'PERCENT',
        value: 2000,
        maxDisc: 40000,
        minAmt: 100000,
        status: 'EXPIRED',
        funder: 'PLATFORM',
        perUser: 1,
        limit: 1000,
        used: 1000,
        from: now.subtract(const Duration(days: 35)),
        to: now.subtract(const Duration(days: 3)),
        scope: 'All',
        newOnly: false,
        terms: const [
          'Festive early bird discount.',
          'Campaign concluded.',
        ],
      ),
      OfferRecord(
        id: 'OF7',
        code: 'HYDBLR',
        desc: '₹120 off Hyderabad to Bengaluru route',
        type: 'FLAT',
        value: 12000,
        maxDisc: 12000,
        minAmt: 80000,
        status: 'PAUSED',
        funder: 'PLATFORM',
        perUser: 2,
        limit: 600,
        used: 45,
        from: now.subtract(const Duration(days: 14)),
        to: now.add(const Duration(days: 20)),
        scope: 'Route: Hyderabad to Bengaluru',
        newOnly: false,
        terms: const [
          'Route promotional offer temporarily paused.',
        ],
      ),
      OfferRecord(
        id: 'OF8',
        code: 'SLEEP10',
        desc: '10% off on AC sleepers',
        type: 'PERCENT',
        value: 1000,
        maxDisc: 15000,
        minAmt: 60000,
        status: 'DRAFT',
        funder: 'PLATFORM',
        perUser: 1,
        limit: 0,
        used: 0,
        from: now.subtract(const Duration(days: 12)),
        to: now.add(const Duration(days: 50)),
        scope: 'Bus type: AC Sleeper',
        newOnly: false,
        terms: const [
          'Draft sleeper campaign under review.',
        ],
      ),
    ];

    final announcements = <AnnouncementRecord>[
      AnnouncementRecord(
        id: 'AN1',
        title: 'Heavy rain advisory on Hyderabad to Visakhapatnam',
        body: 'Trips may run 30-45 mins late due to waterlogging near NH16. Live GPS tracking is active.',
        audience: 'Customers on route',
        channel: 'Push, WhatsApp',
        status: 'SENT',
        at: now.subtract(const Duration(hours: 4)),
        reach: 4850,
      ),
      AnnouncementRecord(
        id: 'AN2',
        title: 'New Volvo Multi-Axle sleeper buses on Chennai routes',
        body: 'Book early with code WEEKEND15 and save up to ₹250 on premium sleeper berths.',
        audience: 'All customers',
        channel: 'Push',
        status: 'SENT',
        at: now.subtract(const Duration(days: 2)),
        reach: 8900,
      ),
      AnnouncementRecord(
        id: 'AN3',
        title: 'Scheduled platform maintenance tonight 2:00 AM - 3:00 AM',
        body: 'Online booking and seat holds will be briefly unavailable for 60 minutes for gateway upgrade.',
        audience: 'All customers',
        channel: 'Push',
        status: 'SCHEDULED',
        at: now.add(const Duration(hours: 6)),
        reach: 0,
      ),
      AnnouncementRecord(
        id: 'AN4',
        title: 'Safety tips for night journeys',
        body: 'Always share your live bus tracking link with family or friends using the Trip Share button.',
        audience: 'All customers',
        channel: 'Push, WhatsApp',
        status: 'DRAFT',
        at: now.subtract(const Duration(days: 6)),
        reach: 0,
      ),
    ];

    final popularRoutes = <PopularRouteRecord>[
      PopularRouteRecord(
        id: 'PO1',
        route: 'Hyderabad to Bengaluru',
        order: 1,
        active: true,
        searches: 4200,
        bookings: 820,
      ),
      PopularRouteRecord(
        id: 'PO2',
        route: 'Bengaluru to Hyderabad',
        order: 2,
        active: true,
        searches: 3900,
        bookings: 790,
      ),
      PopularRouteRecord(
        id: 'PO3',
        route: 'Hyderabad to Vijayawada',
        order: 3,
        active: true,
        searches: 3100,
        bookings: 620,
      ),
      PopularRouteRecord(
        id: 'PO4',
        route: 'Chennai to Coimbatore',
        order: 4,
        active: true,
        searches: 2800,
        bookings: 510,
      ),
      PopularRouteRecord(
        id: 'PO5',
        route: 'Bengaluru to Chennai',
        order: 5,
        active: true,
        searches: 2400,
        bookings: 460,
      ),
      PopularRouteRecord(
        id: 'PO6',
        route: 'Visakhapatnam to Hyderabad',
        order: 6,
        active: true,
        searches: 2100,
        bookings: 380,
      ),
      PopularRouteRecord(
        id: 'PO7',
        route: 'Kochi to Bengaluru',
        order: 7,
        active: false,
        searches: 1600,
        bookings: 290,
      ),
      PopularRouteRecord(
        id: 'PO8',
        route: 'Hyderabad to Tirupati',
        order: 8,
        active: false,
        searches: 1200,
        bookings: 210,
      ),
    ];

    return MarketingState(
      offers: offers,
      announcements: announcements,
      popularRoutes: popularRoutes,
    );
  }

  // --- Offers Actions ---

  void saveOffer(OfferRecord offer) {
    final existingIndex = state.offers.indexWhere((o) => o.id == offer.id);
    if (existingIndex >= 0) {
      final updated = List<OfferRecord>.from(state.offers);
      updated[existingIndex] = offer;
      state = state.copyWith(offers: updated);
    } else {
      state = state.copyWith(offers: [offer, ...state.offers]);
    }
  }

  void toggleOfferStatus(String id) {
    final updated = state.offers.map((o) {
      if (o.id == id) {
        final newStatus = o.status == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
        return o.copyWith(status: newStatus);
      }
      return o;
    }).toList();
    state = state.copyWith(offers: updated);
  }

  CouponTestResult testCoupon({
    required String code,
    required int amountInRupees,
    required bool isNewCustomer,
    required String dayOfWeek,
  }) {
    final offer = state.offers.firstWhere(
      (o) => o.code == code,
      orElse: () => throw StateError('Coupon code not found'),
    );

    final amountPaise = amountInRupees * 100;
    final reasons = <String>[];

    if (offer.status != 'ACTIVE') {
      reasons.add('Offer is ${offer.status.toLowerCase()}');
    }
    if (offer.newOnly && !isNewCustomer) {
      reasons.add('Only for new customers');
    }
    if (amountPaise < offer.minAmt) {
      reasons.add('Minimum booking amount is ₹${offer.minAmt ~/ 100}');
    }
    if (offer.limit > 0 && offer.used >= offer.limit) {
      reasons.add('Total usage limit reached');
    }
    if (offer.code == 'WEEKEND15' &&
        !['Fri', 'Sat', 'Sun'].contains(dayOfWeek)) {
      reasons.add('Only valid on Friday, Saturday or Sunday');
    }

    if (reasons.isNotEmpty) {
      return CouponTestResult(
        isApplied: false,
        reasons: reasons,
        discountPaise: 0,
        finalAmountPaise: amountPaise,
        funder: offer.funder,
      );
    }

    int discount;
    if (offer.type == 'PERCENT') {
      final calculated = (amountPaise * offer.value) ~/ 10000;
      discount = offer.maxDisc > 0 && calculated > offer.maxDisc
          ? offer.maxDisc
          : calculated;
    } else {
      discount = offer.value;
    }

    if (discount > amountPaise) {
      discount = amountPaise;
    }

    return CouponTestResult(
      isApplied: true,
      reasons: const [],
      discountPaise: discount,
      finalAmountPaise: amountPaise - discount,
      funder: offer.funder,
    );
  }

  // --- Announcements Actions ---

  void saveAnnouncement(AnnouncementRecord announcement) {
    state = state.copyWith(
      announcements: [announcement, ...state.announcements],
    );
  }

  // --- Popular Routes Actions ---

  void movePopularRoute(String id, int delta) {
    final routes = List<PopularRouteRecord>.from(state.popularRoutes)
      ..sort((a, b) => a.order.compareTo(b.order));

    final idx = routes.indexWhere((r) => r.id == id);
    if (idx < 0) return;

    final targetIdx = idx + delta;
    if (targetIdx < 0 || targetIdx >= routes.length) return;

    final currentOrder = routes[idx].order;
    routes[idx].order = routes[targetIdx].order;
    routes[targetIdx].order = currentOrder;

    routes.sort((a, b) => a.order.compareTo(b.order));
    state = state.copyWith(popularRoutes: routes);
  }

  void togglePopularRoute(String id) {
    final updated = state.popularRoutes.map((r) {
      if (r.id == id) {
        return PopularRouteRecord(
          id: r.id,
          route: r.route,
          order: r.order,
          active: !r.active,
          searches: r.searches,
          bookings: r.bookings,
        );
      }
      return r;
    }).toList();
    state = state.copyWith(popularRoutes: updated);
  }

  void addPopularRoute(String routeName) {
    final newOrder = state.popularRoutes.length + 1;
    final newRoute = PopularRouteRecord(
      id: 'PO${state.popularRoutes.length + 1}',
      route: routeName,
      order: newOrder,
      active: true,
      searches: 0,
      bookings: 0,
    );
    state = state.copyWith(
      popularRoutes: [...state.popularRoutes, newRoute],
    );
  }
}

final marketingStoreProvider =
    NotifierProvider<MarketingStoreNotifier, MarketingState>(
  MarketingStoreNotifier.new,
);

String formatRupees(int paise) {
  final rupees = paise / 100;
  if (rupees == rupees.roundToDouble()) {
    return '₹${rupees.toInt()}';
  }
  return '₹${rupees.toStringAsFixed(2)}';
}
