# Authorization: RBAC, Granular Permissions, User Overrides, Data Scope

Authentication (who the caller is) is described in [authentication.md](authentication.md). This document describes what an authenticated caller may do. Code: `backend/src/modules/rbac`, `backend/src/modules/audit-logs`, `backend/src/database/data-scope.policy.ts`.

Status: everything in sections 1–9 is **implemented** (Phase 2 step 8). Section 10 lists what is not built yet.

## 1. Model

```
Effective permissions(user) = ( permissions of the user's roles  ∪  ALLOW overrides )  −  DENY overrides
Access(request)             = authenticated ∧ permission ∈ effective ∧ resource inside the actor's data scope
```

```
Request → Authentication guard → AuthenticatedUserActor → Permission guard → AuthorizationService
        → controller → service → ScopedRepository (data scope) → MongoDB
```

| Outcome | Answer |
|---|---|
| No valid access token | 401 `UNAUTHENTICATED` / `TOKEN_EXPIRED` |
| Account access changed since the token was issued | 401 `PERMISSIONS_CHANGED` (the client refreshes) |
| Authenticated, permission missing | 403 `PERMISSION_DENIED` |
| Record outside the caller's data scope | 404 `RESOURCE_NOT_FOUND` (ids of other tenants cannot be probed) |
| Creating a record for another tenant | 403 `PERMISSION_DENIED` |

Rules:

