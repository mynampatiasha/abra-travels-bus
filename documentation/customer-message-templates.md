# Customer Message Templates

Every message Abra Travels sends to a customer about login, bookings, payments, trips, support and safety.

- **WhatsApp** variables use Meta's format `{{1}}`, `{{2}}`. Each WhatsApp template must be approved by Meta before use.
- **SMS is switched off for now** (see "In the code"); the SMS texts are kept for later.
- **SMS** variables use the DLT format `{#var#}`. Each SMS template must be registered on DLT (India) with the sender ID `ABRA`.
- **Email** subjects use the backend payload names in braces, for example `{pnr}`.
- Write English first; every template is then translated into the 8 app languages (`multilingual.md`). A missing language falls back to English.
- Template key = `key + channel + language + version` (`notification-architecture.md`).

**Tone:** friendly and professional. WhatsApp messages greet the customer by name, use a few simple emojis to mark key details, and end with `– Team Abra Travels`. Bad news (delay, cancellation) starts with an apology. Safety messages stay calm and serious, with no emojis. SMS stays short and plain because of DLT and 160-character limits. The OTP text is fixed by Meta's Authentication format.

Status: **Built** = working today. **Rule exists** = the event router has the rule (WhatsApp + email) but the feature that sends the event is not built yet. **New** = not in the code yet.

---

## Summary

| # | Key | Meta category | WhatsApp | SMS | Email | Push / app | Status |
|---|---|---|:-:|:-:|:-:|:-:|---|
| 1 | `login_otp` | Authentication | ✅ | ✅ | | | Built |
| 2 | `booking_confirmed` | Utility | ✅ | ✅ | ✅ | ✅ | Rule exists, SMS missing |
| 3 | `payment_failed` | Utility | ✅ | ✅ | ✅ | ✅ | Rule exists, SMS missing |
| 4 | `booking_cancelled` | Utility | ✅ | ✅ | ✅ | ✅ | Rule exists, SMS missing |
| 5 | `refund_processed` | Utility | ✅ | ✅ | ✅ | ✅ | Rule exists, SMS missing |
| 6 | `travel_reminder_24h` | Utility | ✅ | ✅ | | ✅ | New |
| 7 | `travel_reminder_2h` | Utility | ✅ | ✅ | | ✅ | New |
| 8 | `boarding_started` | Utility | ✅ | ✅ | | ✅ | Rule exists, SMS missing |
| 9 | `bus_delayed` | Utility | ✅ | ✅ | ✅ | ✅ | Rule exists, SMS missing |
| 10 | `trip_cancelled` | Utility | ✅ | ✅ | ✅ | ✅ | App only today; WhatsApp, SMS, email new |
| 11 | `bus_changed` | Utility | ✅ | ✅ | ✅ | ✅ | New |
| 12 | `trip_completed_feedback` | Utility | ✅ | | | ✅ | App only today; WhatsApp new |
| 13 | `support_replied` | Utility | ✅ | | ✅ | ✅ | App only today; WhatsApp, email new |
| 14 | `sos_acknowledged` | Utility | ✅ | ✅ | | ✅ | App only today; WhatsApp, SMS new |
| 15 | `sos_emergency_contact` | Utility | ✅ | ✅ | | | New |
| 16 | `trip_share` | Utility | ✅ | ✅ | | | New (optional) |

Mandatory messages (2–5, 8–11, 14, 15) must reach the customer on at least one channel.

## In the code

- **Words:** `backend/src/modules/notification-templates/customer_message_templates.ts` holds every template. Change the words there and here together. `metaTemplateBody` and `dltTemplateBody` print the exact text to submit to Meta and DLT.
- **Who gets what:** `backend/src/modules/notifications/event_router_core.ts`. Each event names its template, its channels and the payload fields of the contact.
- **Channels:** WhatsApp and email go to every address the booking's contact has, and the app notice and push cover a WhatsApp failure.
- **SMS is not used for now.** It is commented out in `event_router_core.ts` (the `ALL_CHANNELS` and `PHONE_CHANNELS` lists), so no SMS is sent; the emergency contact is told on WhatsApp. The SMS texts above are kept for later. To turn SMS back on, put `'SMS'` back in both lists: SMS then goes only when WhatsApp did not reach the person.
- **Meta approval:** until a template is approved, its WhatsApp message goes through the general notification template (title + message). Once Meta approves a template under its key (for example `booking_confirmed`), add the key to **Approved templates** in the WhatsApp settings (`approvedTemplateKeys`), and from then on it is sent as itself, with its own `{{1}}, {{2}}` and button.
- **DLT:** every SMS is handed to the SMS provider with its template key, which the provider maps to the registered DLT template id.
- **Events the booking, trip and safety features must send** (with the payload fields named in the tables above): `booking.confirmed`, `payment.failed`, `booking.cancelled`, `refund.updated`, `booking.reminder` (`reminder: '24H' | '2H'`), `booking.boarding-started`, `booking.trip-delayed`, `booking.trip-cancelled`, `booking.bus-changed`, `booking.trip-arrived`, `ticket.agent-replied`, `sos.raised`, `sos.updated`, `trip.shared`.

