import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../features/accept_invite/accept_invite_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/bookings/client_bookings_screen.dart';
import '../features/buses/buses_client_manage_screen.dart';
import '../features/commission/client_commission_screen.dart';
import '../features/company/client_company_profile_screen.dart';
import '../features/crew/client_crew_screen.dart';
import '../features/crew/client_driver_reports_screen.dart';
import '../features/crew/client_driver_rules_screen.dart';
import '../features/dashboard/client_dashboard_screen.dart';
import '../features/earnings/client_earnings_screen.dart';
import '../features/fares/client_fares_screen.dart';
import '../features/kyc/client_kyc_verification_screen.dart';
import '../features/kyc/kyc_client_manage_screen.dart';
import '../features/live/client_live_tracking_screen.dart';
import '../features/notifications/client_notifications_screen.dart';
import '../features/offers/client_offers_screen.dart';
import '../features/places/client_places_screen.dart';
import '../features/routes/client_routes_screen.dart';
import '../features/schedules/client_schedules_screen.dart';
import '../features/staff/client_staff_roles_screen.dart';
import '../features/trips/client_trips_screen.dart';
import '../shell/portal_shell.dart';
import 'portal_route_guard.dart';
import 'portal_routes.dart';

final portalRouterProvider = Provider<GoRouter>((ref) {
  final accessChanges = _ChangeSignal();
  ref
    ..listen(accessProvider, (_, _) => accessChanges.notify())
    ..onDispose(accessChanges.dispose);

  final router = GoRouter(
    initialLocation: PortalRoutes.dashboard,
    refreshListenable: accessChanges,
    redirect: (context, state) => PortalRouteGuard.redirect(
      access: ref.read(accessProvider),
      path: state.uri.path,
      from: state.uri.queryParameters[PortalRoutes.fromParameter],
    ),
    errorBuilder: (context, state) =>
        const Scaffold(body: AbraStateView(kind: AbraStateKind.notFound)),
    routes: <RouteBase>[
      GoRoute(path: PortalRoutes.splash, redirect: (_, __) => PortalRoutes.dashboard),
      GoRoute(path: PortalRoutes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(
        path: PortalRoutes.acceptInvite,
        builder: (_, state) => AcceptInviteScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(path: PortalRoutes.home, redirect: (_, __) => PortalRoutes.dashboard),
      ShellRoute(
        builder: (context, state, child) =>
            PortalShell(currentPath: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(path: PortalRoutes.dashboard, builder: (_, __) => const ClientDashboardScreen()),
          GoRoute(path: PortalRoutes.kycVerification, builder: (_, __) => const ClientKycVerificationScreen()),
          GoRoute(path: PortalRoutes.companyProfile, builder: (_, __) => const ClientCompanyProfileScreen()),
          GoRoute(path: PortalRoutes.buses, builder: (_, __) => const BusesClientManageScreen(initialTab: 0)),
          GoRoute(path: PortalRoutes.seatLayouts, builder: (_, __) => const BusesClientManageScreen(initialTab: 1)),
          GoRoute(path: PortalRoutes.crew, builder: (_, __) => const ClientCrewScreen()),
          GoRoute(path: PortalRoutes.driverReports, builder: (_, __) => const ClientDriverReportsScreen()),
          GoRoute(path: PortalRoutes.driverRules, builder: (_, __) => const ClientDriverRulesScreen()),
          GoRoute(path: PortalRoutes.routes, builder: (_, __) => const ClientRoutesScreen()),
          GoRoute(path: PortalRoutes.places, builder: (_, __) => const ClientPlacesScreen()),
          GoRoute(path: PortalRoutes.fares, builder: (_, __) => const ClientFaresScreen()),
          GoRoute(path: PortalRoutes.schedules, builder: (_, __) => const ClientSchedulesScreen()),
          GoRoute(path: PortalRoutes.trips, builder: (_, __) => const ClientTripsScreen()),
          GoRoute(path: PortalRoutes.bookings, builder: (_, __) => const ClientBookingsScreen()),
          GoRoute(path: PortalRoutes.offers, builder: (_, __) => const ClientOffersScreen()),
          GoRoute(path: PortalRoutes.earnings, builder: (_, __) => const ClientEarningsScreen()),
          GoRoute(path: PortalRoutes.commission, builder: (_, __) => const ClientCommissionScreen()),
          GoRoute(path: PortalRoutes.liveTracking, builder: (_, __) => const ClientLiveTrackingScreen()),
          GoRoute(path: PortalRoutes.notifications, builder: (_, __) => const ClientNotificationsScreen()),
          GoRoute(path: PortalRoutes.staffRoles, builder: (_, __) => const ClientStaffRolesScreen()),
          GoRoute(path: PortalRoutes.company, builder: (_, __) => const ClientCompanyProfileScreen()),
          GoRoute(path: '${PortalRoutes.onboardingPrefix}:id', builder: (_, __) => const ClientKycVerificationScreen()),
          GoRoute(path: '${PortalRoutes.busKycPrefix}:busId', builder: (_, state) => BusKycScreen(busId: state.pathParameters['busId'] ?? '')),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _ChangeSignal extends ChangeNotifier {
  void notify() => notifyListeners();
}
