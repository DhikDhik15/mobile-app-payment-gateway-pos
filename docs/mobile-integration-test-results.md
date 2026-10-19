# GO-SAAS — M2 Integration Test Results

**Project:** GO-SAAS Payment Gateway Simulator
**Phase:** M2 — Flutter + Isolated Local Staging Integration Test Execution
**Report date:** Mon Oct 19 2026
**Report path:** `docs/mobile-integration-test-results.md`
**Final status:** M2 BLOCKED

---

## Safety compliance

- Only the isolated staging backend (`http://127.0.0.1:18080`) and staging
  PostgreSQL (`127.0.0.1:55433`, database `go_saas_m2_staging`) were used.
- No requests were sent to the protected backend on port 8081 (it remained
  running and untouched, HTTP 200 on `/health`).
- No existing databases, containers, volumes, or application data were deleted,
  stopped, or modified. No Docker prune/cleanup commands were run.
- No live payment provider was used (`PAYMENT_PROVIDER=mock`).
- No real payment credentials or real money were used.
- No secrets, passwords, API keys, or tokens are printed in this report.
- No login credentials were invented or guessed.
- No new merchant or user was created.
- No application source code was modified.
- The original Flutter `.env` was restored after testing (verified identical).

---

## 1. Environment verification (Phase 1)

| Check | Result | Evidence |
|---|---|---|
| Staging execution report inspected | PASS | `docs/mobile-local-staging-execution.md` — status READY FOR M2 INTEGRATION TESTS |
| Flutter git status | PASS | Clean, on `main`, up to date with `origin/main` |
| Flutter `.env` state | PASS | Untracked local file; backed up before any change; restored after testing |
| `main.dart` env filename | PASS | `dotenv.load(fileName: '.env')` — `.env.stage` not auto-loaded |
| `.env.stage` points to staging | PASS | `API_BASE_URL=http://127.0.0.1:18080` |
| Staging backend `/health` | PASS | HTTP 200 `{"success":true,"data":{"status":"ok"}}` |
| Staging backend `/health/ready` | PASS | HTTP 200, same envelope |
| Staging backend DB connection | PASS | Backend ready → connected to staging PostgreSQL |
| Staging schema version | PASS | `version=25`, `dirty=false` (>= 22 required) |
| Staging database name/user | PASS | `go_saas_m2_staging` / `go_saas_m2_staging` on `127.0.0.1:55433` |
| `PAYMENT_PROVIDER=mock` | PASS | Staging `.env.stage`: `PAYMENT_PROVIDER=mock`; expiry/webhook/email workers disabled |
| Protected backend port 8081 | PASS | Still healthy (HTTP 200), separate and untouched |
| Authorized staging test account identified | PASS | Merchant `b80f9794-...` ACTIVE; owner user `m2-staging-test@example.com` ACTIVE (role OWNER) |

Note: when testing began, port 18080 was not listening and the staging DB
container (`go-saas-m2-staging-db`) was Exited. The staging PostgreSQL was
started via `docker compose --env-file .env.stage -f docker-compose.stage.yml
--project-name go-saas-m2-staging up -d`, and the staging backend binary was
rebuilt (`go build -o /tmp/opencode/paygate-stage ./cmd/server`) and launched
with `.env.stage` sourced into the environment. The protected port-8081 service
(`pay-gate-app`) was not touched.

---

## 2. Test account availability (without credentials)

A staging test tenant was provisioned during Phase A via
`POST /api/v1/admin/onboarding/merchants`. The account exists and is usable in
principle, but its **login credentials are not available** for this test
execution:

| Item | Value | Classification |
|---|---|---|
| Merchant ID | `b80f9794-c1e6-4717-b1ef-45731c0332ef` | Non-secret identifier |
| Merchant code | `m2-staging-test` | Non-secret |
| Merchant status | ACTIVE | Non-secret |
| Owner ID | `4f47c488-b7c6-4d40-974e-8aaf49419dc1` | Non-secret identifier |
| Owner email | `m2-staging-test@example.com` | Non-secret |
| Owner role | OWNER | Non-secret |
| API credential key_id | `pk_e8e16d3cce3590cf00ed262807e2c27da0417f39` | Non-secret identifier |
| Owner password | NOT AVAILABLE | Set once during onboarding; returned once; never recorded |
| API credential secret | NOT AVAILABLE | Returned once during onboarding; never recorded |

