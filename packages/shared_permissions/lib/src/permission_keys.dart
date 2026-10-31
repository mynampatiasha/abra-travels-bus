/// The permission keys of the backend catalogue
/// (`backend/src/modules/rbac/permissions/permission-catalog.ts`).
///
/// This is not a second registry: it is a typed copy of the keys so app code
/// does not spell them as loose strings. `permission_keys_parity_test.dart`
/// compares this list with the backend source and fails when they differ.
/// Names, descriptions and who may hold a permission come from the server
/// (`GET /permissions`).
abstract final class PermissionKeys {
  static const usersRead = 'users.read';
  static const usersCreate = 'users.create';
  static const usersUpdate = 'users.update';
  static const usersDelete = 'users.delete';
  static const usersRolesAssign = 'users.roles.assign';
  static const usersPermissionsRead = 'users.permissions.read';
  static const usersPermissionsManage = 'users.permissions.manage';
  static const usersDataScopeManage = 'users.data-scope.manage';
  static const rolesRead = 'roles.read';
  static const bookingsRead = 'bookings.read';
  static const bookingsCreate = 'bookings.create';
  static const bookingsUpdate = 'bookings.update';
  static const bookingsCancel = 'bookings.cancel';
  static const busesRead = 'buses.read';
  static const busesCreate = 'buses.create';
  static const busesUpdate = 'buses.update';
  static const busesDelete = 'buses.delete';
  static const catalogueRead = 'catalogue.read';
  static const catalogueManage = 'catalogue.manage';
  static const documentsRead = 'documents.read';
  static const documentsManage = 'documents.manage';
  static const documentsReview = 'documents.review';
  static const documentsUpload = 'documents.upload';
  static const documentsView = 'documents.view';
  static const bannersManage = 'banners.manage';
  static const bannersDelete = 'banners.delete';
  static const routesRead = 'routes.read';
  static const routesCreate = 'routes.create';
  static const routesUpdate = 'routes.update';
  static const tripsRead = 'trips.read';
  static const tripsCreate = 'trips.create';
  static const tripsUpdate = 'trips.update';
  static const tripsPublish = 'trips.publish';
  static const tripsCancel = 'trips.cancel';
  static const faresRead = 'fares.read';
  static const faresCreate = 'fares.create';
  static const faresUpdate = 'fares.update';
  static const reportsRead = 'reports.read';
  static const settlementsRead = 'settlements.read';
  static const customersRead = 'customers.read';
  static const customersUpdate = 'customers.update';
  static const operatorsRead = 'operators.read';
  static const operatorsCreate = 'operators.create';
  static const operatorsUpdate = 'operators.update';
  static const operatorsApprove = 'operators.approve';
  static const partnersRead = 'partners.read';
  static const partnersCreate = 'partners.create';
  static const partnersUpdate = 'partners.update';
  static const notificationsRead = 'notifications.read';
  static const notificationsManage = 'notifications.manage';
  static const settingsRead = 'settings.read';
  static const settingsUpdate = 'settings.update';
  static const auditRead = 'audit.read';
  static const auditExport = 'audit.export';
  static const catalogueDelete = 'catalogue.delete';
  static const catalogueExport = 'catalogue.export';
  static const documentsDelete = 'documents.delete';
  static const documentsExport = 'documents.export';
  static const operatorsDelete = 'operators.delete';
  static const operatorsExport = 'operators.export';
  static const bannersRead = 'banners.read';
  static const bannersExport = 'banners.export';
  static const rolesManage = 'roles.manage';
  static const messagesRead = 'messages.read';
  static const messagesResend = 'messages.resend';
  static const maintenanceBypass = 'maintenance.bypass';
  static const commissionsRead = 'commissions.read';
  static const commissionsManage = 'commissions.manage';
  static const commissionsDelete = 'commissions.delete';
  static const commissionsExport = 'commissions.export';
  static const payoutRead = 'payout.read';
  static const payoutManage = 'payout.manage';
  static const payoutExport = 'payout.export';
  static const payoutDelete = 'payout.delete';
  static const contentRead = 'content.read';
  static const contentManage = 'content.manage';
  static const customersAccountDelete = 'customers.account.delete';
  static const supportRead = 'support.read';
  static const supportManage = 'support.manage';

  /// Every key above.
  static const Set<String> all = <String>{
    usersRead,
    usersCreate,
    usersUpdate,
    usersDelete,
    usersRolesAssign,
    usersPermissionsRead,
    usersPermissionsManage,
    usersDataScopeManage,
    rolesRead,
    bookingsRead,
    bookingsCreate,
    bookingsUpdate,
    bookingsCancel,
    busesRead,
    busesCreate,
    busesUpdate,
    busesDelete,
    catalogueRead,
    catalogueManage,
    documentsRead,
    documentsManage,
    documentsReview,
    documentsUpload,
    documentsView,
    bannersManage,
    bannersDelete,
    routesRead,
    routesCreate,
    routesUpdate,
    tripsRead,
    tripsCreate,
    tripsUpdate,
    tripsPublish,
    tripsCancel,
    faresRead,
    faresCreate,
    faresUpdate,
    reportsRead,
    settlementsRead,
    customersRead,
    customersUpdate,
    operatorsRead,
    operatorsCreate,
    operatorsUpdate,
    operatorsApprove,
    partnersRead,
    partnersCreate,
    partnersUpdate,
    notificationsRead,
    notificationsManage,
    settingsRead,
    settingsUpdate,
    auditRead,
    auditExport,
    catalogueDelete,
    catalogueExport,
    documentsDelete,
    documentsExport,
    operatorsDelete,
    operatorsExport,
    bannersRead,
    bannersExport,
    rolesManage,
    messagesRead,
    messagesResend,
    maintenanceBypass,
    commissionsRead,
    commissionsManage,
    commissionsDelete,
    commissionsExport,
    payoutRead,
    payoutManage,
    payoutExport,
    payoutDelete,
    contentRead,
    contentManage,
    customersAccountDelete,
    supportRead,
    supportManage,
  };
}
