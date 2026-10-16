import 'package:shared_permissions/shared_permissions.dart';

abstract final class PortalRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const acceptInvite = '/accept-invite';
  static const home = '/';

  // Main sections
  static const dashboard = '/dashboard';
  static const kycVerification = '/kyc-verification';
  static const companyProfile = '/company-profile';
  static const buses = '/buses';
  static const seatLayouts = '/seat-layouts';
  static const crew = '/crew';
  static const driverReports = '/driver-reports';
  static const driverRules = '/driver-rules';
  static const routes = '/routes';
  static const places = '/places';
  static const fares = '/fares';
  static const schedules = '/schedules';
  static const trips = '/trips';
  static const bookings = '/bookings';
  static const offers = '/offers';
  static const earnings = '/earnings';
  static const commission = '/commission';
  static const liveTracking = '/live-tracking';
  static const notifications = '/notifications';
  static const staffRoles = '/staff-roles';

  // Legacy
  static const company = '/company';
  static const onboardingPrefix = '/onboarding/';
  static const busKycPrefix = '/bus-kyc/';
  static String onboardingOf(String id) => '$onboardingPrefix$id';
  static String busKycOf(String busId) => '$busKycPrefix$busId';

  static const fromParameter = 'from';

  static const Map<String, String> requiredPermission = <String, String>{
    dashboard: PermissionKeys.documentsView,
    places: PermissionKeys.routesRead,
    company: PermissionKeys.operatorsRead,
    companyProfile: PermissionKeys.operatorsRead,
    kycVerification: PermissionKeys.documentsView,
  };

  static const List<String> sections = <String>[
    dashboard,
    places,
    company,
    companyProfile,
    kycVerification,
  ];

  static String sectionOf(String path) =>
      path.startsWith(onboardingPrefix) || path.startsWith(busKycPrefix)
          ? dashboard
          : path;
}
