import 'package:meta/meta.dart';

import 'enums.dart';
import 'json_reader.dart';

/// A user's data scope (`users.dataScope`).
@immutable
final class DataScope {
  const DataScope({required this.type, this.operatorIds = const <String>[]});

  factory DataScope.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return DataScope(
      type: DataScopeType.fromWire(reader.string('type')),
      operatorIds: reader.stringList('operatorIds'),
    );
  }

  final DataScopeType type;

  /// Operators for `OWN_OPERATOR` and `SELECTED_OPERATORS`.
  final List<String> operatorIds;
}

/// Key and display name of a role.
@immutable
final class RoleSummary {
  const RoleSummary({required this.key, required this.name});

  factory RoleSummary.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return RoleSummary(key: reader.string('key'), name: reader.string('name'));
  }

  /// Stable key such as `BOOKING_STAFF`.
  final String key;
  final String name;
}

/// Response of `GET /me/permissions`: what the signed-in user may do.
/// Used only to decide what the UI shows; the server enforces every
/// permission on every request.
@immutable
final class MyPermissions {
  const MyPermissions({
    required this.userId,
    required this.userType,
    required this.roles,
    required this.permissionVersion,
    required this.dataScope,
    required this.permissions,
    this.operatorId,
    this.partnerId,
  });

  factory MyPermissions.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return MyPermissions(
      userId: reader.string('userId'),
      userType: UserType.fromWire(reader.string('userType')),
      roles: reader.objectList('roles', RoleSummary.fromJson),
      permissionVersion: reader.integer('permissionVersion'),
      dataScope: DataScope.fromJson(reader.object('dataScope')),
      operatorId: reader.stringOrNull('operatorId'),
      partnerId: reader.stringOrNull('partnerId'),
      permissions: reader.stringList('permissions').toSet(),
    );
  }

  final String userId;
  final UserType userType;
  final List<RoleSummary> roles;

  /// Changes whenever the user's access changes.
  final int permissionVersion;
  final DataScope dataScope;
  final String? operatorId;
  final String? partnerId;

  /// Effective permission keys such as `bookings.cancel`.
  final Set<String> permissions;
}

/// One entry of the permission catalogue (`GET /permissions`).
@immutable
final class PermissionDefinition {
  const PermissionDefinition({
    required this.key,
    required this.module,
    required this.action,
    required this.name,
    required this.description,
    required this.sensitive,
    required this.grantableTo,
  });

  factory PermissionDefinition.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return PermissionDefinition(
      key: reader.string('key'),
      module: reader.string('module'),
      action: reader.string('action'),
      name: reader.string('name'),
      description: reader.string('description'),
      sensitive: reader.boolean('sensitive'),
      grantableTo: reader
          .stringList('grantableTo')
          .map(UserType.fromWire)
          .toList(growable: false),
    );
  }

  final String key;
  final String module;
  final String action;
  final String name;
  final String description;
  final bool sensitive;

  /// Kinds of account that may hold the permission.
  final List<UserType> grantableTo;
}

/// One entry of the role catalogue (`GET /roles`).
@immutable
final class Role {
  const Role({
    required this.key,
    required this.name,
    required this.description,
    required this.userType,
    required this.dataScopeType,
    required this.isSystemRole,
    required this.permissionKeys,
  });

  factory Role.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return Role(
      key: reader.string('key'),
      name: reader.string('name'),
      description: reader.string('description'),
      userType: UserType.fromWire(reader.string('userType')),
      dataScopeType: DataScopeType.fromWire(reader.string('dataScopeType')),
      isSystemRole: reader.boolean('isSystemRole'),
      permissionKeys: reader.stringList('permissionKeys'),
    );
  }

  final String key;
  final String name;
  final String description;
  final UserType userType;
  final DataScopeType dataScopeType;
  final bool isSystemRole;

  /// Permission keys, or the single wildcard `*`.
  final List<String> permissionKeys;
}

/// A user-level exception to the permissions of the user's roles.
@immutable
final class PermissionOverride {
  const PermissionOverride({
    required this.permissionKey,
    required this.effect,
    required this.reason,
    required this.grantedBy,
    this.updatedAt,
  });

  factory PermissionOverride.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return PermissionOverride(
      permissionKey: reader.string('permissionKey'),
      effect: OverrideEffect.fromWire(reader.string('effect')),
      reason: reader.string('reason'),
      grantedBy: reader.string('grantedBy'),
      updatedAt: reader.dateTimeOrNull('updatedAt'),
    );
  }

  final String permissionKey;
  final OverrideEffect effect;
  final String reason;

  /// Id of the administrator who set the override.
  final String grantedBy;
  final DateTime? updatedAt;
}

/// An effective permission and where it comes from.
@immutable
final class EffectivePermission {
  const EffectivePermission({required this.key, required this.source});

  factory EffectivePermission.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return EffectivePermission(
      key: reader.string('key'),
      source: PermissionSource.fromWire(reader.string('source')),
    );
  }

  final String key;
  final PermissionSource source;
}

/// Another user's authorization as seen by an administrator
/// (`GET /users/:userId/permissions`).
@immutable
final class UserAuthorization {
  const UserAuthorization({
    required this.userId,
    required this.userType,
    required this.permissionVersion,
    required this.roles,
    required this.dataScope,
    required this.overrides,
    required this.effectivePermissions,
    required this.deniedPermissions,
    this.operatorId,
    this.partnerId,
  });

  factory UserAuthorization.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return UserAuthorization(
      userId: reader.string('userId'),
      userType: UserType.fromWire(reader.string('userType')),
      operatorId: reader.stringOrNull('operatorId'),
      partnerId: reader.stringOrNull('partnerId'),
      permissionVersion: reader.integer('permissionVersion'),
      roles: reader.objectList('roles', RoleSummary.fromJson),
      dataScope: DataScope.fromJson(reader.object('dataScope')),
      overrides: reader.objectList('overrides', PermissionOverride.fromJson),
      effectivePermissions: reader.objectList(
        'effectivePermissions',
        EffectivePermission.fromJson,
      ),
      deniedPermissions: reader.stringList('deniedPermissions'),
    );
  }

  final String userId;
  final UserType userType;
  final String? operatorId;
  final String? partnerId;
  final int permissionVersion;
  final List<RoleSummary> roles;
  final DataScope dataScope;
  final List<PermissionOverride> overrides;
  final List<EffectivePermission> effectivePermissions;

  /// Role permissions removed by a DENY override.
  final List<String> deniedPermissions;
}
