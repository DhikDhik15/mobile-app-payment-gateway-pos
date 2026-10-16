# GO-SAAS Payment Gateway Simulator — Flutter Staging Integration Validation (M2)

**Repository audited:** `/run/media/dhika/Dhika/payment_simulator` (Flutter)
**Backend repository audited (static inspection only):** `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend`
**Phase:** M2 — Flutter Staging Integration Validation (READ-ONLY; no source, backend, database, or Git changes)
**Report date:** Fri Oct 16 2026
**Report path:** `docs/mobile-staging-validation.md`
**M2 status:** **BLOCKED** — runtime execution blocked; no staging environment positively identified

---

## 1. Executive Summary

Phase M2 was prepared and partially executed. The objective was to validate the existing Flutter application against a running **staging** backend using an emulator or real device.

**Key determination:** No staging environment is positively identified. The only reachable backend is a **local development** instance (`pay-gate-app` Docker container on `127.0.0.1:8081`, locally-built image, `APP_ENV=development` defaults). Per M2 instructions ("Do not assume that an available backend is a staging backend" and "If a staging environment cannot be positively identified, stop before sending any state-changing API request"), **no state-changing runtime tests were executed.**

Read-only connectivity checks (`GET /health`, `GET /health/ready`) were performed against `127.0.0.1:8081` only — both return HTTP 200 with the expected success envelope. These are non-state-changing and safe.

**Configuration mismatch found:** The Flutter app is configured (`API_BASE_URL`) to `http://192.168.110.245:8081`, which is **not** this machine's interface and does not respond. The local backend is reachable only on `127.0.0.1:8081`. A Flutter build running on this machine against its current `.env` would be unable to reach the backend.

**Result:** M2 is **BLOCKED** for runtime execution. Static integration checks (Step 2) are complete. A runtime validation plan (Step 3) and device/platform observations (Step 5) are documented below. Recommended next action is M3 preparation: provision a confirmed staging backend, align Flutter base URL, and add test credentials.

---

## 2. Confirmed Staging Environment Details

**No staging environment was confirmed.** The backend repositories' own documentation defines staging as separate infrastructure:

- `docs/phase-4c-deployment-architecture-specification.md` (§): "Separate staging and production databases and credentials"; staging requires a staging VPS, PostgreSQL, ingress, frontend host, registry, and secret management — none of which is present in the current environment.
- `docs/phase-9-production-runbook.md`: "Create separate staging/production database users and databases"; "Never point staging at a production database or use production secrets"; "Use a disposable/synthetic staging tenant."
- `docs/phase-4b-backend-local-to-production-report.md`: "Production/staging must inject `MIGRATION_DATABASE_URL` ... The Compose fallback assembled from `DB_*` variables is development-only."

**What IS running (local development, not staging):**

| Item | Observed value | Environment class |
|---|---|---|
| Backend container | `pay-gate-app`, image `pay-gate-backend-app`, created ~4 hours ago, healthy | Locally built dev image |
| Backend listen port | Container 8080, published to host `0.0.0.0:8081` | Docker dev Compose |
| `APP_ENV` | Development defaults (per `.env.example`: `APP_ENV=development`) | Development |
| CORS allowed origins | `http://localhost:5173` (per `.env.example`) | Development |
| `DB_SSLMODE` | `disable` (per `.env.example`) | Development |
| `PAYMENT_SIMULATOR_ENABLED` | `false` (per `.env.example`) | Development (fail-closed) |
| `FRONTEND_PUBLIC_URL` | `http://localhost:5173` | Development |

**No test accounts or test credentials are documented** anywhere in either repository. The backend `docs/phase-0d-live-payment-integration-report.md` references a test merchant provisioned in a prior phase via `POST /api/v1/admin/onboarding/merchants` with `X-Admin-Key`, but that credential is described as "used internally only, not disclosed," and no current test account exists in documentation.

**Missing (documented as required for staging but absent):**
- Separate staging database and credentials
- Staging `APP_ENV=production` configuration
- Documented staging test merchant / dashboard user / API key
- Disposable/synthetic staging tenant
- Staging base URL distinct from localhost/LAN dev address

---

## 3. Flutter Configuration Assessment

