# GO-SAAS — M2A: Local Staging Feasibility & Isolation Audit

**Project:** GO-SAAS Payment Gateway Simulator
**Phase:** M2A — Local Staging Feasibility & Isolation Audit (AUDIT AND PLANNING ONLY)
**Report date:** Fri Oct 16 2026
**Report path:** `docs/mobile-local-staging-plan.md`
**Repositories inspected:**
- Backend: `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend`
- Flutter: `/run/media/dhika/Dhika/payment_simulator`
- Dashboard: `/run/media/dhika/Dhika/pay-gate-dashboard`

**Safety status:** Zero runtime/database changes made. No services started, stopped, or reconfigured. No migrations executed. No `.env` or secret values printed. No state-changing HTTP requests sent.

---

## 1. Executive Summary

Isolated local staging is **feasible** using existing repository tooling (Docker Compose, `migrate/migrate:v4.18.1`, the backend binary, and `flutter_dotenv`), at zero cost and with no paid services.

**Key verified facts:**
- The backend `config.Load()` requires only `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` as mandatory environment variables; all other settings have safe defaults.
- The backend does **not** auto-run migrations at startup; it calls `CheckSchema()` which requires `schema_migrations.version >= 22` and `dirty = false`.
- Migrations `000001` through `000025` exist as sequential up/down SQL pairs; migration `000022` is the minimum schema version required by the current binary.
- A disposable PostgreSQL container pattern already exists in `docker-compose.phase-11-verify.yml` (read-only reference; not to be executed here).
- All Flutter tests use fake `ApiClient` instances — there are **no live-backend integration tests** today.
- The Flutter app reads a single `API_BASE_URL` from `.env` (currently `http://192.168.110.245:8081`, which does not respond from this machine); there are no per-platform URL overrides.
- The protected port-8081 backend must not be touched; the isolated staging backend must use a different port.

**Key prerequisites remaining (not yet verified by execution):**
- A dedicated PostgreSQL instance (container or local) reachable by the isolated backend.
- A migrated test database at schema version >= 22.
- Test merchant/dashboard-user credentials provisioned into that test database (via the onboarding API, not by direct DB writes).
- A Flutter `.env` pointing at the isolated backend's reachable address/port.
- An Android emulator or physical device (none currently available; `flutter emulators` reports none).
- Confirmation that the isolated backend's port is free and does not collide with the protected port-8081 service.

**GO / NO-GO:** **NO-GO for immediate runtime execution.** The plan is complete and safe to execute in a separately authorized phase, but no isolated staging environment exists yet. Provisioning and executing the plan is the recommended next step.

---

## 2. Current Verified Environment

