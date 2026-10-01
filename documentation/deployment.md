# Deployment, CI/CD and Operations

## Environments

`development` (local) → `test` (CI) → `staging` (production-like, gateway test mode) → `production`. Payment and inventory changes are validated on staging with concurrency and load tests before promotion.

## Local development

- Backend: `npm run start:dev` (API) and `npm run worker:dev` (workers), after `npm run env:create-development` once. Alternatively both run in Docker with the Compose profile `application` (see `infrastructure/README.md`).
- Image: `backend/Dockerfile` builds one image for API and worker ([background-jobs.md](background-jobs.md) §7).
- MongoDB **replica set** + Redis, either:
  - `infrastructure/docker-compose.development.yml` (Docker Desktop), or
  - MongoDB Atlas free cluster + Upstash/Memurai Redis, via `MONGODB_URI` / `REDIS_URL`.
- Storage: local filesystem adapter in development, MinIO optional.

## CI/CD (GitHub Actions)

```
push / PR ─▶ backend: install → lint → type-check → unit → integration (replica set) → build image
          ─▶ flutter: analyze → test (each app & package) → build web
          ─▶ public_website: lint → type-check → build → Lighthouse
          ─▶ security: npm audit, dependency review, secret scan
main ─▶ deploy staging ─▶ e2e + smoke ─▶ manual approval ─▶ production (rolling) ─▶ smoke ─▶ automatic rollback on failed health checks
```

Database migrations (indexes, backfills) are versioned idempotent scripts in `backend/src/database/migrations`, run before the new version receives traffic. Rollback = redeploy the previous image; migrations stay backward compatible for one version.

## Production topology

API containers (≥ 2, auto-scaling), worker containers (≥ 2, per-queue concurrency), MongoDB Atlas replica set (3 nodes, PITR), managed Redis with persistence, S3 + CDN, Flutter web and Next.js on CDN/edge. Health endpoints `/health/live` and `/health/ready` (Mongo, Redis, queue lag).

## Monitoring

Structured JSON logs with requestId and redaction (passwords, tokens, card data and OTPs are never logged). Metrics: latency, error rate, seat-lock conflicts, payment success rate, webhook failures, queue lag, tracking staleness. Alerts to on-call and the WhatsApp admin bot.

## Backups and disaster recovery

- Atlas continuous backup with point-in-time recovery; daily snapshots kept 35 days, monthly kept 1 year.
- Object storage versioning + cross-region replication.
- **Quarterly restore test** into a scratch environment, with a recorded result.
- Targets: RPO ≤ 5 min, RTO ≤ 1 h. Runbooks for DB failover, Redis loss (safe by design), gateway outage, notification outage, region outage.
