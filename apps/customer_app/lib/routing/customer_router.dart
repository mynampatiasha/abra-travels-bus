import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../features/language/language_screen.dart';
import '../features/startup/splash_screen.dart';
import '../features/unavailable/feature_unavailable_screen.dart';
import '../features/unavailable/page_not_found_screen.dart';
import '../l10n/customer_strings.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';
import 'route_guard.dart';

/// The router of the app. Re-evaluates [RouteGuard] whenever the
/// authentication state changes, so a session that ends on the server takes
/// the user to sign-in from wherever they are.
final customerRouterProvider = Provider<GoRouter>((ref) {
  final authChanges = _ChangeSignal();
  ref
    ..listen(authStateProvider, (_, _) => authChanges.notify())
    ..onDispose(authChanges.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authChanges,
    redirect: (context, state) => RouteGuard.redirect(
      auth: ref.read(authStateProvider),
      location: state.uri,
    ),
    errorBuilder: (context, state) => const PageNotFoundScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (context, state) => const LanguageScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          for (final tab in AppShell.tabs)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: tab.path,
                  builder: (context, state) =>
                      FeatureUnavailableBody(titleKey: tab.labelKey),
                  routes: <RouteBase>[
                    if (tab.path == AppRoutes.myTrips)
                      _notBuilt(':id', CustomerStrings.routeMyTripDetailTitle),
                  ],
                ),
              ],
            ),
        ],
      ),
      // Not built yet. Each entry is replaced by its real screen in the
      // milestone that delivers the feature; until then the screen says so.
      _notBuilt(AppRoutes.onboarding, CustomerStrings.routeOnboardingTitle),
      _notBuilt(AppRoutes.login, CustomerStrings.routeLoginTitle),
      _notBuilt(AppRoutes.otp, CustomerStrings.routeOtpTitle),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const FeatureUnavailableScreen(
          titleKey: CustomerStrings.routeSearchTitle,
        ),
        routes: <RouteBase>[
          _notBuilt('results', CustomerStrings.routeSearchResultsTitle),
        ],
      ),
      _notBuilt(AppRoutes.busPattern, CustomerStrings.routeBusTitle),
      _notBuilt(AppRoutes.tripPattern, CustomerStrings.routeTripTitle),
      _notBuilt(AppRoutes.seats, CustomerStrings.routeSeatsTitle),
      _notBuilt(
        AppRoutes.passengerDetails,
        CustomerStrings.routePassengerDetailsTitle,
      ),
      _notBuilt(
        AppRoutes.bookingReview,
        CustomerStrings.routeBookingReviewTitle,
      ),
      _notBuilt(AppRoutes.payment, CustomerStrings.routePaymentTitle),
      _notBuilt(
        AppRoutes.bookingSuccess,
        CustomerStrings.routeBookingSuccessTitle,
      ),
      _notBuilt(AppRoutes.ticketPattern, CustomerStrings.routeTicketTitle),
      _notBuilt(
        AppRoutes.cancelBooking,
        CustomerStrings.routeCancelBookingTitle,
      ),
      _notBuilt(AppRoutes.liveTracking, CustomerStrings.routeLiveTrackingTitle),
      _notBuilt(AppRoutes.womenSafety, CustomerStrings.routeWomenSafetyTitle),
      _notBuilt(AppRoutes.settings, CustomerStrings.routeSettingsTitle),
      _notBuilt(
        AppRoutes.accountDelete,
        CustomerStrings.routeAccountDeleteTitle,
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

GoRoute _notBuilt(String path, String titleKey) => GoRoute(
  path: path,
  builder: (context, state) => FeatureUnavailableScreen(titleKey: titleKey),
);

class _ChangeSignal extends ChangeNotifier {
  void notify() => notifyListeners();
}
