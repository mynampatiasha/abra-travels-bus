import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../features/authentication/gate/sign_in_intent.dart';
import '../features/authentication/gate/sign_in_required.dart';
import '../features/authentication/login_screen.dart';
import '../features/booking/boarding_dropping_screen.dart';
import '../features/booking/passenger_review_screen.dart';
import '../features/booking/payment_screen.dart';
import '../features/booking/seat_selection_screen.dart';
import '../features/booking/ticket_screen.dart';
import '../features/discovery/screens/city_picker_screen.dart';
import '../features/discovery/screens/search_form.dart';
import '../features/discovery/screens/search_results_screen.dart';
import '../features/discovery/screens/trip_details_screen.dart';
import '../features/info/info_page.dart';
import '../features/language/language_screen.dart';
import '../features/my_trips/booking_details_screen.dart';
import '../features/my_trips/cancel_booking_screen.dart';
import '../features/my_trips/my_trips_screen.dart';
import '../features/my_trips/refund_status_screen.dart';
import '../features/notifications/notifications_offers_screen.dart';
import '../features/onboarding/first_launch.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/startup/splash_screen.dart';
import '../features/support/support_screen.dart';
import '../features/tracking/live_tracking_screen.dart';
import '../features/tracking/trip_sharing_screen.dart';
import '../features/tracking/women_safety_screen.dart';
import '../features/unavailable/feature_unavailable_screen.dart';
import '../features/unavailable/page_not_found_screen.dart';
import '../l10n/customer_strings.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';
import 'route_guard.dart';

