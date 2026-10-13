import 'package:shared_permissions/shared_permissions.dart';

/// Locations of the management app.
abstract final class AdminRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const home = '/';
  static const cities = '/cities';
  static const busTypes = '/bus-types';
  static const documentTypes = '/document-types';
  static const kycConfiguration = '/kyc-configuration';
  static const customers = '/customers';
  static const settings = '/settings';
  static const invitations = '/invitations';
  static const reviews = '/reviews';

  /// One onboarding file of the review queue.
  static String reviewOf(String id) => '$reviews/$id';

  /// The section a path belongs to: a review file belongs to Reviews.
  static String sectionOf(String path) =>
      path.startsWith('$reviews/') ? reviews : path;
  static const operators = '/operators';
  static const locations = '/locations';
  static const buses = '/buses';
  static const routes = '/routes';
  static const trips = '/trips';
  static const banners = '/banners';

  /// Cities and places (demo page `places`): Places, Cities and Operator
  /// requests in one page. `/cities` and `/locations` still open on their own.
  static const places = '/places';

  /// Query parameter that carries the section to return to after the
  /// session check or sign-in.
  static const fromParameter = 'from';

  /// The permission needed to open each management section. The backend
  /// enforces the same permission on the section's API; this map only
  /// decides what is offered.
  static const Map<String, String> requiredPermission = <String, String>{
    cities: PermissionKeys.catalogueRead,
    busTypes: PermissionKeys.busesRead,
    documentTypes: PermissionKeys.documentsRead,
    kycConfiguration: PermissionKeys.documentsRead,
    customers: PermissionKeys.usersRead,
    settings: PermissionKeys.settingsRead,
    invitations: PermissionKeys.operatorsCreate,
    reviews: PermissionKeys.documentsReview,
    operators: PermissionKeys.operatorsRead,
    locations: PermissionKeys.routesRead,
    buses: PermissionKeys.busesRead,
    routes: PermissionKeys.routesRead,
    trips: PermissionKeys.tripsRead,
    banners: PermissionKeys.bannersRead,
    places: PermissionKeys.catalogueRead,
  };

  /// Sections in the order they are listed.
  static const List<String> sections = <String>[
    trips,
    buses,
    routes,
    locations,
    operators,
    invitations,
    reviews,
    customers,
    places,
    cities,
    busTypes,
    documentTypes,
    kycConfiguration,
    banners,
    settings,
  ];
}
