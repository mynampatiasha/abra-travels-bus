# Catalogue management

How cities, locations, operators, bus types, buses, routes and trips get into the system, and how a trip reaches customer search. Backend API, implemented 2026-10-06. It feeds the public discovery described in [discovery.md](discovery.md).

The management screens for this API are in the management app ([admin-app.md](admin-app.md)). The first Super Admin of an installation is created with the bootstrap command described there.

## 1. What is managed, and by whom

| Resource | Collection | Owner | Managed through |
|---|---|---|---|
| City | `cities` | platform | `/catalogue/cities` |
| Bus type | `bus_types` | platform | `/catalogue/bus-types` |
| Operator | `operators` | platform (status), operator (own profile) | `/catalogue/operators` |
| Location | `locations` | platform (shared) or one operator | `/catalogue/locations` |
| Bus | `buses` | one operator | `/catalogue/buses` |
| Route | `routes` | one operator | `/catalogue/routes` |
| Trip | `trips` | one operator | `/catalogue/trips` |

Relationships are those of [discovery.md](discovery.md) §3. Two fields were added for management: `buses.seatCapacity` (number of seats sold on the bus, until seat layouts exist) and `cities.countryCode` (default `IN`). Trips gained `departureTimeLocal`, `cancelledAt` and `cancellationReason`.

Schedules (recurring timetables that generate trips) are not built: every trip is created individually.

## 2. Permissions and data scope

All endpoints require sign-in and a permission, checked on the backend for every request. Seven permission keys were added (the catalogue now has 46): `catalogue.read`, `catalogue.manage`, `routes.read`, `routes.create`, `routes.update`, `trips.publish`, `operators.approve`. The Flutter key registry (`shared_permissions`) was updated to match.

| Action | Permission | Who holds it by role |
|---|---|---|
| View cities (including inactive) | `catalogue.read` | Super Admin, Admin |
| Create, edit, enable, disable cities and bus types | `catalogue.manage` | Super Admin, Admin |
| List bus types | `buses.read` | platform staff, operator staff, support |
| View operators | `operators.read` | platform staff, support; operator staff see their own |
| Register an operator | `operators.create` | Super Admin, Admin |
| Edit an operator profile | `operators.update` | Super Admin, Admin; Operator Admin for their own |
| Approve, reject, suspend, reactivate an operator | `operators.approve` (sensitive) | Super Admin, Admin |
| View, create, edit, enable, disable locations and routes | `routes.read` / `.create` / `.update` | Super Admin, Admin, Operator Admin, Operator Manager |
| View, add, edit buses and change their status | `buses.read` / `.create` / `.update` | as above; booking staff and support read only |
| View trips | `trips.read`, as platform or operator staff | staff roles; customers and drivers are refused here |
| Create and edit draft trips | `trips.create` / `trips.update` | Super Admin, Admin, Operator Admin, Operator Manager |
| Publish a trip | `trips.publish` | same |
| Cancel a trip | `trips.cancel` (sensitive) | same |

**Data scope** is applied in the repositories, not in the controllers:

- Platform staff (`ALL`) work across operators and must name the operator when creating a bus or a route.
- Operator staff (`OWN_OPERATOR`) see and change only their operator's buses, routes, trips and locations. A record of another operator answers `RESOURCE_NOT_FOUND`, a list filter cannot widen the scope, and a record cannot be created for another operator. They need not name their operator when creating.
- A trip can only combine a bus and a route the caller can see, and both must belong to the same operator. A trip never changes operator.
- **Locations** are of two kinds. Shared locations (no operator) are created and changed by platform staff only and can be used by every operator. An operator's own locations are visible and usable only by that operator.
- Cities and bus types have no tenant; access is by permission alone.

## 3. Endpoints

Lists are paginated (`page`, `pageSize` up to 100; `meta.page`, `meta.pageSize`, `meta.total`). Unknown fields are rejected. Ids in responses are strings; no database internals are exposed.

