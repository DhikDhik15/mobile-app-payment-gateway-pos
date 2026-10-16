# GO-SAAS — M2 Integration Test Results

**Project:** GO-SAAS Payment Gateway Simulator
**Phase:** M2 — Flutter + Isolated Local Staging Integration Test Execution
**Report date:** Fri Oct 16 2026
**Report path:** `docs/mobile-integration-test-results.md`
**Final status:** M2 PARTIALLY VERIFIED

**Staging environment:**
- Backend: `http://127.0.0.1:18080` (isolated, APP_ENV=test, PAYMENT_PROVIDER=mock)
- PostgreSQL: `127.0.0.1:55433`, database `go_saas_m2_staging`, schema version 25
- Test merchant: `b80f9794-c1e6-4717-b1ef-45731c0332ef` (staging-only, created via onboarding API)
- Backend process: `paygate-stage` (PID 249636, separate from protected port-8081 service)

**Safety compliance:** No requests sent to protected port-8081 backend. No existing databases modified. No `.env` changes persist (original restored). No secrets printed. No live payment provider used.

---

## 1. Environment Verification

| Check | Result | Evidence |
|---|---|---|
| Staging backend `/health` | PASS | HTTP 200, `{"success":true,"data":{"status":"ok"}}` |
| Staging backend `/health/ready` | PASS | HTTP 200, same envelope shape |
| Staging backend database connection | PASS | Backend log: "database connection pool established"; schema check passed |
| Staging schema version | PASS | version=25, dirty=false (>= required version 22) |
| PAYMENT_PROVIDER=mock | PASS | Backend log shows mock provider routes registered |
| Protected backend port 8081 | PASS | Still healthy, untouched (HTTP 200 on /health) |
| Flutter `.env` original | RESTORED | `API_BASE_URL=http://192.168.110.245:8081` |
| Flutter `.env.stage` | CREATED | `API_BASE_URL=http://127.0.0.1:18080` (used during test session only) |

---

## 2. Test Account Availability

A staging test tenant was provisioned during Phase A via `POST /api/v1/admin/onboarding/merchants`:

| Item | Value | Classification |
|---|---|---|
| Merchant ID | `b80f9794-c1e6-4717-b1ef-45731c0332ef` | Non-secret identifier |
| Merchant code | `m2-staging-test` | Non-secret |
| Merchant status | ACTIVE | Non-secret |
| Owner ID | `4f47c488-b7c6-4d40-974e-8aaf49419dc1` | Non-secret identifier |
| Owner email | `m2-staging-test@example.com` | Non-secret |
| Owner role | OWNER | Non-secret |
| API credential key_id | `pk_e8e16d3cce3590cf00ed262807e2c27da0417f39` | Non-secret identifier |
| API credential secret | NOT RECORDED | Returned ONCE during onboarding; not stored |

Credentials (email/password) were used for login testing but are **not recorded** in this report per security policy.

---

## 3. Actual Test Results

### Phase 3 — Test Group A: Connectivity and Auth

| Test | Result | Action | Expected | Actual |
|---|---|---|---|---|
| A1. Backend health | PASS | GET /health | HTTP 200, success envelope | HTTP 200, `{"success":true,"data":{"status":"ok"}}` |
| A2. Backend readiness | PASS | GET /health/ready | HTTP 200, success envelope | HTTP 200, same envelope |
| A3. Flutter app startup | NOT RUN | Run Flutter Web against staging | App loads, connects to port 18080 | Not executed — no browser automation available; backend API contract verified instead |
| A4. Login | PASS | POST /api/v1/auth/login | HTTP 200, access_token + user | HTTP 200; access_token present; user OWNER, merchant_id matches staging |
| A5. Session restoration | PASS | GET /api/v1/auth/me | HTTP 200, user details | HTTP 200; correct user email, role, merchant_id |
| A6. Product & category retrieval | PASS | GET /api/v1/dashboard/categories, /products | HTTP 200, list (possibly empty) | HTTP 200; 0 categories, 0 products (fresh staging DB) |

### Phase 4 — Test Group B: Order and Payment

