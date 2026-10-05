import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';

/// The effective permissions of the signed-in user, for deciding what the
/// UI shows. Built from the server's answer to `GET /me/permissions`; it
/// never computes permissions itself (roles, overrides and precedence are
/// resolved by the backend).
///
/// UI only — hiding a button is not security. The server rejects any
/// request the user is not allowed to make.
@immutable
final class PermissionSet {
  const PermissionSet._({
    required Set<String> permissions,
    required Set<String> roleKeys,
    required this.dataScope,
    required this.permissionVersion,
    this.operatorId,
    this.partnerId,
  }) : _permissions = permissions,
       _roleKeys = roleKeys;

  factory PermissionSet.fromMyPermissions(MyPermissions mine) =>
      PermissionSet._(
        permissions: Set<String>.unmodifiable(mine.permissions),
        roleKeys: Set<String>.unmodifiable(mine.roles.map((role) => role.key)),
        dataScope: mine.dataScope,
        permissionVersion: mine.permissionVersion,
        operatorId: mine.operatorId,
        partnerId: mine.partnerId,
      );

  /// Nobody signed in, or permissions not loaded yet: nothing is allowed.
  static const PermissionSet none = PermissionSet._(
    permissions: <String>{},
    roleKeys: <String>{},
    dataScope: DataScope(type: DataScopeType.unknown),
    permissionVersion: 0,
  );

  final Set<String> _permissions;
  final Set<String> _roleKeys;

  /// Which records the user can reach; the server applies it to every query.
  final DataScope dataScope;

  /// Changes whenever the user's access changes on the server.
  final int permissionVersion;
  final String? operatorId;
  final String? partnerId;

  Set<String> get permissions => _permissions;

  Set<String> get roleKeys => _roleKeys;

  bool get isEmpty => _permissions.isEmpty;

  /// True when the user holds [permission] (a key from `PermissionKeys`).
  bool hasPermission(String permission) => _permissions.contains(permission);

  /// True when the user holds at least one of [permissions]. False for an
  /// empty list.
  bool hasAnyPermission(Iterable<String> permissions) =>
      permissions.any(_permissions.contains);

  /// True when the user holds every one of [permissions]. False for an
  /// empty list, so a missing requirement never opens something by mistake.
  bool hasAllPermissions(Iterable<String> permissions) =>
      permissions.isNotEmpty && permissions.every(_permissions.contains);

  /// True when the user holds the role [roleKey] (a key from `RoleKeys`).
  bool hasRole(String roleKey) => _roleKeys.contains(roleKey);

  bool hasAnyRole(Iterable<String> roleKeys) =>
      roleKeys.any(_roleKeys.contains);
}
