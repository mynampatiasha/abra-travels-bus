import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_notifications/shared_notifications.dart';

import '../../../app/providers.dart';
import '../models/notification_models.dart';

/// The customer's notifications. Screens depend on this interface only;
/// [ApiNotificationFeed] is the real one (the `/notifications` endpoints that
/// the bell in the top bar already uses). Needs sign-in.
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

/// Backend implementation for offers and banners.
class ApiOffersRepository implements OffersRepository {
  @override
  Future<List<Offer>> offers() async => const <Offer>[];

  @override
  Future<List<OfferBanner>> banners() async => const <OfferBanner>[];
}

final notificationFeedProvider = Provider<NotificationFeed>(
  (ref) => ApiNotificationFeed(
    NotificationsRepository(ref.read(appDependenciesProvider).apiClient),
  ),
);

final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => ApiOffersRepository(),
);
