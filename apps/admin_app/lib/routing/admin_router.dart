import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../features/audit/audit_admin_manage_screen.dart';
import '../features/auth/access_gate_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/banners/admin_banners_manage.dart';
import '../features/catalogue/pages/bus_types_page.dart';
import '../features/catalogue/pages/buses_page.dart';
import '../features/catalogue/pages/cities_page.dart';
import '../features/catalogue/pages/document_types_page.dart';
import '../features/catalogue/pages/locations_page.dart';
import '../features/catalogue/pages/operators_page.dart';
import '../features/catalogue/pages/routes_page.dart';
import '../features/catalogue/pages/trips_page.dart';
import '../features/customers/admin_customers.dart';
import '../features/invitations/invitations_page.dart';
import '../features/kyc/admin_kyc_configuration.dart';
import '../features/notifications/admin_notification_screen.dart';
import '../features/operators/operators_admin_manage_screen.dart';
import '../features/places/places_admin_manage_screen.dart';
import '../features/reviews/review_detail_page.dart';
import '../features/reviews/reviews_page.dart';
import '../features/settings/settings_page.dart';
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
    AdminRoutes.documentTypes: DocumentTypesPage(),
    AdminRoutes.kycConfiguration: AdminKycConfigurationPage(),
    AdminRoutes.customers: AdminCustomersPage(),
    AdminRoutes.settings: SettingsPage(),
    AdminRoutes.invitations: InvitationsPage(),
    AdminRoutes.reviews: ReviewsPage(),
    AdminRoutes.operators: OperatorsPage(),
    AdminRoutes.locations: LocationsPage(),
    AdminRoutes.buses: BusesPage(),
    AdminRoutes.routes: RoutesPage(),
    AdminRoutes.trips: TripsPage(),
    AdminRoutes.banners: AdminBannersPage(),
    AdminRoutes.places: PlacesAdminManageScreen(),
    AdminRoutes.audit: AuditAdminManageScreen(),
  };

  final router = GoRouter(
    initialLocation: AdminRoutes.splash,
    refreshListenable: accessChanges,
    redirect: (context, state) => AdminRouteGuard.redirect(
      access: ref.read(accessProvider),
      path: state.uri.path,
      from: state.uri.queryParameters[AdminRoutes.fromParameter],
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
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const AdminNotificationScreen(),
          ),
          for (final entry in pages.entries)
            GoRoute(
              path: entry.key,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                transitionDuration: AbraDurations.fast,
                reverseTransitionDuration: AbraDurations.fast,
                transitionsBuilder: (context, animation, _, child) =>
                    AbraMotion.isReduced(context)
                    ? child
                    : FadeTransition(opacity: animation, child: child),
                child: _PermissionGate(path: entry.key, child: entry.value),
              ),
            ),
          GoRoute(
            path: '${AdminRoutes.operators}/:id',
            builder: (context, state) => _PermissionGate(
              path: AdminRoutes.operators,
              child: OperatorDetailPage(id: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '${AdminRoutes.reviews}/:id',
            builder: (context, state) => _PermissionGate(
              path: AdminRoutes.reviews,
              child: ReviewDetailPage(id: state.pathParameters['id']!),
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
