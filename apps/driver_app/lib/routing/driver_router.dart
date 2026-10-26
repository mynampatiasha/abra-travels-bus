import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/providers.dart';
import '../features/auth_access/auth_access_driver_screen.dart';
import '../features/driver_core/driver_core_driver_screen.dart';
import '../features/driver_reports/driver_reports_driver_screen.dart';
import '../features/driver_rules/driver_rules_driver_screen.dart';
import '../features/notifications/notifications_driver_screen.dart';
import '../shell/driver_shell.dart';
import 'driver_routes.dart';

final driverRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: DriverRoutes.home,
    // Nobody reaches a screen of the driver app without signing in first
    redirect: (context, state) {
      final signedIn = ref.read(driverTokenSourceProvider).token != null;
      final atSignIn = state.matchedLocation == DriverRoutes.signIn;
      if (!signedIn && !atSignIn) return DriverRoutes.signIn;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: DriverRoutes.signIn,
        builder: (context, state) => const AuthAccessDriverScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => DriverShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: DriverRoutes.home,
            builder: (context, state) => const DriverHomeScreen(),
          ),
          GoRoute(
            path: DriverRoutes.trip,
            builder: (context, state) => const DriverTripScreen(),
          ),
          GoRoute(
            path: DriverRoutes.reports,
            builder: (context, state) => const DriverReportsScreen(),
          ),
          GoRoute(
            path: DriverRoutes.alerts,
            builder: (context, state) => const NotificationsDriverScreen(),
          ),
          GoRoute(
            path: DriverRoutes.profile,
            builder: (context, state) => const DriverProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: DriverRoutes.preTrip,
        builder: (context, state) => DriverPreTripChecklistScreen(
          tripId: state.pathParameters['tripId'] ?? '',
        ),
      ),
      GoRoute(
        path: DriverRoutes.endTrip,
        builder: (context, state) => DriverEndTripChecklistScreen(
          tripId: state.pathParameters['tripId'] ?? '',
        ),
      ),
    ],
  );
});
