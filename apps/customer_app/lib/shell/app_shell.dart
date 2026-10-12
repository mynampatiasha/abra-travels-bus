import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_theme/shared_theme.dart';

import '../app/providers.dart';
import '../core/ui/gradient_header.dart';
import '../core/ui/responsive.dart';
import '../features/authentication/gate/require_sign_in.dart';
import '../features/authentication/gate/sign_in_intent.dart';
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

/// Frame of the app: the four main sections, as a bottom bar below 840 px
/// and a navigation rail from there (extended from 1200 px). Each section
/// keeps its own navigation history and scroll position. Guests see the
/// same frame; My trips and Profile show them a guest card, and "Log in" in
/// the bar opens the sign-in sheet over the current screen.
class AppShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final current = navigationShell.currentIndex;
    final auth = ref.watch(authStateProvider);
    final center = auth is AuthSignedIn
        ? ref.watch(appDependenciesProvider).notifications
        : null;
    // The page area: with notifications on, a banner asks the person to allow
    // them, and the lifecycle keeps the live channel and push registered.
    final content = center == null
        ? navigationShell
        : _NotificationLifecycle(
            center: center,
            accessToken: ref.read(sessionManagerProvider).accessToken,
            child: Column(
              children: <Widget>[
                PushPermissionBanner(center: center),
                Expanded(child: navigationShell),
              ],
            ),
          );
    final appBar = GradientAppBar(
      title: l10n.text(tabs[current].labelKey),
      automaticallyImplyLeading: false,
      actions: <Widget>[
        if (center != null)
          NotificationBell(
            center: center,
            color: AbraColors.white,
            onOpen: (item) => _openRoute(context, item.route),
          ),
        if (auth is AuthSignedOut)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AbraColors.white),
            icon: const Icon(Icons.login),
            onPressed: () => requireSignIn(
              context,
              SignInIntent(returnLocation: currentLocation(context)),
            ),
            label: Text(l10n.text(CustomerStrings.gateActionShort)),
          ),
        IconButton(
          icon: const Icon(Icons.language),
          tooltip: l10n.text(CustomerStrings.languageChangeAction),
          onPressed: () => context.push(AppRoutes.language),
        ),
      ],
    );

    if (CustomerLayout.usesNavigationRail(context)) {
      final extended = CustomerLayout.usesExtendedRail(context);
      return Scaffold(
        appBar: appBar,
        body: SafeArea(
          top: false,
          child: Row(
            children: <Widget>[
              Semantics(
                container: true,
                label: l10n.text(CustomerStrings.navMainLabel),
                child: NavigationRail(
                  selectedIndex: current,
                  onDestinationSelected: _select,
                  extended: extended,
                  minExtendedWidth: AbraSizes.sideNavigation,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  backgroundColor: AbraColors.white,
                  indicatorColor: AbraColors.skyContainer,
                  selectedIconTheme: const IconThemeData(
                    color: AbraColors.deepBlue,
                  ),
                  selectedLabelTextStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(
                        color: AbraColors.deepBlue,
                        fontWeight: FontWeight.w700,
                      ),
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
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: Semantics(
        container: true,
        label: l10n.text(CustomerStrings.navMainLabel),
        child: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: _select,
          backgroundColor: AbraColors.white,
          indicatorColor: AbraColors.skyContainer,
          destinations: <NavigationDestination>[
            for (final tab in tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(
                  tab.selectedIcon,
                  color: AbraColors.deepBlue,
                ),
                label: l10n.text(tab.labelKey),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the screen a notification is about. Only places this app has are
/// opened; anything else is ignored.
void _openRoute(BuildContext context, String? route) {
  if (route != null && route.startsWith(AppRoutes.myTrips)) {
    context.go(route);
  }
}

/// Starts the notifications once the person is in (live channel and push),
/// shows a toast when one arrives while the app is open, and opens the screen
/// of a push the person tapped. Stopping at sign-out is done where the person
/// signs out, while the session is still valid.
class _NotificationLifecycle extends StatefulWidget {
  const _NotificationLifecycle({
    required this.center,
    required this.accessToken,
    required this.child,
  });

  final NotificationCenter center;
  final Future<String?> Function() accessToken;
  final Widget child;

  @override
  State<_NotificationLifecycle> createState() => _NotificationLifecycleState();
}

class _NotificationLifecycleState extends State<_NotificationLifecycle> {
  StreamSubscription<NotificationItem>? _toasts;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.center.start(widget.accessToken));
      _toasts = widget.center.arrivals.listen(_toast);
      _taps = widget.center.routeOpens.listen((route) {
        if (mounted) _openRoute(context, route);
      });
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
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _openRoute(context, item.route),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_toasts?.cancel());
    unawaited(_taps?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
