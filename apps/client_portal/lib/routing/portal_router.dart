import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../app/providers.dart';
import '../features/accept_invite/accept_invite_screen.dart';
import '../features/auth/access_gate_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/kyc/kyc_client_manage_screen.dart';
import '../features/notifications/client_notification_screen.dart';
import '../features/onboarding/client_kyc_based_screen.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/places/places_client_manage_screen.dart';
import '../shell/portal_shell.dart';
import 'portal_route_guard.dart';
import 'portal_routes.dart';

final portalRouterProvider = Provider<GoRouter>((ref) {
  final accessChanges = _ChangeSignal();
  ref
    ..listen(accessProvider, (_, _) => accessChanges.notify())
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
            builder: (context, state) => const ClientKycBasedScreen(),
          ),
          GoRoute(
            path: PortalRoutes.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: PortalRoutes.places,
            builder: (context, state) => Consumer(
              builder: (context, ref, _) =>
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
              builder: (context, ref, _) =>
                  PortalRouteGuard.canOpen(
                    ref.watch(accessProvider),
                    PortalRoutes.company,
                  )
                  ? const KycClientManageScreen()
                  : const AbraStateView(kind: AbraStateKind.forbidden),
            ),
          ),
          GoRoute(
            path: '${PortalRoutes.onboardingPrefix}:id',
            builder: (context, state) =>
                OnboardingPage(id: state.pathParameters['id']!),
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
