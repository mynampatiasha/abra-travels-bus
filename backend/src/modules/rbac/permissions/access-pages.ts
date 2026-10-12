import { PermissionRegistry } from './permission-registry';

/**
 * The access matrix of the admin and the operator (client) portal: one level per role per page
 * (documentation/abra-master-plan.md, Appendix C). A page is a screen of the portal; it maps to
 * the permission modules whose keys it needs. A level turns into permission keys, so the matrix
 * is only a friendly way to edit the same permissions every endpoint already checks.
 *
 * Fail closed: a module that has not declared its permissions yet contributes no keys, so a page
 * of a module that is not built grants nothing until that module adds its permission group.
 */
export const ACCESS_LEVELS = ['NONE', 'VIEW', 'EDIT', 'FULL'] as const;
export type AccessLevel = (typeof ACCESS_LEVELS)[number];

export const ACCESS_LEVEL_LABELS: Readonly<Record<AccessLevel, string>> = {
  NONE: 'None',
  VIEW: 'View',
  EDIT: 'Edit',
  FULL: 'Edit and delete',
};

export type AccessAudience = 'ADMIN' | 'OPERATOR';

export interface AccessPage {
  /** Same ids as the demo pages, so the screens and the server speak about the same page. */
  readonly id: string;
  readonly title: string;
  readonly audience: AccessAudience;
  /** Permission modules whose actions this page uses, e.g. `trips`. */
  readonly modules: readonly string[];
}

const admin = (id: string, title: string, ...modules: string[]): AccessPage => ({
  id,
  title,
  audience: 'ADMIN',
  modules,
});
const operator = (id: string, title: string, ...modules: string[]): AccessPage => ({
  id,
  title,
  audience: 'OPERATOR',
  modules,
});

export const ACCESS_PAGES: readonly AccessPage[] = [
  admin('dashboard', 'Dashboard', 'reports'),
  admin('invitations', 'Invitations', 'operators'),
  admin('kyc', 'KYC reviews', 'operators', 'documents'),
  admin('operators', 'Operators', 'operators'),
  admin('dreports', 'Driver reports', 'drivers'),
  admin('drules', 'Driver rules (defaults)', 'drivers'),
  admin('commission', 'Commission', 'commissions'),
  admin('payout', 'Payout and fees', 'settlements'),
  admin('places', 'Cities and places', 'catalogue'),
  admin('bustypes', 'Bus types and amenities', 'catalogue'),
  admin('documents', 'Required documents', 'documents'),
  admin('questions', 'KYC questionnaire', 'documents'),
  admin('buses', 'Buses', 'buses'),
  admin('trips', 'Trips', 'trips'),
  admin('inventory', 'Seat inventory', 'trips'),
  admin('tracking', 'Live tracking', 'trips'),
  admin('bookings', 'Bookings', 'bookings'),
  admin('payments', 'Payments', 'payments'),
  admin('refunds', 'Refunds', 'refunds'),
  admin('settlements', 'Settlements', 'settlements'),
  admin('customers', 'Customers', 'customers'),
  admin('tickets', 'Support tickets', 'support'),
  admin('messages', 'Messages sent', 'notifications'),
  admin('content', 'Help centre and pages', 'content'),
  admin('banners', 'Banners', 'banners'),
  admin('offers', 'Offers and coupons', 'offers'),
  admin('announce', 'Announcements', 'notifications'),
  admin('popular', 'Popular routes', 'content'),
  admin('sos', 'SOS board', 'safety'),
  admin('incidents', 'Incidents and sharing', 'safety'),
  admin('safety', 'Safety settings', 'safety'),
  admin('reports', 'Reports', 'reports'),
  admin('settings', 'Settings and integrations', 'settings'),
  // The roles module is deliberately not here: only the Super Admin (wildcard) edits the matrix
  admin('staff', 'Staff and roles', 'users', 'users.roles'),
  admin('flags', 'Feature flags and maintenance', 'settings'),
  admin('audit', 'Audit log', 'audit'),
  admin('notifications', 'Notifications', 'notifications'),
  admin('ai', 'AI assistant settings', 'settings'),

  operator('dashboard', 'Dashboard', 'reports'),
  operator('kyc', 'KYC verification', 'documents'),
  operator('company', 'Company profile', 'operators'),
  operator('buses', 'Buses', 'buses'),
  operator('layouts', 'Seat layouts', 'buses'),
  operator('crew', 'Drivers and crew', 'drivers'),
  operator('dreports', 'Driver reports', 'drivers'),
  operator('drules', 'Driver rules', 'drivers'),
  operator('routes', 'Routes and stops', 'routes'),
  operator('places', 'Places', 'catalogue'),
  operator('fares', 'Fares', 'fares'),
  operator('schedules', 'Schedules', 'trips'),
  operator('trips', 'Trips', 'trips'),
  operator('bookings', 'Bookings', 'bookings'),
  operator('offers', 'Offers', 'offers'),
  operator('earnings', 'Earnings and settlements', 'settlements'),
  operator('commission', 'Commission', 'commissions'),
  operator('live', 'Live buses and safety', 'trips'),
  operator('notifications', 'Notifications', 'notifications'),
  operator('staff', 'Staff and roles', 'users'),
];

