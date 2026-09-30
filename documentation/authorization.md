# Authorization: RBAC, Granular Permissions, User Overrides, Data Scope

## 1. Model

```
Effective permissions(user) = ( ∪ permissionKeys of user's roles  ∪  ALLOW overrides )  −  DENY overrides
Access(request)             = authenticated ∧ user ACTIVE ∧ permission ∈ effective ∧ resource within data scope ∧ ownership (if applicable)
```

- **Deny by default.** An endpoint without `@RequirePermission(...)` or `@PublicEndpoint()` fails a startup check.
- **DENY wins** over any role grant.
- **SUPER_ADMIN** holds the `*` wildcard. Only a SUPER_ADMIN can assign or edit SUPER_ADMIN users or roles.
- Role names are never checked in business code. Only permission keys and scope.

## 2. Permission keys

Format `module.action` (sub-module allowed: `users.permissions.manage`). Defined once in `backend/src/modules/rbac/permission-registry.ts`, seeded into `permissions` on start-up, served to apps via `GET /api/v1/permissions`.

Actions: `view, create, edit, delete, publish, approve, reject, cancel, refund, export, import, manage, assign, block, unblock, verify`. New actions are added to the registry without schema changes.

| Module | Actions |
|---|---|
| dashboard | view |
| users | view, create, edit, delete |
| users.permissions | manage |
| roles | view, create, edit, delete |
| operators | view, create, edit, delete, approve, reject, block, unblock |
| operator-staff | view, create, edit, delete |
| buses | view, create, edit, delete |
| seat-layouts | view, create, edit |
| routes | view, create, edit, delete |
| schedules | view, create, edit, delete |
| trips | view, create, edit, delete, publish, cancel, assign |
| fares | view, create, edit |
| inventory | view, block, unblock |
| customers | view, edit, export |
| bookings | view, create, edit, cancel, export |
| manifests | view, export |
| check-in | verify |
| payments | view, verify, export |
| refunds | view, create, approve, reject |
| tickets | view, create |
| commissions | view, manage |
| settlements | view, create, approve, export |
| reports | view, export |
| analytics | view |
| partners | view, create, edit, approve, block |
| api-clients | view, create, edit, block |
| api-monitoring | view |
| webhooks | view, manage |
| banners | view, create, edit, delete, publish |
| offers | view, create, edit, delete, publish |
| coupons | view, create, edit, delete |
| campaign-reports | view, export |
| content | view, create, edit, publish |
| notifications | view, manage |
| whatsapp | view, manage |
| chatbot | view, manage |
| languages | view, manage |
| safety | view, manage |
| tracking | view |
| trip-operations | edit (status, delay) |
| support | view, create, edit |
| audit-logs | view, export |
| settings | view, edit |
| feature-flags | view, edit |
| maintenance | manage |
| drivers | view, create, edit, delete |

Customer self-service and partner API use separate mechanisms (ownership checks and API scopes) described below, not the admin permission matrix.

## 3. Roles (12, all editable defaults)

| Role | Audience | Default permissions (summary) | Default scope |
|---|---|---|---|
| SUPER_ADMIN | Platform | `*` | ALL |
| ADMIN | Platform | Everything except `users.permissions.manage` on super admins, `maintenance.manage`, `settings.edit` for security keys | ALL |
| SUPPORT | Platform | dashboard.view, customers.view, bookings.view, tickets.view, payments.view, refunds.view, support.*, safety.view, tracking.view | ALL |
| OPERATOR_ADMIN | Operator | All operator-side modules incl. operator-staff.*, settlements.view, reports.export | OWN_OPERATOR |
| OPERATOR_MANAGER | Operator | buses, routes, schedules, trips, fares, inventory, bookings (no delete), manifests, reports.view | OWN_OPERATOR |
| BOOKING_STAFF | Operator | bookings.view/create/edit/cancel, customers.view, inventory.view, manifests.view | OWN_OPERATOR |
| ACCOUNT_STAFF | Operator | payments.view, refunds.view/create, settlements.view, reports.view | OWN_OPERATOR |
| OPERATIONS_STAFF | Operator | trips.view, trip-operations.edit, manifests.view, tracking.view, drivers.view | OWN_OPERATOR |
| DRIVER | Field | manifests.view, check-in.verify, trip-operations.edit, safety.create (own trips) | ASSIGNED_RECORDS |
| CONDUCTOR | Field | same as DRIVER | ASSIGNED_RECORDS |
| PARTNER | Partner | partner portal only; API access via scopes | OWN_PARTNER |
| CUSTOMER | Customer | self-service only (ownership checks) | OWN_RECORDS |