---

## A. Login

### 1. `login_otp`

**Event:** `POST /auth/otp/send` · **Category:** Authentication · **Status:** Built

**WhatsApp**
```
{{1}} is your Abra Travels verification code. Do not share it with anyone.
```
Button: **Copy code**

| Var | Value |
|---|---|
| {{1}} | OTP code |

**SMS**
```
{#var#} is your Abra Travels login code. Valid for 5 minutes. Do not share it. -ABRA
```

---

## B. Booking and payment

### 2. `booking_confirmed`

**Event:** `booking.confirmed` · **Sent to:** the booking's contact (not only the account holder)

**WhatsApp**: header: document (ticket PDF)
```
Hi {{1}} 👋, great news! Your bus ticket is confirmed ✅

🎫 PNR: {{2}}
🚌 Route: {{3}}
🕒 Departure: {{4}}
💺 Seats: {{5}}
📍 Boarding: {{6}}
💳 Amount paid: {{7}}

Please reach your boarding point 15 minutes early. Wishing you a safe and comfortable journey!
– Team Abra Travels
```
Buttons: **View ticket** (URL), **Track bus** (URL)

| Var | Payload field | Example |
|---|---|---|
| {{1}} | contactName | Ravi |
| {{2}} | pnr | ABRX7058A |
| {{3}} | route | Hyderabad to Bengaluru |
| {{4}} | departureText | 12 Jan, 10:30 pm |
| {{5}} | seatsText | L4, L5 |
| {{6}} | boardingPoint | Ameerpet, Metro Pillar 1012 |
| {{7}} | amountText | Rs 1,250 |

**SMS**
```
Abra Travels: Booking confirmed. PNR {#var#}, {#var#}, {#var#}, Seats {#var#}. Ticket: {#var#} -ABRA
```
Vars: pnr, route, departureText, seatsText, ticket link

**Email**: Subject: `Booking confirmed: {pnr}`. Body: all details above, operator name and phone, cancellation policy, ticket PDF attached, buttons View ticket / Track bus.

**Push**: Title: `Booking confirmed` · Body: `{pnr}: {route}, {departureText}`

---

### 3. `payment_failed`

**Event:** `payment.failed`

**WhatsApp**
```
Hi {{1}}, we couldn't complete your payment of {{2}} for {{3}}.
Reason: {{4}}

Don't worry, your seats are held for the next {{5}} minutes. Tap below to try again.
If any amount was deducted, it will be refunded automatically within 5-7 working days.
– Team Abra Travels
```
Button: **Retry payment** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | amountText |
| {{3}} | route |
| {{4}} | reason |
| {{5}} | holdMinutes |

**SMS**
```
Abra Travels: Payment of {#var#} failed. Seats held for {#var#} min. Retry: {#var#} -ABRA
```

**Email**: Subject: `Payment failed: please try again`

**Push**: Title: `Payment failed` · Body: `Seats held for {holdMinutes} min. Tap to retry.`

---

### 4. `booking_cancelled`

**Event:** `booking.cancelled` (cancelled by the customer)

**WhatsApp**
```
Hi {{1}}, your booking {{2}} for {{3}} ({{4}}) has been cancelled as requested.

💰 Refund amount: {{5}}
Your refund is on its way and will reach your original payment method in 5-7 working days.

We hope to see you on board again soon!
– Team Abra Travels
```
Button: **View booking** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | pnr |
| {{3}} | route |
| {{4}} | departureText |
| {{5}} | refundAmountText |

**SMS**
```
Abra Travels: PNR {#var#} cancelled. Refund {#var#} in 5-7 working days. -ABRA
```

**Email**: Subject: `Booking cancelled: {pnr}`. Body: fare paid, cancellation charge, refund amount, timeline.

**Push**: Title: `Booking cancelled` · Body: `{pnr} on {route}. Your refund has started.`

---

### 5. `refund_processed`

**Event:** `refund.updated` with `status = PAID`

**WhatsApp**
```
Hi {{1}}, good news! 🎉 Your refund of {{2}} for PNR {{3}} has been processed.
Reference no: {{4}}

It may take 1-3 working days to reflect in your account, depending on your bank.
– Team Abra Travels
```

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | amountText |
| {{3}} | pnr |
| {{4}} | reference |