| Item | Value | Classification | Source |
|---|---|---|---|
| Backend repo git status | Clean (last commit `48cba6f maintenance backend`) | VERIFIED | `git status` |
| Flutter repo git status | Clean except 2 new report docs | VERIFIED | `git status` |
| Dashboard repo git status | Clean | VERIFIED | `git status` |
| Protected backend listening | `0.0.0.0:8081` (container `pay-gate-app`, healthy, ~4h old) | VERIFIED | `ss`, `docker ps` |
| Backend `/health` on 127.0.0.1:8081 | HTTP 200, `{"success":true,"data":{"status":"ok"}}` | VERIFIED | `curl` (read-only) |
| Flutter-configured `API_BASE_URL` | `http://192.168.110.245:8081` — **not reachable** from this machine | VERIFIED | `.env` read; `curl` failed (HTTP 000) |
| This machine's interface | `192.168.102.215/23` (not `192.168.110.x`) | VERIFIED | `ip addr` |
| Flutter emulator | None available | VERIFIED | `flutter emulators` |
| Connected Flutter devices | Linux desktop, Chrome web | VERIFIED | `flutter devices` |
| `flutter analyze` | Passes; 1 INFO lint (pre-existing) | VERIFIED | `flutter analyze` |
| `flutter test` | 363 passed, 0 failed | VERIFIED | `flutter test` |
| Backend migrations present | `000001` … `000025` (up/down pairs) | VERIFIED | `ls migrations/` |
| Minimum schema version required | 22 (`ExpectedMigrationVersion`) | VERIFIED | `pkg/database/postgres.go:23` |
| Backend auto-runs migrations | No — `CheckSchema()` only validates; migrations run separately | VERIFIED | `cmd/server/main.go:116-119`, `config.go` |
| Required backend env vars | `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | VERIFIED | `config.go:597-612` |
| Backend default listen port | `8080` (`APP_PORT`, default) | VERIFIED | `config.go:320` |
| Backend default bind host | All interfaces (`:port`) unless `APP_BIND_HOST` set | VERIFIED | `config.go:1095-1107`, `main.go:950` |
| Flutter tests using live backend | None — all use `_FakeApiClient` | VERIFIED | grep of `test/` |
| Existing disposable-DB Compose pattern | `docker-compose.phase-11-verify.yml` (PostgreSQL only) | VERIFIED | file read |

---

## 3. Existing Repository Configuration

### 3.1 Backend — Docker Compose files (reference only; not to be executed)

| File | Purpose | Safety note |
|---|---|---|
| `docker-compose.yml` | Main development Compose: `app` + one-shot `migrate`; references an **external** PostgreSQL (`DB_HOST=host.docker.internal` default). | Existing file; do not modify. The `app` container publishes `8081:8080` — this is the protected port-8081 service. |
| `docker-compose.phase-11-verify.yml` | Disposable PostgreSQL-only Compose (port `55433` by default, overridable via `PHASE11_DB_PORT`). Required env vars: `PHASE11_DB_USER`, `PHASE11_DB_PASSWORD`, `PHASE11_DB_NAME`. | Read-only reference. Documents the disposable-container pattern without reusing the protected service. |
| `docker-compose.elk.yml` | Observability (ELK stack). | Not relevant to staging isolation; do not touch. |

**No dedicated staging or test Compose file exists** in the repository. A new, separately named Compose project would need to be created for isolated local staging (see Section 6).

### 3.2 Backend — Configuration loading (`internal/config/config.go`)

`config.Load()` calls `godotenv.Load()` then reads environment variables.

**Required variables (startup fails if missing):**
- `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` (via `requiredEnv`)

**Variables with safe defaults (sanitized names only; values not printed):**
- `APP_NAME` → `payment-gateway`
- `APP_ENV` → `development` (must be `development`/`test`/`production`)
- `APP_PORT` → `8080`
- `APP_BIND_HOST` → unset (binds all interfaces `:port`; set to `127.0.0.1` for loopback-only)
- `DB_PORT` → `5432`
- `DB_SSLMODE` → `disable` (must be `verify-full` in production)
- `PAYMENT_PROVIDER` → `mock` (rejected in production)
- `PAYMENT_PROVIDER_TIMEOUT` → `15s`
- `MIDTRANS_BASE_URL` → `https://app.sandbox.midtrans.com` (only used if provider=midtrans)
- `IDEMPOTENCY_TTL` → `24h`
- `PAYMENT_EXPIRY_ENABLED` → `true`; interval `30s`; batch `100`
- `RATE_LIMIT_ENABLED` → `true` (limits 10/60/120 per minute)
- `WEBHOOK_DELIVERY_ENABLED` → `true`
- `EMAIL_ENABLED` → `false` (SMTP path inert when disabled)
- `PAYMENT_SIMULATOR_ENABLED` → `false` (fail-closed; requires `SIMULATOR_MERCHANT_ID` UUID when enabled; rejected in production)
- `LEGACY_API_CREDENTIALS_ENABLED` → unset → `true` in development/test, `false` otherwise
- `TRUSTED_PROXIES` → unset (nil; production requires explicit value)
- `WEBHOOK_REQUIRE_HTTPS` → `false` in development, `true` in production
- `AUTH_ACCESS_TOKEN_TTL` → `15m`; `AUTH_REFRESH_TOKEN_TTL` → `168h`
- `HTTP_MAX_BODY_BYTES` → `1048576` (1 MiB)
- Product image defaults (5 MiB max, 4096px dimension)

