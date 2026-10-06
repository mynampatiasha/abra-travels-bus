# Discovery: finding a bus

How a customer, signed in or not, finds a bus: choose two cities and a date, see the buses, filter and sort them, open one. Implemented in Step 10C (2026-10-06). Seat selection and everything after it are not part of this.

Catalogue data (cities, operators, buses, routes, trips) is entered and published through the management API described in [catalogue-management.md](catalogue-management.md). No sample data is shipped, so a new database has no buses until someone enters them through that API.

## 1. Flow

```
Home (search form) ──▶ City picker (from / to) ──▶ Travel date ──▶ Search
        │
        ▼
Search results ──▶ previous / next day, filters, sorting, more results
        │
        ▼
Trip details: bus, timings, fare, amenities, boarding points, dropping points
        │
        ▼
(Seat selection — not built. The screen says so; there is no button.)
```

Everything above is open to guests. Sign-in is required for booking steps and for personal sections (My trips, Support, Profile), and the location the customer was heading to is kept through sign-in.

## 2. Backend endpoints

All are public (`@PublicEndpoint`), read-only, and return nothing that depends on who is asking. The customer app sends no token to them.

| Endpoint | Purpose |
|---|---|
| `GET /cities?query=&limit=` | Cities whose name starts with `query`; without `query`, the popular cities |
| `GET /trips/search` | Trips on sale between two cities on a date (filters, sorting, pagination) |
| `GET /trips/search/filters` | The values that search can be filtered by, with counts |
| `GET /trips/:tripId` | One trip in full |

**A trip is "on sale"** when it is published and bookable (`status = SCHEDULED`), has not departed, and belongs to an `ACTIVE` operator. Every query goes through this rule (`TripCatalogueRepository.onSale`); drafts, cancelled and departed trips and trips of suspended operators are never returned, also not through a filter or by id (`RESOURCE_NOT_FOUND`).

### 2.1 `GET /cities`

- `query` (1–40 characters, optional): matched against the start of the English name, and of the name in the `Accept-Language` language. Case-insensitive. Treated as text, never as a pattern.
- `limit` (1–50, default 20).
- Response: `[{ id, name, state, slug }]`. `name` is in the `Accept-Language` language when a translation exists. Only active cities.

### 2.2 `GET /trips/search`

| Parameter | Rule |
|---|---|
| `from`, `to` | City ids (required, different, both active cities) |
| `date` | `YYYY-MM-DD`, India calendar date, from today to 90 days ahead (`SEARCH_HORIZON_DAYS`) |
| `passengers` | 1–6, optional: only trips with at least that many seats available. Without it sold-out trips are listed and marked |
| `sort` | `DEPARTURE_EARLIEST` (default), `DEPARTURE_LATEST`, `FARE_LOWEST`, `FARE_HIGHEST`, `DURATION_SHORTEST` |
| `departureWindows` | Comma list of `EARLY_MORNING` (00–06), `MORNING` (06–12), `AFTERNOON` (12–18), `NIGHT` (18–24), local time of the trip |
| `busTypes` | Comma list of bus type keys (`AC_SLEEPER`) |
| `ac` | `true` / `false` |
| `operatorIds` | Comma list of operator ids |
| `amenities` | Comma list; the bus must have every one |
| `minFare`, `maxFare` | Paise, inclusive, on the lowest fare of the trip |
| `page`, `pageSize` | From 1; page size 1–50, default 20 |

Invalid input answers `VALIDATION_FAILED` (unknown fields and query operators are rejected by the DTO). Limited to 60 requests a minute per client address across search and filters (`RATE_LIMITED` with `details.retryAfterSeconds`).

Response: a page of trips (`meta.page`, `meta.pageSize`, `meta.total`). Each trip:

```
id, operator {id, name},
bus {name, typeKey, typeName, isAc, berthType, amenities[]},
origin {id, name}, destination {id, name},
travelDate, timezone, departureAt, arrivalAt, durationMinutes,
fare {startingPaise, currency},
seats {total, available, isSoldOut},
boardingPoints [{id, name, time}], droppingPoints [{id, name, time}]
```

The order is total (ties are broken by id), so pages never repeat or skip a trip. Internal fields (operator, bus, route and layout ids, registration number, timestamps) are not included.

### 2.3 `GET /trips/search/filters`

Same `from`, `to`, `date`, `passengers`. Describes the unfiltered search:

```
total,
busTypes [{key, name, isAc, berthType, count}],
operators [{id, name, count}],
amenities [{key, count}],
departureWindows [{key, fromMinute, toMinute, count}],
fare {minPaise, maxPaise, currency} | null
```

### 2.4 `GET /trips/:tripId`

The search result plus: `status`, `bus.registrationNumber`, `stops [{id, name}]` (cities passed through), and full points: `city {id, name}`, `address`, `landmark`, `instructions`, `contactPhone`, `location {latitude, longitude}`. Points are returned in time order.

