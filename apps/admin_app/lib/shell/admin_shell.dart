import 'dart:async';

import 'package:flutter/material.dart';
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

/// One entry of the side navigation.
class AdminSection {
  const AdminSection(this.path, this.labelKey, this.hintKey, this.icon);

  final String path;
  final String labelKey;

  /// One line that says what the section is for.
  final String hintKey;
  final IconData icon;

  static const Map<String, AdminSection> byPath = <String, AdminSection>{
    AdminRoutes.trips: AdminSection(
      AdminRoutes.trips,
      AdminStrings.navTrips,
      AdminStrings.hintTrips,
      Icons.event_note_outlined,
    ),
    AdminRoutes.buses: AdminSection(
      AdminRoutes.buses,
      AdminStrings.navBuses,
      AdminStrings.hintBuses,
      Icons.directions_bus_outlined,
    ),
    AdminRoutes.routes: AdminSection(
      AdminRoutes.routes,
      AdminStrings.navRoutes,
      AdminStrings.hintRoutes,
      Icons.alt_route,
    ),
    AdminRoutes.locations: AdminSection(
      AdminRoutes.locations,
      AdminStrings.navLocations,
      AdminStrings.hintLocations,
      Icons.place_outlined,
    ),
    AdminRoutes.operators: AdminSection(
      AdminRoutes.operators,
      AdminStrings.navOperators,
      AdminStrings.hintOperators,
      Icons.business_outlined,
    ),
    AdminRoutes.places: AdminSection(
      AdminRoutes.places,
      AdminStrings.navPlaces,
      AdminStrings.hintPlaces,
      Icons.place_outlined,
    ),
    AdminRoutes.cities: AdminSection(
      AdminRoutes.cities,
      AdminStrings.navCities,
      AdminStrings.hintCities,
      Icons.location_city_outlined,
    ),
    AdminRoutes.busTypes: AdminSection(
      AdminRoutes.busTypes,
      AdminStrings.navBusTypes,
      AdminStrings.hintBusTypes,
      Icons.category_outlined,
    ),
    AdminRoutes.documentTypes: AdminSection(
      AdminRoutes.documentTypes,
      AdminStrings.navDocumentTypes,
      AdminStrings.hintDocumentTypes,
      Icons.fact_check_outlined,
    ),
    AdminRoutes.kycConfiguration: AdminSection(
      AdminRoutes.kycConfiguration,
      AdminStrings.navKycConfiguration,
      AdminStrings.hintKycConfiguration,
      Icons.rule_folder_outlined,
    ),
    AdminRoutes.customers: AdminSection(
      AdminRoutes.customers,
      AdminStrings.navCustomers,
      AdminStrings.hintCustomers,
      Icons.people_outline,
    ),
    AdminRoutes.invitations: AdminSection(
      AdminRoutes.invitations,
      AdminStrings.navInvitations,
      AdminStrings.hintInvitations,
      Icons.mark_email_read_outlined,
    ),
    AdminRoutes.reviews: AdminSection(
      AdminRoutes.reviews,
      AdminStrings.navReviews,
      AdminStrings.hintReviews,
      Icons.fact_check_outlined,
    ),
    AdminRoutes.banners: AdminSection(
      AdminRoutes.banners,
      AdminStrings.navBanners,
      AdminStrings.hintBanners,
      Icons.view_carousel_outlined,
    ),
    AdminRoutes.settings: AdminSection(
      AdminRoutes.settings,
      AdminStrings.navSettings,
      AdminStrings.hintSettings,
      Icons.settings_outlined,
    ),
  };

  /// Sections listed under "Content" (what customers see in the app) rather
  /// than under "Catalogue".
  static const Set<String> contentPaths = <String>{AdminRoutes.banners};

  /// Cities and Locations are tabs of "Cities and places"; they are listed
  /// on their own only for someone who cannot open that page.
  static const Set<String> _insidePlaces = <String>{
    AdminRoutes.cities,
    AdminRoutes.locations,
  };

