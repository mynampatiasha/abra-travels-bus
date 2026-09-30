# Live Tracking Architecture

```
Driver app (foreground service, trip started)
   │  every 10 s moving / 60 s stationary, batched when offline
   ▼
Socket.IO /tracking  "location.update"  (or POST /driver/trips/:tripId/locations fallback)
   │  auth: driver assigned to trip, trip in BOARDING/DEPARTED/IN_TRANSIT/DELAYED
   ▼
LiveTrackingService
   ├─ validate (accuracy ≤ 200 m, timestamp not in future, speed plausible, device matches)
   ├─ upsert trip_live_status (latest point, ETA, trackingState=LIVE)
   ├─ insert driver_location_points (TTL 30 days)
   ├─ Redis pub → Socket room trip:{tripId} → customer / operator / admin viewers
   └─ throttled partner webhook tracking.updated (max 1/min per trip)
```

## Staleness (never fake location)

`tracking-staleness.worker.ts` every 30 s:

| Age of last point | trackingState | UI |
|---|---|---|
| < 2 min | LIVE | Live marker |
| 2–10 min | STALE | Grey marker, "Last updated 6 min ago" |
| > 10 min or driver app disconnected | OFFLINE | "Tracking unavailable. Last known location at 22:14", admin/operator alert |
| trip not started | NOT_STARTED | "Tracking starts when the bus departs" |

The customer app shows only what `trip_live_status` holds. No interpolation or simulated movement.

## ETA

ETA to the customer's boarding and dropping point = MapsProvider route duration from the last location (cached 2 min per trip), falling back to schedule offset + current delay. ETA is labelled "approximate".

## Privacy and battery

- GPS runs only while the driver has an active trip in a running state; stops automatically on ARRIVED/CANCELLED.
- Android foreground-service notification is visible to the driver throughout.
- Customers can view tracking only for trips they hold a booking on, or through a time-limited trip-share link.
- Raw points expire after 30 days; only the latest point is kept after that.

## Development

A `DevelopmentGpsRouteReplay` tool (admin dev tools, disabled in production) replays a recorded GPS track through the same driver endpoint for testing. It is labelled as a replay and sends points exactly like a real device.
