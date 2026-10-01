# API Architecture

## 1. Conventions

- Base path `/api/v1`. Partner API under `/partner/v1` (same services, different guard and response shaping).
- JSON, camelCase fields, ISO-8601 UTC times, money as integer paise plus `currency: "INR"`.
- Success envelope: `{ "success": true, "data": ..., "meta": { "requestId", "page", "pageSize", "total" } }`.
- Error envelope: `{ "success": false, "error": { "code": "SEAT_NOT_AVAILABLE", "message": "...", "details": {...}, "requestId": "..." } }`. Messages are translated using `Accept-Language`.
- Pagination: `?page=1&pageSize=20` (max 100); cursor pagination for logs and events.
- Every mutating transactional endpoint accepts `Idempotency-Key`. Required for seat locks, bookings, payment orders, cancellations and refunds.
- Validation with zod DTOs; unknown fields rejected; request body limit 1 MB (uploads use pre-signed URLs).
- Rate limits (Redis sliding window): anonymous search 60/min/IP, OTP 3/15 min, seat lock 20/min/user, partner per `api_clients.rateLimitPerMinute`.
- Every endpoint in Swagger lists its required permission or scope and idempotency behaviour.

## 2. Error codes (selection)

`VALIDATION_FAILED 400` · `UNAUTHENTICATED 401` · `TOKEN_EXPIRED 401` · `PERMISSIONS_CHANGED 401` · `PERMISSION_DENIED 403` · `SCOPE_MISSING 403` · `RESOURCE_NOT_FOUND 404` · `SEAT_NOT_AVAILABLE 409` · `SEAT_LOCK_EXPIRED 409` · `INVALID_STATE_TRANSITION 409` · `IDEMPOTENCY_KEY_REUSED 422` · `COUPON_INVALID 422` · `COUPON_USAGE_EXCEEDED 422` · `PAYMENT_AMOUNT_MISMATCH 422` · `RATE_LIMITED 429` · `PAYMENT_PROVIDER_UNAVAILABLE 502` · `SERVICE_UNAVAILABLE 503` · `MAINTENANCE_MODE 503`.

## 3. Endpoint map

Permission shown in brackets. `public` = no login. `me` = customer ownership.

### Public / customer

```
GET  /cities?query=                                   public
GET  /popular-routes                                  public
GET  /banners?placement=HOME_HERO                     public (only active + within dates)
POST /banners/:bannerId/events                        public  { type: IMPRESSION|CLICK }
GET  /offers                                          public
GET  /content/:slug                                   public
GET  /trips/search?from=&to=&date=&passengers=        public  filters + sort
GET  /trips/:tripId                                   public  bus, route, points, amenities, policy
GET  /trips/:tripId/seat-map                          public  live seat states from master inventory (no PII)
POST /trips/:tripId/seat-locks                        customer  Idempotency-Key
DELETE /seat-locks/:lockId                            owner
POST /bookings                                        customer  { lockId, passengers[], contact, couponCode? }  Idempotency-Key
POST /bookings/:bookingId/coupon                      owner   validate + apply
POST /payments/orders                                 owner   { bookingId } → gateway order
POST /payments/:paymentId/client-callback             owner   triggers server verification only
GET  /bookings/:bookingId                             owner
GET  /me/bookings?status=upcoming|completed|cancelled me
GET  /bookings/:bookingId/cancellation-quote          owner   refund preview per seat
POST /bookings/:bookingId/cancel                      owner   { bookingSeatIds[] }  Idempotency-Key
GET  /tickets/:ticketId  /tickets/:ticketId/pdf       owner
POST /tickets/:ticketId/share                         owner   { channel: EMAIL|WHATSAPP|SMS }
POST /tickets/lookup                                  public  { pnr, phone } rate limited
GET  /trips/:tripId/live-status                       owner of booking on trip, or share-link token
GET/PUT /me/profile  /me/saved-passengers  /me/notification-preferences  /me/emergency-contacts
POST /safety/sos                                      me      { bookingId?, location? }
POST /safety/incidents                                me
POST /safety/trip-shares                              me      → share link
POST /support/tickets   GET /me/support/tickets        me
POST /assistant/messages                              me/public  AI assistant
```

### Operator (all filtered by data scope)

```
GET/POST/PUT  /operator/profile                         [operators.update]
GET/POST/PUT/DELETE /operator/staff                     [operator-staff.*]
GET/POST/PUT/DELETE /buses                              [buses.*]
GET/POST /seat-layouts   POST /seat-layouts/:id/versions  [seat-layouts.*]
GET/POST/PUT/DELETE /routes  /routes/:id/stops  /routes/:id/points   [routes.*]
GET/POST/PUT/DELETE /schedules                          [schedules.*]
POST /schedules/:id/generate-trips                      [trips.create]
GET/POST/PUT /trips                                     [trips.*]
POST /trips/:tripId/publish                             [trips.publish]
POST /trips/:tripId/status                              [trip-operations.update]  SCHEDULED→BOARDING...
POST /trips/:tripId/delay                               [trip-operations.update]
POST /trips/:tripId/change-bus                          [trips.update]  preview + confirm, seat mapping
POST /trips/:tripId/cancel                              [trips.cancel]  reason required
GET  /trips/:tripId/inventory                           [inventory.read]
POST /trips/:tripId/inventory/block | unblock           [inventory.block|unblock]
GET/POST /fare-rule-sets  POST /fare-rule-sets/:id/versions   [fares.*]
GET  /bookings?pnr=&phone=&tripId=&status=              [bookings.read]
POST /counter-bookings                                  [bookings.create]
GET  /trips/:tripId/manifest  /manifest.pdf  /manifest.csv   [manifests.read|export]
GET  /settlements  /settlements/:id                     [settlements.read]
GET  /reports/:reportKey  /reports/:reportKey/export    [reports.read|export]
GET  /dashboard/operator                                [dashboard.read]
```

