# Background Jobs: BullMQ, Worker Process and Event Outbox

How work leaves the request path. Code: `backend/src/queues`, `backend/src/events`, `backend/src/workers`, `backend/src/worker.ts`.

```
State change (MongoDB transaction) ──▶ outbox_events (same transaction, PENDING)
                                             │
                     worker process: OutboxRelayWorker → OutboxRelayService
                                             │  claim (lease) → Queue.add(jobId = eventId) → PUBLISHED
                                             ▼
                              BullMQ queue "domain-events" (Redis)
                                             │
                     worker process: QueueWorkerHost → DomainEventDispatchProcessor
                                             │
                              handlers registered per event type (idempotent)
```

## 1. Redis responsibilities

Redis carries **jobs, cache and rate limits only**. It is never the source of truth: every job is derived from state already committed to MongoDB (the outbox), so losing Redis loses no business fact. After a Redis loss, unpublished and re-claimed outbox events are simply published again.

| Connection | Options | Used by |
|---|---|---|
| Shared client (`REDIS_CLIENT`) | `maxRetriesPerRequest: 3`, offline queue off | readiness ping, later cache / rate limits |
| BullMQ producer | `maxRetriesPerRequest: 1`, offline queue on | `Queue.add`, counts — fails in about 1 s when Redis is down instead of hanging |
| BullMQ worker | `maxRetriesPerRequest: null` (required by BullMQ) | blocking job fetch; waits and reconnects by itself |

The producer keeps the offline queue **on**: BullMQ sends a version check the moment a `Queue` is constructed, and with the offline queue off that check fails before the socket opens and the queue is unusable for good.

## 2. Queues

Defined once in `queues/queue-names.ts`. Currently one queue: `domain-events`. Business queues (notifications per channel, partner webhooks, refunds ...) are added by the phase that implements them.

`QueueRegistry` is the only place that creates `Queue` instances: one per name, key prefix `QUEUE_PREFIX`, default job options from configuration:

| Setting | Default | Meaning |
|---|---|---|
| `QUEUE_PREFIX` | `abra` | Redis key namespace (`abra:domain-events:...`) |
| `QUEUE_DEFAULT_ATTEMPTS` | 5 | Attempts per job |
| `QUEUE_BACKOFF_DELAY_MS` | 5000 | Exponential back-off base between attempts |
| `WORKER_CONCURRENCY` | 5 | Jobs processed in parallel per queue per worker process |
| `QUEUE_LAG_ALERT_MS` | 60000 | Oldest waiting job / unpublished event age that raises a lag warning |

Completed jobs are kept 24 h (so a re-published event with the same job id is recognised as a duplicate); failed jobs are kept 7 days for inspection. A job that throws `UnrecoverableError` is not retried.

## 3. Redis outage and recovery

| Situation | Behaviour |
|---|---|
| Redis up | Queue initialises; readiness 200 |
| Redis down, queue already initialised | `add` / counts fail fast (≈1 s); readiness 503 (`redis`, `queues` down); liveness stays 200. When Redis returns the **same** queue instance reconnects by itself |
| Redis down when the queue is first created | Creation does not throw; initialisation fails in the background and the instance is marked failed |
| Queue requested again after a failed initialisation | `QueueRegistry.get()` closes the broken instance and creates a new one — at most once per second per queue (`QUEUE_RECREATE_INTERVAL_MS`), so a long outage does not churn connections. Never more than one live instance per queue name |
| Redis returns | The next `get()` (relay pass or readiness check) yields a working queue. No process restart needed |
| Worker started while Redis is down | Keeps retrying the connection and starts processing when Redis returns |
| Shutdown | Every queue is closed with a 5 s upper bound each; a queue that never connected cannot block shutdown |

BullMQ never retries a failed initialisation, which is why the registry replaces the instance instead of waiting for it.

## 4. Event outbox

Collection `outbox_events` (unique `eventId`, indexes on `status + availableAt` and `status + lockedUntil`).

```
PENDING ──claim──▶ PUBLISHING ──enqueue ok──▶ PUBLISHED
   ▲                   │
   └── retry (back-off, lastError) ── enqueue failed
                       │
                       └── attempts ≥ OUTBOX_MAX_PUBLISH_ATTEMPTS ──▶ FAILED ──requeue──▶ PENDING
```

