import 'package:shared_authentication/shared_authentication.dart';

import 'app_routes.dart';

/// Decides where a navigation may go, given who is signed in. Pure: the
/// router calls it for every navigation and whenever the authentication
/// state changes (sign-in, sign-out, session ended by the server).
///
/// This protects screens from being *shown*. It is not a security
/// boundary: the backend authorizes every request on its own.
abstract final class RouteGuard {
  /// The location to go to instead of [location], or null to allow it.
  static String? redirect({required AuthState auth, required Uri location}) {
    final path = location.path;
    return switch (auth) {
      // The stored session is still being checked: wait on the splash
      // screen and remember where the user was heading.
      AuthUnknown() =>
        path == AppRoutes.splash
            ? null
            : _withReturnTo(AppRoutes.splash, location),
      AuthSignedOut() => _signedOut(path, location),
      AuthSignedIn() => _signedIn(path, location),
    };
  }

  static String? _signedOut(String path, Uri location) {
    if (path == AppRoutes.splash) {
      final target = returnTo(location);
      // Guests start on the home screen: looking for buses needs no account.
      if (target == null) return AppRoutes.home;
      if (AppRoutes.isPublic(Uri.parse(target).path)) return target;
      return _to(AppRoutes.login, returnTo: target);
    }
    if (AppRoutes.isPublic(path)) return null;
    return _withReturnTo(AppRoutes.login, location);
  }

  static String? _signedIn(String path, Uri location) {
    if (path == AppRoutes.splash || AppRoutes.signedOutOnly.contains(path)) {
      return returnTo(location) ?? AppRoutes.home;
    }
    return null;
  }

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
  /// remembering) when that is worth returning to.
  static String _withReturnTo(String destination, Uri from) {
    final path = from.path;
    final isReturnable =
        path != AppRoutes.splash &&
        path != AppRoutes.home &&
        !AppRoutes.signedOutOnly.contains(path);
    final target = returnTo(from) ?? (isReturnable ? from.toString() : null);
    return target == null ? destination : _to(destination, returnTo: target);
  }

  static String _to(String destination, {required String returnTo}) => Uri(
    path: destination,
    queryParameters: <String, String>{AppRoutes.returnToParameter: returnTo},
  ).toString();
}
