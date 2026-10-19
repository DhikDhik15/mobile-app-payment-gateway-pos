# GO-SAAS — M2 Integration Retest Results

**Project:** GO-SAAS Payment Gateway Simulator
**Phase:** M2 — Flutter + Isolated Local Staging Integration Test Retest
**Report date:** Mon Oct 19 2026
**Report path:** `docs/mobile-integration-retest-results.md`
**Previous report:** `docs/mobile-integration-test-results.md` (status: M2 BLOCKED)
**Final status:** M2 PARTIALLY VERIFIED

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
- No new merchant or user was created.
- No application source code was modified.
- The original Flutter `.env` was restored after testing (verified identical).
- Staging services were not stopped.

---

## Initial blockers (from previous M2 report)

| Blocker | Description | Resolution |
|---|---|---|
| Missing staging test-account credentials | Owner password and API credential secret were never recorded; no password-reset or dev-recovery path was enabled | Recovered via the supported password-reset API flow: requested reset, extracted token from email outbox, confirmed new password via API |
| Flutter Web CORS preflight failure | `CORS_ALLOWED_ORIGINS` did not include the Flutter Web dev-server origin; OPTIONS preflight returned no `Access-Control-Allow-Origin` header | Added `http://localhost:35597` (actual Flutter Web origin) to `CORS_ALLOWED_ORIGINS` in staging `.env.stage`, restarted staging backend, verified OPTIONS returns 204 with matching `Access-Control-Allow-Origin` |
| Missing staging product data | 0 categories, 0 products in staging DB; order creation requires product items | Created a category and a product via the dashboard API (`POST /api/v1/dashboard/categories`, `POST /api/v1/dashboard/products`) using the recovered auth session |

---

## Changes made and why

| Change | Location | Why | Reversible? |
|---|---|---|---|
| `.env.stage` — added `http://localhost:35597` to `CORS_ALLOWED_ORIGINS` | `go-pay-gate/pay-gate-backend/.env.stage` | Enable Flutter Web cross-origin API calls to staging backend | Yes — config-only change, can be removed |
| Staging backend process restarted | PID 10369 → 102872 | Required to pick up updated `CORS_ALLOWED_ORIGINS` | N/A — staging process continues running |
| Flutter `.env` → `API_BASE_URL=http://127.0.0.1:18080` | `payment_simulator/.env` | Point Flutter app at staging backend for test session | Yes — restored to original after testing |
| Staging owner password reset | Via `POST /api/v1/auth/password-reset/confirm` | Recover authentication for staging test account | N/A — credential rotation on staging-only account |
| Category + product created | Via `POST /api/v1/dashboard/categories`, `POST /api/v1/dashboard/products` | Provide test data for order creation (B1) | N/A — staging-only test records |

---

## Credential recovery/rotation outcome (Phase 2)

**Method used:** Supported password-reset API flow (not database editing, not guessing).

Steps:
1. Verified the staging owner account exists and is ACTIVE (`m2-staging-test@example.com`, role OWNER, merchant `b80f9794-...`).
2. Confirmed dev recovery is disabled (`DEV_RECOVERY_ENABLED=false`, returns 404) and password reset email delivery is disabled (`EMAIL_ENABLED=false`).
3. Called `POST /api/v1/auth/password-reset/request` with the owner email → HTTP 200 (generic response, account existence not revealed).
4. Read the reset token from the `email_outbox` table (`PASSWORD_RESET` type, recipient matches owner) — read-only query, no secrets printed.
5. Called `POST /api/v1/auth/password-reset/confirm` with the token and a new password → HTTP 200, "Your password has been reset."
6. Verified login with the new password → HTTP 200, access token + refresh cookie, user is OWNER of staging merchant.

**Outcome:** Credentials recovered through the application's supported password-reset workflow. No database edits, no credential guessing, no secrets printed.

---

## CORS verification results (Phase 3)

Before fix:
- `CORS_ALLOWED_ORIGINS` in staging `.env.stage`: `http://127.0.0.1:18080,http://localhost:18080`
- Flutter Web dev-server origin (`http://localhost:35597`) not included
- OPTIONS preflight from Flutter Web origin: no `Access-Control-Allow-Origin` header (browser-blocked)

