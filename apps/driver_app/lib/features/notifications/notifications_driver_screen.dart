import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_notifications/shared_notifications.dart';
import '../../app/providers.dart';

final driverNotificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final repo = ref.watch(driverNotificationsRepositoryProvider);
  try {
    final page = await repo.list(pageSize: 50);
    return page.items;
  } catch (_) {
    return const <NotificationItem>[];
  }
});

class NotificationsDriverScreen extends ConsumerWidget {
  const NotificationsDriverScreen({super.key});

  static String _formatTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return 'm ago';
    if (difference.inHours < 24) return 'h ago';
    return 'd ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(driverNotificationsProvider);
    final repo = ref.read(driverNotificationsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
        actions: [
          asyncList.maybeWhen(
            data: (list) {
              final unread = list.where((n) => !n.read).length;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await repo.markAllRead();
                  ref.invalidate(driverNotificationsProvider);
                },
                child: const Text('Mark all read', style: TextStyle(color: Color(0xFF36BDF5))),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(driverNotificationsProvider.future),
        child: asyncList.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                  const SizedBox(height: 12),
                  const Text('Unable to load notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(driverNotificationsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 54, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'No notifications',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF475569)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Trip updates from your operator and Abra appear here.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = list[index];
                final isRead = item.read;

                return Card(
                  elevation: isRead ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFF36BDF5),
                      width: isRead ? 1 : 1.5,
                    ),
                  ),
                  color: isRead ? const Color(0xFFF8FAFC) : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFE0F2FE),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: isRead ? const Color(0xFF64748B) : const Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(item.createdAt),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: isRead
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0284C7),
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () async {
                      if (!item.read) {
                        await repo.markRead(item.id);
                        ref.invalidate(driverNotificationsProvider);
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