Per safety requirements, credentials were not invented, guessed, or recovered.
The existing staging test account **cannot be used** because its password is not
recorded anywhere in the repository or reports, and no password-reset or
dev-recovery path is enabled in staging (`DEV_RECOVERY_ENABLED=false`).

Consequence: authentication tests (A4–A6) and every test depending on an
authenticated session (Group B, Group C) are **BLOCKED**.

---

## 3. Actual test results

Every test classified as PASS, FAIL, BLOCKED, or NOT RUN.

### Phase 3 — Test Group A: Connectivity and Auth

| Test | Result | Preconditions | Action | Expected | Actual |
|---|---|---|---|---|---|
| A1. Backend health | PASS | Staging backend running on 18080 | `GET /health` | HTTP 200, success envelope | HTTP 200 `{"success":true,"data":{"status":"ok"}}` |
| A2. Backend readiness | PASS | Staging backend running on 18080 | `GET /health/ready` | HTTP 200, success envelope | HTTP 200 `{"success":true,"data":{"status":"ok"}}` |
| A3. Flutter app startup | PASS | `.env` set to `API_BASE_URL=http://127.0.0.1:18080` | `flutter run -d chrome` (debug) | App launches; effective base URL = staging | App launched on Chrome; debug log confirmed `[Environment] API_BASE_URL=http://127.0.0.1:18080` |
| A4. Login | BLOCKED | Valid owner credentials | `POST /api/v1/auth/login` `{email,password}` | HTTP 200, access token + user | Cannot execute — owner password not recorded; credentials unavailable |
| A5. Session restoration | BLOCKED | Successful login + stored tokens | `GET /api/v1/auth/me` | HTTP 200, user details | Cannot execute — no login performed; no stored access/refresh token |
| A6. Product & category retrieval | BLOCKED | Authenticated session | `GET /api/v1/dashboard/categories`, `/products` | HTTP 200, list | Cannot execute — endpoints return `401 INVALID_CREDENTIALS` without a token; Flutter Web also CORS-blocked |

### Phase 4 — Test Group B: Order and Payment

| Test | Result | Preconditions | Action | Expected | Actual |
|---|---|---|---|---|---|
| B1. Create order | BLOCKED | Authenticated session + products | `POST /api/v1/dashboard/orders` | HTTP 201, order created | Cannot execute — `401 INVALID_CREDENTIALS` without a token; 0 orders and 0 products in staging DB |
| B2. Retrieve order | BLOCKED | Existing order + auth | `GET /api/v1/dashboard/orders/{id}` | HTTP 200, order details | Cannot execute — no orders exist; no auth token |
| B3. Create payment | BLOCKED | Authenticated session + order | `POST /api/v1/dashboard/payments` | HTTP 201, PENDING, payment_url | Cannot execute — `401 INVALID_CREDENTIALS` without a token |
| B4. Retrieve payment | BLOCKED | Existing payment + auth | `GET /api/v1/dashboard/payments/{id}` | HTTP 200, payment details | Cannot execute — no auth token |
| B5. Open payment URL | BLOCKED | Existing payment + browser | Open `http://127.0.0.1:18080/pay/{identifier}` | Mock payment page loads | Cannot execute — no payment created in this session; Flutter Web cross-origin calls CORS-blocked |
| B6. Verify pending state | BLOCKED | Existing payment + auth | Check payment status | Status PENDING | Cannot execute — no auth token / no payment created in this session |
| B7. Simulate successful payment | BLOCKED | Existing payment + auth | `POST .../simulate/success` | HTTP 200, status PAID | Cannot execute — `401 INVALID_CREDENTIALS` without a token |
| B8. Simulate failed payment | BLOCKED | Existing payment + auth | `POST .../simulate/fail` | HTTP 200, status FAILED | Cannot execute — `401 INVALID_CREDENTIALS` without a token |
| B9. Verify expired payment | BLOCKED | Existing payment + expiry enabled | Check status EXPIRED | Status EXPIRED | Cannot execute — `PAYMENT_EXPIRY_ENABLED=false` in staging (expiry worker disabled); also requires auth |
| B10. Verify cancelled payment | BLOCKED | Existing payment + auth | `POST /api/v1/payments/{id}/cancel` | HTTP 200, status CANCELLED | Cannot execute — `401` without a merchant API key; Flutter app dashboard API does not expose cancel |

### Phase 5 — Test Group C: History and Session

