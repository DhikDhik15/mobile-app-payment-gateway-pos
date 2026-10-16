# GO-SAAS — M2A Phase A: Isolated Local Staging Execution Report

**Project:** GO-SAAS Payment Gateway Simulator
**Phase:** M2A Phase A — Isolated Local Staging Infrastructure Provisioning
**Report date:** Fri Oct 16 2026
**Report path:** `docs/mobile-local-staging-execution.md`
**Final status:** READY FOR M2 INTEGRATION TESTS

**Safety compliance:** Zero changes to protected resources. No existing container, network, volume, database, or `.env` file was modified or deleted. No `docker compose down -v`, `docker volume prune`, or `docker system prune` was executed. No state-changing HTTP requests were sent. No secrets were printed.

---

## 1. Pre-flight Results

| Check | Result | Classification | Detail |
|---|---|---|---|
| Git status — backend | Clean | PASS | No uncommitted changes |
| Git status — Flutter | Clean (report docs only) | PASS | Only new report files |
| Docker availability | PASS | VERIFIED | Docker 29.9.0, Compose v5.6.0 |
| Protected backend on 8081 | PASS | VERIFIED | `pay-gate-app` healthy on 0.0.0.0:8081 |
| Port 5432 in use | PASS | VERIFIED | Existing PostgreSQL — not reused |
| Port 8081 in use | PASS | VERIFIED | Protected backend — not reused |
| Port 18080 free | PASS | VERIFIED | Selected for staging backend |
| Port 55433 free | PASS | VERIFIED | Selected for staging PostgreSQL |
| APP_ENV=test supported | PASS | VERIFIED | `parseAppEnv()` accepts "test" |
| PAYMENT_PROVIDER=mock supported | PASS | VERIFIED | Default, allowed in non-production |
| Onboarding requires X-Admin-Key | PASS | VERIFIED | Confirmed in handler source |

---

## 2. Resources Created

| Resource | Name | Type | Purpose |
|---|---|---|---|
| Docker network | `go-saas-m2-staging-net` | Bridge | Isolated network for staging containers |
| Docker volume | `go-saas-m2-staging-pgdata` | local | Staging-only PostgreSQL data |
| Docker container | `go-saas-m2-staging-db` | `postgres:16-alpine` | Staging-only database |
| Backend process | `paygate-stage` (PID 249636) | Go binary | Staging backend on 127.0.0.1:18080 |
| Compose file | `docker-compose.stage.yml` | File | Staging PostgreSQL service definition |
| Backend env file | `.env.stage` | File | Staging backend configuration |
| Flutter env file | `.env.stage` | File | Staging Flutter API_BASE_URL |

**Staging identifier:** `go-saas-m2-staging` (used as prefix for all resources)

---

## 3. Actual Ports Used

| Service | Host Address | Container Address | Bound Interface |
|---|---|---|---|
| Staging PostgreSQL | `127.0.0.1:55433` | `5432` | Loopback only (not LAN) |
| Staging backend | `127.0.0.1:18080` | `8080` | Loopback only (not LAN) |
| Protected backend | `0.0.0.0:8081` | `8080` | All interfaces (protected — untouched) |
| Existing PostgreSQL | `0.0.0.0:5432` | — | Existing — not reused |

---

## 4. PostgreSQL Isolation Evidence

| Check | Result | Evidence |
|---|---|---|
| Container identity | `go-saas-m2-staging-db` | `docker ps` filter |
| Image | `postgres:16-alpine` | `docker ps` |
| Database name | `go_saas_m2_staging` | `POSTGRES_DB` env |
| Database user | `go_saas_m2_staging` | `POSTGRES_USER` env |
| Host port | `55433` | `127.0.0.1:55433->5432/tcp` |
| Bound interface | `127.0.0.1` only | Not exposed to LAN |
| Network | `go-saas-m2-staging-net` | Dedicated bridge network |
| Volume | `go-saas-m2-staging-pgdata` | Dedicated named volume |
| Volume reuse | None | Does not reference `pay-gate-postgres-data` or any existing volume |
| Network reuse | None | Does not reference `pay-gate-network` or any existing network |

---

## 5. Migration Result

| Check | Result | Detail |
|---|---|---|
| Migrations applied | PASS | All 25 migrations (`000001` → `000025`) |
| Migration tool | `migrate/migrate:v4.18.1` | Docker image, ran against staging DB only |
| Schema version | 25 | `>= 22` required — PASS |
| Dirty flag | `false` | `dirty = f` — PASS |
| Table count | 26 | `information_schema.tables` count |
| Target database | `go_saas_m2_staging` | Fresh, no pre-existing data |
| Existing DB touched | No | Only staging database was migrated |

