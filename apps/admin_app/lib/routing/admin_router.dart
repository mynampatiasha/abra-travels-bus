import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../features/auth/access_gate_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/catalogue/pages/bus_types_page.dart';
import '../features/catalogue/pages/buses_page.dart';
import '../features/catalogue/pages/cities_page.dart';
import '../features/catalogue/pages/locations_page.dart';
import '../features/catalogue/pages/operators_page.dart';
import '../features/catalogue/pages/routes_page.dart';
import '../features/catalogue/pages/trips_page.dart';
import '../shell/admin_shell.dart';
import 'admin_route_guard.dart';
import 'admin_routes.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final accessChanges = _ChangeSignal();
  ref
    ..listen(accessProvider, (_, _) => accessChanges.notify())
    ..onDispose(accessChanges.dispose);

  const pages = <String, Widget>{
    AdminRoutes.cities: CitiesPage(),
    AdminRoutes.busTypes: BusTypesPage(),
    AdminRoutes.operators: OperatorsPage(),
    AdminRoutes.locations: LocationsPage(),
    AdminRoutes.buses: BusesPage(),
    AdminRoutes.routes: RoutesPage(),
    AdminRoutes.trips: TripsPage(),
  };

  final router = GoRouter(
    initialLocation: AdminRoutes.splash,
    refreshListenable: accessChanges,
    redirect: (context, state) => AdminRouteGuard.redirect(
      access: ref.read(accessProvider),
      path: state.uri.path,
    ),
    errorBuilder: (context, state) =>
        const Scaffold(body: AbraStateView(kind: AbraStateKind.notFound)),
    routes: <RouteBase>[
      GoRoute(
        path: AdminRoutes.splash,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AdminRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AdminRoutes.home,
        builder: (context, state) => const AccessGateScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(currentPath: state.uri.path, child: child),
        routes: <RouteBase>[
          for (final entry in pages.entries)
            GoRoute(
              path: entry.key,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                child: _PermissionGate(path: entry.key, child: entry.value),
              ),
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Shows a section only to a user who holds its permission; anyone else
/// (for example through a typed address) sees "no access".
class _PermissionGate extends ConsumerWidget {
  const _PermissionGate({required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AdminRouteGuard.canOpen(ref.watch(accessProvider), path)
      ? child
      : const AbraStateView(kind: AbraStateKind.forbidden);
}

class _ChangeSignal extends ChangeNotifier {
  void notify() => notifyListeners();
}