**SMS**
```
Abra Travels: Refund {#var#} for PNR {#var#} processed. Ref {#var#} -ABRA
```

**Email**: Subject: `Refund processed: {pnr}`

**Push**: Title: `Refund {statusLabel}` · Body: `Refund of {amountText} is {statusLabel}.`

---

## C. Before the trip

### 6. `travel_reminder_24h`

**Event:** `booking.reminder` (scheduled, 24 hours before departure) · **Status:** New

**WhatsApp**
```
Hi {{1}} 👋, just a friendly reminder: your trip is tomorrow!

🚌 {{2}}
🕒 Departure: {{3}}
🎫 PNR: {{4}}
💺 Seats: {{5}}
📍 Boarding point: {{6}}

Please carry a valid photo ID. See you on board!
– Team Abra Travels
```
Buttons: **View ticket** (URL), **Boarding point map** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | route |
| {{3}} | departureTime |
| {{4}} | pnr |
| {{5}} | seatsText |
| {{6}} | boardingPoint |

**SMS**
```
Abra Travels: Your bus {#var#} leaves tomorrow {#var#}. PNR {#var#}. Boarding: {#var#} -ABRA
```

**Push**: Title: `Your trip is tomorrow` · Body: `{route} at {departureTime}`

---

### 7. `travel_reminder_2h`

**Event:** `booking.reminder` (scheduled, 2 hours before departure) · **Status:** New

**WhatsApp**
```
Hi {{1}}, your bus leaves in 2 hours, at {{2}} 🕒

🚌 Bus no: {{3}}
👤 Driver: {{4}} ({{5}})
📍 Boarding point: {{6}}

Please plan to reach 15 minutes early. Have a pleasant journey!
– Team Abra Travels
```
Buttons: **Track bus** (URL), **Call operator** (phone)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | departureTime |
| {{3}} | busRegistration |
| {{4}} | driverName |
| {{5}} | driverPhone |
| {{6}} | boardingPoint |

**SMS**
```
Abra Travels: Bus {#var#} leaves at {#var#}. Driver {#var#} {#var#}. Boarding {#var#} -ABRA
```

**Push**: Title: `Your bus leaves in 2 hours` · Body: `Bus {busRegistration} from {boardingPoint}`

---

## D. Trip day

### 8. `boarding_started`

**Event:** `booking.boarding-started`

**WhatsApp**
```
Hi {{1}}, boarding has started! 🚌
PNR {{2}}: bus {{3}} is now at {{4}}.
💺 Seats: {{5}}

Please make your way to the bus now. Enjoy your trip!
– Team Abra Travels
```
Button: **Track bus** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | pnr |
| {{3}} | busRegistration |
| {{4}} | boardingPoint |
| {{5}} | seatsText |

**SMS**
```
Abra Travels: Boarding started. Bus {#var#} at {#var#}. PNR {#var#} -ABRA
```

**Push**: Title: `Boarding started` · Body: `Your bus {busRegistration} is boarding now.`

---

### 9. `bus_delayed`

**Event:** `booking.trip-delayed`

**WhatsApp**
```
Hi {{1}}, we're sorry, your bus on {{2}} (PNR {{3}}) is running about {{4}} minutes late.
Reason: {{5}}
🕒 New expected time: {{6}}

You can track your bus live below. Thank you for your patience.
– Team Abra Travels
```
Button: **Track live** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | route |
| {{3}} | pnr |
| {{4}} | minutes |
| {{5}} | reason |
| {{6}} | newDepartureTime |

**SMS**
```
Abra Travels: Bus for PNR {#var#} is {#var#} min late. New time {#var#} -ABRA
```

**Email**: Subject: `Bus delayed: {pnr}`

**Push**: Title: `Bus running late` · Body: `{route}: about {minutes} minutes late. {reason}`

---

### 10. `trip_cancelled`

**Event:** `trip.cancelled` (cancelled by the operator; one message per booking)

**WhatsApp**
```
Hi {{1}}, we're very sorry. Your trip {{2}} on {{3}} (PNR {{4}}) has been cancelled by the operator.

💰 A full refund of {{5}} has been started and will reach you in 5-7 working days.

We'd be glad to help you find another bus. Tap below to book again or contact our support team.
– Team Abra Travels
```
Buttons: **Book another bus** (URL), **Contact support** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | route |
| {{3}} | departureText |
| {{4}} | pnr |
| {{5}} | amountText |

**SMS**
```
Abra Travels: Trip PNR {#var#} on {#var#} cancelled by operator. Full refund {#var#} started -ABRA
```