### 3.1 Base URL configuration
- **Mechanism:** `AppEnvironment` (`lib/core/config/app_environment.dart`) reads `API_BASE_URL` from the bundled `.env` asset via `flutter_dotenv`; `validate()` fails fast if empty.
- **Configured value:** `.env` contains `API_BASE_URL=http://192.168.110.245:8081` (not printed in full per safety policy; the host portion is noted for network assessment only).
- `.env.example`: `API_BASE_URL=http://localhost:8081`.
- No `--dart-define` or flavor mechanism; single `.env` is the sole source of truth (`app_environment.dart:11-12`).
- HTTPS is not required by the client code; `ApiClient` uses whatever scheme is in `API_BASE_URL`. `NetworkConfig.defaultHeaders` sets `Content-Type`/`Accept` to `application/json` only — no TLS-pinning or certificate validation override (TLS validation is never disabled).

### 3.2 Endpoint definitions (`lib/core/network/api_endpoints.dart`)
All Flutter-used endpoints map to the dashboard API surface (`/api/v1/dashboard/*`), authenticated by Bearer JWT. The Flutter client deliberately does **not** use the Merchant API (`/api/v1/payments*`, `X-API-Key`) or the public merchant simulator (`/api/v1/simulator/payments*`) — documented at `payment_remote_datasource.dart:13`.

### 3.3 Android emulator vs physical-device URL configuration
No emulator-specific or device-specific URL overrides exist. A single `API_BASE_URL` applies to all platforms. The code comment in `app_environment.dart:9` suggests `http://192.168.x.x:8081` for LAN, but there is no conditional logic for emulator (`10.0.2.2`) vs physical device vs host browser. This is a gap for multi-device testing.

### 3.4 Secrets
No secrets, tokens, API keys, or credentials are stored in Flutter source. `.env` holds only `API_BASE_URL`. Token storage uses `flutter_secure_storage` (Android Keystore / iOS Keychain) — no SharedPreferences or plain files.

---

## 4. API Contract Verification (Static, Step 2)

Flutter implementation compared against backend handlers, models, and `swagger/swagger.json`. All checks below are **static source inspection** (no live API calls beyond read-only `/health`).

| Area | Flutter side | Backend side | Verified match? | Evidence |
|---|---|---|---|---|
| Auth login | `POST /api/v1/auth/login`, body `{email, password}` | `AuthHandler.Login` (`auth_handler.go:54-93`) | Yes | `auth_remote_datasource.dart:49-55` |
| Refresh token delivery | Captured from `Set-Cookie: refresh_token=…`, sent via `X-Refresh-Token` header | HttpOnly cookie + `X-Refresh-Token` fallback (`auth_handler.go:273-278`) | Yes | `dio_api_client.dart:255-267`, `auth_handler.go:273-278` |
| Logout | `POST /api/v1/auth/logout`, Bearer; clears local tokens even on backend failure | `AuthHandler.Logout` clears cookie; stateless access JWT valid until `exp` | Yes | `auth_repository_impl.dart:31-41`, `auth_handler.go:109-157` |
| Me | `GET /api/v1/auth/me` → `DashboardUserResponse` | `AuthHandler.Me` | Yes | `auth_remote_datasource.dart:68-76` |
| Health | `GET /health`, `GET /health/ready` | `health_handler` | Yes (read-only check passed) | `api_endpoints.dart:10-11` |
| Create payment | `POST /api/v1/dashboard/payments`, body `{merchant_order_id, amount, currency, payment_method}`, header `Idempotency-Key` | `DashboardPaymentHandler.CreatePayment` | Yes | `payment_remote_datasource.dart:80-98` |
| Order-scoped payment create | `POST /api/v1/dashboard/orders/{order_id}/payments`, body `{payment_method}` | `DashboardOrderPaymentHandler.CreatePayment` | Yes | `payment_remote_datasource.dart:162-175` |
| Order payment list | `GET /api/v1/dashboard/orders/{order_id}/payments` (read-only) | `DashboardOrderPaymentHandler.ListPayments` | Yes | `payment_remote_datasource.dart:204-231` |
| Get payment | `GET /api/v1/dashboard/payments/{payment_id}` | `DashboardPaymentHandler.GetPayment` | Yes | `payment_remote_datasource.dart:100-106` |
| List payments | `GET /api/v1/dashboard/payments` (page/limit omitted → backend defaults) | `DashboardPaymentHandler.ListPayments` | Yes | `payment_remote_datasource.dart:109-110` |
| Simulate success/fail | `POST /api/v1/dashboard/payments/{id}/simulate/success\|fail` | `DashboardPaymentHandler.SimulateSuccess/Failure` | Yes | `api_endpoints.dart:48-51` |
| Create order | `POST /api/v1/dashboard/orders`, body `{items:[{product_id, quantity}]}`, header `Idempotency-Key` | `DashboardOrderHandler.CreateOrder` | Yes | `order_remote_data_source.dart:37-47` |
| Get order | `GET /api/v1/dashboard/orders/{order_id}` | `DashboardOrderHandler.GetOrder` | Yes | `order_remote_data_source.dart:93-100` |
| List orders | `GET /api/v1/dashboard/orders?page=&limit=` | `DashboardOrderHandler.ListOrders` | Yes | `order_remote_data_source.dart:50-90` |
| List categories | `GET /api/v1/dashboard/categories` | `DashboardCategoryHandler` | Yes | `api_endpoints.dart:42-43` |
| List products | `GET /api/v1/dashboard/products` | `DashboardProductHandler` | Yes | `api_endpoints.dart:45-46` |
| Dashboard overview | `GET /api/v1/dashboard/overview` | `DashboardOverviewHandler` | Yes | `api_endpoints.dart:41` |
| Response envelope | `{"success":true,"data":...,"meta":...}` / error `{"success":false,"error":{code,message,details}}` | `pkg/response/response.go` | Yes | `dio_api_client.dart:334-365` |
| Status enum | CREATED/PENDING/PAID/FAILED/EXPIRED/CANCELLED (closed, throws on unknown) | `TransactionStatus` (`transaction.go:14-20`) | Yes | `payment.dart:73-79` |
| Idempotency error codes | `PAYMENT_PROVIDER_ERROR`, `PAYMENT_PROVIDER_TIMEOUT`, `INVALID_TRANSACTION_STATE`, `IDEMPOTENCY_KEY_REUSED`, `IDEMPOTENCY_REQUEST_IN_PROGRESS`, etc. | `pkg/response/response.go:60-64` | Yes | `payment_error_kind.dart:55-100` |

