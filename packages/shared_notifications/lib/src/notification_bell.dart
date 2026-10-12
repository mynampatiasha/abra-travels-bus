import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

import 'device_push.dart' show PushPermission;
import 'notification_center.dart';
import 'notification_item.dart';

/// How long ago, in words, for the list ("just now", "5 min ago", "3 h ago", a date).
String timeAgo(DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays < 7) return '${difference.inDays} d ago';
  return '${time.day.toString().padLeft(2, '0')}/'
      '${time.month.toString().padLeft(2, '0')}/${time.year}';
}

/// The bell for the top bar: a badge with the unread count and a panel with
/// the latest notifications. Tapping one marks it read and calls [onOpen] so
/// the app can go to the screen it is about.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    required this.center,
    required this.onOpen,
    this.color,
    super.key,
  });

  final NotificationCenter center;
  final void Function(NotificationItem item) onOpen;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: center,
    builder: (context, _) {
      final unread = center.unreadCount;
      return IconButton(
        tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
        onPressed: () => _showPanel(context),
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: Icon(Icons.notifications_outlined, color: color),
        ),
      );
    },
  );

  Future<void> _showPanel(BuildContext context) {
    unawaited(center.refresh());
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close notifications',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 56, right: 12, left: 12),
            child: _NotificationPanel(
              center: center,
              onOpen: (item) {
                Navigator.of(dialogContext).pop();
                onOpen(item);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({required this.center, required this.onOpen});

  final NotificationCenter center;
  final void Function(NotificationItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: AbraRadius.medium,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 540),
        child: ListenableBuilder(
          listenable: center,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: center.unreadCount == 0
                          ? null
                          : center.markAllRead,
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
              if (center.pushAvailable && !center.pushEnabled)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Get alerts even when this page is closed'),
                  trailing: TextButton(
                    onPressed: center.enablePush,
                    child: const Text('Turn on'),
                  ),
                ),
              const Divider(height: 1),
              Flexible(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (center.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            center.isLoading
                ? 'Loading...'
                : center.error != null
                ? 'Could not load notifications.'
                : 'No notifications yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: center.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = center.items[index];
        return ListTile(
          onTap: () {
            center.markRead(item);
            onOpen(item);
          },
          leading: Icon(
            Icons.circle,
            size: 10,
            color: item.read ? Colors.transparent : AbraColors.blue,
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: item.read ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${item.body}\n${timeAgo(item.createdAt)}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
        );
      },
    );
  }
}

/// Asks the person to allow notifications (a button, because some browsers
/// only show the question after a tap), or explains how to undo a refusal.
/// Shows nothing when push is already on or not possible here.
class PushPermissionBanner extends StatelessWidget {
  const PushPermissionBanner({required this.center, super.key});

  final NotificationCenter center;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: center,
    builder: (context, _) {
      if (!center.pushAvailable) return const SizedBox.shrink();
      final denied = center.pushPermission == PushPermission.denied;
      if (center.pushPermission != PushPermission.notAsked && !denied) {
        return const SizedBox.shrink();
      }
      final theme = Theme.of(context);
      return Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AbraSpacing.lg,
            vertical: AbraSpacing.sm,
          ),
          color: denied ? AbraColors.orangeContainer : AbraColors.lightBlue,
          child: Wrap(
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Icon(
                denied
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
                color: denied ? AbraColors.orangeDark : AbraColors.deepBlue,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  denied
                      ? 'Notifications are blocked on this device, so you will not be told when '
                            'the app is closed. Allow them in your browser or phone settings.'
                      : 'Turn on notifications to hear about decisions even when the app is closed.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: denied ? AbraColors.orangeDark : AbraColors.deepBlue,
                  ),
                ),
              ),
              if (!denied)
                FilledButton(
                  onPressed: () => unawaited(center.enablePush()),
                  child: const Text('Turn on'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
