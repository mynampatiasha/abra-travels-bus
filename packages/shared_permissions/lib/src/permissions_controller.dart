import 'dart:async';

import 'package:shared_core/shared_core.dart';

import 'permission_set.dart';
import 'permissions_repository.dart';

/// Holds the signed-in user's [PermissionSet] for the UI.
///
/// Load it after sign-in, [clear] it on sign-out, and [refresh] it when the
/// server reports that access changed (`PERMISSIONS_CHANGED` is handled by
/// the API client, which refreshes the session; the app then reloads the
/// permissions). Until loaded, and whenever loading fails, the set is
/// [PermissionSet.none]: the UI shows less, never more.
class PermissionsController {
  PermissionsController(this._repository);

  final PermissionsRepository _repository;
  final StreamController<PermissionSet> _changes =
      StreamController<PermissionSet>.broadcast();
  PermissionSet _current = PermissionSet.none;

  PermissionSet get current => _current;

  /// Every change of the permission set, starting with the next one.
  Stream<PermissionSet> get changes => _changes.stream;

  void _publish(PermissionSet next) {
    _current = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  /// Loads the permissions from the server. On failure the previous set is
  /// kept (the server still enforces everything) and the failure returned.
  Future<Result<PermissionSet>> refresh() async {
    final result = await Result.guard(_repository.fetchMine);
    return result.map((mine) {
      final next = PermissionSet.fromMyPermissions(mine);
      _publish(next);
      return next;
    });
  }

  /// Forgets the permissions (sign-out, session expired).
  void clear() => _publish(PermissionSet.none);

  Future<void> dispose() => _changes.close();
}