**Infrastructure dependencies at startup:**
- PostgreSQL (mandatory via `DB_*` vars; `NewPool` + `Ping` + `CheckSchema`)
- No Redis, no Kafka, no external service required when `PAYMENT_PROVIDER=mock` and `EMAIL_ENABLED=false`
- Midtrans only if `PAYMENT_PROVIDER=midtrans` (not the case for local staging)
- SMTP only if `EMAIL_ENABLED=true` (not required for staging)

### 3.3 Backend — Startup sequence (`cmd/server/main.go`)

1. `config.Load()` — exits if invalid
2. `database.NewPool(ctx, DSN)` — connects + pings PostgreSQL; exits if unreachable
3. `database.CheckSchema(ctx, pool)` — queries `schema_migrations(version, dirty)`; requires `version >= 22` and `dirty = false`; exits if not ready. **Does not run migrations.**
4. `validateSimulatorMerchant()` — if simulator enabled, confirms `SIMULATOR_MERCHANT_ID` exists and is active (DB read)
5. Builds Gin engine, registers all routes
6. Starts background workers: expiry, merchant webhook delivery, email outbox, email cleanup (all optional via config flags)
7. `ListenAndServe` on `BuildListenAddr(bindHost, port)` — default `:8080`

**No automatic migration execution at startup.** Migrations must be applied separately before starting the backend.

### 3.4 Dashboard — configuration

- `.env.example`: `VITE_API_BASE_URL=http://localhost:8081`, `VITE_ENABLE_SIMULATOR=false`
- API client (`src/lib/api/client.ts`): `VITE_API_BASE_URL` required in production builds; HTTPS required for non-local production; defaults to empty in dev
- Simulator (`src/lib/simulator/config.ts`): enabled only when `MODE !== production` AND `VITE_ENABLE_SIMULATOR === 'true'`
- Authenticated calls send credentials: `"include"` (HttpOnly refresh cookie)
- **Not in scope for modification** in this phase; noted for context only.

### 3.5 Flutter — configuration

- `.env`: single `API_BASE_URL=http://192.168.110.245:8081` (not reachable from this machine)
- `.env.example`: `API_BASE_URL=http://localhost:8081`
- `AppEnvironment.validate()` fails fast if `API_BASE_URL` is empty; single source of truth; no per-platform overrides; no flavor mechanism
- `flutter_dotenv` loads `.env` at startup before any network client is created
- **No live-backend integration tests** — all 41 test files use fake `ApiClient` instances

---

## 4. Database Isolation Analysis

### 4.1 Migration files

Migrations `000001` through `000025` exist as sequential `*.up.sql` / `*.down.sql` pairs. Notable migrations:
- `000001_create_merchants` — merchants table, uses `gen_random_uuid()` (requires `pgcrypto` extension)
- `000002_create_transactions` — core transactions/payments table
- `000003_create_payment_attempts`
- `000007_create_idempotency_keys`
- `000014_create_merchant_users` — dashboard users
- `000020_create_categories_products` — catalog
- `000021_create_orders` — orders
- `000022_order_payment_link` — adds `transactions.order_id` (minimum schema version 22)
- `000025_password_reset_tokens` — latest migration

### 4.2 Schema tracking

The application tracks migrations in a `schema_migrations` table with columns `version` (int) and `dirty` (boolean). `CheckSchema()` requires `version >= ExpectedMigrationVersion (22)` and `dirty = false`.

### 4.3 Required PostgreSQL features

- **Version:** `postgres:16-alpine` is used in the existing disposable Compose pattern (`docker-compose.phase-11-verify.yml`). Not explicitly mandated elsewhere, but 16 is the documented baseline.
- **Extensions:** `gen_random_uuid()` is used in `000001_create_merchants.up.sql`, which requires the `pgcrypto` extension (or PostgreSQL 13+ built-in `pgcrypto`). In PostgreSQL 16, `gen_random_uuid()` is available in `pgcrypto` and also as a built-in in some distributions; the `migrate/migrate` image runs the SQL as-is, so the target database must support `gen_random_uuid()`.
- **No other extensions** were observed as mandatory in the migration files reviewed.

