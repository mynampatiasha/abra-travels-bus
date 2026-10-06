import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../features/authentication/login_screen.dart';
import '../features/authentication/otp_screen.dart';
import '../features/discovery/screens/city_picker_screen.dart';
import '../features/discovery/screens/search_form.dart';
import '../features/discovery/screens/search_results_screen.dart';
import '../features/discovery/screens/trip_details_screen.dart';
import '../features/language/language_screen.dart';
import '../features/profile/profile_screen.dart';
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
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) => const OtpScreen(),
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
                  builder: (context, state) => switch (tab.path) {
                    AppRoutes.home => const SearchFormView(),
                    AppRoutes.profile => const ProfileScreen(),
                    _ => FeatureUnavailableBody(titleKey: tab.labelKey),
                  },
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
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'results',
            builder: (context, state) => SearchResultsScreen(
              // A new search is a new screen: filters and sorting start over
              key: ValueKey<String>(state.uri.toString()),
              arguments: SearchResultsArguments.tryParse(state.uri),
            ),
          ),
          GoRoute(
            path: 'city',
            builder: (context, state) => CityPickerScreen(
              isOrigin: state.uri.queryParameters['field'] != 'to',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.tripPattern,
        builder: (context, state) =>
            TripDetailsScreen(tripId: state.pathParameters['id'] ?? ''),
      ),
      _notBuilt(AppRoutes.busPattern, CustomerStrings.routeBusTitle),
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
