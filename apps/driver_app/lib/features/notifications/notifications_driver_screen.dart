import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

// ===== 1. NOTIFIER =====
class NotificationsDriverNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    return ref.watch(driverMockDbProvider).notifications;
  }

  void markAllRead() {
    for (final n in state) {
      n['read'] = true;
    }
    state = List<Map<String, dynamic>>.from(state);
  }

  void toggleRead(int index) {
    state[index]['read'] = !(state[index]['read'] as bool);
    state = List<Map<String, dynamic>>.from(state);
  }
}

final notificationsDriverProvider =
    NotifierProvider<NotificationsDriverNotifier, List<Map<String, dynamic>>>(
  NotificationsDriverNotifier.new,
);

// ===== 2. SCREEN =====
class NotificationsDriverScreen extends ConsumerWidget {
  const NotificationsDriverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsDriverProvider);
    final notifier = ref.read(notificationsDriverProvider.notifier);
    final unread = list.where((n) => n['read'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF12304A),
        foregroundColor: Colors.white,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: notifier.markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Color(0xFF36BDF5))),
            ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_none, size: 54, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF475569)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Trip changes from your company and Abra appear here.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = list[index];
                final isRead = item['read'] as bool;

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
                      item['t'] as String,
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
                          item['b'] as String,
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Received today',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                    onTap: () => notifier.toggleRead(index),
                  ),
                );
              },
            ),
    );
  }
}
