import 'package:shared_models/shared_models.dart';

import '../app/providers.dart';
import 'admin_routes.dart';

/// Where a navigation may go. Pure; re-evaluated on every navigation and
/// whenever the access state changes. Not a security control: the backend
/// authorizes every request.
abstract final class AdminRouteGuard {
  /// [from] is the section the user was heading to before being sent to the
  /// start-up or sign-in screen (the `from` query parameter). It is what
  /// keeps the open section across a page reload: the address still names
  /// the section, the session check passes through `/splash`, and the user
  /// lands where they were.
  static String? redirect({
    required AccessState access,
    required String path,
    String? from,
  }) {
    switch (access.level) {
      case AccessLevel.signedOut:
        return path == AdminRoutes.signIn
            ? null
            : _remembering(AdminRoutes.signIn, _sectionOf(path) ?? from);
      case AccessLevel.pending:
        // Waiting for the session check or the permissions.
        return path == AdminRoutes.splash
            ? null
            : _remembering(AdminRoutes.splash, _sectionOf(path) ?? from);
      case AccessLevel.notStaff:
      case AccessLevel.mfaSetupRequired:
      case AccessLevel.failed:
        // One explanatory screen; no management screen is reachable.
        return path == AdminRoutes.home ? null : AdminRoutes.home;
      case AccessLevel.granted:
        if (path == AdminRoutes.splash || path == AdminRoutes.signIn) {
          final remembered = _sectionOf(from);
          if (remembered != null && canOpen(access, remembered)) {
            return remembered;
          }
          return firstSection(access) ?? AdminRoutes.home;
        }
        if (path == AdminRoutes.home) return firstSection(access);
        return null;
    }
  }

  /// [path] when it is one of the sections, otherwise null. Anything else
  /// (an outside address, a made-up path) is never remembered.
  static String? _sectionOf(String? path) =>
      AdminRoutes.sections.contains(path) ? path : null;

  static String _remembering(String location, String? section) =>
      _sectionOf(section) == null
      ? location
      : Uri(
          path: location,
          queryParameters: <String, String>{
            AdminRoutes.fromParameter: section!,
          },
        ).toString();

  /// The first section the user may open, or null when there is none.
  static String? firstSection(AccessState access) {
    for (final section in AdminRoutes.sections) {
      if (canOpen(access, section)) return section;
    }
    return null;
  }

  /// Whether the user may open [path]. Unknown paths are not allowed.
  static bool canOpen(AccessState access, String path) {
    if ((AdminRoutes.sectionOf(path) == AdminRoutes.kycConfiguration ||
            AdminRoutes.sectionOf(path) == AdminRoutes.customers) &&
        access.user?.userType != UserType.staff) {
      return false;
    }
    final permission =
        AdminRoutes.requiredPermission[AdminRoutes.sectionOf(path)];
    return permission != null && access.can(permission);
  }
}