### 4.4 Migration sequence

Verified sequential order `000001` → `000025`. Each has a matching `.down.sql` for rollback. The `migrate/migrate:v4.18.1` image is the documented runner (used in `docker-compose.yml` and `docker-compose.phase-11-verify.yml`).

### 4.5 Seed data requirements

The application requires at least one **merchant** and one **dashboard user (OWNER)** plus a **Phase 5C API credential** to exercise the payment flow. These are created via:
- `POST /api/v1/admin/onboarding/merchants` (requires `X-Admin-Key`, creates merchant + OWNER user + API credential atomically)
- No seed SQL files or seed scripts were found in the repository; test data must be provisioned through the API after migration.

### 4.6 Automatic migration at startup

**No.** `main.go` calls `CheckSchema()` (validation only) — it does not invoke the `migrate` tool. Migrations are a separate operational step (documented in `docker-compose.yml` `migrate` service and `phase-1a`/`phase-2` CI reports).

### 4.7 Separate PostgreSQL container practicality

**Yes.** The `docker-compose.phase-11-verify.yml` pattern demonstrates a standalone `postgres:16-alpine` container with its own named volume (`phase11_verify_pgdata`), dedicated port, and dedicated database/user/password. A new Compose project can replicate this with explicitly named resources (new container name, new network, new volume, new port) without touching the protected port-8081 service or its network/volume.

### 4.8 Avoiding existing networks/volumes

**Yes.** A new Compose project can define:
- A new network (e.g., `paygate-stage-net`)
- A new named volume (e.g., `paygate-stage-pgdata`)
- A new container name (e.g., `paygate-stage-db`)
- A new port (must not collide with 8081, 5432, 5173, 55433)

No existing Docker networks or volumes need to be reused or modified.

### 4.9 Can application startup be configured without connecting to an existing database?

**No — the backend requires a reachable, migrated PostgreSQL at startup.** `NewPool` + `Ping` + `CheckSchema` all run before the HTTP server starts. However, that database can be the isolated test database (separate container, separate credentials) rather than the protected port-8081 backend's database.

---

## 5. Flutter Networking Analysis

### 5.1 `API_BASE_URL` configuration

- Single value from `.env` via `flutter_dotenv`; `AppEnvironment.validate()` rejects empty/missing
- Current value: `http://192.168.110.245:8081` — **not reachable** from this machine (connection refused; machine interface is `192.168.102.215/23`)
- `.env.example`: `http://localhost:8081`
- **No per-platform overrides:** no emulator-specific (`10.0.2.2`), no device-specific, no web-specific base URL. One `API_BASE_URL` serves all build targets.
- No HTTPS enforcement in the Flutter client; scheme follows whatever is in `API_BASE_URL`
- `NetworkConfig.defaultHeaders`: `Content-Type: application/json`, `Accept: application/json` only; no TLS pinning; no certificate validation override

### 5.2 Target-specific reachability

| Target | How it reaches the backend | Notes |
|---|---|---|
| Flutter Web (Chrome) | `API_BASE_URL` must be reachable from the browser; CORS must allow the web origin | Dashboard Vite dev runs on `5173`; Flutter web on a different port would need CORS allowance on the backend |
| Android Emulator | `API_BASE_URL` must use the host's LAN IP or `10.0.2.2` (Android emulator's special alias to host loopback) | No emulator currently available; no emulator-specific override exists in Flutter code |
| Physical device | `API_BASE_URL` must use the host's LAN IP reachable from the device | Requires same Wi-Fi/LAN; no device-specific override exists |
| Linux desktop | `API_BASE_URL` can use `127.0.0.1` (localhost) if backend binds to loopback or all interfaces | Most straightforward for local testing |

### 5.3 CORS requirements for Flutter Web

The backend `CORS` middleware is configured with `CORS_ALLOWED_ORIGINS` (from env). Flutter Web running on a different origin than the backend must be listed in `CORS_ALLOWED_ORIGINS`, or requests will be blocked by the browser. This must be configured on the isolated backend.

