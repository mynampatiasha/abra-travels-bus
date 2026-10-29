import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_permissions/shared_permissions.dart';

import '../bootstrap/app_dependencies.dart';

/// Active theme mode (Light or Dark).
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setMode(ThemeMode mode) {
    state = mode;
  }
}

/// Dynamic badge counts for navigation items matching demo model state.
/// The numbers on the side navigation: what waits for an admin, counted by the
/// server. Keyed by the page the admin is on, so it is read again on every move.
/// Only pages whose backend exists have a number (KYC reviews and place
/// requests); payments, refunds, tickets and SOS get theirs in later phases.
/// A count that cannot be read is simply not shown.
final navBadgeCountsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, currentPath) async {
      final access = ref.watch(accessProvider);
      final client = ref.watch(appDependenciesProvider).apiClient;
      final counts = <String, int>{};
      if (access.can(PermissionKeys.documentsView)) {
        try {
          final response = await client.get(
            'onboarding/submissions',
            query: <String, Object?>{'status': 'PENDING', 'pageSize': 1},
          );
          counts['kyc'] = response.page?.total ?? 0;
        } on Object {
          // No number rather than a wrong one.
        }
      }
      if (access.can(PermissionKeys.catalogueRead)) {
        try {
          final response = await client.get('admin/place-requests/pending-count');
          final data = response.data;
          final pending = data is Map ? data['pending'] : null;
          counts['places'] = pending is num ? pending.toInt() : 0;
        } on Object {
          // No number rather than a wrong one.
        }
      }
      return counts;
    });

/// Overridden in `bootstrap` (and in tests).
final appDependenciesProvider = Provider<AppDependencies>(
  (ref) => throw StateError('appDependenciesProvider was not overridden'),
);

final notificationCenterProvider = Provider<NotificationCenter>(
  (ref) => ref.watch(appDependenciesProvider).notifications,
);

final sessionManagerProvider = Provider<AuthSessionManager>(
  (ref) => ref.watch(appDependenciesProvider).sessionManager,
);

/// Mirror of the shared session manager's state.
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
}

/// Whether the signed-in account may use the management app at all.
enum AccessLevel {
  /// Start-up, or signed in and the permissions are still loading.
  pending,
  signedOut,

  /// Signed in, but not as platform or operator staff (a customer, driver or
  /// partner account). Nothing is shown.
  notStaff,

  /// The account must set up two-step verification first; the server
  /// refuses everything else for this session.
  mfaSetupRequired,

  /// The permissions could not be loaded.
  failed,
  granted,
}

class AccessState {
  const AccessState(
    this.level, {
    this.permissions = PermissionSet.none,
    this.user,
    this.failure,
  });

  final AccessLevel level;

  /// What the user may see. Empty unless [level] is granted.
  final PermissionSet permissions;
  final UserProfile? user;
  final AppFailure? failure;

  /// True when the user works across all operators (platform staff).
  bool get hasPlatformScope => permissions.dataScope.type == DataScopeType.all;

  bool can(String permission) => permissions.hasPermission(permission);
}

/// Loads the permissions whenever a staff user signs in, and forgets them
/// when the session ends. The navigation, the route guard and every action
/// button read this; none of them checks a role name.
final accessProvider = NotifierProvider<AccessController, AccessState>(
  AccessController.new,
);

class AccessController extends Notifier<AccessState> {
  static const _staffTypes = <UserType>{UserType.staff, UserType.operatorStaff};

  PermissionsController get _permissions =>
      ref.read(appDependenciesProvider).permissions;

  @override
  AccessState build() {
    final auth = ref.watch(authStateProvider);
    switch (auth) {
      case AuthUnknown():
        return const AccessState(AccessLevel.pending);
      case AuthSignedOut():
        _permissions.clear();
        return const AccessState(AccessLevel.signedOut);
      case AuthSignedIn(:final user, :final mfaEnrollmentRequired):
        if (!_staffTypes.contains(user.userType)) {
          return AccessState(AccessLevel.notStaff, user: user);
        }
        if (mfaEnrollmentRequired) {
          return AccessState(AccessLevel.mfaSetupRequired, user: user);
        }
        Future<void>.microtask(() => _load(user));
        return AccessState(AccessLevel.pending, user: user);
    }
  }

  Future<void> _load(UserProfile user) async {
    final result = await _permissions.refresh();
    if (!ref.mounted) return;
    state = result.fold(
      onSuccess: (permissions) => AccessState(
        AccessLevel.granted,
        permissions: permissions,
        user: user,
      ),
      onFailure: (failure) => AccessState(
        AccessLevel.failed,
        user: user,
        failure: failure,
      ),
    );
  }

  /// Loads the permissions again (after a failure).
  Future<void> reload() async {
    final user = state.user;
    if (user == null) return;
    state = AccessState(AccessLevel.pending, user: user);
    await _load(user);
  }

}

/// Start-up check of the stored session.
final startupProvider = NotifierProvider<StartupController, AppFailure?>(
  StartupController.new,
);

/// Holds the failure when the stored session could not be checked.
class StartupController extends Notifier<AppFailure?> {
  @override
  AppFailure? build() {
    Future<void>.microtask(restore);
    return null;
  }

  Future<void> restore() async {
    state = null;
    final result = await ref.read(sessionManagerProvider).restore();
    if (!ref.mounted) return;
    state = result.failureOrNull;
  }
}