```
Cities
GET  /catalogue/cities?query=&active=            [catalogue.read]
GET  /catalogue/cities/:id                       [catalogue.read]
POST /catalogue/cities                           [catalogue.manage]  name, state, countryCode?, slug?, translations?, latitude?, longitude?, isPopular?, sortOrder?
PUT  /catalogue/cities/:id                       [catalogue.manage]  (slug cannot change)
POST /catalogue/cities/:id/active                [catalogue.manage]  { active, reason? }

Bus types
GET  /catalogue/bus-types?active=                [buses.read]
POST /catalogue/bus-types                        [catalogue.manage]  key, name, isAc, berthType
PUT  /catalogue/bus-types/:id                    [catalogue.manage]  (key cannot change)
POST /catalogue/bus-types/:id/active             [catalogue.manage]

Operators
GET  /catalogue/operators?status=                [operators.read]
GET  /catalogue/operators/:id                    [operators.read]
POST /catalogue/operators                        [operators.create]  companyName, displayName?   → PENDING_APPROVAL
PUT  /catalogue/operators/:id                    [operators.update]
POST /catalogue/operators/:id/status             [operators.approve] { status, reason }

Locations
GET  /catalogue/locations?cityId=&active=        [routes.read]
GET  /catalogue/locations/:id                    [routes.read]
POST /catalogue/locations                        [routes.create]  cityId, operatorId?, name, address, landmark?, instructions?, contactPhone?, latitude?, longitude?
PUT  /catalogue/locations/:id                    [routes.update]
POST /catalogue/locations/:id/active             [routes.update]

Buses
GET  /catalogue/buses?operatorId=&status=        [buses.read]
GET  /catalogue/buses/:id                        [buses.read]
POST /catalogue/buses                            [buses.create]  operatorId?, registrationNumber, name, busTypeId, amenities[], seatCapacity
PUT  /catalogue/buses/:id                        [buses.update]  (operator and registration cannot change)
POST /catalogue/buses/:id/status                 [buses.update]  { status: ACTIVE | MAINTENANCE | RETIRED, reason? }

Routes
GET  /catalogue/routes?operatorId=&originCityId=&destinationCityId=&status=   [routes.read]
GET  /catalogue/routes/:id                       [routes.read]
POST /catalogue/routes                           [routes.create]  operatorId?, originCityId, destinationCityId, name, distanceKm?, estimatedDurationMinutes, stops[{cityId, offsetMinutes, distanceFromOriginKm?}]
PUT  /catalogue/routes/:id                       [routes.update]  (origin, destination and operator cannot change)
POST /catalogue/routes/:id/status                [routes.update]  { status: ACTIVE | INACTIVE, reason? }

Trips
GET  /catalogue/trips?operatorId=&busId=&routeId=&travelDate=&status=   [trips.read]
GET  /catalogue/trips/:id                        [trips.read]
POST /catalogue/trips                            [trips.create]   → DRAFT
PUT  /catalogue/trips/:id                        [trips.update]   drafts only
POST /catalogue/trips/:id/publish                [trips.publish]  DRAFT → SCHEDULED
POST /catalogue/trips/:id/cancel                 [trips.cancel]   { reason }
```

Errors: `VALIDATION_FAILED` (400), `PERMISSION_DENIED` (403), `RESOURCE_NOT_FOUND` (404, also for records outside the data scope), `ALREADY_REGISTERED` (409, a duplicate city slug, bus type key or bus registration number), `INVALID_STATE_TRANSITION` (409).

### Validation rules

- **City:** name and state required; the slug is made from the name when left out and is unique; latitude and longitude go together. A disabled city is no longer offered to customers and is refused for new locations and routes.
- **Bus type:** unique, permanent upper-case key; berth type `SEATER`, `SLEEPER`, `SEMI_SLEEPER` or `MIXED`.
- **Operator:** status follows the state machine: `PENDING_APPROVAL → ACTIVE | REJECTED`, `ACTIVE ↔ SUSPENDED`. A reason is required.
- **Location:** the city must be active.
- **Bus:** the registration number is normalised (upper case, no spaces or hyphens) and unique on the platform; the bus type must be active; seat capacity 1–100; amenities from the fixed list. `RETIRED` is final.
- **Route:** origin and destination differ; origin, destination and stops are active cities, each used once; stop times increase and fall within the journey time.
- **Trip:** see §4.

## 4. Trips and publishing

### Creating a draft

```
{ busId, routeId, travelDate, departureTime, durationMinutes?, startingFarePaise,
  boardingPoints: [{ locationId, offsetMinutes }], droppingPoints: [{ locationId, offsetMinutes }] }
```

- `travelDate` (`YYYY-MM-DD`) and `departureTime` (`HH:mm`) are India time; the date is from today to 180 days ahead.
- `durationMinutes` defaults to the route's estimate. The fare is in paise and is the lowest seat fare.
- Bus and route must be visible to the caller and belong to the same operator.
- Each point refers to a location the operator can use (shared or its own). Boarding points lie in the origin or a stop city; dropping points in a stop city or the destination. Point times are minutes after departure, inside the journey, and every dropping point comes after the first boarding point. A location is used once per list.
- The client cannot set status, seat counts or any derived field.