**Email**: Subject: `Trip cancelled: {pnr}`

**Push**: Title: `Trip cancelled` · Body: `{route} on {departureText} was cancelled. Your full refund has started.`

---

### 11. `bus_changed`

**Event:** `booking.bus-changed` · **Status:** New

**WhatsApp**
```
Hi {{1}}, a quick update on your trip (PNR {{2}}): your bus has changed.

🚌 New bus: {{3}} ({{4}})
💺 Your seats: {{5}}
🕒 Departure (unchanged): {{6}}

Everything else stays the same. Have a safe journey!
– Team Abra Travels
```
Button: **View ticket** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | pnr |
| {{3}} | busRegistration |
| {{4}} | busTypeLabel |
| {{5}} | seatsText |
| {{6}} | departureText |

**SMS**
```
Abra Travels: Bus changed for PNR {#var#}. New bus {#var#}, seats {#var#} -ABRA
```

**Email**: Subject: `Bus changed for your trip: {pnr}`

**Push**: Title: `Your bus has changed` · Body: `New bus {busRegistration}. Seats {seatsText}.`

---

### 12. `trip_completed_feedback`

**Event:** `trip.arrived`

**WhatsApp**
```
Welcome to your destination, {{1}}! 🙏
Thank you for travelling with Abra Travels on {{2}}. We'd love to hear how your trip went. It takes just one tap.
```
Button: **Rate trip** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | route |

**Push**: Title: `You have arrived` · Body: `Thanks for travelling. Please rate your trip.`

---

## E. Support and safety

### 13. `support_replied`

**Event:** `ticket.agent-replied`

**WhatsApp**
```
Hi {{1}}, our support team has replied to your ticket {{2}}:
"{{3}}"

Tap below to read the full reply. We're here to help!
– Team Abra Travels
```
Button: **Open ticket** (URL)

| Var | Payload field |
|---|---|
| {{1}} | contactName |
| {{2}} | ticketRef |
| {{3}} | subject |

**Email**: Subject: `Reply to your ticket {ticketRef}`

**Push**: Title: `Support replied` · Body: `{subject}`

---

### 14. `sos_acknowledged`

**Event:** `sos.updated` with `status = ACKNOWLEDGED` (to the person who raised it)

**WhatsApp**
```
We have received your SOS alert. Our safety team is calling you right now. Please stay calm and keep your phone close.
If you are in immediate danger, call 112.
– Abra Travels Safety Team
```

**SMS**
```
Abra Travels: We received your SOS. Our safety team is calling you now. In danger? Call 112. -ABRA
```

**Push**: Title: `SOS {statusLabel}` · Body: `Our safety team has your alert and is calling you.`

---

### 15. `sos_emergency_contact`

**Event:** `sos.raised` raised by a customer (never by a driver), to the customer's saved emergency contact · **Status:** New

The contact has no Abra account, so the message is calm, plain and has no emojis.

**WhatsApp**
```
Urgent: {{1}} has raised an SOS alert on their Abra Travels bus.
Bus: {{2}}
Route: {{3}}
Live location: {{4}}

Our safety team is responding now. If you cannot reach them, call 112.
– Abra Travels Safety Team
```

| Var | Payload field |
|---|---|
| {{1}} | customerName |
| {{2}} | busRegistration |
| {{3}} | route |
| {{4}} | trackingUrl |

Contact fields: emergencyContactName, emergencyContactPhone

**SMS** (switched off for now)
```
ALERT: {#var#} raised an SOS on bus {#var#} ({#var#}). Live location: {#var#}. Abra safety team is on it. -ABRA
```
Vars: customer name, busRegistration, route, live tracking link

---

### 16. `trip_share` (optional)

**Event:** customer taps **Share trip** · **Status:** New

**WhatsApp**
```
Hi! {{1}} is sharing their live bus trip with you 🚌
Route: {{2}}
Bus: {{3}}
Follow the journey live here: {{4}}
```

| Var | Value |
|---|---|
| {{1}} | customer name |
| {{2}} | route |
| {{3}} | busRegistration |
| {{4}} | live tracking link |

**SMS**
```
Abra Travels: {#var#} is sharing their bus trip {#var#}, bus {#var#}. Track: {#var#} -ABRA
```

---

## Checklist before go-live

- [ ] Pick the WhatsApp provider (Meta Cloud API or a BSP) and submit templates 1–14 and 16 for approval
- [ ] Pick the SMS provider, register the sender ID `ABRA` and all SMS templates on DLT
- [ ] Pick the email provider and set up the sending domain (SPF, DKIM)
- [ ] Translate every template into the 8 languages and submit each language version to Meta
- [ ] Load the approved provider template ids into `notification_templates`
