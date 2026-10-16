abstract final class DriverRoutes {
  static const signIn = '/sign-in';
  static const home = '/home';
  static const trip = '/trip';
  static const reports = '/reports';
  static const alerts = '/alerts';
  static const profile = '/profile';
  static const preTrip = '/pre-trip/:tripId';
  static const endTrip = '/end-trip/:tripId';
  static const reportForm = '/report-form/:typeId';

  static String preTripPath(String tripId) => '/pre-trip/$tripId';
  static String endTripPath(String tripId) => '/end-trip/$tripId';
  static String reportFormPath(String typeId) => '/report-form/$typeId';
}
