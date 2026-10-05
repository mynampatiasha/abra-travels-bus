import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../l10n/customer_strings.dart';
import '../routing/app_routes.dart';

/// One section of the signed-in shell.
class AppShellTab {
  const AppShellTab({
    required this.path,
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;
}

/// Frame of the signed-in app: the four main sections, as a bottom bar on
/// phones and a side rail on tablets and wider. Each section keeps its own
/// navigation history.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<AppShellTab> tabs = <AppShellTab>[
    AppShellTab(
      path: AppRoutes.home,
      labelKey: CustomerStrings.navHome,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppShellTab(
      path: AppRoutes.myTrips,
      labelKey: CustomerStrings.navMyTrips,
      icon: Icons.confirmation_number_outlined,
      selectedIcon: Icons.confirmation_number,
    ),
    AppShellTab(
      path: AppRoutes.support,
      labelKey: CustomerStrings.navSupport,
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent,
    ),
    AppShellTab(
      path: AppRoutes.profile,
      labelKey: CustomerStrings.navProfile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  void _select(int index) => navigationShell.goBranch(
    index,
    // Tapping the current section again returns to its first screen.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final current = navigationShell.currentIndex;
    final appBar = AppBar(
      title: Text(l10n.text(tabs[current].labelKey)),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.language),
          tooltip: l10n.text(CustomerStrings.languageChangeAction),
          onPressed: () => context.push(AppRoutes.language),
        ),
      ],
    );

    if (AbraBreakpoint.of(context).isTabletOrWider) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              Semantics(
                container: true,
                label: l10n.text(CustomerStrings.navMainLabel),
                child: NavigationRail(
                  selectedIndex: current,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: <NavigationRailDestination>[
                    for (final tab in tabs)
                      NavigationRailDestination(
                        icon: Icon(tab.icon),
                        selectedIcon: Icon(tab.selectedIcon),
                        label: Text(l10n.text(tab.labelKey)),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: navigationShell,
      bottomNavigationBar: Semantics(
        container: true,
        label: l10n.text(CustomerStrings.navMainLabel),
        child: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: _select,
          destinations: <NavigationDestination>[
            for (final tab in tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: l10n.text(tab.labelKey),
              ),
          ],
        ),
      ),
    );
  }
}
