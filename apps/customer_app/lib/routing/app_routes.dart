/// Every location of the customer app. Screens navigate with these
/// constants and helpers, never with string literals.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';

  /// The code step used to be its own location; it is now a step inside
  /// sign-in. Old links lead to [login].
  static const otp = '/otp';
  static const language = '/language';

  /// [language] as the last step of the first launch: shows "Continue".
  static const languageFirstLaunch = '/language?onboarding=1';

  // Tabs of the shell.
  static const home = '/home';
  static const myTrips = '/my-trips';
  static const support = '/support';
  static const profile = '/profile';

  // Inside the tabs.
  static const myTripPattern = '/my-trips/:id';
  static const supportContact = '/support/contact';
  static const profileEdit = '/profile/edit';
  static const notificationSettings = '/profile/notifications';
  static const messagesArchive = '/profile/messages';

  // Information pages (open to everyone).
  static const terms = '/terms';
  static const privacy = '/privacy';
  static const about = '/about';

  static const search = '/search';
  static const searchResults = '/search/results';
  static const cityPicker = '/search/city';
  static const busPattern = '/bus/:id';
  static const tripPattern = '/trip/:id';
  static const tripSeatsPattern = '/trip/:id/seats';
  static const tripPointsPattern = '/trip/:id/points';
  static const tripPassengersPattern = '/trip/:id/passengers';
  static const tripReviewPattern = '/trip/:id/review';
  static const tripPaymentPattern = '/trip/:id/payment';
  static const bookingConfirmedPattern = '/booking/:id/confirmed';
  static const tripHoldExpiredPattern = '/trip/:id/hold-expired';
  static const seats = '/seats';
  static const passengerDetails = '/passenger-details';
  static const bookingReview = '/booking-review';
  static const payment = '/payment';
  static const bookingSuccess = '/booking-success';
  static const ticketPattern = '/ticket/:id';
  static const cancelBooking = '/cancel-booking';
  static const liveTracking = '/live-tracking';
  static const womenSafety = '/women-safety';
  static const notifications = '/notifications';
  static const offers = '/offers';
  static const settings = '/settings';
  static const accountDelete = '/account-delete';

  static String bus(String id) => '/bus/${Uri.encodeComponent(id)}';
  static String trip(String id) => '/trip/${Uri.encodeComponent(id)}';
  static String tripSeats(String id) => '${trip(id)}/seats';
  static String tripPoints(String id) => '${trip(id)}/points';
  static String tripPassengers(String id) => '${trip(id)}/passengers';
  static String tripReview(String id) => '${trip(id)}/review';
  static String tripPayment(String id) => '${trip(id)}/payment';
  static String bookingConfirmed(String id) =>
      '/booking/${Uri.encodeComponent(id)}/confirmed';
  static String tripHoldExpired(String id) => '${trip(id)}/hold-expired';

  /// The results of a search. City names travel with the ids so the screen
  /// can show its heading before (and without) any result.
  static String searchResultsFor({
    required String fromId,
    required String fromName,
    required String toId,
    required String toName,
    required String date,
  }) => Uri(
    path: searchResults,
    queryParameters: <String, String>{
      'origin': fromId,
      'originName': fromName,
      'destination': toId,
      'destinationName': toName,
      'date': date,
    },
  ).toString();
  static String ticket(String id) => '/ticket/${Uri.encodeComponent(id)}';
  static String myTrip(String id) => '/my-trips/${Uri.encodeComponent(id)}';
  static String myTripCancel(String id) => '${myTrip(id)}/cancel';
  static String myTripRefund(String id) => '${myTrip(id)}/refund';
  static String myTripTrack(String id) => '${myTrip(id)}/track';
  static String myTripSafety(String id) => '${myTrip(id)}/safety';
  static String myTripShare(String id) => '${myTrip(id)}/share';

  /// Name of the query parameter that carries the location to return to
  /// after start-up or sign-in.
  static const returnToParameter = 'from';

  /// Locations that make sense only while signed out. A signed-in user is
  /// sent on to the app.
  static const Set<String> signedOutOnly = <String>{login, otp};

  /// Locations open to everyone, signed in or not. Guests can browse
  /// everything up to booking; the personal tabs (My trips, Profile) are
  /// open and show a guest card. **A location that is not listed here needs
  /// an account**, including ones added later: the router shows the guest
  /// card and the sign-in sheet in its place.
  static const Set<String> public = <String>{
    splash,
    onboarding,
    language,
    home,
    myTrips,
    support,
    profile,
    terms,
    privacy,
    about,
    search,
    searchResults,
    cityPicker,
    offers,
    ...signedOutOnly,
  };

  /// A trip and its seat map are open to guests (they can look and choose);
  /// everything after the seats needs an account.
  static bool isPublic(String path) =>
      public.contains(path) || _isPublicTripPath(path);

  static bool _isPublicTripPath(String path) {
    const prefix = '/trip/';
    if (!path.startsWith(prefix)) return false;
    final parts = path.substring(prefix.length).split('/');
    if (parts.first.isEmpty) return false;
    return parts.length == 1 || (parts.length == 2 && parts[1] == 'seats');
  }
}