export function pagesFor(audience: AccessAudience): readonly AccessPage[] {
  return ACCESS_PAGES.filter((page) => page.audience === audience);
}

/** The portal a kind of account works in: platform staff use the admin portal, operator staff the client portal. */
export function audienceOfUserType(userType: string): AccessAudience | undefined {
  return userType === 'STAFF' ? 'ADMIN' : userType === 'OPERATOR_STAFF' ? 'OPERATOR' : undefined;
}

export function findPage(audience: AccessAudience, pageId: string): AccessPage | undefined {
  return ACCESS_PAGES.find((page) => page.audience === audience && page.id === pageId);
}

export function isAccessLevel(value: unknown): value is AccessLevel {
  return typeof value === 'string' && (ACCESS_LEVELS as readonly string[]).includes(value);
}

/**
 * What the word "view" means in an action name; everything else changes data. `export` is a view
 * action: the demos show Export CSV to every role that can open the page.
 */
const VIEW_ACTIONS: ReadonlySet<string> = new Set(['read', 'view', 'list', 'export']);
const DELETE_ACTIONS: ReadonlySet<string> = new Set(['delete']);

/** Every declared permission of one module, in declaration order (empty for an unbuilt module). */
function moduleDefinitions(module: string) {
  return PermissionRegistry.byModule()[module] ?? [];
}

/**
 * Permission keys that one page grants at a level:
 *  VIEW  reading only; EDIT everything except deletion and sensitive actions; FULL everything.
 */
export function keysForPageLevel(page: AccessPage, level: AccessLevel): string[] {
  if (level === 'NONE') return [];
  const keys: string[] = [];
  for (const module of page.modules) {
    for (const definition of moduleDefinitions(module)) {
      const view = VIEW_ACTIONS.has(definition.action);
      const del = DELETE_ACTIONS.has(definition.action);
      const sensitive = definition.sensitive === true;
      const allowed =
        level === 'FULL' ? true : level === 'EDIT' ? !del && !sensitive : view && !sensitive;
      if (allowed) keys.push(definition.key);
    }
  }
  return keys;
}

/** Every key any page of the audience could grant: the keys the matrix owns for that audience. */
export function managedKeys(audience: AccessAudience): ReadonlySet<string> {
  const keys = new Set<string>();
  for (const page of pagesFor(audience)) {
    for (const module of page.modules) {
      for (const definition of moduleDefinitions(module)) keys.add(definition.key);
    }
  }
  return keys;
}

/**
 * Final permission keys of a role edited through the matrix: the keys the matrix does not own
 * stay as the role had them, the keys it owns come only from the page levels (union over pages
 * that share a module).
 */
export function permissionKeysFromLevels(
  audience: AccessAudience,
  levels: Readonly<Record<string, AccessLevel>>,
  baseKeys: readonly string[],
): string[] {
  const owned = managedKeys(audience);
  const result = new Set<string>(baseKeys.filter((key) => !owned.has(key)));
  for (const page of pagesFor(audience)) {
    const level = levels[page.id];
    if (!level) continue;
    for (const key of keysForPageLevel(page, level)) result.add(key);
  }
  return [...result].sort();
}

/**
 * The level a role effectively has on a page, read back from its permission keys. A role that
 * holds the wildcard is FULL everywhere. A key set that does not match any level exactly is
 * reported as the highest level it fully contains, with `exact: false`.
 */
export function inferLevel(
  page: AccessPage,
  permissionKeys: ReadonlySet<string>,
  wildcard: boolean,
): { level: AccessLevel; exact: boolean } {
  if (wildcard) return { level: 'FULL', exact: true };
  const owned = new Set<string>();
  for (const module of page.modules) {
    for (const definition of moduleDefinitions(module)) owned.add(definition.key);
  }
  const held = [...owned].filter((key) => permissionKeys.has(key));
  if (held.length === 0) return { level: 'NONE', exact: true };
  const holdsAll = (keys: readonly string[]) => keys.every((key) => permissionKeys.has(key));
  const sameSet = (keys: readonly string[]) => keys.length === held.length && holdsAll(keys);
  for (const level of ['FULL', 'EDIT', 'VIEW'] as const) {
    const keys = keysForPageLevel(page, level);
    if (keys.length > 0 && sameSet(keys)) return { level, exact: true };
  }
  for (const level of ['FULL', 'EDIT', 'VIEW'] as const) {
    const keys = keysForPageLevel(page, level);
    if (keys.length > 0 && holdsAll(keys)) return { level, exact: false };
  }
  return { level: 'NONE', exact: false };
}
