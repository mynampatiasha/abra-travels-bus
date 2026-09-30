# Notification Architecture

```
State change (in transaction) ─▶ outbox_events ─▶ outbox-relay.worker ─▶ BullMQ "domain-events"
                                                                              │
                                                     notification-planner.worker
                                   (event → recipients → channels from preferences + mandatory rules
                                    → language → template version) → notifications rows (QUEUED)
                                                                              │
                          ┌───────────────┬───────────────┬───────────────┬───┴───────────┐
                     whatsapp queue    sms queue      email queue     push queue     in-app (direct write)
                          │               │               │               │
                   WhatsAppProvider   SmsProvider    EmailProvider   PushProvider (FCM)
```

## Rules

- Notifications never run inside the booking transaction. Provider failure never changes booking state.
- Idempotent: unique `(eventId, channel, recipientKey)` on `notifications`, so relay retries do not double-send.
- Retries: exponential back-off, 5 attempts per channel. If WhatsApp fails permanently for a mandatory message, fall back to SMS, then email.
- Channel selection: transactional messages (booking confirmed, ticket, cancellation, refund, trip delay/cancel, safety) are mandatory on at least one channel; marketing respects `notificationPreferences` and consent.
- Templates: `notification_templates` keyed by `key + channel + language + version`, with variables, provider template id and approval status (WhatsApp templates must be approved by Meta). Missing language → fall back to English and log `translation.missing`.
- Delivery receipts from providers update `notifications.status` via provider webhooks.
- Admin → Notifications screen shows queue depth, failure rates per provider and per template, and allows resend with `notifications.manage`.

## Events → messages

| Event | Customer | Operator | Admin |
|---|---|---|---|
| booking.confirmed | WhatsApp/SMS/email/push + ticket | in-app | — |
| payment.failed | push/SMS with retry link | — | alert if rate spikes |
| seat lock about to expire (60 s) | in-app timer only | — | — |
| travel reminder (T-24h, T-2h) | WhatsApp/push | — | — |
| trip.delayed / trip.cancelled / bus.changed | all mandatory channels | WhatsApp summary | alert |
| refund.created / refund.completed | WhatsApp/SMS/email | — | — |
| safety SOS | confirmation to reporter + emergency contact SMS | WhatsApp alert | WhatsApp + in-app critical alert |
| webhook / payment / inventory failures | — | — | WhatsApp admin bot + dashboard alert |
