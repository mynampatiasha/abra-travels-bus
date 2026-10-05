/// Every location of the customer app. Screens navigate with these
/// constants and helpers, never with string literals.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/otp';
  static const language = '/language';

  // Tabs of the signed-in shell.
  static const home = '/home';
  static const myTrips = '/my-trips';
  static const support = '/support';
  static const profile = '/profile';

  static const search = '/search';
  static const searchResults = '/search/results';
  static const busPattern = '/bus/:id';
  static const tripPattern = '/trip/:id';
  static const seats = '/seats';
  static const passengerDetails = '/passenger-details';
  static const bookingReview = '/booking-review';
  static const payment = '/payment';
  static const bookingSuccess = '/booking-success';
  static const ticketPattern = '/ticket/:id';
  static const myTripPattern = '/my-trips/:id';
  static const cancelBooking = '/cancel-booking';
  static const liveTracking = '/live-tracking';
  static const womenSafety = '/women-safety';
  static const settings = '/settings';
  static const accountDelete = '/account-delete';

  static String bus(String id) => '/bus/${Uri.encodeComponent(id)}';
  static String trip(String id) => '/trip/${Uri.encodeComponent(id)}';
  static String ticket(String id) => '/ticket/${Uri.encodeComponent(id)}';
  static String myTrip(String id) => '/my-trips/${Uri.encodeComponent(id)}';

  /// Name of the query parameter that carries the location to return to
  /// after start-up or sign-in.
  static const returnToParameter = 'from';

  /// Locations that make sense only while signed out. A signed-in user is
  /// sent on to the app.
  static const Set<String> signedOutOnly = <String>{onboarding, login, otp};

  /// Locations open to everyone. **Every other location requires a signed-in
  /// user**: a new route is protected unless it is added here on purpose.
  static const Set<String> public = <String>{
    splash,
    language,
    ...signedOutOnly,
  };

  static bool isPublic(String path) => public.contains(path);
}
