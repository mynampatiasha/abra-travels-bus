import 'package:shared_notifications/shared_notifications.dart';

import '../models/notification_models.dart';
import 'notifications_repositories.dart';

/// Sample notifications of every kind, newest first. Reading is remembered
/// while the app runs.
class MockNotificationFeed implements NotificationFeed {
  MockNotificationFeed({
    required DateTime Function() now,
    this.delay = const Duration(milliseconds: 500),
  }) : _now = now;

  final DateTime Function() _now;
  final Duration delay;
  List<NotificationItem>? _items;

  List<NotificationItem> _create() {
    final now = _now();
    NotificationItem item(
      String id,
      String type,
      String title,
      String body,
      Duration ago, {
      bool read = false,
      String? route,
    }) => NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      data: <String, String>{'route': ?route},
      read: read,
      createdAt: now.subtract(ago),
    );
    return <NotificationItem>[
      item(
        'n1',
        'BOOKING_BUS_SOON',
        'Your bus leaves soon',
        'Bengaluru to Hyderabad departs from Hebbal Flyover. Track your bus.',
        const Duration(minutes: 10),
        route: '/my-trips/sample-b3',
      ),
      item(
        'n2',
        'OFFER_NEW',
        'Weekend offer: 15% off',
        'Use WEEKEND15 on bookings from Friday to Sunday.',
        const Duration(minutes: 90),
        route: '/offers',
      ),
      item(
        'n3',
        'BOOKING_CONFIRMED',
        'Booking confirmed',
        'Seat 12A on Chennai to Coimbatore is confirmed. PNR ABR3N8TQ4W.',
        const Duration(minutes: 150),
        read: true,
        route: '/my-trips/sample-b2',
      ),
      item(
        'n4',
        'SAFETY_TIP',
        'Travelling alone? Share your trip',
        'Let family follow your bus live from My trips.',
        const Duration(days: 1, hours: 3),
        read: true,
      ),
      item(
        'n5',
        'REFUND_PROCESSED',
        'Refund processed',
        'Your refund of ₹1,150 was credited to your UPI account.',
        const Duration(days: 3),
        read: true,
      ),
    ];
  }

  @override
  Future<List<NotificationItem>> list() async {
    await Future<void>.delayed(delay);
    return List<NotificationItem>.unmodifiable(_items ??= _create());
  }

  @override
  Future<void> markRead(String id) async {
    _items = <NotificationItem>[
      for (final item in _items ??= _create())
        item.id == id ? item.asRead() : item,
    ];
  }

  @override
  Future<void> markAllRead() async {
    _items = <NotificationItem>[
      for (final item in _items ??= _create()) item.asRead(),
    ];
  }
}

/// Sample offers and banners.
class MockOffersRepository implements OffersRepository {
  MockOffersRepository({
    required DateTime Function() now,
    this.delay = const Duration(milliseconds: 500),
  }) : _now = now;

  final DateTime Function() _now;
  final Duration delay;

  static const _terms = <String>[
    'Valid on bus bookings made in the Abra Travels app.',
    'One coupon per booking. Cannot be combined.',
    'Maximum discount ₹250 per booking.',
    'Not valid on convenience fee or GST.',
    'Abra Travels may withdraw the offer at any time.',
  ];

  @override
  Future<List<Offer>> offers() async {
    await Future<void>.delayed(delay);
    final now = _now();
    Offer offer(String code, String text, int days) => Offer(
      code: code,
      description: text,
      validTill: now.add(Duration(days: days)),
      terms: _terms,
    );
    return <Offer>[
      offer('ABRA100', '₹100 off on your first booking', 21),
      offer('WEEKEND15', '15% off up to ₹250, Friday to Sunday', 35),
      offer('UPIFEST', '₹75 cashback when you pay with UPI', 2),
      offer('WOMEN10', '10% off for women travellers', 82),
    ];
  }

  @override
  Future<List<OfferBanner>> banners() async {
    await Future<void>.delayed(delay);
    return const <OfferBanner>[
      OfferBanner(
        id: 'b1',
        title: 'Festive special',
        subtitle: 'Flat 15% off on selected routes',
        code: 'WEEKEND15',
        style: 0,
      ),
      OfferBanner(
        id: 'b2',
        title: 'Travel with family',
        subtitle: 'Save up to ₹500 on 4+ seats',
        code: 'ABRA100',
        style: 1,
      ),
      OfferBanner(
        id: 'b3',
        title: 'Safe journeys',
        subtitle: 'Extra 10% off for women travellers',
        code: 'WOMEN10',
        style: 2,
      ),
    ];
  }
}
