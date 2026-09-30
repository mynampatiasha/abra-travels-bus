# Women Safety Architecture

> Safety workflows must be reviewed for legal, operational and privacy requirements before production launch (escalation contacts, police/helpline integration such as 112, data retention).

## Features

| Feature | Behaviour |
|---|---|
| SOS | Hold-to-trigger button (3 s) in the customer app during an active booking, and in the driver app. Creates `safety_incidents` (type SOS, severity CRITICAL) with the device location and the trip's live location. |
| Emergency contacts | Up to 3 per customer (name, phone). SOS sends them an SMS/WhatsApp with trip details and a live trip-share link. |
| Trip sharing | Time-limited link (valid until arrival + 2 h) showing bus, route and live status. No passenger list, no other passengers' seats. Revocable. |
| Incident report | Categories: harassment, unsafe driving, unsafe behaviour, medical, other. Optional attachments (object storage). During or after the trip. |
| Women-only seat preference | Gender restriction on layout seats, enforced server-side at lock time. |
| Safety information | Operator verification, bus and driver details (as legally appropriate), helpline numbers — managed in CMS. |
| Admin safety dashboard | Live incident queue, SLA timers, map, assignment, timeline, escalation, resolution notes. |

## SOS workflow

```
SOS pressed ─▶ POST /safety/sos (authenticated; if offline → device SMS to the safety number)
  ─▶ incident OPEN (audited) ─▶ outbox safety.sos
       ├─ admin critical alert (dashboard sound + WhatsApp admin bot)
       ├─ operator operations contact alert (WhatsApp)
       ├─ emergency contacts SMS/WhatsApp with share link
       └─ customer confirmation "Help has been notified" + call-support button
  ─▶ not acknowledged within SLA (default 2 min) ─▶ auto ESCALATED to the next escalation level
```

Every incident action (view, acknowledge, escalate, note, resolve) is audited. Access requires `safety.view` / `safety.manage`. Operators see only incidents on their own trips, without reporter contact details unless an admin grants them.

## Abuse handling

SOS is never blocked. Repeated false alarms from one user are flagged for review instead.