**No contract mismatches were found** in the statically inspected surface. The Flutter `DioApiClient` correctly unwraps the envelope, maps `error.code` into `ApiException.code`, and `classifyOrderPaymentError` covers every documented backend error code with HTTP-status fallbacks.

---

## 5. Test Matrix (Step 3 — planned, not executed)

Because no staging environment is confirmed, **no tests in this matrix were executed.** Each is documented for future M2/M3 execution against a confirmed staging backend.

| # | Test | Preconditions | Test steps | Expected API behavior | Expected UI behavior | Creates/Changes state? |
|---|---|---|---|---|---|---|
| 1 | Login | Staging backend reachable; valid staging test account | Enter email/password → submit | 200 `LoginResponse` (`access_token` + user); refresh token via `Set-Cookie` | `AuthAuthenticated`; advances past login to home | No (session only) |
| 2 | Session restoration | Staging backend reachable; stored refresh token | Cold-start app | `GET /api/v1/auth/me` 200 (transparent 401→refresh retry if needed) | Restores `AuthAuthenticated` without login prompt | No |
| 3 | Product & category retrieval | Staging backend reachable; authenticated | Open Products page | 200 product/category list | Catalog displays items | No |
| 4 | Order creation | Authenticated; cart has items | Add to cart → create order | 201 `Order` (or 200 idempotency replay) | Order confirmation page shows order | Yes (creates order) |
| 5 | Payment creation | Authenticated; order exists | Continue to Payment → Pay | 201 `CreatePaymentResponse` incl. `payment_url` | Payment detail page; "Open payment page" button | Yes (creates payment) |
| 6 | Payment URL launch | Payment has non-null `payment_url` | Tap "Open payment page" | N/A (client-side URL launch) | External browser opens; snackbar confirms dispatch | No |
| 7 | Pending payment retrieval | Payment in `CREATED`/`PENDING` | Pull-to-refresh / reopen detail | 200 `PaymentResponse` status `PENDING` | Status chip shows PENDING; simulator buttons visible (debug) | No |
| 8 | Successful payment | Payment pending; staging simulator enabled | Simulate success | 200 `{"status":"PAID"}`; GET payment → `PAID` | Status transitions to PAID; `paidAt` set | Yes (state transition) |
| 9 | Failed payment | Payment pending; staging simulator enabled | Simulate fail | 200 `{"status":"FAILED"}`; GET payment → `FAILED` | Status transitions to FAILED | Yes |
| 10 | Expired payment | Payment past `expired_at`, still `PENDING` | Retrieve payment | 200 status `EXPIRED` | Status chip shows EXPIRED | No (backend worker-driven) |
| 11 | Cancelled payment | Payment `CREATED`/`PENDING` | Cancel via backend | 200 status `CANCELLED` | Status chip shows CANCELLED | Yes |
| 12 | Transaction history | Authenticated | Open Transactions page | 200 paginated payment list with `meta` | List displays transactions; pull-to-refresh works | No |
| 13 | Token refresh | Access token expired; valid refresh token | Make authenticated request after expiry | 401 → transparent refresh → retry 200 | Request completes without login prompt | No (rotates tokens) |
| 14 | Logout | Authenticated | Tap Sign out | 200; refresh cookie cleared | `AuthUnauthenticated`; returns to login; tokens cleared | No (clears session) |

