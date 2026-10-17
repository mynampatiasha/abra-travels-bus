import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';
import '../app/providers.dart';
import '../routing/portal_routes.dart';

const _navGroups = [
  _NavGroup('OVERVIEW', [
    _NavItem('Dashboard', PortalRoutes.dashboard, Icons.home_outlined),
  ]),
  _NavGroup('COMPANY', [
    _NavItem('KYC verification', PortalRoutes.kycVerification, Icons.verified_user_outlined),
    _NavItem('Company details', PortalRoutes.companyProfile, Icons.business_outlined),
  ]),
  _NavGroup('FLEET', [
    _NavItem('Buses', PortalRoutes.buses, Icons.directions_bus_outlined),
    _NavItem('Seat layouts', PortalRoutes.seatLayouts, Icons.grid_view_outlined),
    _NavItem('Drivers and crew', PortalRoutes.crew, Icons.people_outlined),
    _NavItem('Driver reports', PortalRoutes.driverReports, Icons.bar_chart_outlined),
    _NavItem('Driver rules', PortalRoutes.driverRules, Icons.rule_outlined),
  ]),
  _NavGroup('NETWORK', [
    _NavItem('Routes and stops', PortalRoutes.routes, Icons.route_outlined),
    _NavItem('Places', PortalRoutes.places, Icons.place_outlined),
  ]),
  _NavGroup('SALES SETUP', [
    _NavItem('Fares', PortalRoutes.fares, Icons.local_offer_outlined),
    _NavItem('Schedules', PortalRoutes.schedules, Icons.calendar_today_outlined),
    _NavItem('Trips', PortalRoutes.trips, Icons.directions_outlined),
  ]),
  _NavGroup('SALES', [
    _NavItem('Bookings', PortalRoutes.bookings, Icons.confirmation_number_outlined),
    _NavItem('Offers', PortalRoutes.offers, Icons.discount_outlined),
  ]),
  _NavGroup('MONEY', [
    _NavItem('Earnings', PortalRoutes.earnings, Icons.account_balance_wallet_outlined),
    _NavItem('Commission', PortalRoutes.commission, Icons.percent_outlined),
  ]),
  _NavGroup('OPERATIONS', [
    _NavItem('Live tracking', PortalRoutes.liveTracking, Icons.near_me_outlined),
  ]),
  _NavGroup('SYSTEM', [
    _NavItem('Notifications', PortalRoutes.notifications, Icons.notifications_outlined),
    _NavItem('Staff and roles', PortalRoutes.staffRoles, Icons.manage_accounts_outlined),
  ]),
];

class _NavGroup {
  const _NavGroup(this.label, this.items);
  final String label;
  final List<_NavItem> items;
}

class _NavItem {
  const _NavItem(this.label, this.route, this.icon);
  final String label;
  final String route;
  final IconData icon;
}

/// The full-sidebar shell for the operator portal.
class PortalShell extends ConsumerStatefulWidget {
  const PortalShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  @override
  ConsumerState<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends ConsumerState<PortalShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int get _notifCount => 0;

