import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../features/accept_invite/accept_invite_screen.dart';
import '../features/auth/access_gate_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/bookings/client_bookings_screen.dart';
import '../features/buses/buses_client_manage_screen.dart';
import '../features/commission/client_commission_screen.dart';
import '../features/company/client_company_profile_screen.dart';
import '../features/crew/crew_client_manage_screen.dart';
import '../features/crew/client_driver_reports_screen.dart';
import '../features/crew/client_driver_rules_screen.dart';
import '../features/dashboard/client_dashboard_screen.dart';
import '../features/earnings/client_earnings_screen.dart';
import '../features/fares/client_fares_screen.dart';
import '../features/kyc/kyc_client_manage_screen.dart';
import '../features/live/client_live_tracking_screen.dart';
import '../features/notifications/client_notification_screen.dart';
import '../features/offers/client_offers_screen.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/places/places_client_manage_screen.dart';
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
    ..listen(accessProvider, (previous, next) => accessChanges.notify())
    ..onDispose(accessChanges.dispose);

  final router = GoRouter(
    initialLocation: PortalRoutes.splash,
    refreshListenable: accessChanges,
    redirect: (context, state) => PortalRouteGuard.redirect(
      access: ref.read(accessProvider),
      path: state.uri.path,
      from: state.uri.queryParameters[PortalRoutes.fromParameter],
    ),
    errorBuilder: (context, state) =>
        const Scaffold(body: AbraStateView(kind: AbraStateKind.notFound)),
    routes: <RouteBase>[
      GoRoute(
        path: PortalRoutes.splash,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: PortalRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: PortalRoutes.acceptInvite,
        builder: (context, state) =>
            AcceptInviteScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: PortalRoutes.home,
        builder: (context, state) => const AccessGateScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            PortalShell(currentPath: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const ClientNotificationScreen(),
          ),
          GoRoute(
            path: '/kyc',
            builder: (context, state) => const ClientKycVerificationScreen(),
          ),
          GoRoute(
            path: PortalRoutes.dashboard,
            builder: (context, state) => const ClientDashboardScreen(),
          ),
          GoRoute(
            path: PortalRoutes.places,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  PortalRouteGuard.canOpen(
                    ref.watch(accessProvider),
                    PortalRoutes.places,
                  )
                  ? const PlacesClientManageScreen()
                  : const AbraStateView(kind: AbraStateKind.forbidden),
            ),
          ),
          GoRoute(
            path: PortalRoutes.company,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  PortalRouteGuard.canOpen(
                    ref.watch(accessProvider),
                    PortalRoutes.company,
                  )
                  ? const ClientCompanyProfileScreen()
                  : const AbraStateView(kind: AbraStateKind.forbidden),
            ),
          ),
          GoRoute(
            path: PortalRoutes.companyProfile,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  PortalRouteGuard.canOpen(
                    ref.watch(accessProvider),
                    PortalRoutes.company,
                  )
                  ? const ClientCompanyProfileScreen()
                  : const AbraStateView(kind: AbraStateKind.forbidden),
            ),
          ),
          GoRoute(
            path: PortalRoutes.kycVerification,
            builder: (context, state) => const ClientKycVerificationScreen(),
          ),
          GoRoute(
            path: PortalRoutes.buses,
            builder: (context, state) => const BusesClientManageScreen(initialTab: 0),
          ),
          GoRoute(
            path: PortalRoutes.seatLayouts,
            builder: (context, state) => const BusesClientManageScreen(initialTab: 1),
          ),
          GoRoute(
            path: PortalRoutes.crew,
            builder: (context, state) => const CrewClientManageScreen(),
          ),
          GoRoute(
            path: PortalRoutes.driverReports,
            builder: (context, state) => const ClientDriverReportsScreen(),
          ),
          GoRoute(
            path: PortalRoutes.driverRules,
            builder: (context, state) => const ClientDriverRulesScreen(),
          ),
          GoRoute(
            path: PortalRoutes.routes,
            builder: (context, state) => const ClientRoutesScreen(),
          ),
          GoRoute(
            path: PortalRoutes.fares,
            builder: (context, state) => const ClientFaresScreen(),
          ),
          GoRoute(
            path: PortalRoutes.schedules,
            builder: (context, state) => const ClientSchedulesScreen(),
          ),
          GoRoute(
            path: PortalRoutes.trips,
            builder: (context, state) => const ClientTripsScreen(),
          ),
          GoRoute(
            path: PortalRoutes.bookings,
            builder: (context, state) => const ClientBookingsScreen(),
          ),
          GoRoute(
            path: PortalRoutes.offers,
            builder: (context, state) => const ClientOffersScreen(),
          ),
          GoRoute(
            path: PortalRoutes.earnings,
            builder: (context, state) => const ClientEarningsScreen(),
          ),
          GoRoute(
            path: PortalRoutes.commission,
            builder: (context, state) => const ClientCommissionScreen(),
          ),
          GoRoute(
            path: PortalRoutes.liveTracking,
            builder: (context, state) => const ClientLiveTrackingScreen(),
          ),
          GoRoute(
            path: PortalRoutes.notifications,
            builder: (context, state) => const ClientNotificationScreen(),
          ),
          GoRoute(
            path: PortalRoutes.staffRoles,
            builder: (context, state) => const ClientStaffRolesScreen(),
          ),
          GoRoute(
            path: '${PortalRoutes.onboardingPrefix}:id',
            builder: (context, state) =>
                OnboardingPage(id: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '${PortalRoutes.busKycPrefix}:busId',
            builder: (context, state) =>
                BusKycScreen(busId: state.pathParameters['busId'] ?? ''),
          ),
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
