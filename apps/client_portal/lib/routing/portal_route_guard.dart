import '../app/providers.dart';
import 'portal_routes.dart';

final class PortalRouteGuard {
  const PortalRouteGuard._();

  static String? redirect({
    required AccessState access,
    required String path,
    String? from,
  }) {
    final level = access.level;

    // Waiting for session check or permissions
    if (level == AccessLevel.pending) {
      return path == PortalRoutes.splash ? null : PortalRoutes.splash;
    }

    // Signed out — redirect to sign-in
    if (level == AccessLevel.signedOut) {
      if (path == PortalRoutes.signIn || path == PortalRoutes.acceptInvite) {
        return null;
      }
      if (path == PortalRoutes.splash || path == PortalRoutes.home || path == '/') {
        return PortalRoutes.signIn;
      }
      return '${PortalRoutes.signIn}?${PortalRoutes.fromParameter}=${Uri.encodeComponent(path)}';
    }

    // Gated states: non-staff, MFA setup required, or load failure
    if (level == AccessLevel.notStaff ||
        level == AccessLevel.mfaSetupRequired ||
        level == AccessLevel.failed) {
      return path == PortalRoutes.home ? null : PortalRoutes.home;
    }

    // Signed in and granted — don't stay on splash or sign-in
    if (level == AccessLevel.granted) {
      if (path == PortalRoutes.splash ||
          path == PortalRoutes.signIn ||
          path == PortalRoutes.home ||
          path == '/') {
        final dest = from ?? PortalRoutes.dashboard;
        return (dest == PortalRoutes.splash || dest == PortalRoutes.signIn)
            ? PortalRoutes.dashboard
            : dest;
      }
      return null;
    }

    return null;
  }

  static bool canOpen(AccessState access, String path) =>
      access.level == AccessLevel.granted;
}