Seat-level availability is not part of this response. It will be `GET /trips/:tripId/seat-map` (api-architecture.md), attached by trip id; the trip response keeps seat totals only.

## 3. Catalogue collections

| Collection | Owner | Used by discovery for |
|---|---|---|
| `cities` | platform | City picker; names of origin, destination and stops |
| `locations` | platform or operator | Source of boarding and dropping points (copied into trips) |
| `operators` | platform | Name shown; `status` decides whether trips are offered |
| `bus_types` | platform | Key and name of the bus type (copied into trips) |
| `buses` | operator | Name, registration, type, amenities (copied into trips) |
| `routes` | operator | Origin, destination, stop cities (`stops` embedded; copied into trips) |
| `trips` | operator | The unit customers search and book |

```
Operator ─┬─ Bus ──── BusType
          ├─ Route ── origin City, destination City, stop Cities
          └─ Trip ─── Route, Bus, travelDate, departureAt, arrivalAt
                      boardingPoints[], droppingPoints[]   (copies of Locations, each with its time)
                      bus {name, type, amenities}          (copy at publishing)
                      startingFarePaise, seatCounts
```

A trip carries copies of what customers see. Search is therefore one indexed query (`originCityId, destinationCityId, travelDate, status, departureAt`), and later edits to a bus or location do not change a trip already on sale. Two fields exist for search only: `departureMinuteOfDay` (time-of-day filter) and `durationMinutes` (sorting).

What later modules attach, without changing the trip model:

- **Seat inventory:** `trip_seat_inventory` by `tripId`, generated at publishing from `seatLayoutVersionId`; it maintains `trips.seatCounts`.
- **Fares:** `fareRuleSetVersionId`; `startingFarePaise` is the lowest seat fare, for display. The amount to pay is always calculated by the backend at booking.
- **Bookings:** refer to `tripId` and to the `pointId` of the chosen boarding and dropping point.
- **Schedules:** recurring timetables that generate trips (`scheduleId`); not needed for discovery and not created yet.

Differences from the first design in database-architecture.md: route stops are embedded in `routes` instead of a separate `route_stops` collection, and trips have the copied `bus`, `startingFarePaise`, `departureMinuteOfDay`, `durationMinutes` and `timezone` fields.

Data isolation: the catalogue is read through `TripCatalogueRepository`, which is deliberately not a scoped repository because there is no actor; it can only return trips on sale. Operator staff will manage their own buses, routes and trips through scoped repositories. Discovery writes nothing.

## 4. Customer app

Code: `apps/customer_app/lib/features/discovery/` (`models`, `repositories`, `controllers`, `screens`, `widgets`).

| Location | Screen |
|---|---|
| `/home` (shell tab), `/search` | Search form: from, to, swap, date (calendar, Today, Tomorrow), recent searches |
| `/search/city?field=from\|to` | City picker: popular cities, search as you type (one request per pause in typing) |
| `/search/results?origin=&originName=&destination=&destinationName=&date=` | Results |
| `/trip/:id` | Trip details |

- **Validation before searching:** origin and destination chosen and different, date within today…+90 days. The backend validates again.
- **Results:** every change of day, filter or order is a new backend request; the app never filters or reorders what it has, so it cannot show availability the backend did not just return. Further pages are loaded on request and a trip is never listed twice. Results are not cached after the screen closes; trip details are always loaded fresh.
- **Filters:** only values that occur in the search are offered (from `/trips/search/filters`), each with its number of buses; a departure window with no buses is not shown. Maximum price is a slider between the lowest and highest fare.
- **States:** loading, no buses (with "clear filters" when filters are the cause), no connection, timeout, server problem, too many searches, each with retry where retrying can help; a trip that is gone has its own explanation and a way back to searching; a malformed results link is explained.
- **Times and dates:** travel dates are India calendar dates and trip times are shown as the clock in India shows them, whatever the phone's timezone. Trips in another timezone would need a timezone database and are shown in the phone's local time until then.
- **Recent searches:** the last five routes (city ids and names only) are kept in ordinary preferences on the device.
- **Amenities:** known keys are translated; a key added on the backend later is shown as readable text ("Hot towel"), never as a raw key.
- **Guests:** start on Home. The top bar offers Sign in. My trips, Support and Profile lead to sign-in and return there afterwards.

## 5. Not included

- Screens for entering catalogue data (the API exists: [catalogue-management.md](catalogue-management.md)).
- Seat map, seat selection, booking, payment.
- Offers, banners and "upcoming trip" on Home (no backend for them yet).
- Ratings, cancellation policy and live tracking on trip details.
- Maps for boarding and dropping points (coordinates are in the API; the app does not draw them yet).
- Translations of city and amenity names beyond English (the mechanism exists; no translated data).
- Running on a device or emulator, and the iOS build.