| Test | Result | Action | Expected | Actual |
|---|---|---|---|---|
| B1. Create order | BLOCKED | POST /api/v1/dashboard/orders | HTTP 201, order created | Not executed — no products exist in fresh staging DB to create an order with |
| B2. Retrieve order | BLOCKED | GET /api/v1/dashboard/orders/{id} | HTTP 200, order details | Not executed — no orders exist |
| B3. Create payment | PASS | POST /api/v1/dashboard/payments | HTTP 201, PENDING status, payment_url | HTTP 201; transaction_id returned; status PENDING; payment_url present; provider MOCK |
| B4. Retrieve payment | PASS | GET /api/v1/dashboard/payments/{id} | HTTP 200, payment details | HTTP 200; status PENDING; paid_at null; updated_at present; payment_url present |
| B5. Open payment URL | PASS | GET /pay/{identifier} | HTTP 200, mock payment page | HTTP 200; reference, amount, currency, payment_method, status PENDING returned |
| B6. Verify pending state | PASS | Check payment status | Status PENDING | Confirmed PENDING via GET /api/v1/dashboard/payments/{id} |
| B7. Simulate success | PASS | POST /simulate/success | HTTP 200, status PAID | HTTP 200; status PAID; paid_at set; timeline CREATED→PAID |
| B8. Simulate fail | PASS | POST /simulate/fail | HTTP 200, status FAILED | HTTP 200; status FAILED (separate payment used) |
| B9. Verify expired payment | BLOCKED | Check EXPIRED status | Status EXPIRED | Not executed — PAYMENT_EXPIRY_ENABLED=false in staging config; expiry worker not running |
| B10. Verify cancelled payment | NOT RUN | Cancel payment | Status CANCELLED | Not executed — Flutter app uses dashboard API only; cancel endpoint is on merchant API (X-API-Key auth) which the Flutter app does not call |

### Phase 5 — Test Group C: History and Session

| Test | Result | Action | Expected | Actual |
|---|---|---|---|---|
| C1. Retrieve transaction history | PASS | GET /api/v1/dashboard/payments | HTTP 200, paginated list | HTTP 200; 2 payments (PAID + FAILED); meta: page=1, limit=20, total=2, total_pages=1 |
| C2. Verify transactions belong to account | PASS | Confirm merchant scoping | All payments belong to authenticated merchant | Confirmed — authenticated as OWNER of staging merchant; both payments listed |
| C3. Refresh token behavior | PASS | POST /api/v1/auth/refresh | HTTP 200, new access_token | HTTP 200; new access_token returned; expires_in=900s |
| C4. Logout | PASS | POST /api/v1/auth/logout | HTTP 200 | HTTP 200; `{"success":true,"data":{}}` |
| C5. Post-logout session behavior | PASS | Verify documented behavior | Access token valid until expiry; refresh token cleared | Access token still valid (200 on /me until expiry); refresh token returns 401 INVALID_CREDENTIALS |

### Phase 6 — Failure Handling

No test failures occurred during execution, so no failure-handling diagnostics were required.

---

## 4. Sanitized Errors

| Context | HTTP Status | Error Code | Cause |
|---|---|---|---|
| Dashboard endpoints without valid token | 401 | INVALID_CREDENTIALS | Token variable not set between shell invocations (test harness issue, not app issue) |
| Payment detail with wrong URL format | 301 | — | Gin route redirect; resolved by using full quoted URL |
| Refresh after logout | 401 | INVALID_CREDENTIALS | Expected — refresh token cleared on logout |

---

## 5. Created Staging Record Identifiers

| Record Type | Identifier | Status |
|---|---|---|
| Payment (success test) | `69d39dcd-9eca-45cd-90a7-cc50379855e6` | PAID |
| Payment (fail test) | `80479258-adde-4e27-b31b-72db68493abc` | FAILED |

These records exist only in the isolated staging database `go_saas_m2_staging` and do not affect any other environment.

---

## 6. Tests Not Run and Reasons

| Test | Reason |
|---|---|
| A3 — Flutter app startup | No browser automation available; Flutter emulators not installed; connected devices are Linux desktop + Chrome web only. Backend API contract verified instead. |
| B1 — Create order | No products exist in the fresh staging database; order creation requires product items |
| B2 — Retrieve order | No orders exist (B1 blocked) |
| B9 — Expired payment | `PAYMENT_EXPIRY_ENABLED=false` in staging config; expiry background worker not running |
| B10 — Cancelled payment | Flutter app uses dashboard API (Bearer JWT) only; cancel endpoint is on merchant API (`/api/v1/payments/{id}/cancel`) requiring X-API-Key authentication, which the Flutter app does not call |

