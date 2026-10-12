import 'package:meta/meta.dart';

/// The filters of the notification list.
enum NotificationCategory {
  booking,
  offers,
  safety;

  /// The category of a notification by its backend `type` ("BOOKING_
  /// CONFIRMED", "OFFER_NEW", "SAFETY_ALERT"). Anything unknown is about a
  /// booking, the most common kind.
  static NotificationCategory of(String type) {
    final upper = type.toUpperCase();
    if (upper.startsWith('OFFER') || upper.startsWith('PROMO')) return offers;
    if (upper.startsWith('SAFETY') || upper.startsWith('SOS')) return safety;
    return booking;
  }
}

/// An offer shown on the offers page (`GET /offers`).
@immutable
final class Offer {
  const Offer({
    required this.code,
    required this.description,
    required this.validTill,
    required this.terms,
  });

  final String code;

  /// What the offer gives ("Rs 100 off on your first booking"), as the
  /// backend words it.
  final String description;
  final DateTime validTill;

  /// The conditions, one line each.
  final List<String> terms;

  bool isValidOn(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(validTill.year, validTill.month, validTill.day);
    return !last.isBefore(today);
  }
}

/// A banner of the offers carousel; it points at the offer with [code].
@immutable
final class OfferBanner {
  const OfferBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.style,
  });

  final String id;
  final String title;
  final String subtitle;
  final String code;

  /// Which of the brand gradients paints it.
  final int style;
}