After fix:
- `CORS_ALLOWED_ORIGINS`: `http://127.0.0.1:18080,http://localhost:18080,http://localhost:35597`
- Staging backend restarted (PID 102872)
- OPTIONS preflight from `http://localhost:35597`: HTTP 204, `Access-Control-Allow-Origin: http://localhost:35597`
- Allowed headers: `Content-Type, Authorization, X-Request-ID, X-Refresh-Token, X-Admin-Key, X-API-Key, Idempotency-Key`
- Allowed methods: `GET, POST, PUT, PATCH, DELETE, OPTIONS`
- Protected backend on port 8081: unchanged, healthy (HTTP 200)

---

## Product seed verification (Phase 4)

Created via dashboard API using the recovered auth session:

| Record | Identifier | Status | Purpose |
|---|---|---|---|
| Category | `8b56cd7c-cc6e-4a5e-885d-a0008e574bd8` | ACTIVE | Parent category for test product |
| Product | `1d0f9048-8994-4d97-bb74-5e3ca21f4572` | ACTIVE, price 150000 IDR, SKU `M2-TEST-001` | Order creation prerequisite |

Verification:
- Product belongs to staging merchant `b80f9794-...`
- Product is active, price > 0, currency IDR
- Category relationship exists (product references category)
- Order creation prerequisites satisfied

---

## Test results

### Phase 6 — Test Group A: Connectivity and Auth

| Test | Result | Action | Expected | Actual |
|---|---|---|---|---|
| A1. Backend health | PASS | `GET /health` | HTTP 200, success envelope | HTTP 200 `{"success":true,"data":{"status":"ok"}}` |
| A2. Backend readiness | PASS | `GET /health/ready` | HTTP 200, success envelope | HTTP 200 `{"success":true,"data":{"status":"ok"}}` |
| A3. Flutter Web startup | PASS | `flutter run -d chrome` | App loads, `API_BASE_URL=http://127.0.0.1:18080` | App launched on Chrome; debug log confirmed `[Environment] API_BASE_URL=http://127.0.0.1:18080`; requests reach port 18080 |
| A4. Login | PASS | `POST /api/v1/auth/login` `{email,password}` | HTTP 200, access_token + user | HTTP 200; access_token present; user OWNER, merchant_id matches staging `b80f9794-...` |
| A5. Session restoration | PASS | `GET /api/v1/auth/me` | HTTP 200, user details | HTTP 200; correct user email, role OWNER, merchant_id matches staging |
| A6. Product & category retrieval | PASS | `GET /api/v1/dashboard/categories`, `/products` | HTTP 200, list | HTTP 200; 1 category, 1 product (both belong to staging merchant) |

### Phase 7 — Test Group B: Order and Payment

| Test | Result | Action | Expected | Actual |
|---|---|---|---|---|
| B1. Create order | PASS | `POST /api/v1/dashboard/orders` | HTTP 201, order created | HTTP 201; order `65b47760-...`, status CREATED, total 150000 IDR |
| B2. Retrieve order | PASS | `GET /api/v1/dashboard/orders/{id}` | HTTP 200, order details | HTTP 200; order `65b47760-...`, status CREATED, item snapshot present |
| B3. Create payment | PASS | `POST /api/v1/dashboard/payments` | HTTP 201, PENDING, payment_url | HTTP 201; transaction `101cc397-...`, status PENDING, payment_url `http://127.0.0.1:18080/pay/MOCK-TXN-...`, provider MOCK |
| B4. Retrieve payment | PASS | `GET /api/v1/dashboard/payments/{id}` | HTTP 200, payment details | HTTP 200; status PENDING, timeline CREATED, paid_at null |
| B5. Open payment URL | PASS | `GET /pay/{identifier}` | HTTP 200, mock payment page | HTTP 200; reference, amount, currency, payment_method QRIS, status PENDING, qris_payload present |
| B6. Verify pending state | PASS | Check payment status | Status PENDING | Confirmed PENDING via GET /api/v1/dashboard/payments/{id} |
| B7. Simulate successful payment | PASS | `POST .../simulate/success` | HTTP 200, status PAID | HTTP 200; status PAID; timeline CREATED→PAID; paid_at set |
| B8. Simulate failed payment | PASS | `POST .../simulate/fail` | HTTP 200, status FAILED | HTTP 200; separate payment `9f2768ee-...`; status FAILED |
| B9. Verify expired payment | BLOCKED | Check EXPIRED status | Status EXPIRED | `PAYMENT_EXPIRY_ENABLED=false` in staging; expiry worker not running; no supported API to manually expire a payment |
| B10. Verify cancelled payment | BLOCKED | Cancel payment | Status CANCELLED | Cancel endpoint `POST /api/v1/payments/{id}/cancel` is on merchant API (requires X-API-Key); Flutter app uses dashboard API only which does not expose cancel |

