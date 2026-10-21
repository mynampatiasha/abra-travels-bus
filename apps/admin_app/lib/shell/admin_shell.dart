import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../l10n/admin_strings.dart';
import '../routing/admin_route_guard.dart';
import '../routing/admin_routes.dart';

/// One navigation section with route, title, subtitle, icon, and optional badge.
class AdminSection {
  const AdminSection({
    required this.path,
    required this.title,
    required this.hint,
    required this.icon,
    this.badgeKey,
    this.isUrgentBadge = false,
  });

  final String path;
  final String title;
  final String hint;
  final IconData icon;
  final String? badgeKey;
  final bool isUrgentBadge;
}

/// One group of navigation sections in the side navigation bar.
class AdminNavGroup {
  const AdminNavGroup({
    required this.id,
    required this.title,
    required this.sections,
  });

  final String id;
  final String title;
  final List<AdminSection> sections;
}

/// Registry of the 11 demo groups matching prototypes/admin_demo_model.html.
abstract final class AdminNavigationRegistry {
  static const List<AdminNavGroup> groups = <AdminNavGroup>[
    // 1. Overview
    AdminNavGroup(
      id: 'overview',
      title: 'Overview',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.dashboard,
          title: 'Dashboard',
          hint: 'Everything that needs attention, and how sales are going',
          icon: Icons.dashboard_outlined,
        ),
      ],
    ),

    // 2. Operators
    AdminNavGroup(
      id: 'operators',
      title: 'Operators',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.invitations,
          title: 'Invitations',
          hint: 'Invite bus operators by email',
          icon: Icons.mark_email_read_outlined,
        ),
        AdminSection(
          path: AdminRoutes.reviews,
          title: 'KYC reviews',
          hint: 'Check every document before operators or buses go live',
          icon: Icons.verified_user_outlined,
          badgeKey: 'kyc',
        ),
        AdminSection(
          path: AdminRoutes.operators,
          title: 'Operators',
          hint: 'Every bus operator on the platform',
          icon: Icons.business_center_outlined,
        ),
        AdminSection(
          path: AdminRoutes.driverReports,
          title: 'Driver reports',
          hint: 'Driver misconduct, complaint records and breathalyzer compliance',
          icon: Icons.badge_outlined,
        ),
        AdminSection(
          path: AdminRoutes.driverRules,
          title: 'Driver rules',
          hint: 'Driving hours, rest limits and safety compliance rules',
          icon: Icons.rule_outlined,
        ),
      ],
    ),

    // 3. Commercial
    AdminNavGroup(
      id: 'commercial',
      title: 'Commercial',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.commission,
          title: 'Commission',
          hint: 'Set what Abra earns on each booking. Operators can see it but not change it.',
          icon: Icons.percent_outlined,
        ),
        AdminSection(
          path: AdminRoutes.payout,
          title: 'Payout and fees',
          hint: 'Payout cycles, platform fees and refund slabs',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    ),

    // 4. Catalogue
    AdminNavGroup(
      id: 'catalogue',
      title: 'Catalogue',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.places,
          title: 'Cities and places',
          hint: 'Cities, boarding points and operator requested stops',
          icon: Icons.place_outlined,
          badgeKey: 'places',
        ),
        AdminSection(
          path: AdminRoutes.busTypes,
          title: 'Bus types',
          hint: 'Bus categories, seating types and amenities',
          icon: Icons.directions_bus_filled_outlined,
        ),
        AdminSection(
          path: AdminRoutes.documentTypes,
          title: 'Required documents',
          hint: 'Documents required for company and bus KYC',
          icon: Icons.fact_check_outlined,
        ),
        AdminSection(
          path: AdminRoutes.kycConfiguration,
          title: 'KYC questionnaire',
          hint: 'Onboarding questions and rule triggers',
          icon: Icons.tune_outlined,
        ),
      ],
    ),

    // 5. Operations
    AdminNavGroup(
      id: 'operations',
      title: 'Operations',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.buses,
          title: 'Buses',
          hint: 'Every bus on the platform and insurance tracking',
          icon: Icons.directions_bus_outlined,
        ),
        AdminSection(
          path: AdminRoutes.trips,
          title: 'Trips',
          hint: 'Trips, schedules and seat management',
          icon: Icons.event_note_outlined,
        ),
        AdminSection(
          path: AdminRoutes.inventory,
          title: 'Seat inventory',
          hint: 'Real-time occupied, held and blocked seats monitor',
          icon: Icons.layers_outlined,
        ),
        AdminSection(
          path: AdminRoutes.tracking,
          title: 'Live tracking',
          hint: 'Live GPS locations and route tracking',
          icon: Icons.navigation_outlined,
        ),
      ],
    ),

    // 6. Sales
    AdminNavGroup(
      id: 'sales',
      title: 'Sales',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.bookings,
          title: 'Bookings',
          hint: 'Search passenger reservations by PNR, name or phone',
          icon: Icons.confirmation_number_outlined,
        ),
        AdminSection(
          path: AdminRoutes.payments,
          title: 'Payments',
          hint: 'Every payment through the gateway and reconciliation',
          icon: Icons.payment_outlined,
          badgeKey: 'payments',
        ),
        AdminSection(
          path: AdminRoutes.refunds,
          title: 'Refunds',
          hint: 'Approve, track and retry passenger refunds',
          icon: Icons.currency_exchange_outlined,
          badgeKey: 'refunds',
        ),
        AdminSection(
          path: AdminRoutes.settlements,
          title: 'Settlements',
          hint: 'Periodic operator payments, gross and net breakdown',
          icon: Icons.account_balance_outlined,
        ),
      ],
    ),

    // 7. Customers
    AdminNavGroup(
      id: 'customers',
      title: 'Customers',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.customers,
          title: 'Customers',
          hint: 'Travellers who use the app',
          icon: Icons.people_outline,
        ),
        AdminSection(
          path: AdminRoutes.tickets,
          title: 'Support tickets',
          hint: 'Questions and problems from customers',
          icon: Icons.help_outline,
          badgeKey: 'tickets',
        ),
        AdminSection(
          path: AdminRoutes.messages,
          title: 'Chat & messages',
          hint: 'Customer WhatsApp chatbot and support conversations',
          icon: Icons.chat_outlined,
        ),
        AdminSection(
          path: AdminRoutes.content,
          title: 'Help content',
          hint: 'FAQs, policy pages and support contacts',
          icon: Icons.menu_book_outlined,
        ),
      ],
    ),

    // 8. Marketing
    AdminNavGroup(
      id: 'marketing',
      title: 'Marketing',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.banners,
          title: 'Banners',
          hint: 'Promotional graphics at the top of customer app',
          icon: Icons.view_carousel_outlined,
        ),
        AdminSection(
          path: AdminRoutes.offers,
          title: 'Offers & coupons',
          hint: 'Promotional discount coupons and campaign limits',
          icon: Icons.local_offer_outlined,
        ),
        AdminSection(
          path: AdminRoutes.announcements,
          title: 'Announcements',
          hint: 'Broadcast alerts and push messages to passengers',
          icon: Icons.campaign_outlined,
        ),
        AdminSection(
          path: AdminRoutes.popularRoutes,
          title: 'Popular routes',
          hint: 'Featured high-demand routes shown on search home',
          icon: Icons.star_outline,
        ),
      ],
    ),

    // 9. Safety
    AdminNavGroup(
      id: 'safety',
      title: 'Safety',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.sos,
          title: 'SOS alerts',
          hint: 'Live emergency alerts from traveling passengers',
          icon: Icons.warning_amber_rounded,
          badgeKey: 'sos',
          isUrgentBadge: true,
        ),
        AdminSection(
          path: AdminRoutes.incidents,
          title: 'Incidents',
          hint: 'Passenger and crew incident investigation records',
          icon: Icons.report_problem_outlined,
        ),
        AdminSection(
          path: AdminRoutes.safetySettings,
          title: 'Safety settings',
          hint: 'Escalation time limits, police contacts and SOS config',
          icon: Icons.security_outlined,
        ),
      ],
    ),

    // 10. Insights
    AdminNavGroup(
      id: 'insights',
      title: 'Insights',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.reports,
          title: 'Reports & analytics',
          hint: 'Revenue, occupancy and cancellation analytics',
          icon: Icons.bar_chart_outlined,
        ),
      ],
    ),

    // 11. System
    AdminNavGroup(
      id: 'system',
      title: 'System',
      sections: <AdminSection>[
        AdminSection(
          path: AdminRoutes.settings,
          title: 'Settings',
          hint: 'Company info, booking rules and payment gateways',
          icon: Icons.settings_outlined,
        ),
        AdminSection(
          path: AdminRoutes.staff,
          title: 'Staff & roles',
          hint: 'Platform staff accounts and permission levels',
          icon: Icons.admin_panel_settings_outlined,
        ),
        AdminSection(
          path: AdminRoutes.featureFlags,
          title: 'Feature flags',
          hint: 'Runtime feature flags and maintenance mode',
          icon: Icons.flag_outlined,
        ),
        AdminSection(
          path: AdminRoutes.audit,
          title: 'Audit log',
          hint: 'Sensitive actions, who did them and when',
          icon: Icons.history_outlined,
        ),
      ],
    ),
  ];

  static final Map<String, AdminSection> byPath = <String, AdminSection>{
    for (final group in groups)
      for (final section in group.sections) section.path: section,
  };

  /// Visible groups for current user's access state.
  static List<AdminNavGroup> visibleGroups(AccessState access) {
    final result = <AdminNavGroup>[];
    for (final group in groups) {
      final permittedSections = group.sections.where((section) {
        return AdminRouteGuard.canOpen(access, section.path);
      }).toList();
      if (permittedSections.isNotEmpty) {
        result.add(AdminNavGroup(
          id: group.id,
          title: group.title,
          sections: permittedSections,
        ));
      }
    }
    return result;
  }
}

