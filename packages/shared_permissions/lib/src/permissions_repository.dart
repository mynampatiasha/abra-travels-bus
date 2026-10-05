import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

/// Reads authorization data from the backend (documentation/
/// authorization.md §8). Throws `AppException` on failure.
class PermissionsRepository {
  PermissionsRepository(this._client);

  final ApiClient _client;

  /// The signed-in user's own roles, effective permissions and data scope
  /// (`GET /me/permissions`).
  Future<MyPermissions> fetchMine() async => (await _client.get(
    'me/permissions',
  )).decodeObject(MyPermissions.fromJson);

  /// The permission catalogue (`GET /permissions`, needs `roles.read`).
  Future<List<PermissionDefinition>> fetchCatalogue() async =>
      (await _client.get(
        'permissions',
      )).decodeList(PermissionDefinition.fromJson);

  /// Roles the caller could assign (`GET /roles`, needs `roles.read`).
  Future<List<Role>> fetchRoles() async =>
      (await _client.get('roles')).decodeList(Role.fromJson);

  /// Another user's authorization (`GET /users/:userId/permissions`, needs
  /// `users.permissions.read`).
  Future<UserAuthorization> fetchForUser(String userId) async =>
      (await _client.get(
        'users/$userId/permissions',
      )).decodeObject(UserAuthorization.fromJson);
}