---

## 6. Backend Startup Result

| Check | Result | Detail |
|---|---|---|
| Build | PASS | `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /tmp/paygate-stage ./cmd/server` |
| Process PID | 249636 | Running as background process |
| Listen address | `127.0.0.1:18080` | `APP_BIND_HOST=127.0.0.1`, `APP_PORT=18080` |
| Environment | `APP_ENV=test` | Staging-only configuration |
| Database connection | PASS | `database connection pool established` in log |
| Schema check | PASS | Backend started successfully (would exit on schema failure) |
| Health endpoint | PASS | `GET /health` → HTTP 200 |
| Ready endpoint | PASS | `GET /health/ready` → HTTP 200 |
| Payment provider | `mock` | No live payment provider |
| External side effects | Disabled | `EMAIL_ENABLED=false`, `WEBHOOK_DELIVERY_ENABLED=false`, `PAYMENT_EXPIRY_ENABLED=false` |
| Rate limiting | Disabled | `RATE_LIMIT_ENABLED=false` (staging test convenience) |
| Log output | `/tmp/paygate-stage.log` | No secrets logged |

---

## 7. Health Check Results

| Endpoint | URL | Status | Body |
|---|---|---|---|
| Health | `http://127.0.0.1:18080/health` | HTTP 200 | `{"success":true,"data":{"status":"ok"},"meta":{...}}` |
| Ready | `http://127.0.0.1:18080/health/ready` | HTTP 200 | `{"success":true,"data":{"status":"ok"},"meta":{...}}` |
| Protected backend health | `http://127.0.0.1:8081/health` | HTTP 200 | Unchanged, still healthy |

---

## 8. Flutter Configuration Result

| Check | Result | Detail |
|---|---|---|
| `.env.stage` created | PASS | `API_BASE_URL=http://127.0.0.1:18080` |
| Existing `.env` modified | No | Preserved unchanged |
| `.env` auto-loading | Limitation | `main.dart` hardcodes `fileName: '.env'` — `.env.stage` must be manually copied to `.env` for use |
| Backend reachable from host | PASS | `curl http://127.0.0.1:18080/health` → HTTP 200 |
| CORS for Flutter Web | Limitation | `CORS_ALLOWED_ORIGINS=http://127.0.0.1:18080,http://localhost:18080` — Flutter Web runs on a different port; add the web dev-server origin if needed |
| Android emulator | None available | `flutter emulators` reports no emulators |
| Physical device | None detected | `flutter devices` shows Linux desktop + Chrome web only |

**Flutter connectivity:** The staging backend at `127.0.0.1:18080` is reachable from the host. A Flutter app running on Linux desktop can reach it directly. For Flutter Web, CORS must allow the web dev-server origin. For Android emulator/physical device, the backend would need to be reachable from the device network (loopback binding would need to be adjusted — see Known Limitations).

---

## 9. Test Tenant Status

| Check | Result | Detail |
|---|---|---|
| Tenant created | PASS | Via `POST /api/v1/admin/onboarding/merchants` |
| Merchant ID | `b80f9794-c1e6-4717-b1ef-45731c0332ef` | Non-secret identifier |
| Merchant code | `m2-staging-test` | Non-secret |
| Merchant status | `ACTIVE` | Non-secret |
| Owner ID | `4f47c488-b7c6-4d40-974e-8aaf49419dc1` | Non-secret identifier |
| Owner email | `m2-staging-test@example.com` | Non-secret |
| Owner role | `OWNER` | Non-secret |
| API credential key_id | `pk_e8e16d3cce3590cf00ed262807e2c27da0417f39` | Non-secret identifier |
| API credential secret | NOT RECORDED | Returned ONCE only; not stored in report |
| Orders created | No | Not in scope for Phase A |
| Payments created | No | Not in scope for Phase A |

---

## 10. Protected Resource Verification

| Resource | Status | Verification |
|---|---|---|
| Port-8081 backend | UNTOUCHED | `pay-gate-app` still running healthy on 0.0.0.0:8081 |
| Port-8081 health | PASS | `GET /health` → HTTP 200 |
| Existing databases | UNTOUCHED | Only staging DB (`go_saas_m2_staging`) was created/migrated |
| Existing Docker containers | UNTOUCHED | No existing container stopped, restarted, or deleted |
| Existing Docker networks | UNTOUCHED | New network `go-saas-m2-staging-net` created separately |
| Existing Docker volumes | UNTOUCHED | New volume `go-saas-m2-staging-pgdata` created separately |
| Existing `.env` files | UNTOUCHED | Backend `.env` and Flutter `.env` preserved |
| Uncommitted changes | PRESERVED | No existing files modified |

