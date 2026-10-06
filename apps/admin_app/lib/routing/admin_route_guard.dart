import '../app/providers.dart';
import 'admin_routes.dart';

/// Where a navigation may go. Pure; re-evaluated on every navigation and
/// whenever the access state changes. Not a security control: the backend
/// authorizes every request.
abstract final class AdminRouteGuard {
  static String? redirect({required AccessState access, required String path}) {
    switch (access.level) {
      case AccessLevel.signedOut:
        return path == AdminRoutes.signIn ? null : AdminRoutes.signIn;
      case AccessLevel.pending:
        // Waiting for the session check or the permissions.
        return path == AdminRoutes.splash ? null : AdminRoutes.splash;
      case AccessLevel.notStaff:
      case AccessLevel.mfaSetupRequired:
      case AccessLevel.failed:
        // One explanatory screen; no management screen is reachable.
        return path == AdminRoutes.home ? null : AdminRoutes.home;
      case AccessLevel.granted:
        if (path == AdminRoutes.splash || path == AdminRoutes.signIn) {
          return firstSection(access) ?? AdminRoutes.home;
        }
        if (path == AdminRoutes.home) return firstSection(access);
        return null;
    }
  }

  /// The first section the user may open, or null when there is none.
  static String? firstSection(AccessState access) {
    for (final section in AdminRoutes.sections) {
      if (access.can(AdminRoutes.requiredPermission[section]!)) return section;
    }
    return null;
  }

  /// Whether the user may open [path]. Unknown paths are not allowed.
  static bool canOpen(AccessState access, String path) {
    final permission = AdminRoutes.requiredPermission[path];
    return permission != null && access.can(permission);
  }
}
