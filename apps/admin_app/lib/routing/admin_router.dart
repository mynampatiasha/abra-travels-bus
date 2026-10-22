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
import '../features/buses/buses_admin_manage_screen.dart';
import '../features/catalogue/pages/bus_types_page.dart';
import '../features/catalogue/pages/cities_page.dart';
import '../features/catalogue/pages/document_types_page.dart';
import '../features/catalogue/pages/locations_page.dart';
import '../features/catalogue/pages/operators_page.dart';
import '../features/catalogue/pages/routes_page.dart';
import '../features/commission/admin_payout_page.dart';
import '../features/commission/commission_admin_manage_screen.dart';
import '../features/customers/admin_customers.dart';
import '../features/dashboard/admin_dashboard_page.dart';
import '../features/invitations/invitations_page.dart';
import '../features/kyc/admin_kyc_configuration.dart';
import '../features/marketing/admin_announcements_page.dart';
import '../features/marketing/admin_offers_page.dart';
import '../features/marketing/admin_popular_routes_page.dart';
import '../features/notifications/admin_notification_screen.dart';
import '../features/operations/admin_tracking_page.dart';
import '../features/operators/admin_driver_reports_page.dart';
import '../features/operators/admin_driver_rules_page.dart';
import '../features/operators/operators_admin_manage_screen.dart';
import '../features/places/places_admin_manage_screen.dart';
import '../features/reports/admin_reports_page.dart';
import '../features/reviews/review_detail_page.dart';
import '../features/reviews/reviews_page.dart';
import '../features/safety/admin_incidents_page.dart';
import '../features/safety/admin_safety_settings_page.dart';
import '../features/safety/admin_sos_page.dart';
import '../features/sales/admin_bookings_page.dart';
import '../features/sales/admin_payments_page.dart';
import '../features/sales/admin_refunds_page.dart';
import '../features/sales/admin_settlements_page.dart';
import '../features/settings/admin_feature_flags_page.dart';
import '../features/settings/settings_page.dart';
import '../features/staff/admin_staff_page.dart';
import '../features/support/admin_content_page.dart';
import '../features/support/admin_messages_page.dart';
import '../features/support/admin_tickets_page.dart';
import '../features/trips/trips_admin_manage_screen.dart';
import '../shell/admin_shell.dart';
import 'admin_route_guard.dart';
import 'admin_routes.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final accessChanges = _ChangeSignal();
  ref
    ..listen(accessProvider, (_, _) => accessChanges.notify())
    ..onDispose(accessChanges.dispose);

  final pages = <String, Widget>{
    // 1. Overview
    AdminRoutes.dashboard: const AdminDashboardPage(),

    // 2. Operators
    AdminRoutes.invitations: const InvitationsPage(),
    AdminRoutes.reviews: const ReviewsPage(),
    AdminRoutes.operators: const OperatorsPage(),
    AdminRoutes.driverReports: const AdminDriverReportsPage(),
    AdminRoutes.driverRules: const AdminDriverRulesPage(),

    // 3. Commercial
    AdminRoutes.commission: const CommissionAdminManageScreen(),
    AdminRoutes.payout: const AdminPayoutPage(),

    // 4. Catalogue
    AdminRoutes.places: const PlacesAdminManageScreen(),
    AdminRoutes.cities: const CitiesPage(),
    AdminRoutes.locations: const LocationsPage(),
    AdminRoutes.busTypes: const BusTypesPage(),
    AdminRoutes.documentTypes: const DocumentTypesPage(),
    AdminRoutes.kycConfiguration: const AdminKycConfigurationPage(),

    // 5. Operations
    AdminRoutes.buses: const BusesAdminManageScreen(),
    AdminRoutes.trips: const AdminTripsPage(),
    AdminRoutes.inventory: const AdminInventoryPage(),
    AdminRoutes.tracking: const AdminTrackingPage(),
    AdminRoutes.routes: const RoutesPage(),

    // 6. Sales
    AdminRoutes.bookings: const AdminBookingsPage(),
    AdminRoutes.payments: const AdminPaymentsPage(),
    AdminRoutes.refunds: const AdminRefundsPage(),
    AdminRoutes.settlements: const AdminSettlementsPage(),

    // 7. Customers
    AdminRoutes.customers: const AdminCustomersPage(),
    AdminRoutes.tickets: const AdminTicketsPage(),
    AdminRoutes.messages: const AdminMessagesPage(),
    AdminRoutes.content: const AdminContentPage(),

    // 8. Marketing
    AdminRoutes.banners: const AdminBannersPage(),
    AdminRoutes.offers: const AdminOffersPage(),
    AdminRoutes.announcements: const AdminAnnouncementsPage(),
    AdminRoutes.popularRoutes: const AdminPopularRoutesPage(),

    // 9. Safety
    AdminRoutes.sos: const AdminSosPage(),
    AdminRoutes.incidents: const AdminIncidentsPage(),
    AdminRoutes.safetySettings: const AdminSafetySettingsPage(),

    // 10. Insights
    AdminRoutes.reports: const AdminReportsPage(),

    // 11. System
    AdminRoutes.settings: const SettingsPage(),
    AdminRoutes.staff: const AdminStaffPage(),
    AdminRoutes.featureFlags: const AdminFeatureFlagsPage(),
    AdminRoutes.audit: const AuditAdminManageScreen(),
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