  /// The sections [access] may open, in display order.
  static List<AdminSection> visibleTo(AccessState access) {
    final hasPlaces = AdminRouteGuard.canOpen(access, AdminRoutes.places);
    return <AdminSection>[
      for (final path in AdminRoutes.sections)
        if (AdminRouteGuard.canOpen(access, path) &&
            !(hasPlaces && _insidePlaces.contains(path)))
          byPath[path]!,
    ];
  }
}

/// Frame of the management app: a navy side navigation with the sections
/// the user's permissions allow (a drawer on narrow screens), and a top bar
/// that names the open section and the signed-in user.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AbraLocalizations.of(context);
    final confirmed = await showAbraConfirmDialog(
      context,
      title: l10n.text(AbraStrings.commonSignOut),
      message: l10n.text(AdminStrings.appName),
      confirmLabel: l10n.text(AbraStrings.commonSignOut),
    );
    if (confirmed) {
      // While the session is valid: this device stops receiving this person's push
      await ref.read(notificationCenterProvider).stop();
      await ref.read(sessionManagerProvider).signOut();
    }
  }

  /// Takes the person to what a notification is about. A file waiting for review opens in Reviews.
  static void _openNotification(BuildContext context, NotificationItem item) {
    final route = item.route;
    if (route != null && route.startsWith('/onboarding/')) {
      context.go(AdminRoutes.reviewOf(route.substring('/onboarding/'.length)));
    } else if (route != null && route.startsWith(AdminRoutes.places)) {
      // A place request: the Operator requests tab
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final access = ref.watch(accessProvider);
    final sections = AdminSection.visibleTo(access);
    final breakpoint = AbraBreakpoint.of(context);
    final isWide = breakpoint == AbraBreakpoint.desktop;
    final current = AdminSection.byPath[AdminRoutes.sectionOf(currentPath)];
    final userName = access.user?.name;

    Widget navigation({required bool inDrawer}) => _SideNavigation(
      sections: sections,
      currentPath: currentPath,
      onSelect: (section) {
        if (inDrawer) Navigator.of(context).pop();
        context.go(section.path);
      },
    );

    final appBar = AppBar(
      backgroundColor: AbraColors.white,
      foregroundColor: AbraColors.navy,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      titleSpacing: isWide ? AbraSpacing.xl : 0,
      shape: const Border(bottom: BorderSide(color: AbraColors.divider)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            current == null
                ? l10n.text(AdminStrings.appName)
                : l10n.text(current.labelKey),
            style: textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (current != null && breakpoint.isTabletOrWider)
            Text(
              l10n.text(current.hintKey),
              style: textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: <Widget>[
        if (breakpoint.isTabletOrWider)
          Center(
            child: AbraStatusBadge(
              label: l10n.text(
                access.hasPlatformScope
                    ? AdminStrings.navScopePlatform
                    : AdminStrings.navScopeOperator,
              ),
              tone: AbraStatusTone.info,
              icon: access.hasPlatformScope
                  ? Icons.public
                  : Icons.business_outlined,
            ),
          ),
        const SizedBox(width: AbraSpacing.sm),
        IconButton(
          icon: const Icon(Icons.inbox_outlined),
          tooltip: 'Notification inbox',
          onPressed: () => context.go('/notifications'),
        ),
        NotificationBell(
          center: ref.watch(notificationCenterProvider),
          onOpen: (item) => _openNotification(context, item),
        ),
        if (userName != null) ...<Widget>[
          const SizedBox(width: AbraSpacing.lg),
          _UserChip(name: userName, showName: breakpoint.isTabletOrWider),
        ],
        const SizedBox(width: AbraSpacing.xs),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: l10n.text(AbraStrings.commonSignOut),
          onPressed: () => _signOut(context, ref),
        ),
        const SizedBox(width: AbraSpacing.sm),
      ],
    );

    final pageBody = Column(
      children: <Widget>[
        PushPermissionBanner(center: ref.watch(notificationCenterProvider)),
        Expanded(child: child),
      ],
    );
    if (!isWide) {
      return _NotificationLifecycle(
        onOpen: (item) => _openNotification(context, item),
        child: Scaffold(
          appBar: appBar,
          drawer: Drawer(
            backgroundColor: AbraColors.navy,
            child: SafeArea(child: navigation(inDrawer: true)),
          ),
          body: SafeArea(child: pageBody),
        ),
      );
    }
    return _NotificationLifecycle(
      onOpen: (item) => _openNotification(context, item),
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: AbraSizes.sideNavigation,
                child: navigation(inDrawer: false),
              ),
              Expanded(
                child: Scaffold(appBar: appBar, body: pageBody),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Starts the notifications once a staff user is in (live socket and push) and shows a toast
/// when one arrives while the page is open. Stops them when the session ends.
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
    // A session that ends by itself (expired, signed out elsewhere) also ends the live channel
    ref.listen(authStateProvider, (previous, next) {
      if (next is AuthSignedOut) {
        unawaited(ref.read(notificationCenterProvider).stop());
      }
    });
    return widget.child;
  }
}

/// The navy navigation: product mark, then the sections.
class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.sections,
    required this.currentPath,
    required this.onSelect,
  });

  final List<AdminSection> sections;
  final String currentPath;
  final ValueChanged<AdminSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    Widget heading(String key) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AbraSpacing.md,
        AbraSpacing.sm,
        AbraSpacing.md,
        AbraSpacing.sm,
      ),
      child: ExcludeSemantics(
        child: Text(
          l10n.text(key).toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: AbraColors.onNavyMuted,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
    Widget item(AdminSection section) => _NavItem(
      section: section,
      isSelected: section.path == currentPath,
      onTap: () => onSelect(section),
    );
    final content = sections
        .where((section) => AdminSection.contentPaths.contains(section.path))
        .toList();
    return Material(
      color: AbraColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AbraSpacing.lg,
              AbraSpacing.lg,
              AbraSpacing.lg,
              AbraSpacing.lg,
            ),
            child: AbraBrandMark(
              name: l10n.text(AdminStrings.brandName),
              caption: l10n.text(AdminStrings.brandCaption),
            ),
          ),
          const Divider(color: AbraColors.navyDivider, height: 1),
          Expanded(
            child: Semantics(
              container: true,
              label: l10n.text(AdminStrings.navCatalogue),
              child: ListView(
                padding: const EdgeInsets.all(AbraSpacing.md),
                children: <Widget>[
                  heading(AdminStrings.navCatalogue),
                  for (final section in sections)
                    if (!content.contains(section)) item(section),
                  if (content.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AbraSpacing.md),
                    heading(AdminStrings.navContent),
                    for (final section in content) item(section),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final AdminSection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final foreground = isSelected ? AbraColors.white : AbraColors.onNavyMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.xs),
      child: AnimatedContainer(
        duration: AbraMotion.isReduced(context)
            ? Duration.zero
            : AbraDurations.fast,
        decoration: BoxDecoration(
          color: isSelected ? AbraColors.blue : Colors.transparent,
          borderRadius: AbraRadius.medium,
        ),
        child: ListTile(
          dense: true,
          minTileHeight: AbraSizes.minTouchTarget,
          horizontalTitleGap: AbraSpacing.md,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AbraSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AbraRadius.medium),
          hoverColor: AbraColors.navyHover,
          focusColor: AbraColors.navyHover,
          splashColor: AbraColors.navyHover,
          iconColor: foreground,
          textColor: foreground,
          selectedColor: AbraColors.white,
          selected: isSelected,
          leading: Icon(section.icon, size: 20),
          title: Text(
            l10n.text(section.labelKey),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// The signed-in user: initials, and the name where there is room.
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
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: showName
          ? null
          : AbraLocalizations.of(context).text(
              AdminStrings.userMenuSignedInAs,
              <String, Object?>{'name': name},
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AbraColors.navySecondary,
              child: Text(
                _initials,
                style: textTheme.labelMedium?.copyWith(color: AbraColors.white),
              ),
            ),
          ),
          if (showName) ...<Widget>[
            const SizedBox(width: AbraSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                name,
                style: textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