/// The router of the app. Re-evaluates [RouteGuard] whenever the
/// authentication state, the splash screen or the first-launch tour change.
final customerRouterProvider = Provider<GoRouter>((ref) {
  final changes = _ChangeSignal();
  ref
    ..listen(authStateProvider, (_, _) => changes.notify())
    ..listen(splashDoneProvider, (_, _) => changes.notify())
    ..listen(welcomeSeenProvider, (_, _) => changes.notify())
    ..onDispose(changes.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: changes,
    redirect: (context, state) => RouteGuard.redirect(
      auth: ref.read(authStateProvider),
      location: state.uri,
      hasSeenOnboarding: ref.read(welcomeSeenProvider),
      splashDone: ref.read(splashDoneProvider),
      pendingReturn: ref
          .read(pendingSignInIntentProvider.notifier)
          .fresh
          ?.returnLocation,
    ),
    errorBuilder: (context, state) => const PageNotFoundScreen(),
    routes: <RouteBase>[
      _page(AppRoutes.splash, (_) => const SplashScreen()),
      _page(AppRoutes.onboarding, (_) => const OnboardingScreen()),
      _page(
        AppRoutes.language,
        (state) => LanguageScreen(
          isFirstLaunch: state.uri.queryParameters['onboarding'] == '1',
        ),
      ),
      _page(AppRoutes.login, (_) => const LoginScreen()),
      // Kept so that old links still resolve; the guard sends it to /login.
      _page(AppRoutes.otp, (_) => const LoginScreen()),
      _page(AppRoutes.terms, (_) => const InfoPage(kind: InfoPageKind.terms)),
      _page(
        AppRoutes.privacy,
        (_) => const InfoPage(kind: InfoPageKind.privacy),
      ),
      _page(AppRoutes.about, (_) => const InfoPage(kind: InfoPageKind.about)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              _page(AppRoutes.home, (_) => const SearchFormView()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              _page(AppRoutes.myTrips, (_) => const MyTripsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              _page(
                AppRoutes.support,
                (_) => const SupportScreen(),
                routes: <RouteBase>[
                  _notBuilt(
                    'contact',
                    CustomerStrings.routeSupportContactTitle,
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              _page(
                AppRoutes.profile,
                (_) => const ProfileScreen(),
                routes: <RouteBase>[
                  _notBuilt('edit', CustomerStrings.routeProfileEditTitle),
                  _notBuilt(
                    'notifications',
                    CustomerStrings.routeNotificationSettingsTitle,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _page(
        AppRoutes.search,
        (_) => const SearchScreen(),
        routes: <RouteBase>[
          _page(
            'results',
            (state) => SearchResultsScreen(
              // A new search is a new screen: filters and sorting start over
              key: ValueKey<String>(state.uri.toString()),
              arguments: SearchResultsArguments.tryParse(state.uri),
            ),
          ),
          _page(
            'city',
            (state) => CityPickerScreen(
              isOrigin: state.uri.queryParameters['field'] != 'to',
            ),
          ),
        ],
      ),
      _page(
        AppRoutes.tripPattern,
        (state) => TripDetailsScreen(tripId: state.pathParameters['id'] ?? ''),
        routes: <RouteBase>[
          // Open to guests: they can look at the seats and choose some;
          // "Continue" asks them to sign in.
          _page(
            'seats',
            (state) =>
                SeatSelectionScreen(tripId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.routeSeatsTitle,
          ),
          _page(
            'points',
            (state) => BoardingDroppingScreen(
              tripId: state.pathParameters['id'] ?? '',
            ),
            titleKey: CustomerStrings.pointsTitle,
          ),
          _page(
            'passengers',
            (state) => PassengerDetailsScreen(
              tripId: state.pathParameters['id'] ?? '',
            ),
            titleKey: CustomerStrings.passengerTitle,
          ),
          _page(
            'review',
            (state) =>
                BookingReviewScreen(tripId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.reviewTitle,
          ),
          _page(
            'payment',
            (state) => PaymentScreen(tripId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.payTitle,
          ),
          _page(
            'hold-expired',
            (state) =>
                HoldExpiredScreen(tripId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.holdExpiredBarTitle,
          ),
        ],
      ),
      // Not built yet. Each entry is replaced by its real screen in the
      // milestone that delivers the feature; until then the screen says so.
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
      // A booking and what can be done with it. Above the tabs, so it has
      // its own bar and Back returns to the list.
      _page(
        AppRoutes.myTripPattern,
        (state) =>
            BookingDetailsScreen(bookingId: state.pathParameters['id'] ?? ''),
        titleKey: CustomerStrings.routeMyTripDetailTitle,
        routes: <RouteBase>[
          _page(
            'cancel',
            (state) => CancelBookingScreen(
              bookingId: state.pathParameters['id'] ?? '',
            ),
            titleKey: CustomerStrings.cancelTitle,
          ),
          _page(
            'track',
            (state) =>
                LiveTrackingScreen(bookingId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.trackTitle,
          ),
          _page(
            'safety',
            (state) =>
                WomenSafetyScreen(bookingId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.sosTitle,
          ),
          _page(
            'share',
            (state) =>
                TripSharingScreen(bookingId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.shareTitle,
          ),
          _page(
            'refund',
            (state) =>
                RefundStatusScreen(bookingId: state.pathParameters['id'] ?? ''),
            titleKey: CustomerStrings.refundTitle,
          ),
        ],
      ),
      _page(
        AppRoutes.ticketPattern,
        (state) => TicketScreen(bookingId: state.pathParameters['id'] ?? ''),
        titleKey: CustomerStrings.routeTicketTitle,
      ),
      _page(
        AppRoutes.bookingConfirmedPattern,
        (state) =>
            BookingConfirmedScreen(bookingId: state.pathParameters['id'] ?? ''),
        titleKey: CustomerStrings.ticketConfirmedTitle,
      ),
      _notBuilt(
        AppRoutes.cancelBooking,
        CustomerStrings.routeCancelBookingTitle,
      ),
      _notBuilt(AppRoutes.liveTracking, CustomerStrings.routeLiveTrackingTitle),
      _notBuilt(AppRoutes.womenSafety, CustomerStrings.routeWomenSafetyTitle),
      _page(AppRoutes.notifications, (_) => const NotificationsScreen()),
      // Offers are open to guests.
      _page(AppRoutes.offers, (_) => const OffersScreen()),
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

/// Every location is built through here: one that is not public is wrapped
/// in [SignInRequired], so a location added later needs an account unless
/// it is listed in [AppRoutes.public].
GoRoute _page(
  String path,
  Widget Function(GoRouterState state) builder, {
  List<RouteBase> routes = const <RouteBase>[],
  String? titleKey,
}) => GoRoute(
  path: path,
  routes: routes,
  builder: (context, state) {
    final screen = builder(state);
    if (AppRoutes.isPublic(state.uri.path)) return screen;
    return SignInRequired(
      location: state.uri.toString(),
      titleKey: titleKey,
      child: screen,
    );
  },
);

GoRoute _notBuilt(String path, String titleKey) => _page(
  path,
  (_) => FeatureUnavailableScreen(titleKey: titleKey),
  titleKey: titleKey,
);

class _ChangeSignal extends ChangeNotifier {
  void notify() => notifyListeners();
}
