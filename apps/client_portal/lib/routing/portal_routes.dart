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
  static String onboardingOf(String id) => '';
  static String busKycOf(String busId) => '';

  static const fromParameter = 'from';
}
