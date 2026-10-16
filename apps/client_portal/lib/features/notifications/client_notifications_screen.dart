import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';
import '../../core/mock/abra_mock_db.dart';
import '../../core/widgets/portal_section_title.dart';

class ClientNotificationsScreen extends StatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  State<ClientNotificationsScreen> createState() => _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends State<ClientNotificationsScreen> {
  late List<Map<String, dynamic>> _notifs;

  @override
  void initState() {
    super.initState();
    _notifs = List.from(kMockNotifications);
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'shield' => Icons.shield_outlined,
      'bus' => Icons.directions_bus_outlined,
      'ticket' => Icons.confirmation_number_outlined,
      'wallet' => Icons.account_balance_wallet_outlined,
      'file' => Icons.description_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AbraSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionTitle(
            title: 'Notifications',
            subtitle: 'Updates from Abra, bookings and your buses.',
            breadcrumbs: const ['System', 'Notifications'],
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Mark all read'),
                onPressed: _notifs.isEmpty ? null : () {
                  setState(() {
                    for (final n in _notifs) {
                      n['read'] = true;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications marked as read')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xl),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              border: Border.all(color: AbraColors.border),
              boxShadow: AbraShadows.soft,
            ),
            child: _notifs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.inbox_outlined, size: 48, color: AbraColors.textSecondary),
                          SizedBox(height: 12),
                          Text(
                            'No notifications',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AbraColors.textPrimary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'You are all caught up.',
                            style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notifs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AbraColors.divider),
                    itemBuilder: (ctx, i) {
                      final n = _notifs[i];
                      final isRead = n['read'] == true;
                      final relTime = relativeTime(n['at'] as String? ?? '');
                      final icon = _iconFor(n['icon'] as String?);

                      return InkWell(
                        onTap: () {
                          setState(() => n['read'] = true);
                          final go = n['go'] as String?;
                          if (go == 'buses') context.go('/buses');
                          if (go == 'bookings') context.go('/bookings');
                          if (go == 'earnings') context.go('/earnings');
                          if (go == 'kyc') context.go('/kyc-verification');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isRead ? AbraColors.lightGray : AbraColors.lightBlue,
                                  borderRadius: BorderRadius.circular(AbraRadius.md),
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: isRead ? AbraColors.textSecondary : AbraColors.deepBlue,
                                ),
                              ),
                              const SizedBox(width: AbraSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${n['t']}',
                                          style: TextStyle(
                                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                            fontSize: 14,
                                            color: AbraColors.textPrimary,
                                          ),
                                        ),
                                        if (!isRead) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AbraColors.skyContainer,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'New',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AbraColors.deepBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${n['b']}',
                                      style: TextStyle(
                                        color: isRead ? AbraColors.textSecondary : AbraColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AbraSpacing.md),
                              Text(
                                relTime,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AbraColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 18, color: AbraColors.textSecondary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