- **Enforced on the server.** What a client shows or hides is not authorization; every request is checked.
- **Deny by default.** Every HTTP endpoint declares `@PublicEndpoint()`, `@AuthenticatedOnly()` (self-service on the caller's own account) or `@RequirePermission(...)`. An endpoint that declares nothing stops start-up (`EndpointAccessDeclarationCheck`) and would be denied by the guard.
- **Fail closed.** An unknown permission key, an unknown or foreign role, a missing user, or a resource without the facts the scope needs all mean "no".
- **DENY wins** over every grant, including the wildcard.
- **Role names are never checked in business code** — only permission keys and data scope.
- **Nothing from the client is trusted**: roles, permissions and scope are read from MongoDB for the authenticated user on every request.

## 2. Permission catalogue

Keys are `<module>.<action>` (sub-modules allowed: `users.permissions.manage`). Each permission has a key, name, module, action, description, and `grantableTo` — the kinds of account that may ever hold it, through a role or an ALLOW override. A platform-only permission therefore can never reach a customer, driver or partner account.

Declared in `modules/rbac/permissions/permission-catalog.ts`; the union type `PermissionKey` makes `@RequirePermission('...')` and role definitions type-checked. The catalogue is validated at start-up.

| Module | Actions |
|---|---|
| users | read, create, update, delete |
| users.roles | assign |
| users.permissions | read, manage |
| users.data-scope | manage |
| roles | read |
| bookings | read, create, update, cancel |
| buses | read, create, update, delete |
| trips | read, create, update, cancel |
| fares | read, create, update |
| reports | read |
| settlements | read |
| customers | read, update |
| operators | read, create, update |
| partners | read, create, update |
| notifications | read, manage |
| settings | read, update |
| audit | read |

**Adding permissions:** a module exports a group built with `definePermissions('<module>', { <action>: { name, description, grantableTo } })` and adds it to `PERMISSION_CATALOG`. Only permissions for capabilities that exist, or that the authorization foundation needs, are declared; each business module adds its own when it is built. Older planning documents use `view` / `edit`; the implemented verbs are `read` / `update`.

## 3. Roles

The twelve roles of the platform specification, defined in `modules/rbac/roles/system-roles.ts` and mirrored into the `roles` collection at start-up (`SystemRolesSynchronizer`; it creates roles, never users). Each role has a key, name, description, the kind of account it suits, a data scope, and permission keys.

| Role | Account kind | Data scope | Permissions (summary) |
|---|---|---|---|
| SUPER_ADMIN | STAFF | ALL | `*` — every permission |
| ADMIN | STAFF | ALL | Everything except `users.delete` and `settings.update` |
| SUPPORT | STAFF | ALL | Read customers, bookings, trips, buses, operators, notifications |
| OPERATOR_ADMIN | OPERATOR_STAFF | OWN_OPERATOR | Users (read/create/update, roles, overrides), fleet, trips, fares, bookings, reports, settlements, audit |
| OPERATOR_MANAGER | OPERATOR_STAFF | OWN_OPERATOR | Buses, trips, fares, bookings (no cancel), customers, reports |
| BOOKING_STAFF | OPERATOR_STAFF | OWN_OPERATOR | Bookings (read/create/update/cancel), read customers, trips, buses, fares |
| ACCOUNT_STAFF | OPERATOR_STAFF | OWN_OPERATOR | Read bookings, fares, settlements, reports |
| OPERATIONS_STAFF | OPERATOR_STAFF | OWN_OPERATOR | Read/update trips, read buses and bookings |
| DRIVER | DRIVER | ASSIGNED_RECORDS | Read trips and bookings |
| CONDUCTOR | DRIVER | ASSIGNED_RECORDS | Read trips and bookings |
| PARTNER | PARTNER_USER | OWN_PARTNER | Read trips and fares; bookings (read/create/cancel); reports, settlements |
| CUSTOMER | CUSTOMER | OWN_RECORDS | Read trips and fares; bookings (read/create/cancel) |

- A role only takes effect on the kind of account it was made for.
- Customer accounts hold the CUSTOMER role implicitly (sign-up stores no role). Every other account has **no permissions** until a role is assigned.
- A user may hold several roles of the same data scope; their permissions add up.

## 4. User-level overrides

Collection `permission_overrides`: at most one override per user and permission, with `effect` ALLOW or DENY, a mandatory `reason`, and who set it.

- **ALLOW** adds one permission the roles do not give. Only for permissions that exist and that the user's kind of account may hold.
- **DENY** removes one permission, whatever grants it.
- Precedence is the formula in section 1, implemented as one pure function (`resolveEffectivePermissions`).

## 5. Data scope

One system, from Phase 2 step 5: `users.dataScope` → actor → `ScopedRepository` and `isResourceWithinScope` (both in `database/`).

| Scope | Reaches |
|---|---|
| ALL | Everything |
| OWN_OPERATOR | Records of the user's operator |
| SELECTED_OPERATORS | Records of the listed operators |
| OWN_PARTNER | Records of the user's partner |
| OWN_RECORDS | Records the user owns |
| ASSIGNED_RECORDS | Records assigned to the user (for example a driver's trips) |

- **Lists and lookups** go through `ScopedRepository`: the scope filter is AND-ed with the caller's filter, so a filter can narrow the result but never widen it. A record outside the scope behaves as missing.
- **Single records already loaded** are checked with `AuthorizationService.can / require(actor, permission, resource)`.
- **Scope per kind of account:** STAFF → ALL or SELECTED_OPERATORS; OPERATOR_STAFF → OWN_OPERATOR or SELECTED_OPERATORS; DRIVER → ASSIGNED_RECORDS; PARTNER_USER → OWN_PARTNER; CUSTOMER → OWN_RECORDS.
- **Background jobs** run as an explicit SYSTEM actor (set with a reason), which is unrestricted. A SYSTEM actor never comes from a request.

**Operator isolation:** a user of Operator A cannot read or change Operator B's records, cannot reach them by filter or by id, cannot change their own scope, and cannot give anyone access to an operator outside their own scope. **Partner isolation** works the same way through `partnerId`.

## 6. Evaluating and enforcing

- `AuthorizationService.can(actor, permission, resource?)` / `require(...)` — the single evaluator. `require` throws `PERMISSION_DENIED`, or `RESOURCE_NOT_FOUND` for an out-of-scope resource (`outOfScope: 'forbid'` for writes).
- `@RequirePermission('bookings.cancel')` on a handler or controller; `PermissionGuard` (global, after the authentication guard) enforces it. Several keys mean all are required. It also documents the endpoint in OpenAPI.
- Effective permissions are cached in memory per `userId:permissionVersion`. Every authorization change increments `users.permissionVersion` in the same transaction, so a changed user never hits a stale entry; access tokens issued before the change answer `PERMISSIONS_CHANGED` and the client refreshes. MongoDB stays the source of truth.

## 7. Administration and escalation rules

Changing another user's access (`AuthorizationAdministrationService`), each in one MongoDB transaction together with its audit entry:

1. **Never your own account** — not even for a super administrator.
2. **Only users inside your data scope**; others answer `RESOURCE_NOT_FOUND`.
3. **Not a more privileged user:** the target may not hold a permission you lack; wildcard holders are changed only by wildcard holders.
4. **No more than you hold:** a role you assign and a permission you ALLOW (or restore by removing a DENY) must be within your own effective permissions. Only a wildcard holder can assign SUPER_ADMIN.
5. **Roles must suit the account kind** and share one data scope. Assigning roles sets the scope the roles are built for; a scope narrowed on purpose (SELECTED_OPERATORS) is kept.
6. **Data scope** must suit the account kind and stay inside your own scope; only an actor with scope ALL can hand out ALL.

## 8. Endpoints

All under `/api/v1`.

```
GET    /me/permissions                               authenticated   own roles, effective permissions, data scope
GET    /permissions                                  roles.read      permission catalogue
GET    /roles                                        roles.read      roles the caller could assign
GET    /users                                        users.read      user directory inside the caller's scope
GET    /users/:userId/permissions                    users.permissions.read     roles, overrides, effective permissions (ROLE / ALLOW_OVERRIDE), denied
PUT    /users/:userId/roles                          users.roles.assign         { roleKeys[], reason? }   (empty list removes all roles)
PUT    /users/:userId/permissions/:permissionKey     users.permissions.manage   { effect: ALLOW | DENY, reason }
DELETE /users/:userId/permissions/:permissionKey     users.permissions.manage   { reason? }
PUT    /users/:userId/data-scope                     users.data-scope.manage    { type, operatorIds[], reason }
GET    /audit-logs                                   audit.read      audit trail inside the caller's scope
```

`GET /me/permissions` returns `userId, userType, roles[{key,name}], permissionVersion, dataScope{type,operatorIds}, operatorId, partnerId, permissions[], permissionsByModule{}` — authorization facts only, always about the caller (there is no user id parameter). Clients use it to decide what to show and refetch when `permissionVersion` changes.

## 9. Audit trail

Collection `audit_logs`, append-only. An entry is written inside the transaction of the change, so it exists if and only if the change committed; a refused change writes nothing.

| Action | Recorded for |
|---|---|
| `user.roles.changed` | Role assignment and removal (before/after role keys and data scope) |
| `user.permission-override.set` | Override created or modified (before/after effect) |
| `user.permission-override.removed` | Override removed |
| `user.data-scope.changed` | Data scope change |

Each entry: actor (user id, account kind, role keys), action, target (`entityType`, `entityId`, operator, partner), `before`, `after`, reason, request id, IP, user agent, time. Entries hold authorization facts only — never passwords, OTPs, tokens, MFA secrets or recovery codes. Reading is scoped: an operator administrator sees only entries about their own operator.

## 10. Not implemented yet

- Creating users and custom roles through the API, and their administration screens. (The management app exists for the catalogue: [admin-app.md](admin-app.md).)
- (Done) The first SUPER_ADMIN account of a new environment is created with the bootstrap command: [admin-app.md](admin-app.md) §2. No account is ever seeded.
- Partner API scopes (`trip:read`, `booking:create`, ...) — Phase 7.
- Permissions and audit actions of business modules — added with each module.
