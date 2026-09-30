# Master Inventory, Seat Locking and Booking Flow

## 1. Inventory generation

When a trip is published (`DRAFT → SCHEDULED`), one `trip_seat_inventory` document is inserted per bookable seat from the trip's `seatLayoutVersionId`, with `fareSnapshotPaise` calculated from the fare rule set version. The unique index `(tripId, seatKey)` prevents duplicate generation; publishing twice is idempotent.

## 2. Locking seats (all channels use this one service)

`POST /api/v1/trips/:tripId/seat-locks` with `Idempotency-Key` header and `{ seatKeys: ["L-A1","L-A2"], boardingPointId, droppingPointId }`.

`SeatLockService.lockSeats()`:

1. Validate trip is `SCHEDULED` or `BOARDING`, before sales cut-off, seat count ≤ max per booking, gender restrictions.
2. Check idempotency record `(holder, key)`. If it exists, return the stored result.
3. Optional Redis pre-check (`SET lockhint:{tripId}:{seatKey} NX PX`) to reject obvious conflicts fast. **Correctness never depends on it**; if Redis is down this step is skipped.
4. Start a MongoDB transaction. For each seat, in sorted `seatKey` order (avoids deadlock-style write conflicts):

```ts
const now = new Date();
const updated = await inventory.findOneAndUpdate(
  {
    tripId, seatKey,
    $or: [
      { status: 'AVAILABLE' },
      { status: 'LOCKED', 'lock.expiresAt': { $lte: now } },   // lazy expiry
      { status: 'LOCKED', 'lock.holderId': holderId },         // same holder re-selecting
    ],
  },
  { $set: { status: 'LOCKED', lock: { lockId, holderType, holderId, channel, partnerId, expiresAt } },
    $inc: { version: 1 } },
  { session, returnDocument: 'after' },
);
if (!updated) throw new ApiException('SEAT_NOT_AVAILABLE', { seatKey });   // aborts whole transaction
```

5. Insert `seat_lock_groups` and `inventory_events`, update `trips.seatCounts`, commit.
6. On `WriteConflict` retry (bounded, 3 attempts). If still conflicting → `SEAT_NOT_AVAILABLE`.
7. Emit `seat.locked` via outbox; notify Socket.IO room `trip:{tripId}` so other viewers refresh.

Lock duration comes from `system_settings.booking.seatLockDurationSeconds` (default 300). It is extended **once** to cover the payment window when a payment order is created (`booking.paymentWindowSeconds`, default 600, capped).

## 3. Lock expiry

- **Lazy:** the lock query above treats an expired lock as available, so correctness does not depend on any job running.
- **Active:** `seat-lock-expiry.worker.ts` runs every 15 s, flips expired `LOCKED` rows back to `AVAILABLE` (conditional on the same `lockId` and `expiresAt <= now`), marks lock groups `EXPIRED`, moves bookings in `SEAT_LOCKED`/`PAYMENT_PENDING` without captured payment to `EXPIRED`, and emits `seat.released`.

## 4. Confirmation (only after payment verification)

`BookingConfirmationService.confirm(bookingId, verifiedPayment)` in one transaction:

```ts
const result = await inventory.updateMany(
  { tripId, seatKey: { $in: seatKeys }, status: 'LOCKED', 'lock.lockId': booking.lockId },
  { $set: { status: 'BOOKED', bookingId, lock: null }, $inc: { version: 1 } },
  { session },
);
if (result.modifiedCount !== seatKeys.length) → lock was lost → go to recovery (below)
```

Then: booking `CONFIRMED`, PNR assigned, payment `SUCCESS` linked, coupon `REDEEMED`, `booking_financials` computed, `outbox_events` (`booking.confirmed`, `payment.success`). Ticket generation and notifications happen in workers.

The partial unique index on `booking_seats (tripId, seatKey) where status = ACTIVE` is the second guard: even a bug in the service cannot insert two active booking seats for one trip seat.

## 5. Lock lost before payment verified (edge cases 3, 4, 6, 7)

1. Try to re-acquire **all** original seats atomically (same conditional update as locking, holder = booking).
2. If all re-acquired → confirm normally.
3. If not → booking `EXPIRED`, automatic full refund with reason `LOCK_EXPIRED_AFTER_PAYMENT`, customer notified with an apology message and alternative-seat link. Never confirm a seat someone else now holds.

## 6. Idempotency

| Operation | Key |
|---|---|
| Seat lock | `Idempotency-Key` header, scoped per holder |
| Booking create | `Idempotency-Key` header, scoped per customer or partner (unique index) |
| Payment order create | one active order per booking |
| Payment webhook | unique `(gateway, gatewayEventId)` + status transition guard |
| Booking confirm | confirmation is a no-op if booking already `CONFIRMED` with the same paymentId |
| Partner webhooks out | unique `(subscriptionId, eventId)` |

`idempotency_records` stores a hash of the request body. The same key with a different body returns `IDEMPOTENCY_KEY_REUSED` (422).

## 7. Channels

Customer app, WhatsApp-assisted booking, operator counter booking and partner API all call the same `SeatLockService` and `BookingService`. `channel` and `partnerId` are recorded on the lock and booking for reporting. Operator counter bookings use `bookings.create` permission and the operator's data scope.

## 8. Fail-safe behaviour

| Failure | Behaviour |
|---|---|
| MongoDB unavailable | Search may serve cached trip lists marked stale; seat lock and booking return `SERVICE_UNAVAILABLE` (503). Never assume availability. |
| Redis unavailable | Pre-check skipped, rate limiting falls back to in-memory per instance, BullMQ jobs wait; locking and booking still correct. |
| Payment gateway unavailable | Payment order creation fails with `PAYMENT_PROVIDER_UNAVAILABLE`; lock stays until expiry; booking not confirmed. |

## 9. Concurrency test targets

- 500 concurrent lock requests on one seat → exactly 1 success, 499 `SEAT_NOT_AVAILABLE`.
- 500 users on 40 different seats of one trip → no seat locked twice; sum of seatCounts equals total.
- Customer + partner on the same seat → exactly 1 success.
- Same booking request replayed 20 times with one key → 1 booking.
- Same payment webhook delivered 10 times concurrently → 1 confirmation, 1 notification.
- Lock expires during payment → recovery path in section 5.