| Test | Result | Preconditions | Action | Expected | Actual |
|---|---|---|---|---|---|
| C1. Retrieve transaction history | BLOCKED | Authenticated session | `GET /api/v1/dashboard/payments` | HTTP 200, paginated list | Cannot execute — `401 INVALID_CREDENTIALS` without a token |
| C2. Verify transactions belong to account | BLOCKED | Authenticated session | Confirm merchant scoping | All payments belong to authenticated merchant | Cannot execute — no auth token |
| C3. Refresh-token behavior | BLOCKED | Valid refresh token (HttpOnly cookie) | `POST /api/v1/auth/refresh` | HTTP 200, new access token | Cannot execute — no login performed; no refresh token |
| C4. Logout | BLOCKED | Authenticated session | `POST /api/v1/auth/logout` | HTTP 200, tokens cleared | Cannot execute — no auth token |
| C5. Post-logout session behavior | BLOCKED | Logout performed | Verify documented logout behavior | Refresh cleared; access valid until expiry | Cannot execute — no login/logout performed |

---

## 4. Sanitized errors

| Context | HTTP status | Error code | Cause / classification |
|---|---|---|---|
| All dashboard endpoints without a token (categories, products, orders, payments) | 401 | `INVALID_CREDENTIALS` | Authentication required — no credentials available for the staging test account |
| Staging backend CORS (browser cross-origin) | — | (no `Access-Control-Allow-Origin` header) | `CORS_ALLOWED_ORIGINS` is empty in staging `.env.stage`; middleware emits no CORS headers; OPTIONS preflight returns 404. Flutter Web cross-origin API calls are browser-blocked. |
| Flutter `.env` originally pointed at port 8081 | — | — | Original local `.env` had `API_BASE_URL=http://192.168.110.245:8081` (protected backend). Replaced with `.env.stage` (18080) for the test session, then restored. |

No test failures were recorded because no state-changing request could be
attempted (all return 401 before reaching business logic). No state-changing
request was retried blindly.

---

## 5. Created staging record identifiers

**None.** No orders, payments, or other records were created during this test
execution, because every state-changing endpoint requires authentication and no
credentials are available.

Pre-existing staging records (from the Oct 16 Phase A execution, present in the
persistent `go-saas-m2-staging-pgdata` volume — not created by this session):

| Record type | Identifier(s) | Current status | Note |
|---|---|---|---|
| Mock payment | `gateway_transaction_id` `69d39dcd-9eca-45cd-90a7-cc50379855e6` | PENDING (expired_at in the past) | Oct 16 leftover; not created or modified here |
| Mock payment | `gateway_transaction_id` `80479258-adde-4e27-b31b-72db68493abc` | PENDING (expired_at in the past) | Oct 16 leftover; not created or modified here |
| Payment attempt | `dc8f8f01-5a01-42d5-abc8-b2193dcc2850` | SUCCESS, MOCK | Oct 16 leftover |
| Payment attempt | `f83e365a-2774-4728-84a3-317c865a9deb` | SUCCESS, MOCK | Oct 16 leftover |

These records exist only in the isolated staging database `go_saas_m2_staging`.
They were not created, modified, or deleted during this session.

---

## 6. Tests not run and reasons

All 18 blocked tests (A4–A6, B1–B10, C1–C5) share the same root cause: **no
valid authentication credentials for the staging test account**, and every
Flutter-used order/payment/history/session endpoint returns `401
INVALID_CREDENTIALS` without a bearer token.

| Test | Reason |
|---|---|
| A4 Login | Owner password not recorded; cannot invent/recover/guess credentials |
| A5 Session restoration | Depends on A4; no stored tokens |
| A6 Product & category retrieval | Requires dashboard auth (401 without token) |
| B1–B10 Order/payment flows | Require dashboard auth (401 without token); B9 additionally has expiry disabled in staging |
| C1–C5 History/session | Require auth (401 without token) |

No tests were marked FAIL — none could be executed far enough to fail.

---

## 7. Known limitations

