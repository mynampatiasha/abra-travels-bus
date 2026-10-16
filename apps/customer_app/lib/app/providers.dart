import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';

import '../bootstrap/app_dependencies.dart';

/// The services created at start-up. Overridden in `bootstrap` (and in
/// tests); reading it without an override is a programming error.
final appDependenciesProvider = Provider<AppDependencies>(
  (ref) => throw StateError('appDependenciesProvider was not overridden'),
);

final sessionManagerProvider = Provider<AuthSessionManager>(
  (ref) => ref.watch(appDependenciesProvider).sessionManager,
);

/// The authentication state reported by the shared session manager. The
/// manager is the single owner of that state; this only mirrors it for
/// widgets and the router.
final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final manager = ref.watch(sessionManagerProvider);
    final subscription = manager.states.listen((next) => state = next);
    ref.onDispose(subscription.cancel);
    return manager.state;
  }

  void signInDemo(UserProfile user) {
    state = AuthSignedIn(
      user: user,
      sessionId: 'sess-${user.id}',
      mfaEnrollmentRequired: false,
    );
  }

  void signOut() {
    state = const AuthSignedOut();
  }
}

/// Start-up check of the stored session.
final startupControllerProvider =
    NotifierProvider<StartupController, StartupState>(StartupController.new);

/// [failure] is set when the stored session could not be checked (no
/// connection, server unavailable). The session is kept; the user can retry.
class StartupState {
  const StartupState.checking() : isChecking = true, failure = null;
  const StartupState.failed(AppFailure this.failure) : isChecking = false;
  const StartupState.done() : isChecking = false, failure = null;

  final bool isChecking;
  final AppFailure? failure;
}

class StartupController extends Notifier<StartupState> {
  @override
  StartupState build() {
    Future<void>.microtask(restoreSession);
    return const StartupState.checking();
  }

  /// Asks the server whether the stored session is still valid. The
  /// result arrives through [authStateProvider]; only a failure to reach
  /// the server is kept here.
  Future<void> restoreSession() async {
    state = const StartupState.checking();
    final result = await ref.read(sessionManagerProvider).restore();
    if (!ref.mounted) return;
    state = result.fold(
      onSuccess: (_) => const StartupState.done(),
      onFailure: StartupState.failed,
    );
  }
}
