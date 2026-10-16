import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../routing/admin_routes.dart';

/// Dashboard screen matching prototypes/admin_demo_model.html.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _rangeDays = 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Dashboard',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: AbraSpacing.xs),
                    Text(
                      'Everything that needs attention, and how sales are going.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: AbraSpacing.sm,
                  children: <Widget>[
                    for (final r in [
                      (1, 'Today'),
                      (7, '7 days'),
                      (30, '30 days'),
                    ])
                      ChoiceChip(
                        label: Text(r.$2),
                        selected: _rangeDays == r.$1,
                        onSelected: (val) {
                          if (val) setState(() => _rangeDays = r.$1);
                        },
                        selectedColor: AbraColors.skyContainer,
                        labelStyle: TextStyle(
                          color: _rangeDays == r.$1
                              ? AbraColors.deepBlue
                              : (isDark ? Colors.white70 : AbraColors.textPrimary),
                          fontWeight: _rangeDays == r.$1 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Exported dashboard data to CSV'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export'),
                      style: OutlinedButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),

            // Top 4 KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 980 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: AbraSpacing.md,
                  mainAxisSpacing: AbraSpacing.md,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  children: const <Widget>[
                    _KpiCard(
                      icon: Icons.confirmation_number_outlined,
                      value: '1,428',
                      label: 'Bookings',
                      delta: '+8.2% vs previous',
                      isPositive: true,
                    ),
                    _KpiCard(
                      icon: Icons.account_balance_wallet_outlined,
                      value: '₹14.2 L',
                      label: 'Gross sales',
                      delta: '+5.4% vs previous',
                      isPositive: true,
                    ),
                    _KpiCard(
                      icon: Icons.percent_outlined,
                      value: '₹1.42 L',
                      label: 'Commission earned',
                      delta: '+5.4% vs previous',
                      isPositive: true,
                    ),
                    _KpiCard(
                      icon: Icons.business_center_outlined,
                      value: '14',
                      label: 'Active operators',
                      delta: '2 joined this month',
                      isPositive: true,
                    ),
                    _KpiCard(
                      icon: Icons.directions_bus_outlined,
                      value: '28',
                      label: 'Active trips',
                      delta: 'Across 12 routes',
                      isPositive: true,
                    ),
                    _KpiCard(
                      icon: Icons.navigation_outlined,
                      value: '8',
                      label: 'Buses live now',
                      delta: 'Live GPS tracked',
                      isPositive: true,
                    ),
                    _KpiCard(
                      icon: Icons.currency_exchange_outlined,
                      value: '4',
                      label: 'Refunds pending',
                      delta: 'Needs attention',
                      isPositive: false,
                    ),
                    _KpiCard(
                      icon: Icons.bar_chart_outlined,
                      value: '76%',
                      label: 'Average occupancy',
                      delta: '+1.1 pts',
                      isPositive: true,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Needs Your Attention Section
            Container(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Needs your attention',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                    ),
                  ),
                  const SizedBox(height: AbraSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: AbraSpacing.md,
                        mainAxisSpacing: AbraSpacing.md,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 3.2,
                        children: const <Widget>[
                          _AttentionItem(
                            icon: Icons.verified_user_outlined,
                            count: '3',
                            title: 'KYC waiting for review',
                            path: AdminRoutes.reviews,
                          ),
                          _AttentionItem(
                            icon: Icons.warning_amber_rounded,
                            count: '2',
                            title: 'Open SOS alerts',
                            path: AdminRoutes.sos,
                            isUrgent: true,
                          ),
                          _AttentionItem(
                            icon: Icons.payment_outlined,
                            count: '1',
                            title: 'Failed payments',
                            path: AdminRoutes.payments,
                          ),
                          _AttentionItem(
                            icon: Icons.account_balance_outlined,
                            count: '4',
                            title: 'Settlements to approve',
                            path: AdminRoutes.settlements,
                          ),
                          _AttentionItem(
                            icon: Icons.directions_bus_outlined,
                            count: '2',
                            title: 'Bus documents expiring in 14d',
                            path: AdminRoutes.buses,
                          ),
                          _AttentionItem(
                            icon: Icons.place_outlined,
                            count: '1',
                            title: 'Place requests',
                            path: AdminRoutes.places,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AbraSpacing.xl),

            // Recent Activity / Audit Log Preview
            Container(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13222F) : AbraColors.white,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Latest activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AdminRoutes.audit),
                        child: const Text('View full audit log'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  for (final item in const [
                    ('Super Admin', 'Approved KYC submission for Kaveri Express', '12 min ago'),
                    ('Admin', 'Updated commission rule CR-3 to 12%', '45 min ago'),
                    ('Support', 'Acknowledged SOS alert SOS-2001', '1 hour ago'),
                    ('Accounts', 'Generated settlements for Cycle 1 Oct - 7 Oct', '3 hours ago'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AbraColors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AbraSpacing.md),
                              Text(
                                '${item.$1}: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFE6EEF5) : AbraColors.textPrimary,
                                ),
                              ),
                              Text(
                                item.$2,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.delta,
    required this.isPositive,
  });

  final IconData icon;
  final String value;
  final String label;
  final String delta;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13222F) : AbraColors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AbraColors.skyContainer,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(icon, color: AbraColors.deepBlue, size: 22),
          ),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE6EEF5) : AbraColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                  ),
                ),
                if (delta.isNotEmpty)
                  Text(
                    delta,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? AbraColors.tealDark : AbraColors.danger,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({
    required this.icon,
    required this.count,
    required this.title,
    required this.path,
    this.isUrgent = false,
  });

  final IconData icon;
  final String count;
  final String title;
  final String path;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => context.go(path),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(AbraSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF8FAFB),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isUrgent ? const Color(0xFFFDE8E8) : AbraColors.skyContainer,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Icon(
                icon,
                color: isUrgent ? const Color(0xFFB91C1C) : AbraColors.deepBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: AbraSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isUrgent
                          ? const Color(0xFFB91C1C)
                          : (isDark ? const Color(0xFFE6EEF5) : AbraColors.navy),
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