  String get _activeSection {
    final p = widget.currentPath;
    if (p.startsWith(PortalRoutes.dashboard)) return PortalRoutes.dashboard;
    if (p.startsWith(PortalRoutes.kycVerification)) return PortalRoutes.kycVerification;
    if (p.startsWith(PortalRoutes.companyProfile)) return PortalRoutes.companyProfile;
    if (p.startsWith(PortalRoutes.buses)) return PortalRoutes.buses;
    if (p.startsWith(PortalRoutes.seatLayouts)) return PortalRoutes.seatLayouts;
    if (p.startsWith(PortalRoutes.crew)) return PortalRoutes.crew;
    if (p.startsWith(PortalRoutes.driverReports)) return PortalRoutes.driverReports;
    if (p.startsWith(PortalRoutes.driverRules)) return PortalRoutes.driverRules;
    if (p.startsWith(PortalRoutes.routes)) return PortalRoutes.routes;
    if (p.startsWith(PortalRoutes.places)) return PortalRoutes.places;
    if (p.startsWith(PortalRoutes.fares)) return PortalRoutes.fares;
    if (p.startsWith(PortalRoutes.schedules)) return PortalRoutes.schedules;
    if (p.startsWith(PortalRoutes.trips)) return PortalRoutes.trips;
    if (p.startsWith(PortalRoutes.bookings)) return PortalRoutes.bookings;
    if (p.startsWith(PortalRoutes.offers)) return PortalRoutes.offers;
    if (p.startsWith(PortalRoutes.earnings)) return PortalRoutes.earnings;
    if (p.startsWith(PortalRoutes.commission)) return PortalRoutes.commission;
    if (p.startsWith(PortalRoutes.liveTracking)) return PortalRoutes.liveTracking;
    if (p.startsWith(PortalRoutes.notifications)) return PortalRoutes.notifications;
    if (p.startsWith(PortalRoutes.staffRoles)) return PortalRoutes.staffRoles;
    return PortalRoutes.dashboard;
  }

  String get _pageTitle {
    final section = _activeSection;
    for (final g in _navGroups) {
      for (final i in g.items) {
        if (i.route == section) return i.label;
      }
    }
    return 'Dashboard';
  }

