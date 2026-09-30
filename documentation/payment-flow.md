# Payment, Refund and Settlement Flow

## 1. Gateway abstraction

```ts
interface PaymentGateway {
  readonly gatewayKey: 'razorpay' | 'development' | string;
  createOrder(input: { bookingId; amountPaise; currency; receipt; customer }): Promise<GatewayOrder>;
  fetchPaymentStatus(gatewayOrderId: string): Promise<GatewayPaymentStatus>;
  verifyWebhookSignature(rawBody: Buffer, headers: Record<string,string>): boolean;
  parseWebhookEvent(rawBody: Buffer): GatewayWebhookEvent;           // normalised event
  verifyClientCallbackSignature(payload): boolean;
  createRefund(input: { gatewayPaymentId; amountPaise; refundNumber }): Promise<GatewayRefund>;
  fetchRefundStatus(gatewayRefundId: string): Promise<GatewayRefundStatus>;
}
```

`RazorpayPaymentGateway` is the first production adapter. `DevelopmentPaymentGateway` is a **clearly labelled test gateway** for local development only: it shows a simulated checkout page served by the backend (success / failure / pending / delayed success), and then sends a *signed* webhook to our own webhook endpoint, so the real verification path is exercised. It is disabled in production by configuration validation.

## 2. Pay flow

```
Customer app ──POST /payments/orders──▶ PaymentService
   │                                       ├─ booking must be SEAT_LOCKED/PAYMENT_PENDING, lock valid
   │                                       ├─ recompute total server-side (fare snapshot + fees − coupon)
   │                                       ├─ gateway.createOrder()  → payments(CREATED)
   │                                       └─ booking → PAYMENT_PENDING, lock extended to payment window
   │◀── { gatewayOrderId, keyId, amount } ─┘
   │
   ├── opens Razorpay checkout (UPI / card / net banking)
   │
   ├── client callback ─▶ POST /payments/:id/client-callback ─▶ verify signature ─▶ fetchPaymentStatus ─▶ PaymentVerificationService
   │
Gateway ── webhook ─▶ POST /webhooks/payments/razorpay ─▶ verify signature (raw body) ─▶ insert payment_gateway_events (unique eventId)
                                                        ─▶ duplicate? → 200 OK, no-op
                                                        ─▶ PaymentVerificationService
```

`PaymentVerificationService.handleVerifiedPayment()` is the **only** place that marks a payment `SUCCESS`, and it requires:

1. Valid signature (webhook or client callback).
2. Gateway status fetch says captured.
3. Amount and currency equal the booking total.
4. Payment not already processed (status guard).

Then it calls `BookingConfirmationService.confirm()`; see [seat-locking.md](seat-locking.md). Whichever of webhook or client callback arrives first confirms the booking; the other becomes a no-op.

## 3. Edge cases

| Case | Handling |
|---|---|
| Browser closed after paying | Webhook confirms; customer sees booking in My Bookings + notification |
| Backend timeout during callback | Client polls `GET /bookings/:id`; webhook or status poll worker completes confirmation |
| Payment pending | `payment-status-poll.worker.ts` polls with back-off up to the gateway window; lock is held until payment window end; after that the late-payment recovery path applies |
| Duplicate webhook | Unique `(gateway, gatewayEventId)` + status guard |
| Lock expired, payment succeeded | Re-acquire seats or auto-refund (seat-locking.md §5) |
| Amount mismatch | Payment flagged `AMOUNT_MISMATCH`, booking not confirmed, admin alert, auto refund |
| Payment reversed / chargeback | Payment `REVERSED`, booking flagged for admin review, operator settlement adjustment |
| Gateway down | `PAYMENT_PROVIDER_UNAVAILABLE`; nothing confirmed |

## 4. Reconciliation

`payment-reconciliation.worker.ts` (hourly and daily) compares gateway settlements/payments with `payments`. Mismatches (captured at gateway but not confirmed, confirmed but not captured, amount differences) create admin alerts and appear on the Admin Payments → Reconciliation screen.

## 5. Cancellation and refund

1. `GET /bookings/:id/cancellation-quote` computes per-seat refund from the **policy snapshot stored on the booking** (time-before-departure slabs, e.g. >24h 90%, 12–24h 75%, 6–12h 50%, <6h 0%; configurable per operator).
2. `POST /bookings/:id/cancel` (transaction): booking seats `CANCELLED`, inventory seats back to `AVAILABLE` (conditional on `bookingId`), booking `PARTIALLY_CANCELLED`/`CANCELLED`, refund `APPROVED` (auto) or `REQUESTED` (if manual approval is configured), financials adjusted, outbox events.
3. `refund-processing.worker.ts` calls `gateway.createRefund()`, then polls status → `COMPLETED` → booking `REFUNDED` when all refunds are complete → notifications.
4. Trip cancelled by operator: 100% refund of every active seat, automatic.

## 6. Commission and settlement

- On confirmation, `CommissionService` picks the highest-priority matching `commission_rules` (operator → route → partner → channel → date) and writes `booking_financials` with the rule id and version.
- Cancellations and refunds write adjustment amounts to `booking_financials`.
- `settlement-generation.worker.ts` (weekly, configurable) groups completed trips per operator for the period: gross, commission, partner commission, taxes/fees, refunds, adjustments, **net**. Settlements move `GENERATED → APPROVED → PAID` by users with `settlements.approve`, with payment reference; every step audited.
