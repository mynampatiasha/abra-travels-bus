# syntax=docker/dockerfile:1
#
# Abra Travels backend — one image for the HTTP API and the BullMQ worker.
#
#   API:     docker run <image>                       (default command: node dist/main.js)
#   Worker:  docker run <image> node dist/worker.js
#
# Configuration comes from environment variables at run time (documentation/environment-variables.md).
# No .env file, secret or host node_modules is copied into any stage (see .dockerignore).

ARG NODE_VERSION=24

# ── base: shared runtime settings ────────────────────────────────────────────
FROM node:${NODE_VERSION}-slim AS base
WORKDIR /app
ENV NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

# ── dependencies: full install (build tools included), cached on the lockfile ─
FROM base AS dependencies
COPY package.json package-lock.json ./
RUN npm ci

# ── development: used by infrastructure/docker-compose.development.yml ───────
# Source is bind-mounted over /app/src by Compose; the command (start:dev / worker:dev) is set there.
FROM dependencies AS development
ENV NODE_ENV=development
COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
EXPOSE 4000
CMD ["npm", "run", "start:dev"]

# ── build: compile TypeScript to dist/ ───────────────────────────────────────
FROM dependencies AS build
COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build

# ── production-dependencies: runtime packages only ───────────────────────────
FROM base AS production-dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ── production: minimal runtime image, non-root ──────────────────────────────
FROM base AS production
ENV NODE_ENV=production \
    PORT=4000
COPY --from=production-dependencies --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node package.json ./
USER node
EXPOSE 4000
# No HEALTHCHECK here: the same image runs the worker, which has no HTTP server. The API's
# liveness probe (/health/live) is configured where the container is run (Compose, orchestrator).
# Exec form: node is PID 1 and receives SIGTERM directly, so Nest's shutdown hooks run
# (in-flight requests and jobs finish, then MongoDB / Redis / queue connections close).
CMD ["node", "dist/main.js"]