The trip stores copies of the bus (name, registration, type, amenities) and of each location, with the time the bus is there. Point ids stay the same when a draft is edited.

### Lifecycle

The project's trip state machine ([state-machines.md](state-machines.md) §5) is used unchanged:

```
DRAFT ──publish──▶ SCHEDULED ──▶ BOARDING ─▶ DEPARTED ─▶ IN_TRANSIT ─▶ ARRIVED
  │                    │
  └──────cancel────────┴──▶ CANCELLED
```

| Requested term | Status here |
|---|---|
| Draft | `DRAFT` — visible only to the operator and platform staff; can be edited |
| Published | `SCHEDULED` — on sale; no longer editable |
| Cancelled | `CANCELLED` |
| Completed | `ARRIVED` — reached through trip operations, which are not built yet |

Implemented transitions: create (`DRAFT`), publish (`DRAFT → SCHEDULED`), cancel (`DRAFT | SCHEDULED → CANCELLED`). Anything else answers `INVALID_STATE_TRANSITION`. The running states and `ARRIVED` belong to trip operations (driver app, later).

### Publishing

A trip never appears to customers because it exists. `POST /catalogue/trips/:id/publish` is the only way, and it is refused (`VALIDATION_FAILED`, with the reason) unless at that moment:

- the operator is `ACTIVE`;
- the bus is `ACTIVE`, has a seat capacity, and its bus type is active;
- the route is `ACTIVE` and its origin and destination cities are active;
- every boarding and dropping location is active;
- the departure is in the future;
- the bus is not committed to another trip (`SCHEDULED` … `DELAYED`) that overlaps in time.

On publishing the trip takes fresh copies of bus and locations, records `publishedAt`, and sets `seatCounts` to the bus's seat capacity, all available. Two publish requests at once cannot both succeed.

### Customer search integration

Customer search ([discovery.md](discovery.md)) shows a trip only when it is `SCHEDULED`, not yet departed, and its operator is `ACTIVE`. Consequences, all covered by end-to-end tests that go through the API only:

| Situation | In customer search |
|---|---|
| Draft | no |
| Published | yes, with the real operator, bus, timings, fare, seats and points |
| Cancelled | no (at once) |
| Operator suspended after publishing | no (at once); yes again when reactivated |
| Bus, route, bus type, location or city disabled **before** publishing | cannot be published |
| Bus, route or location changed or disabled **after** publishing | the trip stays on sale with the copies it took |

The last row is deliberate: a trip on sale is a commitment to customers and is taken off sale by cancelling it, not as a side effect of editing the catalogue.

## 5. Audit

Every create, edit and status change is written to the audit trail in the same transaction as the change (`AuditedChangeRunner`): actor, roles, action, resource type and id, operator, before and after values, reason, request id and address. Actions: `catalogue.created`, `catalogue.updated`, `catalogue.status-changed`, `trip.published`, `trip.cancelled`. A refused request writes nothing. Operator administrators see the entries of their own operator through `GET /audit-logs`.

## 6. Entering a catalogue (order of calls)

1. Cities (`POST /catalogue/cities`) and bus types (`POST /catalogue/bus-types`).
2. Shared locations in those cities (`POST /catalogue/locations` without `operatorId`).
3. An operator (`POST /catalogue/operators`), then approve it (`POST …/status` with `ACTIVE`).
4. A bus and a route for the operator.
5. A trip (`POST /catalogue/trips`), then publish it.

Steps 4 and 5 can be done by the operator's own administrator or manager once such a user exists.

## 7. Tests

- Unit: trip planning rules, operator resolution for new records, slug and duplicate handling.
- End-to-end (real application, MongoDB, Redis), three suites: publishing to customer search; permissions and operator isolation; validation, lists and audit.

## 8. Not included

- **Operator staff accounts.** Creating users for an operator is part of user management, not of this step.
- Schedules and generating trips from them; changing the bus of a published trip; delays and the running states; completing a trip.
- Seat layouts, seat inventory and per-seat fares. `seatCapacity` and `startingFarePaise` stand in for them and become derived values when those modules exist.
- Deleting catalogue records. Records are disabled or retired, never deleted.
- Cancelling a trip does not refund anything because bookings do not exist yet; refunding becomes part of cancellation with the booking module.