| # | Limitation | Impact |
|---|---|---|
| 1 | No authentication credentials available | A4–A6, all of Group B, all of Group C cannot be executed; core Flutter↔backend payment integration not validated end-to-end |
| 2 | Flutter `main.dart` hardcodes `fileName: '.env'` | `.env.stage` must be manually copied to `.env` for testing; original `.env` restored after testing |
| 3 | Flutter Web CORS not configured | `CORS_ALLOWED_ORIGINS` empty in staging → no `Access-Control-Allow-Origin` header; OPTIONS preflight 404. Flutter Web cannot call the staging API cross-origin. Flutter Linux desktop is not subject to CORS but could not be automated and still lacks credentials. |
| 4 | No Android emulator / physical device | Mobile-specific behaviors (secure token storage, URL launching, app background/resume, network permissions) not testable |
| 5 | No products seeded in staging DB | Order creation (B1) cannot be exercised even with auth |
| 6 | Expiry worker disabled in staging | Expired-payment state (B9) cannot be reproduced |
| 7 | Payment cancellation not in Flutter dashboard API | Flutter app uses dashboard endpoints; cancel is on the merchant API (X-API-Key) which the app does not call |

---

## 8. Manual browser checks required

The following could not be automated and should be verified manually **after**
valid credentials are made available for the staging test account:

1. **Login:** Open the Flutter app (`.env` → `API_BASE_URL=http://127.0.0.1:18080`), log in as the staging owner, confirm HTTP 200 and session establishment.
2. **CORS (Flutter Web):** Verify cross-origin preflight and API responses from the Flutter Web dev-server origin succeed against `127.0.0.1:18080` (may require adding the web origin to `CORS_ALLOWED_ORIGINS`).
3. **Payment URL:** Open `http://127.0.0.1:18080/pay/{identifier}` in a browser and confirm the mock payment page renders.
4. **End-to-end UI flow:** Login → Products → Cart → Order → Payment → Payment Detail → Status refresh → Transaction History; confirm each screen transitions and reflects backend state.
5. **Simulate success/fail:** Trigger the mock-payment transition and confirm status moves PENDING → PAID / PENDING → FAILED.

---

## 9. Final readiness decision

**M2 BLOCKED**

| Group | Passed | Failed | Blocked | Not Run | Total |
|---|---|---|---|---|---|
| A: Connectivity & Auth | 3 (A1, A2, A3) | 0 | 3 (A4, A5, A6) | 0 | 6 |
| B: Order & Payment | 0 | 0 | 10 (B1–B10) | 0 | 10 |
| C: History & Session | 0 | 0 | 5 (C1–C5) | 0 | 5 |
| **Total** | **3** | **0** | **18** | **0** | **21** |

### What was verified
- Staging backend is healthy and ready on `127.0.0.1:18080`, connected to the
  isolated `go_saas_m2_staging` database (schema v25, dirty=false),
  `PAYMENT_PROVIDER=mock`, no live provider.
- Protected port-8081 backend remains separate and healthy.
- Flutter app starts against the staging backend: effective
  `API_BASE_URL=http://127.0.0.1:18080` confirmed at runtime (Chrome, debug
  mode). Original `.env` restored and verified identical.
- All auth-required endpoints correctly return `401 INVALID_CREDENTIALS`
  without a token (auth enforcement is functioning).
- CORS behavior documented: Flutter Web cross-origin calls are blocked because
  `CORS_ALLOWED_ORIGINS` is unset in staging.

### What was NOT verified (blocked)
- Real Flutter runtime login, session restore, refresh, logout.
- Order creation/retrieval, payment creation/retrieval, payment URL opening.
- Payment state transitions (PENDING → PAID / FAILED / EXPIRED / CANCELLED).
- Transaction history and merchant scoping.

### Required before full M2 integration sign-off
1. Make valid staging test-account credentials available (owner password or
   API credential secret) — without these, no auth-dependent flow can be
   tested.
2. Re-run the blocked tests (A4–C5) against the staging backend once
   credentials are available.
3. Seed products in the staging DB to enable order-creation tests (B1, B2).
4. Enable the expiry worker (`PAYMENT_EXPIRY_ENABLED=true`) if expired-payment
   behavior (B9) must be verified.
5. Add the Flutter Web dev-server origin to `CORS_ALLOWED_ORIGINS` if Flutter
   Web runtime testing is required.
6. Test on a mobile emulator/device for secure storage and URL-launch behavior.

**Report path:** `docs/mobile-integration-test-results.md`

**Recommended next step:** Obtain the staging test-account credentials (owner
password or merchant API credential secret) from the team that performed the
Oct 16 onboarding, then re-execute the blocked authentication and payment-flow
tests. Do not mark M2 integrated until A4–C5 have been exercised through the
Flutter runtime against the staging backend.

---

**Runtime or database state changed:** None by this session. Original Flutter
`.env` restored. Staging database records left intact (pre-existing Oct 16
records untouched). Protected port-8081 backend and all existing
infrastructure untouched.