### 5.4 Android cleartext HTTP

Android by default disallows cleartext (HTTP) traffic in production builds. If the isolated staging backend uses HTTP (not HTTPS), Android would require `android:usesCleartextTraffic="true"` or a network security config. This is a platform limitation to document, not a blocker for Linux desktop testing.

### 5.5 Existing integration test support

**None.** All 41 Flutter test files use `_FakeApiClient` (canned responses/errors). There is no `integration_test` directory and no test that connects to a live backend. Real-device/emulator validation against a live backend would be new work.

---

## 6. Proposed Local Architecture

```
┌─────────────────┐      HTTP            ┌──────────────────┐
│ Flutter app     │ ───────────────────> │ Isolated backend │
│ (Linux desktop/ │  on stage port       │ (Go binary)      │
│  emulator/web)  │  e.g. 127.0.0.1:XXXX │ APP_PORT=XXXX    │
└─────────────────┘                      │ APP_ENV=test     │
                                         │ PAYMENT_PROVIDER=mock│
                                         └────────┬─────────┘
                                                  │ PG
                                                  ▼
                                         ┌──────────────────┐
                                         │ Isolated Postgre │
                                         │ (postgres:16)    │
                                         │ stage port YYYY  │
                                         │ separate DB/user │
                                         └──────────────────┘
```

**Design principles:**
1. **Isolated backend process/container** — separate from the protected port-8081 service; different port; separate `APP_ENV=test` configuration
2. **Isolated PostgreSQL database** — separate container/process, separate database name, user, and password; never the protected backend's database
3. **Explicitly separate configuration** — separate `.env` for backend and separate `.env` for Flutter; never editing the protected backend's `.env`
4. **Separate test credentials** — provisioned via the onboarding API into the test database; never production credentials
5. **No production/live payment provider** — `PAYMENT_PROVIDER=mock`; no Midtrans; no SMTP (`EMAIL_ENABLED=false`); no external webhook targets
6. **No dependency on protected port-8081 backend** — no shared network, volume, database, or credentials
7. **Clear cleanup procedure** — `docker compose down` (without `-v` if preserving the volume for inspection, or with `-v` only on the stage-specific named volume) targeting only the stage Compose project; cannot delete unrelated data because resources are explicitly named and scoped to the stage project

**Preferred implementation:** A dedicated Docker Compose project in the backend repository (new file, e.g., `docker-compose.stage.yml` or run via `docker compose -f <new-file>`), with explicitly named container, network, and volume. This is supported safely because:
- The backend Dockerfile already copies migrations and builds the server binary
- `migrate/migrate:v4.18.1` is available as the migration runner
- The `phase-11-verify.yml` disposable-DB pattern is a proven template

**Alternative (no Docker):** Run `postgres:16` locally (if available) and run the backend binary directly (`go run ./cmd/server` or the built binary) with stage-specific env vars. This avoids Docker entirely but requires a local PostgreSQL installation.

---

## 7. Required Prerequisites

The following must be available before executing the plan (Section 8). None are assumed to exist; each is classified:

| # | Prerequisite | Status | Classification | Notes |
|---|---|---|---|---|
| 1 | Docker available | Available | VERIFIED | `docker ps` works; `pay-gate-app` container present |
| 2 | `migrate/migrate:v4.18.1` image accessible | Available | VERIFIED | Referenced in existing Compose files |
| 3 | `go` toolchain to build backend | Available | VERIFIED | Backend builds in Docker; `go.mod` present |
| 4 | Flutter SDK | Available | VERIFIED | 3.47.5 stable |
| 5 | Free TCP port for isolated backend | UNKNOWN | Must not collide with 8081, 5432, 5173, 55433 |
| 6 | Free TCP port for isolated PostgreSQL | UNKNOWN | Must not collide with existing services |
| 7 | PostgreSQL client or `migrate` for applying migrations | Available via Docker image | VERIFIED | `migrate/migrate:v4.18.1` |
| 8 | Test merchant/dashboard-user credentials | NOT PROVISIONED | UNKNOWN | Must be created via onboarding API into test DB |
| 9 | Admin API key (`X-Admin-Key`) for onboarding | NOT AVAILABLE | UNKNOWN | Required to provision test tenant; not printed/assumed |
| 10 | Android emulator or physical device | None | VERIFIED | `flutter emulators` → none; limits mobile-specific validation |
| 11 | Backend `.env` for stage (new file) | NOT CREATED | UNKNOWN | Must not modify existing `.env` |
| 12 | Flutter `.env` for stage (new file) | NOT CREATED | UNKNOWN | Must point `API_BASE_URL` at isolated backend |

