import '../app/providers.dart';
import 'portal_routes.dart';

/// Where a navigation may go. Pure; re-evaluated on every navigation and
/// whenever the access state changes. Not a security control: the backend
/// authorizes every request.
abstract final class PortalRouteGuard {
  /// [from] is where the person was heading before being sent to the start-up
  /// or sign-in screen (the `from` query parameter): it keeps the open page
  /// across a reload and across signing in.
  static String? redirect({
    required AccessState access,
    required String path,
    String? from,
  }) {
    final isInvitation = path == PortalRoutes.acceptInvite;
    switch (access.level) {
      case AccessLevel.signedOut:
        return path == PortalRoutes.signIn || isInvitation
            ? null
            : _remembering(PortalRoutes.signIn, path);
      case AccessLevel.pending:
        // Waiting for the session check or the permissions.
        return path == PortalRoutes.splash || isInvitation
            ? null
            : _remembering(PortalRoutes.splash, path);
      case AccessLevel.notStaff:
      case AccessLevel.mfaSetupRequired:
      case AccessLevel.failed:
        // One explanatory screen; nothing else is reachable.
        return path == PortalRoutes.home ? null : PortalRoutes.home;
      case AccessLevel.granted:
        if (!access.kycApproved &&
            path != '/kyc' &&
            path != '/notifications' &&
            !path.startsWith(PortalRoutes.onboardingPrefix)) {
          return '/kyc';
        }
        if (path == PortalRoutes.splash ||
            path == PortalRoutes.signIn ||
            isInvitation) {
          final remembered = _rememberable(from);
          if (remembered != null && canOpen(access, remembered)) {
            return remembered;
          }
          return PortalRoutes.dashboard;
        }
        if (path == PortalRoutes.home) return PortalRoutes.dashboard;
        return null;
    }
  }

  /// [path] when it is a page worth coming back to; anything else (an outside
  /// address, a made-up path) is never remembered.
  static String? _rememberable(String? path) =>
      path != null &&
          (PortalRoutes.sections.contains(path) ||
              path.startsWith(PortalRoutes.onboardingPrefix))
      ? path
      : null;

  static String _remembering(String location, String path) =>
      _rememberable(path) == null
      ? location
      : Uri(
          path: location,
          queryParameters: <String, String>{PortalRoutes.fromParameter: path},
        ).toString();

  /// Whether the person may open [path]. Unknown paths are not allowed.
  static bool canOpen(AccessState access, String path) {
    final permission =
        PortalRoutes.requiredPermission[PortalRoutes.sectionOf(path)];
    return permission != null && access.can(permission);
  }
}