### Driver / conductor

```
GET  /driver/trips?date=today                           [manifests.read]  assigned trips only
GET  /driver/trips/:tripId/manifest                     [manifests.read]
POST /driver/check-ins                                  [check-in.verify]  { qrToken | pnr+seat }
POST /driver/trips/:tripId/status | /delay              [trip-operations.update]
WS   /tracking  event: location.update                  [trip-operations.update]
POST /driver/sos                                        driver
```

### Admin (platform)

```
GET/POST/PUT /operators   POST /operators/:id/approve|reject|suspend|activate   [operators.*]
GET  /admin/trips   /admin/trips/:tripId/timeline        [trips.read]
GET  /admin/inventory/:tripId                            [inventory.read]  seat, state, lock, booking, channel, partner, last change
GET  /admin/bookings  /admin/bookings/:id (timeline, payments, refunds, notifications, API events, audit)   [bookings.read]
GET  /admin/customers                                    [customers.read]
GET  /admin/payments   POST /admin/payments/:id/reconcile   [payments.read|verify]
GET/POST /admin/refunds   POST /admin/refunds/:id/approve|reject   [refunds.*]
GET/POST/PUT /admin/partners  /admin/api-clients  POST /admin/api-clients/:id/rotate  [partners.*, api-clients.*]
GET  /admin/api-monitoring                               [api-monitoring.read]
GET  /admin/webhook-deliveries  POST /admin/webhook-deliveries/:id/retry   [webhooks.*]
GET/POST/PUT /admin/commission-rules                     [commissions.manage]
POST /admin/settlements/generate   POST /admin/settlements/:id/approve|mark-paid   [settlements.*]
CRUD /admin/banners  POST /admin/banners/:id/publish|unpublish|duplicate|archive   GET /admin/banners/:id/analytics
CRUD /admin/offers  /admin/coupons  /admin/content  /admin/popular-routes
CRUD /admin/notification-templates   GET /admin/notifications
CRUD /admin/languages  /admin/translations
GET  /admin/safety/incidents   POST /admin/safety/incidents/:id/acknowledge|escalate|resolve   [safety.*]
GET  /admin/tracking/live                                [tracking.read]
CRUD /users  /roles  + permission endpoints (see authorization.md)
GET  /admin/audit-logs                                   [audit-logs.read]
GET/PUT /admin/settings  /admin/feature-flags  /admin/maintenance
GET  /admin/search?q=                                    global search (PNR, booking, phone, email, bus, operator, trip)
GET  /dashboard/admin                                    [dashboard.read]
```

### Partner API (`/partner/v1`, scopes)

```
GET  /trips/search                        trip:read
GET  /trips/:tripId/availability          inventory:read
POST /trips/:tripId/seat-locks            booking:create   Idempotency-Key
POST /bookings                            booking:create   Idempotency-Key
POST /bookings/:bookingId/confirm         booking:create   (partner prepaid wallet / credit model)
GET  /bookings/:bookingId                 booking:read
POST /bookings/:bookingId/cancel          booking:cancel   Idempotency-Key
GET  /refunds/:refundId                   refund:read
```

Partner payment model (prepaid wallet vs. customer pays Abra) is a business decision to confirm; the architecture supports a `PartnerWalletPaymentGateway` implementation of the same payment interface.

### Webhooks in

```
POST /webhooks/payments/:gateway          signature verified, raw body preserved
POST /webhooks/whatsapp/:provider         signature verified
POST /webhooks/sms/:provider/delivery
```

### Webhooks out (to partners)

Headers: `X-Abra-Event-Id`, `X-Abra-Event-Type`, `X-Abra-Timestamp`, `X-Abra-Signature: sha256=HMAC(secret, timestamp + "." + body)`. Partners must reject timestamps older than 5 minutes. Retries with exponential back-off for 24 hours (1m, 5m, 15m, 1h, 4h, 12h), then `FAILED` with admin alert. Events: `trip.updated, trip.delayed, trip.cancelled, bus.changed, seat.locked, seat.released, booking.created, booking.confirmed, booking.cancelled, payment.success, payment.failed, refund.created, refund.completed, tracking.updated`.

## 4. Real-time (Socket.IO)

Namespaces: `/tracking` (rooms `trip:{tripId}`), `/inventory` (room `trip:{tripId}` → "seat map changed, refetch"), `/admin-alerts`. Sockets authenticate with the access token on connect; room joins are permission and ownership checked. Sockets push **hints**; clients always re-read authoritative state over REST before acting.