---

## 8. Step-by-Step Execution Plan

**Planned for a separately authorized execution phase.** Every command below includes working directory, purpose, read/write classification, expected result, verification, and cleanup/rollback.

**Pre-execution gate (must pass before Step 1):**
- Confirm the target database and services are isolated from the protected port-8081 backend (different port, different container/process, different database name/credentials).
- Confirm no existing service is listening on the chosen stage ports.
- Confirm `ADMIN_API_KEY` for the stage backend is available (not printed in this report).

### Phase A — Provision isolated infrastructure

| Step | Command | Working directory | Purpose | Read/Write | Expected result | Verification | Rollback |
|---|---|---|---|---|---|---|---|
| A1 | `docker network create paygate-stage-net` | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Create isolated Docker network | Write (Docker network) | Network created | `docker network ls` shows `paygate-stage-net` | `docker network rm paygate-stage-net` |
| A2 | `docker volume create paygate-stage-pgdata` | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Create isolated PostgreSQL data volume | Write (Docker volume) | Volume created | `docker volume ls` shows `paygate-stage-pgdata` | `docker volume rm paygate-stage-pgdata` |
| A3 | Create `docker-compose.stage.yml` (new file) with `postgres:16-alpine` on a free port, mounted `paygate-stage-pgdata`, network `paygate-stage-net`, with stage DB user/password/name from stage `.env` | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Define isolated PostgreSQL service | Write (new file) | Compose file exists | `docker compose -f docker-compose.stage.yml config` validates | Delete the new file |
| A4 | `docker compose -f docker-compose.stage.yml up -d postgres` | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Start isolated PostgreSQL | Write (container start) | PostgreSQL healthy on stage port | `docker compose -f docker-compose.stage.yml ps` shows healthy; `pg_isready` against stage port | `docker compose -f docker-compose.stage.yml stop postgres` |

### Phase B — Migrate the isolated database

| Step | Command | Working directory | Purpose | Read/Write | Expected result | Verification | Rollback |
|---|---|---|---|---|---|---|---|
| B1 | `docker run --rm --network paygate-stage-net -v ./migrations:/migrations:ro migrate/migrate:v4.18.1 -path=/migrations -database "postgres://<stage-user>:<stage-password>@postgres:<stage-port>/<stage-db>?sslmode=disable" up` | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Apply all migrations to isolated DB | Write (database schema) | Schema at version 25, `dirty=false` | Query `schema_migrations` on stage DB: `version >= 22, dirty = false` | `... down` (reverses migrations; only affects stage DB) |

> **Credentials note:** Replace `<stage-user>`, `<stage-password>`, `<stage-db>`, `<stage-port>` with values from the stage `.env` (created in Phase C). Never print these values.

### Phase C — Configure stage environment

