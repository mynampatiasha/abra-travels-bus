import 'package:shared_permissions/shared_permissions.dart';

/// Locations of the bus owner portal.
abstract final class PortalRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';

  /// The page the invitation email leads to; reachable without signing in.
  static const acceptInvite = '/accept-invite';
  static const home = '/';
  static const dashboard = '/dashboard';
  static const onboardingPrefix = '/onboarding/';

  /// Places: ask Abra for a place, see the places the operator can use.
  static const places = '/places';

  /// The documents of the company or of one bus.
  static String onboardingOf(String id) => '$onboardingPrefix$id';

  /// Query parameter that carries where to return to after the session
  /// check or sign-in.
  static const fromParameter = 'from';

  /// The permission needed to open each section. The backend enforces the
  /// same permission on its API; this only decides what is offered.
  static const Map<String, String> requiredPermission = <String, String>{
    dashboard: PermissionKeys.documentsView,
    places: PermissionKeys.routesRead,
  };

  static const List<String> sections = <String>[dashboard, places];

  /// The section a path belongs to: a document file belongs to the dashboard.
  static String sectionOf(String path) =>
      path.startsWith(onboardingPrefix) ? dashboard : path;
}