**Assumptions in this matrix (to be verified before execution):**
- A staging test merchant/dashboard user exists with known credentials. (Not documented — must be provisioned.)
- `PAYMENT_SIMULATOR_ENABLED=true` on staging for tests 8–9 (fail-closed by default; staging must opt in and is prohibited in production).
- The staging `payment_url` is reachable from the test device/emulator for test 6.

---

## 6. Executed Tests and Actual Outcomes

Only **read-only, non-state-changing** checks were performed, because no staging environment is confirmed.

| Check | Target | Outcome |
|---|---|---|
| `GET /health` | `http://127.0.0.1:8081/health` | HTTP 200; `{"success":true,"data":{"status":"ok"},"meta":{...}}` |
| `GET /health/ready` | `http://127.0.0.1:8081/health/ready` | HTTP 200; `{"success":true,"data":{"status":"ok"},"meta":{...}}` |
| `GET /health` | `http://192.168.110.245:8081/health` (Flutter-configured URL) | **Connection failed (HTTP 000)** — not reachable from this machine |
| `flutter analyze` | Flutter source | Passes; 1 INFO lint (`test/payment_detail_test.dart:135`) — pre-existing, unrelated |
| `flutter test` | Flutter test suite | **363 passed, 0 failed** — matches M1 baseline |

**Tests NOT executed (all state-changing, requiring confirmed staging):**
- Tests 1–14 in the matrix above (login, session restore, products, order creation, payment creation, URL launch, pending/successful/failed/expired/cancelled retrieval, transaction history, token refresh, logout).

**Reason:** No staging environment positively identified; no documented test account/credentials; running backend is local development. Per M2 safety rules, state-changing requests were not sent.

---

## 7. Device/Platform Observations (Step 5)

