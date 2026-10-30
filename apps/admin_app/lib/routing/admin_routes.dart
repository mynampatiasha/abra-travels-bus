import 'package:shared_permissions/shared_permissions.dart';

/// Locations of the management app matching the 11 demo groups.
abstract final class AdminRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const staffInvitation = '/staff-invitation';
  static const home = '/';

  // 1. Overview
  static const dashboard = '/dashboard';

  // 2. Operators
  static const invitations = '/invitations';
  static const reviews = '/reviews';
  static const operators = '/operators';
  static const driverReports = '/driver-reports';
  static const driverRules = '/driver-rules';

  // 3. Commercial
  static const commission = '/commission';
  static const payout = '/payout';

  // 4. Catalogue
  static const places = '/places';
  static const cities = '/cities';
  static const locations = '/locations';
  static const busTypes = '/bus-types';
  static const documentTypes = '/document-types';
  static const kycConfiguration = '/kyc-configuration';

  // 5. Operations
  static const buses = '/buses';
  static const trips = '/trips';
  static const inventory = '/inventory';
  static const tracking = '/tracking';
  static const routes = '/routes';

  // 6. Sales
  static const bookings = '/bookings';
  static const payments = '/payments';
  static const refunds = '/refunds';
  static const settlements = '/settlements';

  // 7. Customers
  static const customers = '/customers';
  static const tickets = '/tickets';
  static const messages = '/messages';
  static const content = '/content';

  // 8. Marketing
  static const banners = '/banners';
  static const offers = '/offers';
  static const announcements = '/announcements';
  static const popularRoutes = '/popular-routes';

  // 9. Safety
  static const sos = '/sos';
  static const incidents = '/incidents';
  static const safetySettings = '/safety-settings';

  // 10. Insights
  static const reports = '/reports';

  // 11. System
  static const settings = '/settings';
  static const staff = '/staff';
  static const featureFlags = '/feature-flags';
  static const audit = '/audit';
  static const notifications = '/notifications';

  /// One onboarding file of the review queue.
  static String reviewOf(String id) => '$reviews/$id';

  /// One operator (its detail page).
  static String operatorOf(String id) => '$operators/$id';

  /// The section a path belongs to: a review file belongs to Reviews, an
  /// operator's page to Operators.
  static String sectionOf(String path) {
    if (path.startsWith('$reviews/')) return reviews;
    if (path.startsWith('$operators/')) return operators;
    return path;
  }

  /// Query parameter that carries the section to return to after the
  /// session check or sign-in.
  static const fromParameter = 'from';

  /// Routes open to all granted staff members regardless of granular permissions.
  static const Set<String> openToAllStaff = <String>{
    dashboard,
    notifications,
  };

  /// The permission needed to open each management section.
  static const Map<String, String> requiredPermission = <String, String>{
    dashboard: PermissionKeys.catalogueRead,
    invitations: PermissionKeys.operatorsCreate,
    reviews: PermissionKeys.documentsReview,
    operators: PermissionKeys.operatorsRead,
    driverReports: PermissionKeys.operatorsRead,
    driverRules: PermissionKeys.operatorsRead,
    commission: PermissionKeys.commissionsRead,
    payout: PermissionKeys.payoutRead,
    places: PermissionKeys.catalogueRead,
    cities: PermissionKeys.catalogueRead,
    locations: PermissionKeys.routesRead,
    busTypes: PermissionKeys.busesRead,
    documentTypes: PermissionKeys.documentsRead,
    kycConfiguration: PermissionKeys.documentsRead,
    buses: PermissionKeys.busesRead,
    trips: PermissionKeys.tripsRead,
    inventory: PermissionKeys.tripsRead,
    tracking: PermissionKeys.routesRead,
    routes: PermissionKeys.routesRead,
    bookings: PermissionKeys.bookingsRead,
    payments: PermissionKeys.bookingsRead,
    refunds: PermissionKeys.settlementsRead,
    settlements: PermissionKeys.settlementsRead,
    customers: PermissionKeys.customersRead,
    tickets: PermissionKeys.messagesRead,
    messages: PermissionKeys.messagesRead,
    content: PermissionKeys.contentRead,
    banners: PermissionKeys.bannersRead,
    offers: PermissionKeys.bannersRead,
    announcements: PermissionKeys.notificationsManage,
    popularRoutes: PermissionKeys.routesRead,
    sos: PermissionKeys.tripsRead,
    incidents: PermissionKeys.tripsRead,
    safetySettings: PermissionKeys.settingsRead,
    reports: PermissionKeys.reportsRead,
    settings: PermissionKeys.settingsRead,
    staff: PermissionKeys.usersPermissionsRead,
    featureFlags: PermissionKeys.settingsRead,
    audit: PermissionKeys.auditRead,
    notifications: PermissionKeys.notificationsRead,
  };

  /// Sections in display order across the 11 demo groups.
  static const List<String> sections = <String>[
    dashboard,
    invitations,
    reviews,
    operators,
    driverReports,
    driverRules,
    commission,
    payout,
    places,
    cities,
    locations,
    busTypes,
    documentTypes,
    kycConfiguration,
    buses,
    trips,
    inventory,
    tracking,
    routes,
    bookings,
    payments,
    refunds,
    settlements,
    customers,
    tickets,
    messages,
    content,
    banners,
    offers,
    announcements,
    popularRoutes,
    sos,
    incidents,
    safetySettings,
    reports,
    settings,
    staff,
    featureFlags,
    audit,
    notifications,
  ];
}