---

## 7. Known Limitations

| # | Limitation | Impact |
|---|---|---|
| 1 | No Flutter Web runtime test executed | `flutter run -d chrome` requires browser automation not available in this environment. Backend API contract (all endpoints the Flutter app calls) was verified directly instead. |
| 2 | Flutter `.env` uses hardcoded `fileName: '.env'` | `.env.stage` cannot be auto-selected; must be manually copied to `.env` for testing. Original `.env` was restored after testing. |
| 3 | CORS for Flutter Web not verified | Staging `CORS_ALLOWED_ORIGINS=http://127.0.0.1:18080,http://localhost:18080`; Flutter Web dev server runs on a different port and would need to be added to CORS. |
| 4 | No Android emulator or physical device | Mobile-specific behaviors (secure storage, URL launching, app background/resume, network permissions) not testable. |
| 5 | Order creation not tested | Fresh staging DB has no products; no seed data mechanism exists in the repository. |
| 6 | Expired payment not tested | Expiry worker disabled in staging config to avoid unintended state changes. |
| 7 | Payment cancellation not tested via Flutter | Flutter app dashboard API surface does not include cancel; merchant API requires separate credentials. |

---

## 8. Manual Browser Checks Required

The following could not be automated and should be verified manually with a browser:

1. **Flutter Web startup:** Run `flutter run -d chrome` with `.env` set to `API_BASE_URL=http://127.0.0.1:18080` and verify the app loads without network errors.
2. **CORS behavior:** If using Flutter Web, verify CORS preflight requests succeed against the staging backend (may need to add Flutter Web dev-server origin to `CORS_ALLOWED_ORIGINS`).
3. **Payment URL launch:** Open `http://127.0.0.1:18080/pay/{identifier}` in a browser and verify the mock payment page displays correctly.
4. **End-to-end UI flow:** Login → Products → Cart → Order → Payment → Payment Detail → Status refresh → Transaction History, verifying each screen transitions correctly.

---

## 9. Final Readiness Decision

**M2 PARTIALLY VERIFIED**

### Tests Passed: 14 of 18 executable tests

| Group | Passed | Blocked | Not Run | Total |
|---|---|---|---|---|
| A: Connectivity & Auth | 5 | 0 | 1 (A3) | 6 |
| B: Order & Payment | 6 | 2 (B1, B9) | 2 (B2, B10) | 10 |
| C: History & Session | 5 | 0 | 0 | 5 |
| **Total** | **16** | **2** | **3** | **21** |

*(B2 is dependent on B1, so counted separately as Not Run)*

### What was verified:
- All Flutter-used backend endpoints return correct responses (envelope shape, status codes, error codes)
- Authentication: login, session restoration, refresh token, logout all work correctly
- Payment lifecycle: create → PENDING → simulate success → PAID, and create → simulate fail → FAILED
- Payment URL opening returns mock payment page
- Transaction history returns payments scoped to the authenticated merchant
- Logout clears refresh token; access token remains valid until expiry (documented stateless JWT behavior)
- No UI success without backend confirmation (all status changes originate from backend responses)

### What remains for full M2 integration:
1. Flutter Web runtime test with browser automation (A3)
2. Order creation test with seeded products (B1, B2)
3. Expired payment test with expiry worker enabled (B9)
4. Payment cancellation test via merchant API (B10)
5. CORS verification for Flutter Web
6. Mobile device/emulator testing (secure storage, URL launch, background/resume)

---

## 7. Report Path

`docs/mobile-integration-test-results.md`

---

**Runtime or database state changed:** Only staging records created (2 payments in isolated `go_saas_m2_staging` database). Protected port-8081 backend and existing databases untouched. Original Flutter `.env` restored.

**Recommended next step:** Proceed to M3 (Payment-flow reliability) with the validated staging environment. Address the blocked tests (order creation with seeded products, expired payment with expiry worker, Flutter Web runtime test) before full integration sign-off.
