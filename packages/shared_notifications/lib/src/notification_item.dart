import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';

/// One notification of the signed-in person.
@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  /// From the API list, or from the live socket (which carries no read state
  /// or date: it just arrived, so it is unread and new).
  factory NotificationItem.fromJson(JsonMap json) {
    final data = json['data'];
    return NotificationItem(
      id: '${json['id']}',
      type: '${json['type'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      data: data is Map
          ? <String, String>{
              for (final entry in data.entries)
                '${entry.key}': '${entry.value}',
            }
          : const <String, String>{},
      read: json['read'] == true,
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal() ??
          DateTime.now(),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;

  /// Small values the app uses to open the right screen (`route`, ...).
  final Map<String, String> data;
  final bool read;
  final DateTime createdAt;

  /// Where tapping it should lead, when it says so.
  String? get route => data['route'];

  NotificationItem asRead() => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    read: true,
    createdAt: createdAt,
  );
}
