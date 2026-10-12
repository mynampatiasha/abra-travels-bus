import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';

import '../routing/portal_routes.dart';

/// The failure behind an error thrown by a repository or controller.
/// Anything that is not already an [AppFailure] becomes an
/// [UnexpectedFailure], whose text is never shown to the user.
AppFailure failureOf(Object error) => switch (error) {
  AppFailure() => error,
  AppException(:final failure) => failure,
  _ => UnexpectedFailure(error.runtimeType.toString()),
};

/// The standard way for a screen to show data that is loaded from the
/// backend. Exactly one of three things is on screen:
///
/// - loading: the shared loading view;
/// - failure: the shared failure view for the kind of failure (no
///   connection, timeout, server problem, no access, session ended, ...),
///   with a retry button only when retrying can help and [onRetry] is
///   given;
/// - data: [data].
///
/// Screens therefore never show a blank page or a raw error, and no screen
/// writes its own network error handling.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingLabel,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;

  /// Reloads the data. Usually `() => ref.invalidate(provider)`.
  final VoidCallback? onRetry;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) => switch (value) {
    AsyncData<T>(:final value) => data(context, value),
    AsyncError<T>(:final error) => AbraFailureView(
      failure: failureOf(error),
      onRetry: onRetry,
      onSignIn: () => context.go(PortalRoutes.signIn),
    ),
    _ => AbraLoadingView(label: loadingLabel),
  };
}
