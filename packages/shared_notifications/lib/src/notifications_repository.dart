import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';

import 'notification_item.dart';

/// A page of the signed-in person's notifications, newest first.
class NotificationPage {
  const NotificationPage({required this.items, required this.total});

  final List<NotificationItem> items;
  final int total;
}

/// The notifications API (`/notifications`). Every call is for the person
/// the token belongs to; nobody reaches another person's list.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final ApiClient _client;

  Future<NotificationPage> list({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    final response = await _client.get(
      'notifications',
      query: <String, Object?>{
        'page': page,
        'pageSize': pageSize,
        if (unreadOnly) 'unread': 'true',
      },
    );
    return NotificationPage(
      items: response
          .decodeList(NotificationItem.fromJson)
          .toList(growable: false),
      total: response.page?.total ?? 0,
    );
  }

  Future<int> unreadCount() async {
    final data = (await _client.get(
      'notifications/unread-count',
    )).decodeObject((json) => json);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  /// Marks one as read and returns how many are still unread.
  Future<int> markRead(String id) async {
    final data = (await _client.post(
      'notifications/$id/read',
    )).decodeObject((json) => json);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAllRead() async {
    await _client.post('notifications/read-all');
  }

  /// Tells the server this browser or phone may receive push messages.
  Future<void> registerDevice(String token, {String platform = 'WEB'}) async {
    await _client.post(
      'notifications/devices',
      body: <String, Object?>{'token': token, 'platform': platform},
    );
  }

  /// Called at sign-out, so the next person on this computer is not notified.
  Future<void> removeDevice(String token) async {
    try {
      await _client.post(
        'notifications/devices/remove',
        body: <String, Object?>{'token': token},
      );
    } on AppException {
      // Signing out must not fail because the server was unreachable.
    }
  }
}
