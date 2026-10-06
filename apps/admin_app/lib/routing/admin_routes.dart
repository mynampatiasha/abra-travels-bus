import 'package:shared_permissions/shared_permissions.dart';

/// Locations of the management app.
abstract final class AdminRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const home = '/';
  static const cities = '/cities';
  static const busTypes = '/bus-types';
  static const operators = '/operators';
  static const locations = '/locations';
  static const buses = '/buses';
  static const routes = '/routes';
  static const trips = '/trips';

  /// The permission needed to open each management section. The backend
  /// enforces the same permission on the section's API; this map only
  /// decides what is offered.
  static const Map<String, String> requiredPermission = <String, String>{
    cities: PermissionKeys.catalogueRead,
    busTypes: PermissionKeys.busesRead,
    operators: PermissionKeys.operatorsRead,
    locations: PermissionKeys.routesRead,
    buses: PermissionKeys.busesRead,
    routes: PermissionKeys.routesRead,
    trips: PermissionKeys.tripsRead,
  };

  /// Sections in the order they are listed.
  static const List<String> sections = <String>[
    trips,
    buses,
    routes,
    locations,
    operators,
    cities,
    busTypes,
  ];
}
