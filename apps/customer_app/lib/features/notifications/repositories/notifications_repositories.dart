import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_notifications/shared_notifications.dart';

import '../../../app/providers.dart';
import '../../booking/repositories/booking_repository.dart';
import '../models/notification_models.dart';
import 'mock_notifications_repositories.dart';

/// The customer's notifications. Screens depend on this interface only;
/// [ApiNotificationFeed] is the real one (the `/notifications` endpoints that
/// the bell in the top bar already uses) and [MockNotificationFeed] the
/// sample one. Needs sign-in.
abstract interface class NotificationFeed {
  /// Newest first (`GET /notifications`).
  Future<List<NotificationItem>> list();

  /// `POST /notifications/:id/read`.
  Future<void> markRead(String id);

  /// `POST /notifications/read-all`.
  Future<void> markAllRead();
}

/// The backend, through the shared notifications repository.
class ApiNotificationFeed implements NotificationFeed {
  ApiNotificationFeed(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<List<NotificationItem>> list() async =>
      (await _repository.list(pageSize: 50)).items;

  @override
  Future<void> markRead(String id) async {
    await _repository.markRead(id);
  }

  @override
  Future<void> markAllRead() => _repository.markAllRead();
}

/// Offers and promotions, open to guests.
abstract interface class OffersRepository {
  /// Offers that can still be used (`GET /offers`, no sign-in).
  Future<List<Offer>> offers();

  /// The banners above the offers (`GET /offers/banners`).
  Future<List<OfferBanner>> banners();
}

/// Backend implementation. Not connected yet; see the README table.
class ApiOffersRepository implements OffersRepository {
  @override
  Future<List<Offer>> offers() => throw UnimplementedError('GET /offers');

  @override
  Future<List<OfferBanner>> banners() =>
      throw UnimplementedError('GET /offers/banners');
}

final notificationFeedProvider = Provider<NotificationFeed>(
  (ref) => MockNotificationFeed(now: ref.read(bookingClockProvider)),
);

/// The real feed, for when the mock is dropped: override
/// [notificationFeedProvider] with this.
NotificationFeed realNotificationFeed(Ref ref) => ApiNotificationFeed(
  NotificationsRepository(ref.read(appDependenciesProvider).apiClient),
);

final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => MockOffersRepository(now: ref.read(bookingClockProvider)),
);
