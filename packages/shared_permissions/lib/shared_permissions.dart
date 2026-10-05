/// Permission helpers for the user interface.
///
/// IMPORTANT: these checks only decide what an app shows or hides. They are
/// not security. The backend checks every permission and data scope on
/// every request and is the only authority (documentation/authorization.md).
library;

export 'src/permission_keys.dart';
export 'src/permission_set.dart';
export 'src/permissions_controller.dart';
export 'src/permissions_repository.dart';
export 'src/role_keys.dart';