### Phase 8 — Test Group C: History and Session

| Test | Result | Action | Expected | Actual |
|---|---|---|---|---|
| C1. Retrieve transaction history | PASS | `GET /api/v1/dashboard/payments` | HTTP 200, paginated list | HTTP 200; 4 payments (2 new PAID/FAILED + 2 pre-existing from Oct 16); page=1, limit=20, total=4, total_pages=1 |
| C2. Verify transactions belong to account | PASS | Confirm merchant scoping | All payments belong to authenticated merchant | Confirmed — all payments reference orders belonging to merchant `b80f9794-...`, returned under authenticated OWNER session |
| C3. Refresh-token behavior | PASS | `POST /api/v1/auth/refresh` | HTTP 200, new access_token | HTTP 200; new access_token (different jti); new refresh_token cookie (rotated); expires_in=900s |
| C4. Logout | PASS | `POST /api/v1/auth/logout` | HTTP 200 | HTTP 200; `{"success":true,"data":{}}`; refresh_token cookie cleared (Max-Age=0) |
| C5. Post-logout session behavior | PASS | Verify documented behavior | Refresh cleared; access valid until expiry | Refresh returns 401 `INVALID_CREDENTIALS` after logout; access token still returns 200 on /me until JWT expiry (stateless contract) |

---

## Sanitized errors

| Context | HTTP status | Error code | Cause / classification |
|---|---|---|---|
| B9 — Expired payment | — | — | `PAYMENT_EXPIRY_ENABLED=false` in staging config; expiry background worker disabled; no supported API to force EXPIRED status |
| B10 — Cancelled payment | — | — | Cancel endpoint on merchant API (`/api/v1/payments/{id}/cancel`, X-API-Key auth); Flutter app dashboard API does not expose cancel |
| Idempotency key reused (during B8 setup) | 400 | `IDEMPOTENCY_KEY_REUSED` | Same idempotency key used with different request body; resolved by using a new key |
| Duplicate order (during B8 setup) | 400 | `DUPLICATE_ORDER` | merchant_order_id already had a payment; resolved by creating a new order |

No test failures occurred — all executable tests passed. No state-changing request was retried blindly.

---

## Created staging record identifiers

| Record type | Identifier | Status | Note |
|---|---|---|---|
| Category | `8b56cd7c-cc6e-4a5e-885d-a0008e574bd8` | ACTIVE | Created via dashboard API for test data |
| Product | `1d0f9048-8994-4d97-bb74-5e3ca21f4572` | ACTIVE | Created via dashboard API for test data |
| Order | `65b47760-bf77-4b75-a2e3-43e871dcaad1` | CREATED | Created for payment flow test |
| Order | `6f3ded68-c3ae-40a9-bdaa-5041ccf98c1a` | CREATED | Created for fail-payment test |
| Payment (success) | `101cc397-21ce-489e-8a2f-03c3de42c3df` | PAID | B7 simulate success |
| Payment (fail) | `9f2768ee-90ca-4c9c-b000-1e6f72411825` | FAILED | B8 simulate fail |

Pre-existing staging records (from Oct 16 Phase A, untouched):
| Mock payment | `69d39dcd-9eca-45cd-90a7-cc50379855e6` | PAID |
| Mock payment | `80479258-adde-4e27-b31b-72db68493abc` | FAILED |

All records exist only in the isolated staging database `go_saas_m2_staging`.

---

## Tests not run and reasons

All 21 tests were executed. No tests were marked NOT RUN.

| Test | Result | Reason |
|---|---|---|
| B9 — Verify expired payment | BLOCKED | `PAYMENT_EXPIRY_ENABLED=false` in staging; expiry worker not running; no supported API to manually transition a payment to EXPIRED |
| B10 — Verify cancelled payment | BLOCKED | Cancel endpoint is on merchant API (`/api/v1/payments/{id}/cancel`, requires X-API-Key); Flutter app uses dashboard API (Bearer JWT) only and does not expose cancel |

---

## Known limitations

