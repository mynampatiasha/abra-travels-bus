# Local Development Infrastructure

Docker Desktop (WSL 2 backend). Docker's data disk lives on `D:\Docker\wsl-data`, so images, containers and the named volumes below are stored on D:.

| Service | Container | Host address | Data volume |
|---|---|---|---|
| MongoDB 8 (replica set `rs0`) | abra-mongodb | `127.0.0.1:27017` | `abra_mongodb_data`, `abra_mongodb_config` |
| Redis 7.4 (AOF, noeviction) | abra-redis | `127.0.0.1:6379` | `abra_redis_data` |
| Backend API (optional) | abra-backend-api | `127.0.0.1:4000` | — (profile `application`) |
| BullMQ worker + outbox relay (optional) | abra-backend-worker | — | — (profile `application`) |

All services share the `abra_network` Docker network.

## First-time setup

Run from `D:\New_project\abra-travels`:

```powershell
Copy-Item infrastructure\.env.example infrastructure\.env
```

## Daily commands

```powershell
docker compose -f infrastructure/docker-compose.development.yml --env-file infrastructure/.env up -d
```
```powershell
docker compose -f infrastructure/docker-compose.development.yml ps
```
```powershell
docker compose -f infrastructure/docker-compose.development.yml down
```

`down` keeps the data. `down -v` **deletes MongoDB and Redis data** — only use it to reset the development database on purpose.

### Backend in Docker (optional)

The backend normally runs on Windows (`npm run start:dev` and `npm run worker:dev` in `backend/`). To run API and worker in containers instead (needs `backend/.env.development`, created by `npm run env:create-development`):

```powershell
docker compose -f infrastructure/docker-compose.development.yml --env-file infrastructure/.env --profile application up -d --build
```
```powershell
docker compose -f infrastructure/docker-compose.development.yml --env-file infrastructure/.env --profile application stop backend-api backend-worker
```

Do not run the Windows and the Docker backend at the same time on port 4000. Production image: `docker build --target production -t abra-travels-backend backend` (see `documentation/background-jobs.md`).

If the Docker Desktop window does not open, the engine can be started from the terminal with `docker desktop start`.

## Connecting

- MongoDB Compass: `mongodb://localhost:27017/?directConnection=true`
- Backend on Windows: `MONGODB_URI=mongodb://localhost:27017/abra_travels?directConnection=true`
- Backend in Docker: `mongodb://mongodb:27017/abra_travels?directConnection=true` (set by compose)
- Redis on Windows: `redis://localhost:6379` · in Docker: `redis://redis:6379` (no password in development; ports are bound to 127.0.0.1 only)
- Docker network: `abra_network` (bridge). Containers reach each other by service name: `mongodb`, `redis`.

## Verify

```powershell
docker exec abra-mongodb mongosh --quiet --eval "rs.status().members[0].stateStr"
```
Expected: `PRIMARY`.

```powershell
docker exec abra-redis redis-cli ping
```
Expected: `PONG`.
