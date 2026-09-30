# State Machines

Every transition below is implemented as a table in `backend/src/modules/<module>/<entity>-state-machine.ts`. Any transition not listed throws `INVALID_STATE_TRANSITION` (HTTP 409). Every transition writes a timeline entry and, where relevant, an audit log and an outbox event.

## 1. Seat (trip_seat_inventory.status)

```
             lock (atomic, conditional)             confirm (lockId matches, payment verified)
 AVAILABLE ───────────────────────────────▶ LOCKED ──────────────────────────────────────────▶ BOOKED
     ▲  ▲                                     │                                                  │
     │  └──── release / expire / payment fail ┘                                                  │
     │                                                                                           │
     └──────────────────────────── cancel seat / trip cancelled ─────────────────────────────────┘
 AVAILABLE ◀──▶ BLOCKED   (operator or admin block/unblock with inventory.block / inventory.unblock)
```

`RELEASED` and `CANCELLED` from the PDF are recorded as **event types** in `inventory_events`, not as persistent seat states. A released or cancelled seat is simply `AVAILABLE` again. This keeps the "can I sell this seat" question to one condition.

## 2. Seat lock group

`ACTIVE → CONSUMED` (booking confirmed) · `ACTIVE → RELEASED` (user deselects, payment failed) · `ACTIVE → EXPIRED` (expiry worker or lazy expiry).

## 3. Booking

```
INITIATED ─▶ SEAT_LOCKED ─▶ PAYMENT_PENDING ─▶ CONFIRMED ─▶ COMPLETED (trip arrived)
    │             │               │  │              │
    │             │               │  │              ├─▶ PARTIALLY_CANCELLED ─▶ CANCELLED
    │             │               │  │              └─▶ CANCELLED
    ▼             ▼               ▼  ▼
  FAILED       EXPIRED         FAILED  EXPIRED ── (late payment success) ──▶ CONFIRMED if seats re-acquired
                                                                          └─▶ stays EXPIRED + auto refund
CANCELLED ─▶ REFUND_PENDING ─▶ REFUNDED
```

| From | To | Trigger | Guard |
|---|---|---|---|
| INITIATED | SEAT_LOCKED | seats locked | lock group ACTIVE |
| SEAT_LOCKED | PAYMENT_PENDING | payment order created | passengers valid, total recomputed server-side |
| PAYMENT_PENDING | CONFIRMED | payment verified | amount == booking total; seats still held by this lockId (or re-acquired) |
| PAYMENT_PENDING | FAILED | payment failed / cancelled | — |
| SEAT_LOCKED, PAYMENT_PENDING | EXPIRED | lock expired and no payment captured | — |
| EXPIRED | CONFIRMED | late verified payment and **all** seats re-locked atomically | otherwise auto-refund `LOCK_EXPIRED_AFTER_PAYMENT` |
| CONFIRMED | PARTIALLY_CANCELLED | some seats cancelled | policy allows, before departure cut-off |
| CONFIRMED, PARTIALLY_CANCELLED | CANCELLED | all remaining seats cancelled / trip cancelled | — |
| CANCELLED | REFUND_PENDING | refund created | refundable amount > 0 |
| REFUND_PENDING | REFUNDED | all refunds completed | — |
| CONFIRMED | COMPLETED | trip ARRIVED | — |

`PARTIALLY_CANCELLED` and `COMPLETED` are added to the PDF's list because partial cancellation and "booking completed" are required by sections 19 and 121.

## 4. Payment

```
CREATED ─▶ PENDING ─▶ SUCCESS ─▶ PARTIALLY_REFUNDED ─▶ REFUNDED
   │          │                        └─────────────────▲
   ▼          ▼
CANCELLED   FAILED        SUCCESS ─▶ REVERSED (chargeback / gateway reversal)
```

- `SUCCESS` is set only by the verification service (valid signature **and** gateway status fetch **and** amount match).
- A second `SUCCESS` event for the same payment is a no-op (unique `gatewayEventId` + status check).
- `PENDING` older than the gateway's window is polled by `payment-status-poll.worker.ts` before being marked `FAILED`.

## 5. Trip

```
DRAFT ─▶ SCHEDULED (published, inventory generated) ─▶ BOARDING ─▶ DEPARTED ─▶ IN_TRANSIT ─▶ ARRIVED
                │                                           │           │            │
                │                                           └───────────┴────────────┴─▶ DELAYED ─▶ (back to previous running state)
                └─▶ CANCELLED (from DRAFT, SCHEDULED, BOARDING, DELAYED)
```

- Publishing (`DRAFT → SCHEDULED`) generates `trip_seat_inventory` from the seat layout version in one transaction.
- `DELAYED` stores `delayMinutes` and the previous state; the trip returns to it when the delay is cleared.
- Every trip status change emits `trip.updated` (and `trip.delayed` / `trip.cancelled`) to notifications and partner webhooks.

## 6. Refund

`REQUESTED → APPROVED → PROCESSING → COMPLETED` · `REQUESTED → REJECTED` · `PROCESSING → FAILED → PROCESSING (retry)`.
Automatic refunds (trip cancelled, late payment after expiry) skip `REQUESTED` and start at `APPROVED`.

## 7. Settlement

`DRAFT → GENERATED → APPROVED → PAID` · `GENERATED → DISPUTED → GENERATED` · `APPROVED → FAILED → APPROVED`.

## 8. Operator

`PENDING_APPROVAL → ACTIVE` · `PENDING_APPROVAL → REJECTED` · `ACTIVE ↔ SUSPENDED`. A suspended operator's trips stay visible to existing bookings but are hidden from search; no new trips can be published.

## 9. Safety incident

`OPEN → ACKNOWLEDGED → ESCALATED → RESOLVED → CLOSED`. An `SOS` incident that stays `OPEN` for more than the configured SLA (default 2 minutes) is escalated automatically.