| Step | Command | Working directory | Purpose | Read/Write | Expected result | Verification | Rollback |
|---|---|---|---|---|---|---|---|
| C1 | Create stage backend `.env` (new file, e.g. `.env.stage`) with `APP_ENV=test`, `APP_PORT=<stage-port>`, `DB_*` pointing to isolated PostgreSQL, `PAYMENT_PROVIDER=mock`, `EMAIL_ENABLED=false`, `PAYMENT_SIMULATOR_ENABLED=false` | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Separate stage configuration | Write (new file) | `.env.stage` exists with safe values | `cat` (read-only, no secrets in report) | Delete `.env.stage` |
| C2 | Create stage Flutter `.env` (new file, e.g. `.env.stage`) with `API_BASE_URL=http://<reachable-host>:<stage-port>` | `/run/media/dhika/Dhika/payment_simulator` | Point Flutter at isolated backend | Write (new file) | Flutter `.env.stage` points at stage backend | `cat` (read-only) | Delete `.env.stage` or restore original `.env` |
| C3 | Configure `CORS_ALLOWED_ORIGINS` on stage backend to include Flutter web/emulator origin if Flutter Web is used | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Allow cross-origin requests | Write (`.env.stage`) | CORS allows Flutter origin | Backend starts without CORS config error | Edit `.env.stage` |

### Phase D — Start isolated backend

| Step | Command | Working directory | Purpose | Read/Write | Expected result | Verification | Rollback |
|---|---|---|---|---|---|---|---|
| D1 | Build backend: `docker build -t paygate-stage .` OR `go build -o /tmp/paygate-stage ./cmd/server` | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Build stage backend binary | Write (build artifacts) | Binary/image built | `docker images` shows `paygate-stage` or binary exists | Remove image/binary |
| D2 | Start isolated backend with `.env.stage`, bound to stage port | `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend` | Start stage backend service | Write (container/process start) | Backend listening on stage port; `/health` returns 200 | `curl http://<stage-host>:<stage-port>/health` → 200 | `docker compose -f docker-compose.stage.yml stop app` or kill process |

### Phase E — Provision test tenant (via API, no direct DB writes)

| Step | Command | Working directory | Purpose | Read/Write | Expected result | Verification | Rollback |
|---|---|---|---|---|---|---|---|
| E1 | `POST /api/v1/admin/onboarding/merchants` with `X-Admin-Key` on stage backend | N/A (HTTP client) | Provision test merchant + OWNER + API credential | Write (creates merchant row in stage DB) | 201 response with `key_id:secret` | Response body contains merchant ID and API credential | Cleanup: delete merchant via API (if supported) or leave in isolated test DB (harmless — isolated) |
| E2 | `POST /api/v1/admin/merchants/<id>/users` to create dashboard user, or `POST /api/v1/auth/login` with OWNER credentials | N/A | Create dashboard user for Flutter login | Write (creates user row) | Dashboard user can log in | `POST /api/v1/auth/login` returns 200 with access token | Cleanup: leave in isolated test DB |

### Phase F — Flutter integration validation

| Step | Command | Working directory | Purpose | Read/Write | Expected result | Verification | Rollback |
|---|---|---|---|---|---|---|---|
| F1 | `flutter test` (with stage `.env` if tests reference it) | `/run/media/dhika/Dhika/payment_simulator` | Confirm unit/widget tests still pass | Read-only | 363 tests pass | Test output summary | N/A (no state change) |
| F2 | Build Flutter for Linux desktop: `flutter build linux` (or run on connected device/emulator) | `/run/media/dhika/Dhika/payment_simulator` | Produce app binary against stage backend | Write (build artifacts) | Build succeeds | `flutter build` completes | Remove `build/` |
| F3 | Manual execution against stage backend: login, products, order, payment, status retrieve | N/A | End-to-end smoke test | Read/write (creates order/payment in stage DB) | All M2 test matrix steps pass | UI shows backend-confirmed states | Cleanup: test data remains in isolated stage DB only |

---

## 9. Verification Checklist

Before declaring isolated staging ready, all of the following must be confirmed:

- [ ] Stage PostgreSQL is reachable on its dedicated port and is **not** the protected port-8081 backend's database
- [ ] `schema_migrations` on stage DB shows `version >= 22` and `dirty = false`
- [ ] Stage backend starts successfully with `.env.stage` and `/health` returns 200
- [ ] Stage backend does **not** share container, network, volume, or credentials with the port-8081 service
- [ ] Test merchant/dashboard user provisioned via onboarding API (not direct DB writes)
- [ ] Flutter `.env.stage` `API_BASE_URL` reaches the stage backend from the test target (Linux desktop / emulator / device)
- [ ] CORS configured if Flutter Web is used
- [ ] `flutter test` still passes (363 passed)
- [ ] No secrets printed or committed; `.env.stage` files are local-only
- [ ] Cleanup procedure targets only stage-named resources