  int _badgeFor(String route) {
    if (route == PortalRoutes.dashboard) return 1;
    if (route == PortalRoutes.driverReports) return 6;
    if (route == PortalRoutes.notifications) return _notifCount;
    return 0;
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 262,
      color: AbraColors.navy,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                Icon(Icons.directions_bus_filled, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Abra Travels',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kaveri Express',
                style: TextStyle(
                  color: AbraColors.onNavyMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const Divider(color: AbraColors.navyDivider, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                for (final group in _navGroups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                    child: Text(
                      group.label,
                      style: const TextStyle(
                        color: AbraColors.onNavyMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  for (final item in group.items)
                    _buildNavItem(context, item),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, _NavItem item) {
    final isActive = _activeSection == item.route;
    final badge = _badgeFor(item.route);
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isActive ? AbraColors.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          context.go(item.route);
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: isActive ? Colors.white : const Color(0xFFD3E2EE),
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFD3E2EE),
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: AbraColors.danger,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$badge',
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
    );
  }

  Widget _buildTopBar(BuildContext context, bool isMobile) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final topBarBg = isDark ? const Color(0xFF13222F) : Colors.white;
    final topBarBorder = isDark ? const Color(0xFF2A3E50) : AbraColors.border;
    final titleColor = isDark ? const Color(0xFFE6EEF5) : AbraColors.textPrimary;
    final searchBg = isDark ? const Color(0xFF0B1620) : AbraColors.lightGray;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: topBarBg,
        border: Border(bottom: BorderSide(color: topBarBorder)),
        boxShadow: AbraShadows.soft,
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          Expanded(
            child: Text(
              _pageTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) ...[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openGlobalSearch(context),
              child: Container(
                height: 38,
                width: 280,
                decoration: BoxDecoration(
                  color: searchBg,
                  border: Border.all(color: topBarBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AbraColors.textSecondary, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search PNR, trip, bus, driver...',
                        style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                      ),
                    ),
                    Text(
                      'Ctrl K',
                      style: TextStyle(
                        color: AbraColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AbraColors.skyContainer,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                ref.watch(accessProvider).user != null ? 'Operator Staff' : 'Partner',
                style: const TextStyle(
                  color: AbraColors.deepBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 16, color: AbraColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'English',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: AbraColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.auto_awesome, size: 20, color: AbraColors.blue),
              tooltip: 'Abra AI Copilot',
              onPressed: () => _openAiAssistant(context),
            ),
          ],
          IconButton(
            icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined, size: 20),
            tooltip: 'Toggle theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 22),
                tooltip: 'Notifications',
                onPressed: () => _showNotificationsPopup(context),
              ),
              if (_notifCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AbraColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_notifCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          _buildAccountMenu(context),
        ],
      ),
    );
  }

  Widget _buildAccountMenu(BuildContext context) {
    final access = ref.watch(accessProvider);
    final user = access.user;
    final userName = user?.name ?? 'Partner Staff';
    final userEmail = user?.email ?? '';
    const userRole = 'Operator Staff';

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        side: const BorderSide(color: AbraColors.border),
      ),
      icon: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AbraColors.lightBlue,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'O',
            style: const TextStyle(
              color: AbraColors.deepBlue,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
      onSelected: (value) async {
        if (value == 'profile') {
          context.go(PortalRoutes.companyProfile);
        } else if (value == 'staff') {
          context.go(PortalRoutes.staffRoles);
        } else if (value == 'kyc') {
          context.go(PortalRoutes.kycVerification);
        } else if (value == 'logout') {
          await ref.read(sessionManagerProvider).signOut();
          if (context.mounted) {
            context.go(PortalRoutes.signIn);
          }
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AbraColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userEmail,
                style: const TextStyle(
                  fontSize: 12,
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: AbraColors.skyContainer,
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
                child: const Text(
                  userRole,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AbraColors.deepBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.business_outlined, size: 18, color: AbraColors.textSecondary),
              SizedBox(width: 12),
              Text('Company profile'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'staff',
          child: Row(
            children: [
              Icon(Icons.manage_accounts_outlined, size: 18, color: AbraColors.textSecondary),
              SizedBox(width: 12),
              Text('Staff and roles'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'kyc',
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: AbraColors.textSecondary),
              SizedBox(width: 12),
              Text('KYC verification'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AbraColors.danger),
              SizedBox(width: 12),
              Text(
                'Log out',
                style: TextStyle(
                  color: AbraColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNotificationsPopup(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned(
            top: 60,
            right: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(AbraRadius.lg),
              child: Container(
                width: 360,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AbraRadius.lg),
                  border: Border.all(color: AbraColors.border),
                  boxShadow: AbraShadows.raised,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AbraSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.go(PortalRoutes.notifications);
                            },
                            child: const Text('See all', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AbraColors.divider),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Center(
                        child: Text(
                          'No new notifications',
                          style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGlobalSearch(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _GlobalSearchDialog(),
    );
  }

  void _openAiAssistant(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AiAssistantDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 760;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final scaffoldBg = isDark ? const Color(0xFF0B1620) : AbraColors.lightGray;

    final sidebar = _buildSidebar(context);
    final topBar = _buildTopBar(context, isMobile);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _openGlobalSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _openGlobalSearch(context),
      },
      child: Focus(
        autofocus: true,
        child: isMobile
            ? Scaffold(
                key: _scaffoldKey,
                backgroundColor: scaffoldBg,
                drawer: Drawer(child: sidebar),
                body: Column(
                  children: [
                    topBar,
                    Expanded(child: widget.child),
                  ],
                ),
              )
            : Scaffold(
                key: _scaffoldKey,
                backgroundColor: scaffoldBg,
                body: Row(
                  children: [
                    sidebar,
                    Expanded(
                      child: Column(
                        children: [
                          topBar,
                          Expanded(
                            child: widget.child,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Global Search Dialog for Ctrl+K
class _GlobalSearchDialog extends StatefulWidget {
  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbraRadius.lg)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.search, color: AbraColors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search PNR, trip, bus registration, crew member...',
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => setState(() => _query = val),
                  ),
                ),
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AbraColors.lightGray,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ESC', style: TextStyle(fontSize: 10, color: AbraColors.textSecondary)),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _query.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.manage_search, size: 48, color: AbraColors.textSecondary),
                          SizedBox(height: 8),
                          Text('Type to search across bookings, trips, buses & crew',
                              style: TextStyle(color: AbraColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : Center(
                      child: Text('No results found for "$_query"',
                          style: const TextStyle(color: AbraColors.textSecondary)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abra AI Copilot Dialog
class _AiAssistantDialog extends StatefulWidget {
  @override
  State<_AiAssistantDialog> createState() => _AiAssistantDialogState();
}

class _AiAssistantDialogState extends State<_AiAssistantDialog> {
  String _activeAnswer = '';
  String _activeTitle = '';
  String? _actionLabel;
  String? _actionRoute;

  void _triggerPrompt(String title, String answer, {String? actionLabel, String? actionRoute}) {
    setState(() {
      _activeTitle = title;
      _activeAnswer = answer;
      _actionLabel = actionLabel;
      _actionRoute = actionRoute;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbraRadius.xl)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(AbraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AbraColors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AbraColors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Abra AI Copilot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Smart fleet analytics & operational guidance', style: TextStyle(color: AbraColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Suggested questions for Kaveri Express:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.trending_down, size: 16, color: AbraColors.orangeDark),
                  label: const Text('Which trips have low occupancy?'),
                  onPressed: () => _triggerPrompt(
                    'Low Occupancy Trips (Next 48 Hours)',
                    'Trip TRP2 (BLR → MAA) has only 12 / 45 seats booked (26.6% occupancy). We suggest launching a 10% flash discount to boost last-minute bookings.',
                    actionLabel: 'Create Promo Offer',
                    actionRoute: PortalRoutes.offers,
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AbraColors.teal),
                  label: const Text('7-day earnings summary'),
                  onPressed: () => _triggerPrompt(
                    '7-Day Earnings Summary',
                    'Kaveri Express generated ₹1,29,000 net earnings over the last 7 days from 48 confirmed bookings across 6 scheduled trips. Platform commission withheld was ₹9,030 (7%).',
                    actionLabel: 'View Detailed Settlements',
                    actionRoute: PortalRoutes.earnings,
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.warning_amber_outlined, size: 16, color: AbraColors.danger),
                  label: const Text('Expiring bus documents'),
                  onPressed: () => _triggerPrompt(
                    'Expiring Vehicle Documents',
                    'Bus TS09 UB 4521 (Kaveri Gold 1) insurance expires in 6 days (2025-08-15). Please renew and upload new policy documents to avoid suspension of scheduled trips.',
                    actionLabel: 'Manage Bus Documents',
                    actionRoute: PortalRoutes.buses,
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.badge_outlined, size: 16, color: AbraColors.deepBlue),
                  label: const Text('Driver duty & compliance'),
                  onPressed: () => _triggerPrompt(
                    'Driver Compliance Status',
                    '3 drivers are currently active. Ramesh K and Suresh M completed all pre-trip inspections with zero sobriety flags. Driver Anand R has a licence renewal coming up in 60 days.',
                    actionLabel: 'View Driver Reports',
                    actionRoute: PortalRoutes.driverReports,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _activeAnswer.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AbraColors.lightGray,
                          borderRadius: BorderRadius.circular(AbraRadius.md),
                        ),
                        child: const Text(
                          'Click any prompt chip above to get instant AI-assisted operations intelligence for your fleet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AbraColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AbraColors.lightBlue.withValues(alpha: 0.5),
                        border: Border.all(color: AbraColors.blue.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(AbraRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 16, color: AbraColors.blue),
                              const SizedBox(width: 6),
                              Text(_activeTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AbraColors.deepBlue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                _activeAnswer,
                                style: const TextStyle(fontSize: 13, height: 1.5, color: AbraColors.textPrimary),
                              ),
                            ),
                          ),
                          if (_actionLabel != null && _actionRoute != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                icon: const Icon(Icons.arrow_forward, size: 14),
                                label: Text(_actionLabel!),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AbraColors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.go(_actionRoute!);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