/// Admin Shell containing left navy sidebar and pixel-matched top bar.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  Future<void> _signOut() async {
    final l10n = AbraLocalizations.of(context);
    final confirmed = await showAbraConfirmDialog(
      context,
      title: l10n.text(AbraStrings.commonSignOut),
      message: l10n.text(AdminStrings.appName),
      confirmLabel: l10n.text(AbraStrings.commonSignOut),
    );
    if (confirmed) {
      await ref.read(notificationCenterProvider).stop();
      await ref.read(sessionManagerProvider).signOut();
    }
  }

  void _openNotification(NotificationItem item) {
    final route = item.route;
    if (route != null && route.startsWith('/onboarding/')) {
      context.go(AdminRoutes.reviewOf(route.substring('/onboarding/'.length)));
    } else if (route != null && route.startsWith(AdminRoutes.places)) {
      context.go(route);
    }
  }

  void _openGlobalSearch() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _GlobalSearchDialog(
        onSelect: (route) {
          Navigator.of(dialogContext).pop();
          context.go(route);
        },
      ),
    );
  }

  void _showMfaDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Two-step verification'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Staff sign-in asks for a six digit code from an authenticator app.'),
            SizedBox(height: AbraSpacing.md),
            Text(
              'Status: Enabled\nBackup codes remaining: 8',
              style: TextStyle(color: AbraColors.tealDark, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final access = ref.watch(accessProvider);
    final badgeCounts = ref.watch(navBadgeCountsProvider);
    final navGroups = AdminNavigationRegistry.visibleGroups(access);
    final breakpoint = AbraBreakpoint.of(context);
    final isWide = breakpoint == AbraBreakpoint.desktop;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isExtraWide = screenWidth >= 1200;
    final current = AdminNavigationRegistry.byPath[AdminRoutes.sectionOf(widget.currentPath)];
    final userName = access.user?.name ?? 'Admin User';

    Widget navigation({required bool inDrawer}) => _SideNavigation(
      groups: navGroups,
      currentPath: widget.currentPath,
      badgeCounts: badgeCounts,
      onSelect: (section) {
        if (inDrawer) Navigator.of(context).pop();
        context.go(section.path);
      },
    );

    final appBar = AppBar(
      backgroundColor: isDark ? const Color(0xFF13222F) : AbraColors.white,
      foregroundColor: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      titleSpacing: isWide ? AbraSpacing.xl : 0,
      shape: Border(
        bottom: BorderSide(
          color: isDark ? const Color(0xFF2A3E50) : AbraColors.divider,
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            current?.title ?? 'Abra Travels Admin',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (current != null && isExtraWide)
            Text(
              current.hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: <Widget>[
        // Global Search Pill or Icon
        if (isExtraWide)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: InkWell(
              onTap: _openGlobalSearch,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.search,
                      size: 16,
                      color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                    ),
                    const SizedBox(width: AbraSpacing.sm),
                    Text(
                      'Search PNR, operator, bus...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B2E3E) : const Color(0xFFE5EAEE),
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Text(
                        'Ctrl K',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: 'Search (Ctrl+K)',
            onPressed: _openGlobalSearch,
          ),
        if (isExtraWide) const SizedBox(width: AbraSpacing.md),

        // Role Chip
        if (isExtraWide)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: AbraColors.skyContainer,
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
              child: const Text(
                'Super Admin',
                style: TextStyle(
                  color: AbraColors.deepBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        const SizedBox(width: AbraSpacing.sm),

        // Theme Toggle (Dark / Light)
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        ),

        // Real notifications from NotificationCenter
        NotificationBell(
          center: ref.watch(notificationCenterProvider),
          onOpen: _openNotification,
        ),

        // Account Dropdown Menu
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.xs),
            child: _UserChip(name: userName, showName: isWide),
          ),
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Super Admin',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    'admin@abratravels.in',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'staff',
              child: Row(
                children: <Widget>[
                  Icon(Icons.admin_panel_settings_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Staff and roles')),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'mfa',
              child: Row(
                children: <Widget>[
                  Icon(Icons.security_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Two-step verification')),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'signout',
              child: Row(
                children: <Widget>[
                  Icon(Icons.logout, size: 18, color: AbraColors.danger),
                  SizedBox(width: 8),
                  Expanded(child: Text('Sign out', style: TextStyle(color: AbraColors.danger))),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'staff') {
              context.go(AdminRoutes.staff);
            } else if (value == 'mfa') {
              _showMfaDialog();
            } else if (value == 'signout') {
              _signOut();
            }
          },
        ),
        const SizedBox(width: AbraSpacing.sm),
      ],
    );

    final pageBody = Column(
      children: <Widget>[
        PushPermissionBanner(center: ref.watch(notificationCenterProvider)),
        Expanded(child: widget.child),
      ],
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openGlobalSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openGlobalSearch,
      },
      child: Focus(
        autofocus: true,
        child: _NotificationLifecycle(
          onOpen: _openNotification,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
            appBar: !isWide ? appBar : null,
            drawer: !isWide
                ? Drawer(
                    backgroundColor: const Color(0xFF12304A),
                    child: SafeArea(child: navigation(inDrawer: true)),
                  )
                : null,
            body: SafeArea(
              child: isWide
                  ? Row(
                      children: <Widget>[
                        SizedBox(
                          width: 262,
                          child: navigation(inDrawer: false),
                        ),
                        Expanded(
                          child: Scaffold(
                            backgroundColor: isDark ? const Color(0xFF0B1620) : const Color(0xFFF3F5F7),
                            appBar: appBar,
                            body: pageBody,
                          ),
                        ),
                      ],
                    )
                  : pageBody,
            ),
          ),
        ),
      ),
    );
  }
}


/// Global Search Dialog modal searching PNR, operator, bus, customer, trip and ticket.
class _GlobalSearchDialog extends StatefulWidget {
  const _GlobalSearchDialog({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  static const List<Map<String, String>> _mockEntities = <Map<String, String>>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final results = _query.length < 2
        ? const <Map<String, String>>[]
        : _mockEntities;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13222F) : AbraColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'Search everything',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.sm),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search PNR, phone, operator, bus, customer...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F1C27) : const Color(0xFFF3F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF2A3E50) : AbraColors.border,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
            const SizedBox(height: AbraSpacing.md),
            Expanded(
              child: _query.length < 2
                  ? Center(
                      child: Text(
                        'Type at least 2 characters to search across bookings, buses and operators.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : (results.isEmpty
                      ? Center(
                          child: Text(
                            'Not connected yet',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = results[index];
                            final type = item['type'] ?? '';
                            final title = item['title'] ?? '';
                            final route = item['route'] ?? AdminRoutes.dashboard;

                            return ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AbraColors.skyContainer,
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                child: Icon(
                                  _iconFor(item['icon']),
                                  size: 16,
                                  color: AbraColors.deepBlue,
                                ),
                              ),
                              title: Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1B2E3E) : const Color(0xFFE5EAEE),
                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                    ),
                                    child: Text(
                                      type,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF9FB6C9) : AbraColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AbraSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                              onTap: () => widget.onSelect(route),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? type) => switch (type) {
    'ticket' => Icons.confirmation_number_outlined,
    'business' => Icons.business_center_outlined,
    'bus' => Icons.directions_bus_outlined,
    'trip' => Icons.event_note_outlined,
    'customer' => Icons.people_outline,
    'place' => Icons.place_outlined,
    _ => Icons.info_outline,
  };
}

/// The navy left side navigation with the 11 groups and badge counters.
class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.groups,
    required this.currentPath,
    required this.badgeCounts,
    required this.onSelect,
  });

  final List<AdminNavGroup> groups;
  final String currentPath;
  final Map<String, int> badgeCounts;
  final ValueChanged<AdminSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final activeSection = AdminRoutes.sectionOf(currentPath);

    return Material(
      color: const Color(0xFF12304A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Brand Logo Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AbraColors.blue,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Expanded so the name shortens instead of overflowing a narrow menu
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Abra Travels',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Admin portal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF9FB6C9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
          const Divider(color: Color(0x1FFFFFFF), height: 1),

          // 11 Groups List
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final group in groups)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                          child: Text(
                            group.title.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF8FA9BF),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        for (final section in group.sections)
                          _NavItem(
                            section: section,
                            isSelected: section.path == activeSection,
                            badgeCount: section.badgeKey != null
                                ? (badgeCounts[section.badgeKey] ?? 0)
                                : 0,
                            onTap: () => onSelect(section),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A navigation item matching the demo .ni class.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final AdminSection section;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? Colors.white : const Color(0xFFD3E2EE);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? AbraColors.blue : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          hoverColor: const Color(0x14FFFFFF),
          splashColor: const Color(0x14FFFFFF),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(section.icon, size: 19, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: section.isUrgentBadge
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                      borderRadius: const BorderRadius.all(Radius.circular(99)),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.name, required this.showName});

  final String name;
  final bool showName;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircleAvatar(
          radius: 16,
          backgroundColor: AbraColors.navySecondary,
          child: Text(
            _initials.isEmpty ? 'A' : _initials,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (showName) ...<Widget>[
          const SizedBox(width: AbraSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationLifecycle extends ConsumerStatefulWidget {
  const _NotificationLifecycle({required this.child, required this.onOpen});

  final Widget child;
  final void Function(NotificationItem item) onOpen;

  @override
  ConsumerState<_NotificationLifecycle> createState() =>
      _NotificationLifecycleState();
}

class _NotificationLifecycleState
    extends ConsumerState<_NotificationLifecycle> {
  StreamSubscription<NotificationItem>? _toasts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = ref.read(notificationCenterProvider);
      unawaited(center.start(ref.read(sessionManagerProvider).accessToken));
      _toasts = center.arrivals.listen(_toast);
    });
  }

  void _toast(NotificationItem item) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          '${item.title}: ${item.body}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => widget.onOpen(item),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_toasts?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (next is AuthSignedOut) {
        unawaited(ref.read(notificationCenterProvider).stop());
      }
    });
    return widget.child;
  }
}
