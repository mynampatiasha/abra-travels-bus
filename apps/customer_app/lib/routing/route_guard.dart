import 'package:shared_authentication/shared_authentication.dart';

import 'app_routes.dart';

/// Decides where a navigation may go. Pure: the router calls it for every
/// navigation and whenever the authentication state or start-up changes.
///
/// Guests may open every location. A location that needs an account is not
/// redirected; it shows a guest card and the sign-in sheet in place
/// (`SignInRequired`), so the customer lands where they were heading and
/// Back behaves as usual. The guard only:
///
/// - keeps the splash screen until it has played ([splashDone]), then opens
///   the first-launch tour once ([hasSeenOnboarding]), the location that was
///   asked for, the screen of a recent action that waited for sign-in
///   ([pendingReturn]), or Home;
/// - holds a location that needs an account on the splash screen while the
///   stored session is still being checked (public locations open at once:
///   the check continues in the background);
/// - keeps a signed-in user off the sign-in page.
///
/// This decides what is *shown*. It is not a security boundary: the
/// backend authorizes every request on its own.
abstract final class RouteGuard {
  /// The location to go to instead of [location], or null to allow it.
  static String? redirect({
    required AuthState auth,
    required Uri location,
    bool hasSeenOnboarding = true,
    bool splashDone = true,
    String? pendingReturn,
  }) {
    final path = location.path;
    if (path == AppRoutes.otp) {
      return location.replace(path: AppRoutes.login).toString();
    }
    if (path == AppRoutes.splash) {
      if (!splashDone) return null;
      final target = _startTarget(
        location,
        hasSeenOnboarding: hasSeenOnboarding,
        pendingReturn: pendingReturn,
      );
      final targetPath = Uri.parse(target).path;
      // A personal location waits until the session is known.
      if (auth is AuthUnknown && !AppRoutes.isPublic(targetPath)) return null;
      if (auth is AuthSignedIn &&
          AppRoutes.signedOutOnly.contains(targetPath)) {
        return AppRoutes.home;
      }
      return target;
    }
    return switch (auth) {
      AuthUnknown() =>
        AppRoutes.isPublic(path) ? null : _to(AppRoutes.splash, location),
      AuthSignedOut() => null,
      AuthSignedIn() =>
        AppRoutes.signedOutOnly.contains(path)
            ? returnTo(location) ?? AppRoutes.home
            : null,
    };
  }

  static String _startTarget(
    Uri splash, {
    required bool hasSeenOnboarding,
    String? pendingReturn,
  }) {
    final asked = returnTo(splash);
    if (asked != null) return asked;
    if (!hasSeenOnboarding) return AppRoutes.onboarding;
    if (pendingReturn != null && returnTo(_carrying(pendingReturn)) != null) {
      return pendingReturn;
    }
    return AppRoutes.home;
  }

  static Uri _carrying(String location) => Uri(
    path: AppRoutes.splash,
    queryParameters: <String, String>{AppRoutes.returnToParameter: location},
  );

  /// The location stored in the `from` parameter, if it is safe to use: an
  /// in-app path that is not itself a start-up or sign-in screen.
  static String? returnTo(Uri location) {
    final raw = location.queryParameters[AppRoutes.returnToParameter];
    if (raw == null || !raw.startsWith('/') || raw.startsWith('//')) {
      return null;
    }
    if (raw.contains(r'\')) return null;
    final target = Uri.tryParse(raw);
    if (target == null || target.hasScheme || target.hasAuthority) return null;
    final path = target.path;
    if (path == AppRoutes.splash || AppRoutes.signedOutOnly.contains(path)) {
      return null;
    }
    return raw;
  }

  /// [destination], remembering [from] (or the location [from] was itself
  /// remembering).
  static String _to(String destination, Uri from) {
    final target = returnTo(from) ?? from.toString();
    return Uri(
      path: destination,
      queryParameters: <String, String>{AppRoutes.returnToParameter: target},
    ).toString();
  }
}