Platform admins can also create custom roles. Operator admins can create custom roles for their own operator from the subset of operator-audience permissions they themselves hold.

## 4. Data scope (tenant isolation)

`users.dataScope = { type: 'ALL' | 'OWN_OPERATOR' | 'SELECTED_OPERATORS' | 'OWN_PARTNER' | 'OWN_RECORDS' | 'ASSIGNED_RECORDS', operatorIds: [] }`

Enforcement lives in `ScopedRepository`, not in controllers:

```ts
// every find/update on a tenant collection goes through this
protected scopeFilter(): FilterQuery<T> {
  const scope = this.requestContext.actor.scope;
  switch (scope.type) {
    case 'ALL': return {};
    case 'OWN_OPERATOR':
    case 'SELECTED_OPERATORS': return { operatorId: { $in: scope.operatorIds } };
    case 'ASSIGNED_RECORDS': return { _id: { $in: this.assignedIds() } };   // e.g. driver's trips
    ...
  }
}
```

A request for a record outside scope returns **404 `RESOURCE_NOT_FOUND`** (not 403), so IDs of other tenants cannot be probed. An automated test suite tries every `:id` endpoint with another operator's IDs.

## 5. Enforcement at three levels

| Level | Implementation |
|---|---|
| Backend (security boundary) | `PermissionGuard` reads `@RequirePermission` metadata → loads effective permissions → 403 `PERMISSION_DENIED`. `ScopedRepository` applies tenant filter. |
| Route (Flutter) | go_router `redirect` checks `PermissionService.has('refunds.view')` → `/forbidden` page |
| UI | `PermissionGate(permission: 'bookings.cancel', child: CancelButton())` hides or disables; nav menu built from permission-filtered definitions |

## 6. Effective permission cache and instant revocation

- Effective permissions are computed and cached in Redis `perm:{userId}:{permissionVersion}` (TTL 10 min).
- `users.permissionVersion` increments on any role, override, status or scope change. The access token carries `pv`; the guard compares it with the stored version (cached 30 s) and rejects stale tokens with `PERMISSIONS_CHANGED` → client refreshes and refetches permissions.
- Deactivating a user revokes all `auth_sessions` and bumps `permissionVersion`: access ends within one request.
- If Redis is unavailable, permissions are computed from MongoDB directly.

## 7. Permission management rules

- Users cannot edit their own roles, overrides or scope (`CANNOT_MODIFY_OWN_PERMISSIONS`).
- A user can grant only permissions they hold themselves (no privilege escalation).
- Changes to SUPER_ADMIN users require SUPER_ADMIN.
- Sensitive permissions (`users.permissions.manage`, `refunds.approve`, `settlements.approve`, `settings.edit`, `api-clients.create`) require a reason and, when admin MFA is enabled, a fresh MFA check.
- Every change writes `audit_logs` with before/after, actor, target, reason, IP, user agent.

## 8. Permission APIs

```
GET    /api/v1/permissions                          registry grouped by module
GET    /api/v1/roles            POST /api/v1/roles
PUT    /api/v1/roles/:roleId    DELETE /api/v1/roles/:roleId   (system roles cannot be deleted)
GET    /api/v1/users/:userId/permissions            role grants + overrides, each tagged INHERITED / ALLOWED / DENIED
PUT    /api/v1/users/:userId/permissions            bulk replace overrides (matrix save)
POST   /api/v1/users/:userId/permissions/grant      { permissionKey, reason }
POST   /api/v1/users/:userId/permissions/deny       { permissionKey, reason }
DELETE /api/v1/users/:userId/permissions/:permissionKey   remove override → back to inherited
GET    /api/v1/users/:userId/effective-permissions
GET    /api/v1/me/permissions                       used by all apps after login
```

## 9. Admin permission matrix UI

Rows = modules (grouped: Operations, Sales, Finance, Marketing, Platform), columns = actions. Each cell is a tri-state chip: **inherited ✓** (grey), **allowed override** (green +), **denied override** (red ✕), empty. Toolbar: search, select all/clear per module and globally, apply role template, "show effective only", diff preview before save, reason field for sensitive changes, audit history tab.

## 10. Partner API scopes

Partner API clients use scopes, not the admin matrix: `trip:read`, `inventory:read`, `booking:create`, `booking:read`, `booking:cancel`, `refund:read`. `PartnerClientGuard` validates the API key/HMAC or client-credentials token, status, expiry, scope and rate limit. Partners see only bookings where `partnerId` is theirs.

## 11. Customer ownership

Customer endpoints under `/api/v1/me/...` always filter by `customerId = actor.customerId`. Guest ticket lookup requires PNR **and** the booking phone number, plus rate limiting.
