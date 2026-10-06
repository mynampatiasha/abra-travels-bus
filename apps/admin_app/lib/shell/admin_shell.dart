import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../l10n/admin_strings.dart';
import '../routing/admin_route_guard.dart';
import '../routing/admin_routes.dart';

/// One entry of the side navigation.
class AdminSection {
  const AdminSection(this.path, this.labelKey, this.icon);

  final String path;
  final String labelKey;
  final IconData icon;

  static const Map<String, AdminSection> byPath = <String, AdminSection>{
    AdminRoutes.trips: AdminSection(
      AdminRoutes.trips,
      AdminStrings.navTrips,
      Icons.event_note_outlined,
    ),
    AdminRoutes.buses: AdminSection(
      AdminRoutes.buses,
      AdminStrings.navBuses,
      Icons.directions_bus_outlined,
    ),
    AdminRoutes.routes: AdminSection(
      AdminRoutes.routes,
      AdminStrings.navRoutes,
      Icons.alt_route,
    ),
    AdminRoutes.locations: AdminSection(
      AdminRoutes.locations,
      AdminStrings.navLocations,
      Icons.place_outlined,
    ),
    AdminRoutes.operators: AdminSection(
      AdminRoutes.operators,
      AdminStrings.navOperators,
      Icons.business_outlined,
    ),
    AdminRoutes.cities: AdminSection(
      AdminRoutes.cities,
      AdminStrings.navCities,
      Icons.location_city_outlined,
    ),
    AdminRoutes.busTypes: AdminSection(
      AdminRoutes.busTypes,
      AdminStrings.navBusTypes,
      Icons.category_outlined,
    ),
  };

  /// The sections [access] may open, in display order.
  static List<AdminSection> visibleTo(AccessState access) => <AdminSection>[
    for (final path in AdminRoutes.sections)
      if (AdminRouteGuard.canOpen(access, path)) byPath[path]!,
  ];
}

/// Frame of the management app: top bar with the signed-in user, and the
/// sections the user's permissions allow, as a fixed side list on wide
/// screens and a drawer on narrow ones.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  static const _sideWidth = 248.0;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AbraLocalizations.of(context);
    final confirmed = await showAbraConfirmDialog(
      context,
      title: l10n.text(AbraStrings.commonSignOut),
      message: l10n.text(AdminStrings.appName),
      confirmLabel: l10n.text(AbraStrings.commonSignOut),
    );
    if (confirmed == true) await ref.read(sessionManagerProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final sections = AdminSection.visibleTo(access);
    final isWide = AbraBreakpoint.of(context) == AbraBreakpoint.desktop;
    final current = AdminSection.byPath[currentPath];

    final navigation = Semantics(
      container: true,
      label: l10n.text(AdminStrings.navCatalogue),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AbraSpacing.lg,
              AbraSpacing.sm,
              AbraSpacing.lg,
              AbraSpacing.sm,
            ),
            child: Text(
              l10n.text(AdminStrings.navCatalogue),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AbraColors.textSecondary),
            ),
          ),
          for (final section in sections)
            ListTile(
              leading: Icon(section.icon),
              title: Text(l10n.text(section.labelKey)),
              selected: section.path == currentPath,
              onTap: () {
                if (!isWide) Navigator.of(context).pop();
                context.go(section.path);
              },
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          current == null
              ? l10n.text(AdminStrings.appName)
              : l10n.text(current.labelKey),
        ),
        actions: <Widget>[
          Center(
            child: AbraStatusBadge(
              label: l10n.text(
                access.hasPlatformScope
                    ? AdminStrings.navScopePlatform
                    : AdminStrings.navScopeOperator,
              ),
              tone: AbraStatusTone.info,
            ),
          ),
          const SizedBox(width: AbraSpacing.md),
          if (access.user?.name != null)
            Center(child: Text(access.user!.name!)),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.text(AbraStrings.commonSignOut),
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      drawer: isWide ? null : Drawer(child: SafeArea(child: navigation)),
      body: SafeArea(
        child: isWide
            ? Row(
                children: <Widget>[
                  SizedBox(
                    width: _sideWidth,
                    child: ColoredBox(
                      color: AbraColors.white,
                      child: navigation,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              )
            : child,
      ),
    );
  }
}