---

## 10. Safe Cleanup Plan

Cleanup targets **only** explicitly named stage resources. No destructive commands are routine cleanup.

| Resource | Cleanup command | Safety |
|---|---|---|
| Stage backend container | `docker compose -f docker-compose.stage.yml stop app` (or `kill` process) | Stops only stage container; does not remove data |
| Stage PostgreSQL container | `docker compose -f docker-compose.stage.yml stop postgres` | Stops only stage DB; volume persists for inspection |
| Stage network | `docker network rm paygate-stage-net` | Removes only the stage network (after containers stopped) |
| Stage volume (optional, for full teardown) | `docker volume rm paygate-stage-pgdata` | **Only** the stage-specific named volume; never the protected backend's volume |
| Stage Compose files / `.env.stage` | Delete the new files | Reverts to pre-staging state |

**Prohibited as routine cleanup:** `docker compose down -v`, `docker volume prune`, `docker system prune`, or any command that could affect the protected port-8081 service, its network, or its volume.

---

## 11. Risks and Unresolved Questions

| # | Risk / Question | Classification | Mitigation |
|---|---|---|---|
| 1 | Stage port selection may collide with an existing service | UNKNOWN | Verify port is free (`ss -tlnp`) before starting |
| 2 | `gen_random_uuid()` / `pgcrypto` extension availability in stage PostgreSQL | INFERRED | `postgres:16-alpine` supports it; verify migration `000001` applies cleanly |
| 3 | No `ADMIN_API_KEY` available for onboarding (not printed/assumed) | UNKNOWN | Must be obtained before Stage E; cannot provision test tenant without it |
| 4 | Flutter-configured `API_BASE_URL` (`192.168.110.245:8081`) is not reachable | VERIFIED | Must create `.env.stage` with a reachable stage URL |
| 5 | No emulator/device available; mobile-specific behaviors untestable | VERIFIED | Limit initial validation to Linux desktop; defer mobile-specific tests |
| 6 | Android cleartext HTTP if stage backend uses HTTP | INFERRED | May require `usesCleartextTraffic` or HTTPS; document as platform limitation |
| 7 | CORS for Flutter Web not yet configured | UNKNOWN | Set `CORS_ALLOWED_ORIGINS` on stage backend if using Flutter Web |
| 8 | Test data (orders/payments) created in stage DB persists after cleanup | INFERRED | Acceptable — isolated test DB; data does not affect production |
| 9 | Whether `migrate/migrate:v4.18.1` image is pre-pulled or needs network | UNKNOWN | `docker run` will pull if not present; requires network access |

---

## 12. Explicit GO / NO-GO Decision

**NO-GO for immediate runtime execution.**

**Reasoning:** No isolated staging environment currently exists. The plan is complete, safe, and uses only existing repository tooling, but the following must be provisioned first: an isolated PostgreSQL, a migrated test database (schema >= 22), stage backend configuration, test tenant credentials, and a reachable Flutter `API_BASE_URL`. None of these exist yet, and none may be created or modified in this audit phase.

**Conditions to flip to GO:**
1. A separately authorized execution phase is approved.
2. Stage ports are confirmed free and non-colliding.
3. `ADMIN_API_KEY` for stage onboarding is available.
4. All Phase A–D infrastructure steps complete successfully.
5. The pre-execution gate (isolation from port-8081 backend) passes.

**Next recommended action:** Review and approve this plan; then execute Phase A (infrastructure provisioning) in the authorized follow-up phase. Only after isolated staging is confirmed running should the M2 test matrix (login → order → payment → status → history) be executed against it.

---

**Report path:** `docs/mobile-local-staging-plan.md`
**Runtime or database state changed:** None.
**Files created:** Only `docs/mobile-local-staging-plan.md`.