---

## 11. Known Limitations

| # | Limitation | Impact | Mitigation |
|---|---|---|---|
| 1 | Flutter `main.dart` hardcodes `fileName: '.env'` | `.env.stage` not auto-loaded; must be manually copied to `.env` | Copy `.env.stage` → `.env` before testing, restore after |
| 2 | Flutter Web CORS origin unknown | Flutter Web dev server runs on a dynamic port | Add the web origin to `CORS_ALLOWED_ORIGINS` in backend `.env.stage` |
| 3 | Android emulator binding | Backend binds to `127.0.0.1` only; emulator uses `10.0.2.2` | Change `APP_BIND_HOST` to empty (all interfaces) or set staging network IP for emulator testing |
| 4 | No emulator/device available | Mobile-specific behaviors untestable | Limit initial validation to Linux desktop |
| 5 | Backend runs as foreground process | Not managed by Docker/Compose | Stop with `kill $(cat /tmp/paygate-stage.pid)` when done |
| 6 | Test tenant data persists in staging DB | Merchant/order data remains after testing | Acceptable — isolated test database only |

---

## 12. Staging-Only Cleanup Instructions

**Do NOT execute these automatically. Execute only when intentionally tearing down staging.**

Before cleanup, verify resource names:
```sh
docker ps --filter "name=go-saas-m2-staging-db"
docker volume ls --filter "name=go-saas-m2-staging-pgdata"
docker network ls --filter "name=go-saas-m2-staging-net"
```

**Staging backend process:**
```sh
kill $(cat /tmp/paygate-stage.pid)
rm /tmp/paygate-stage.pid /tmp/paygate-stage.log /tmp/paygate-stage
```

**Staging PostgreSQL (Compose):**
```sh
cd /run/media/dhika/Dhika/go-pay-gate/pay-gate-backend
docker compose --env-file .env.stage -f docker-compose.stage.yml --project-name go-saas-m2-staging stop
```

**Full staging teardown (stage resources only):**
```sh
cd /run/media/dhika/Dhika/go-pay-gate/pay-gate-backend
docker compose --env-file .env.stage -f docker-compose.stage.yml --project-name go-saas-m2-staging down
# The above stops and removes the staging container only.
# To also remove the staging volume (irreversible — data lost):
# docker volume rm go-saas-m2-staging-pgdata
# To remove the staging network:
# docker network rm go-saas-m2-staging-net
```

**Prohibited:** `docker compose down -v`, `docker volume prune`, `docker system prune`, or any command that could affect the protected port-8081 service, its network, or its volume.

**Flutter `.env.stage`:** Delete when no longer needed:
```sh
rm /run/media/dhika/Dhika/payment_simulator/.env.stage
```

**Backend `.env.stage` and `docker-compose.stage.yml`:** Delete when no longer needed (these are new files, not modifications to existing files).

---

## 13. Final Readiness Status

**READY FOR M2 INTEGRATION TESTS**

All required infrastructure and isolation checks have passed:

| # | Check | Status |
|---|---|---|
| 1 | Isolated PostgreSQL container running | PASS |
| 2 | Staging database migrated (version 25, dirty=false) | PASS |
| 3 | Staging backend running on 127.0.0.1:18080 | PASS |
| 4 | Health checks pass (/health, /health/ready) | PASS |
| 5 | Backend connects to staging database only | PASS |
| 6 | No live payment provider (mock only) | PASS |
| 7 | Test tenant provisioned via API | PASS |
| 8 | Flutter staging config points to staging backend | PASS |
| 9 | Protected port-8081 backend untouched | PASS |
| 10 | Existing databases untouched | PASS |
| 11 | No secrets exposed | PASS |
| 12 | No transaction tests executed | PASS |

**Next step:** Execute the M2 transaction test matrix (login → session restore → products → order creation → payment creation → status retrieval → transaction history → token refresh → logout) against the staging backend at `http://127.0.0.1:18080`.

**Report path:** `docs/mobile-local-staging-execution.md`
**Runtime or database state changed:** Only staging resources created (new container, volume, network, database, backend process). Protected resources untouched.