- **Recording:** `OutboxService.record(event, session)` only accepts a session that is inside a transaction, so an event exists if and only if its state change committed.
- **Claiming:** one atomic `findOneAndUpdate` per event sets `PUBLISHING`, `lockedBy`, `lockedUntil` (lease `OUTBOX_LEASE_MS`) and increments `attempts`. A claimed event is invisible to other relays until its lease expires, so several worker processes can relay safely.
- **Publishing:** `Queue.add(type, message, { jobId: eventId })`. The event id is the job id everywhere, so publishing twice enqueues once.
- **Marking:** `PUBLISHED` (with `publishedAt`) only after the enqueue succeeded and only if this relay still holds the lease.
- **Crash between enqueue and mark:** the lease expires, another pass re-claims and re-adds; BullMQ deduplicates on the job id; the event is marked. Delivery is at-least-once and handlers are idempotent.
- **Failure:** the error text (max 500 chars) is stored in `lastError`; the retry is scheduled with back-off 1 s, 2 s, 4 s ... capped at 60 s. After `OUTBOX_MAX_PUBLISH_ATTEMPTS` (default 20) the event is parked as `FAILED`: kept in MongoDB, logged as an error, shown in readiness warnings, and can be requeued. Events are never deleted or silently dropped.

| Setting | Default |
|---|---|
| `OUTBOX_POLL_INTERVAL_MS` | 1000 |
| `OUTBOX_BATCH_SIZE` | 100 |
| `OUTBOX_LEASE_MS` | 30000 |
| `OUTBOX_MAX_PUBLISH_ATTEMPTS` | 20 |

No booking, payment or inventory events exist yet; they are added with those modules.

## 5. Worker process

Same codebase and image as the API, separate process, no HTTP server.

| Environment | Command |
|---|---|
| Development (watch) | `npm run worker:dev` in `backend/` |
| Development (once) | `npm run worker` |
| Production | `node dist/worker.js` (`npm run worker:prod`) |
| Docker image | `docker run <image> node dist/worker.js` |

On start it validates configuration, verifies the MongoDB replica set, ensures indexes, starts one BullMQ `Worker` per queue and the outbox relay loop. On `SIGTERM` / `SIGINT` it stops the relay after the current pass, lets active jobs finish, then closes workers, queues and database connections and exits with code 0.

Handlers register themselves in `DomainEventHandlerRegistry` by event type. A handler error fails the job, BullMQ retries it with back-off and all handlers of that event run again — handlers must be idempotent.

## 6. Health

| Endpoint | Depends on | Result |
|---|---|---|
| `GET /health/live` | nothing | 200 while the process serves HTTP — also during a Redis or MongoDB outage |
| `GET /health/ready` | MongoDB ping, Redis ping, queue counts, outbox stats (2 s timeout each) | 200, or 503 `SERVICE_UNAVAILABLE` if any of them is down |

Readiness details: per queue `waiting, active, delayed, failed, oldestWaitingAgeMs, lagging, workers`; outbox `pending, failed, oldestPendingAgeMs, lagging`.

Worker-side problems are **warnings**, not failures — taking the API out of the load balancer would not fix a worker: no worker connected, queue lag, failed jobs, outbox lag, `FAILED` outbox events.

## 7. Docker

`backend/Dockerfile` (Node 24, multi-stage):

| Stage | Purpose |
|---|---|
| `development` | Full dependencies; used by `infrastructure/docker-compose.development.yml` with `src` bind-mounted |
| `build` | Compiles TypeScript |
| `production` | Runtime dependencies + `dist` only, runs as the non-root `node` user |

```powershell
docker build --target production -t abra-travels-backend backend
```

- API: default command `node dist/main.js`. Worker: `node dist/worker.js` on the same image.
- Configuration is passed as environment variables at run time. `.dockerignore` keeps `.env*` files, keys, host `node_modules`, `dist`, logs, database dumps and local storage out of the build context.
- No `HEALTHCHECK` in the image, because the worker has no HTTP server; the API's liveness probe is defined where the container runs (Compose, orchestrator).
- `node` is PID 1 (exec-form `CMD`), so `docker stop` delivers `SIGTERM` and shutdown is graceful.
- The development Compose services run `nest start --watch`; stopping those containers ends the watcher without the graceful sequence. Graceful shutdown applies to the production image.
- Logs are JSON. The pretty printer (`pino-pretty`) is a development dependency; if it is not installed the logger uses JSON even with `NODE_ENV=development`.

## 8. Tests

Unit tests (`*.spec.ts`) use fakes. E2E tests (`*.e2e-spec.ts`, `npm run test:e2e`) use the real Docker MongoDB and Redis: a separate disposable database (`abra_travels_test`) and queue prefixes starting with `abra-test`, never the development database or the `abra` prefix. Suites clean up after themselves, and `jest.e2e.global-teardown.js` drops the test database and deletes the test queue keys once more at the end of every run, even when a suite failed. `redis-outage.e2e-spec.ts` really stops and starts the `abra-redis` container and always starts it again.
