import 'package:go_router/go_router.dart';

/// The location of the page on top, including a page opened with `push`
/// (`currentConfiguration.uri` names only the location below such pages).
/// Used to come back to exactly this screen after sign-in.
Uri topLocationOf(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  if (configuration.matches.isEmpty) return configuration.uri;
  final top = configuration.matches.last;
  return top is ImperativeRouteMatch ? top.matches.uri : configuration.uri;
}
