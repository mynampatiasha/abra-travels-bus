import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../onboarding/client_kyc_based_screen.dart';

class ClientNotificationScreen extends ConsumerStatefulWidget {
  const ClientNotificationScreen({super.key});
  @override
  ConsumerState<ClientNotificationScreen> createState() =>
      _ClientNotificationScreenState();
}

class _ClientNotificationScreenState
    extends ConsumerState<ClientNotificationScreen> {
  bool _unreadOnly = false;
  String _search = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationCenterProvider).refresh();
    });
  }

  /// Icon, background and colour of a notification, by what it is about.
  (IconData, Color, Color) _look(NotificationItem item) {
    if (item.type.contains('approved')) {
      return (
        Icons.verified_user_outlined,
        AbraColors.tealContainer,
        AbraColors.teal,
      );
    }
    if (item.type.contains('rejected')) {
      return (
        Icons.error_outline,
        AbraColors.dangerContainer,
        AbraColors.danger,
      );
    }
    return (
      Icons.description_outlined,
      AbraColors.skyContainer,
      AbraColors.blue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(notificationCenterProvider);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final items = center.items
            .where(
              (item) =>
                  (!_unreadOnly || !item.read) &&
                  '${item.title} ${item.body}'.toLowerCase().contains(
                    _search.toLowerCase(),
                  ),
            )
            .toList();
        return Column(
          children: [
            PushPermissionBanner(center: center),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AbraSpacing.lg,
                AbraSpacing.lg,
                AbraSpacing.lg,
                AbraSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your notifications',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: center.markAllRead,
                        child: const Text('Mark all as read'),
                      ),
                      IconButton(
                        onPressed: center.refresh,
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  Wrap(
                    spacing: AbraSpacing.md,
                    runSpacing: AbraSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search notifications',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Unread only'),
                        showCheckmark: false,
                        selectedColor: AbraColors.skyContainer,
                        selected: _unreadOnly,
                        onSelected: (value) =>
                            setState(() => _unreadOnly = value),
                      ),
                      if (center.pushAvailable)
                        TextButton(
                          onPressed: center.enablePush,
                          child: Text(
                            center.pushEnabled
                                ? 'Device notifications enabled'
                                : 'Enable device notifications',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (center.isLoading) const LinearProgressIndicator(),
            if (center.error != null)
              const Padding(
                padding: EdgeInsets.all(AbraSpacing.lg),
                child: Text('Could not load notifications. Please refresh.'),
              ),
            if (items.isEmpty && !center.isLoading)
              const Expanded(
                child: AbraStateView(
                  kind: AbraStateKind.empty,
                  title: 'No notifications to show.',
                  message:
                      'We will tell you here when your documents are reviewed.',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AbraSpacing.lg,
                    AbraSpacing.sm,
                    AbraSpacing.lg,
                    AbraSpacing.lg,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AbraSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final look = _look(item);
                    return AbraCard(
                      semanticLabel:
                          '${item.title}. ${item.body}${item.read ? '' : '. Unread'}',
                      onTap: () async {
                        await center.markRead(item);
                        if (context.mounted &&
                            item.data['submissionId'] != null) {
                          ref.invalidate(clientKycProvider);
                          context.go(
                            item.data['subjectType'] == 'BUS'
                                ? '/onboarding/${item.data['submissionId']}'
                                : '/kyc',
                          );
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: look.$2,
                              borderRadius: AbraRadius.medium,
                            ),
                            child: Icon(look.$1, color: look.$3),
                          ),
                          const SizedBox(width: AbraSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: item.read
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AbraSpacing.xxs),
                                Text(
                                  item.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AbraColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AbraSpacing.xs),
                                Text(
                                  timeAgo(item.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AbraColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!item.read)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: AbraColors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