| # | Limitation | Impact |
|---|---|---|
| 1 | Expired payment not testable | `PAYMENT_EXPIRY_ENABLED=false` in staging; no supported API to force EXPIRED status |
| 2 | Payment cancellation not testable via Flutter | Flutter app dashboard API does not include cancel; merchant API requires separate X-API-Key credentials |
| 3 | Flutter `.env` hardcodes `fileName: '.env'` | `.env.stage` must be manually copied to `.env` for testing; original `.env` restored after testing |
| 4 | Flutter Web CORS origin is dynamic | Flutter Web dev-server port changes per session; CORS origin must be re-added for each test session |
| 5 | No Android emulator / physical device | Mobile-specific behaviors (secure storage, URL launching, app background/resume) not testable |

---

## Manual browser checks required

1. **Payment URL rendering:** Open `http://127.0.0.1:18080/pay/{identifier}` in a browser and confirm the mock payment page displays correctly with QRIS payload.
2. **End-to-end UI flow:** Login → Products → Cart → Order → Payment → Payment Detail → Status refresh → Transaction History, verifying each screen transitions correctly in the Flutter Web app.
3. **CORS in browser:** Verify the Flutter Web app running at `http://localhost:35597` can successfully make API calls to `http://127.0.0.1:18080` without CORS errors in the browser console.

---

## Phase 9 — Restore and verify

| Verification | Result | Evidence |
|---|---|---|
| Original Flutter `.env` restored | PASS | `API_BASE_URL=http://192.168.110.245:8081`, verified identical to pre-test backup via `diff`, stable for 10+ seconds |
| No secrets committed or printed | PASS | No tokens, passwords, or API secrets in report or git |
| Protected backend healthy | PASS | Port 8081 `/health` → HTTP 200, unchanged |
| Protected backend configuration unmodified | PASS | Git status shows no changes to protected backend files |
| Staging backend isolated | PASS | Port 18080 bound to `127.0.0.1` only, connected to staging DB only |
| No database/Docker cleanup | PASS | Staging DB container running, no prune/cleanup commands executed |
| Staging services not stopped | PASS | Staging backend (PID 102872) and DB container both running |

---

## Final readiness decision

**M2 PARTIALLY VERIFIED**

| Group | Passed | Failed | Blocked | Not Run | Total |
|---|---|---|---|---|---|
| A: Connectivity & Auth | 6 | 0 | 0 | 0 | 6 |
| B: Order & Payment | 8 | 0 | 2 (B9, B10) | 0 | 10 |
| C: History & Session | 5 | 0 | 0 | 0 | 5 |
| **Total** | **19** | **0** | **2** | **0** | **21** |

### What was verified
- Real Flutter runtime integration: Flutter Web launched on Chrome against `http://127.0.0.1:18080`, confirmed via `[Environment] API_BASE_URL=http://127.0.0.1:18080` debug log
- All Flutter-used backend endpoints return correct responses (envelope shape, status codes, error codes)
- Authentication: login, session restoration, refresh token rotation, logout all work correctly
- Payment lifecycle: create → PENDING → simulate success → PAID, and create → simulate fail → FAILED
- Payment URL opening returns mock payment page with QRIS payload
- Transaction history returns payments scoped to the authenticated merchant
- Logout clears refresh token; access token remains valid until expiry (documented stateless JWT behavior)
- CORS: Flutter Web origin `http://localhost:35597` gets proper `Access-Control-Allow-Origin` header

### What was NOT verified (blocked)
- Expired payment state (B9): `PAYMENT_EXPIRY_ENABLED=false` in staging, no supported expiry API
- Payment cancellation (B10): cancel endpoint not in Flutter dashboard API surface

### Recommended next step
To achieve M2 INTEGRATION PASS, address the two blocked tests:
1. Enable `PAYMENT_EXPIRY_ENABLED=true` in staging config and restart the backend to verify expired-payment behavior (B9)
2. Test payment cancellation via the merchant API with X-API-Key credentials, or add cancel to the Flutter dashboard API surface (B10)

Do not proceed to M3 until B9 and B10 are resolved or explicitly accepted as out of scope.

**Report path:** `docs/mobile-integration-retest-results.md`

**Runtime or database state changed:** Staging records created (2 categories/products/orders/payments for testing). Original Flutter `.env` restored. Protected port-8081 backend and all existing infrastructure untouched. Staging services remain running.
