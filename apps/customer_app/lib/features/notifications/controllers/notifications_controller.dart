import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_notifications/shared_notifications.dart';

import '../models/notification_models.dart';
import '../repositories/notifications_repositories.dart';

/// Which kind of notification the list shows; null is "All".
final notificationFilterProvider =
    NotifierProvider<NotificationFilterController, NotificationCategory?>(
      NotificationFilterController.new,
    );

class NotificationFilterController extends Notifier<NotificationCategory?> {
  @override
  NotificationCategory? build() => null;

  void select(NotificationCategory? category) => state = category;
}

/// The notifications of the signed-in customer. Reading one or all changes
/// the list at once and then tells the backend (a failure puts the unread
/// state back).
final notificationsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      List<NotificationItem>
    >(NotificationsController.new);

class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() =>
      ref.read(notificationFeedProvider).list();

  Future<void> markRead(NotificationItem item) async {
    final before = state.value;
    if (before == null || item.read) return;
    state = AsyncData<List<NotificationItem>>(<NotificationItem>[
      for (final entry in before) entry.id == item.id ? entry.asRead() : entry,
    ]);
    try {
      await ref.read(notificationFeedProvider).markRead(item.id);
    } on Object {
      if (ref.mounted) state = AsyncData<List<NotificationItem>>(before);
    }
  }

  Future<void> markAllRead() async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData<List<NotificationItem>>(<NotificationItem>[
      for (final entry in before) entry.asRead(),
    ]);
    try {
      await ref.read(notificationFeedProvider).markAllRead();
    } on Object {
      if (ref.mounted) state = AsyncData<List<NotificationItem>>(before);
    }
  }
}

/// The notifications that pass [filter] (all of them when it is null).
List<NotificationItem> filterNotifications(
  List<NotificationItem> items,
  NotificationCategory? filter,
) => filter == null
    ? items
    : items
          .where((item) => NotificationCategory.of(item.type) == filter)
          .toList();

/// Splits [items] (newest first) into today's and earlier ones, by the
/// calendar day at [now].
({List<NotificationItem> today, List<NotificationItem> earlier}) groupByDay(
  List<NotificationItem> items,
  DateTime now,
) {
  bool isToday(DateTime time) =>
      time.year == now.year && time.month == now.month && time.day == now.day;
  return (
    today: items.where((item) => isToday(item.createdAt)).toList(),
    earlier: items.where((item) => !isToday(item.createdAt)).toList(),
  );
}

/// The offers that can still be used.
final offersProvider = FutureProvider.autoDispose<List<Offer>>(
  (ref) => ref.watch(offersRepositoryProvider).offers(),
);

final offerBannersProvider = FutureProvider.autoDispose<List<OfferBanner>>(
  (ref) => ref.watch(offersRepositoryProvider).banners(),
);