| Observation | Detail |
|---|---|
| Connected devices | Linux desktop (`linux-x64`), Chrome web (`web-javascript`) |
| Emulators | **None available** (`flutter emulators` reports "No emulators available") |
| Physical devices | None detected |
| Flutter doctor | No issues; Android toolchain SDK 36, Chrome, Linux toolchain all OK |
| Backend reachability | Local Docker backend reachable on `127.0.0.1:8081`; Flutter-configured LAN IP `192.168.110.245:8081` **not reachable** (this machine's interface is `192.168.102.215/23`) |
| Secure storage | `flutter_secure_storage` (Android Keystore / iOS Keychain) — not testable on Linux desktop/web without device |
| URL launching | `url_launcher` with `LaunchMode.externalApplication` — behavior on Linux desktop/web not verified against real payment URL |
| App background/resume | `PaymentDetailPage` uses `AppLifecycleListener.onResume` — not testable without mobile device |
| Network permissions | No platform network-permission configuration inspected (Android `usesCleartextTraffic`, iOS ATS) — relevant if staging uses HTTP vs HTTPS |
| HTTP vs HTTPS | Flutter client makes no TLS assumptions; staging may require HTTPS (`WEBHOOK_REQUIRE_HTTPS`, `DB_SSLMODE=verify-full` in prod) — client must use `https://` base URL if staging enforces TLS |

**Platform limitation:** No Android emulator or physical device is available, so mobile-specific behaviors (secure storage, URL launching to external app, app background/resume, Android network permissions, cleartext traffic policy) cannot be validated in this environment.

---

## 8. Findings with Severity

### F1 — BLOCKER: No staging environment confirmed (Critical for M2 execution)
- **Severity:** Critical (blocks M2 runtime execution)
- **Evidence:** Running backend is locally-built `pay-gate-app` with development defaults (`APP_ENV=development`, `CORS_ALLOWED_ORIGINS=http://localhost:5173`, `DB_SSLMODE=disable`). Staging docs (`phase-4c`, `phase-9-production-runbook`) require separate staging infrastructure not present. No documented test account/credentials.
- **Recommendation:** Provision a confirmed staging backend (separate DB, `APP_ENV=production` for validation per `phase-4c`), create a synthetic staging tenant with documented credentials, then execute the test matrix.

### F2 — High: Flutter base URL does not reach any backend from this machine
- **Severity:** High
- **Evidence:** `.env` `API_BASE_URL=http://192.168.110.245:8081`; curl to that address returned connection failure (HTTP 000). Local backend responds on `127.0.0.1:8081`. This machine's interface is `192.168.102.215/23`, not `192.168.110.x`.
- **Recommendation:** Align `API_BASE_URL` to the confirmed backend reachable from the target device before any runtime test. For emulator testing, consider `10.0.2.2:8080` (Android emulator → host) or the host LAN IP.

### F3 — Medium: No emulator or physical device available
- **Severity:** Medium
- **Evidence:** `flutter emulators` → "No emulators available"; `flutter devices` → Linux desktop + Chrome web only.
- **Recommendation:** Create an Android emulator or connect a physical device to validate mobile-specific behaviors (secure storage, URL launch, background/resume, network permissions).

### F4 — Low: No platform-specific URL overrides (emulator vs device vs host)
- **Severity:** Low
- **Evidence:** `app_environment.dart` uses a single `API_BASE_URL` from `.env` with no conditional for emulator (`10.0.2.2`) vs physical device.
- **Recommendation:** Add environment/flavor support or per-platform base-url resolution if multi-device staging validation is required.

### F5 — Informational: Read-only health checks pass on local dev backend
- **Severity:** Informational
- **Evidence:** `GET /health` and `GET /health/ready` on `127.0.0.1:8081` both return HTTP 200 with the expected success envelope, matching Flutter's `NetworkResponse` envelope unwrapping (`dio_api_client.dart:334-365`).
- **Note:** This confirms the local backend is running and the contract envelope shape is as expected, but it is **not** a staging validation.

---

## 9. Verified vs Unverified Items

### Verified (executed or statically confirmed)
- Flutter `flutter analyze` passes (1 pre-existing INFO lint); `flutter test`: 363 passed, 0 failed.
- Backend `/health` and `/health/ready` return HTTP 200 with the expected success envelope on `127.0.0.1:8081`.
- Static API contract comparison: all Flutter-used endpoints, payloads, envelopes, status values, and error codes match the backend (see Section 4 table).
- Flutter is configured to `API_BASE_URL=http://192.168.110.245:8081` (value noted; full `.env` not printed).
- No staging environment, test account, or test credentials are documented.
- No emulator is available.

### Unverifiable / not verified in M2
- Live backend behavior beyond read-only `/health` (no state-changing calls made).
- Actual login, session restoration, order creation, payment creation, payment URL launch, status transitions, transaction history, token refresh, logout against a live backend.
- Real-device/emulator behavior (secure storage, URL launching, app background/resume, network permissions, HTTP vs HTTPS).
- Token refresh rotation end-to-end against a live auth server.
- Whether `192.168.110.245:8081` is reachable from a different network/device (only tested from this machine, where it failed).

---

## 10. Recommended M3 Work

M3 (Payment-flow reliability) should proceed **after** M2 unblocking:

1. **Unblock M2 first:** Provision a confirmed staging backend (separate staging DB, credentials, `APP_ENV` appropriate for validation), create a documented synthetic staging tenant with test credentials, and align the Flutter `API_BASE_URL` to a URL reachable from the test device.
2. **Execute the Section 5 test matrix** (tests 1–14) against staging, verifying each creates/changes state only as documented and cleaning up test data where applicable.
3. **Address F2:** Align Flutter base URL; consider emulator (`10.0.2.2`) vs physical-device URL resolution.
4. **Address F3:** Set up an Android emulator or physical device for mobile-specific validation.
5. **Add automated integration tests** against the staging backend (not real payments; use simulator/sandbox endpoints only), covering token refresh, payment status transitions, and error recovery.
6. **Acceptance criteria for M2 unblocking:** Staging backend confirmed (not localhost/dev), test credentials documented, Flutter base URL reaches staging from the test device, at least one read-write smoke test (e.g., login → products → order → payment creation → status retrieve) executed successfully without real payment instruments.

---

## 11. Conclusion

M2 is **BLOCKED** for runtime execution because no staging environment is positively identified. The only reachable backend is a local development instance, and the Flutter-configured base URL (`192.168.110.245:8081`) does not respond from this machine. Static integration checks confirm the Flutter contract matches the backend, and all 363 unit/widget tests pass.

No source code, backend code, database, or Git state was modified. The only deliverable is this report at `docs/mobile-staging-validation.md`.

**Recommended next action:** Provision a confirmed staging backend and documented test credentials, align the Flutter base URL, then execute the Section 5 test matrix (M2 unblocking) before proceeding to M3.
