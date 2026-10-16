# GO-SAAS Payment Gateway Simulator — Flutter Mobile Integration Audit (M1)

**Repository audited:** `/run/media/dhika/Dhika/payment_simulator` (Flutter)
**Backend repository audited (static inspection only):** `/run/media/dhika/Dhika/go-pay-gate/pay-gate-backend`
**Phase:** M1 — Flutter Mobile Integration Audit (READ-ONLY audit; no source, backend, database, or Git changes)
**Audit date:** Fri Oct 16 2026
**Report path:** `docs/mobile-integration-audit.md`

---

## 1. Executive Summary

This is a read-only architecture, contract, and payment-flow audit of the Flutter mobile application (`payment_simulator`) and its integration with the GO-SAAS Payment Gateway Simulator backend (`pay-gate-backend`).

**Overall conclusion:** The Flutter application is a complete, well-structured, and well-tested integration with the backend. The payment flow (product selection → cart → order → payment → payment URL → status refresh → transaction history) is implemented end-to-end, relies on backend state rather than local assumptions, and correctly handles pending/successful/failed/expired/cancelled payments. No source code was found that reports payment success without backend confirmation.

### Current verified results
| Check | Result |
|---|---|
| Flutter SDK | 3.47.5 stable (Dart 3.13.4) — matches baseline |
| `flutter analyze` | Passes; 1 INFO lint: `test/payment_detail_test.dart:135` (`no_leading_underscores_for_local_identifiers`, local var `_backgroundAndResume`) |
| `flutter test` | **363 tests passed**, 0 failed |
| Git working tree (Flutter) | Clean (`commit mobile apps`) |
| Git working tree (backend) | Clean (`commit maintenance backend`) |

### Severity count
| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 3 |
| Informational | 7 |

There are **no Critical or High findings**. All Medium/Low findings are architectural or maintainability observations, not defects — none represent a case where the UI shows success without backend confirmation, and all payment-relevant error paths are handled.

---

## 2. Existing Feature Inventory

Each feature was classified by following actual code paths (not filename assumptions).

| Feature | Status | Notes |
|---|---|---|
| Application entry point & navigation | Implemented | `lib/main.dart` composition root; `GoSaasApp` wraps cubits in `MultiBlocProvider`, initial route is `AuthPage` |
| Authentication & session lifecycle | Implemented | Login, logout, refresh, session restore; `AuthCubit` state machine (Initial/CheckingSession/Authenticated/Unauthenticated/Loading/Failure) |
| API client & interceptors | Implemented | Shared `DioApiClient` (single instance), bearer token attach, 401→refresh→retry with single-flight, safe logging |
| Environment & base URL config | Implemented | `AppEnvironment` reads `API_BASE_URL` from `.env` via `flutter_dotenv`; fails fast if missing |
| Secure token storage | Implemented | `flutter_secure_storage` (Android Keystore / iOS Keychain); access + refresh token; never logged |
| Product / catalog flow | Implemented | Products page, product detail, categories, product image resolution |
| Cart & order flow | Implemented | Client-side in-memory cart (`CartCubit`); order create/list/get-by-id via dashboard API |
| Payment creation & details | Implemented | Create payment, order-scoped payment, get payment, list payments, simulate success/fail |
| Payment URL handling | Implemented | `payment_url_opener.dart` validation + `url_launcher`; launch failures produce actionable hints |
| Transaction list & details | Implemented | Paginated, filtered (status/method/search/date-range) list + detail page |
| Dashboard & backend connectivity | Implemented | Dashboard overview (revenue, paid/pending/failed counts, recent transactions); backend health check |
| Settings & logout | Implemented | Settings page shows session (email/role/merchant ID); sign-out clears tokens and cart |

No feature in the verified baseline list is missing.

---

## 3. Flutter Architecture Overview

### 3.1 Composition root (`lib/main.dart`)
- `main()` loads `.env`, calls `AppEnvironment.validate()`, then builds a single composition root:
  - One shared `AuthTokenStorage` (`SecureTokenStorage`) and one shared `DioApiClient` reused by every feature (features never instantiate HTTP clients directly — documented at `dio_api_client.dart:17-19`).
  - All cubits/use cases/repositories/datasources are wired here and injected into `GoSaasApp`.
  - `authCubit.checkSession()` runs before `runApp`; router decision is made by `AuthPage` based on auth state.
- Navigation: no named router; `AuthPage` is the `home` of `MaterialApp`. Feature pages are pushed via `MaterialPageRoute` from `HomePage._navigate` (`main.dart:200-243`).

### 3.2 Layering
Presentation (Bloc/Cubit) → Domain (use cases, entities, repository interfaces) → Data (repository impl, remote datasources, models) → Core (`DioApiClient`, `ApiClient`, `AppEnvironment`, `NetworkConfig`, `Failure`/`AppException`).
- `NetworkResponse` unwraps the backend success envelope so callers receive inner `data` plus `meta` (`network_response.dart:8-23`).

### 3.3 Key design decisions observed (verified from source)
- **Dual-token auth**: access token as `Authorization: Bearer` (in-memory + persisted); refresh token captured from `Set-Cookie: refresh_token=...` at login/refresh and persisted via `AuthTokenStorage`; refresh sent via `X-Refresh-Token` header (non-browser path) (`dio_api_client.dart:29-42`, `auth_handler.go:273-278`).
- **401 handling**: single-flight refresh; concurrent 401s share one in-flight refresh; failed refresh clears tokens → unauthenticated (`dio_api_client.dart:63-65, 278-329`).
- **Logout**: clears tokens locally even if backend call fails (`auth_repository_impl.dart:31-41`).
- **Cart**: purely client-side/in-memory; no server-side cart in the backend contract (`cart.dart:7`).
- **Payment list/details**: Flutter uses the **Dashboard API** (`/api/v1/dashboard/payments`, Bearer JWT), deliberately *not* the Merchant API (`/api/v1/payments`, `X-API-Key`) — documented at `payment_remote_datasource.dart:13`.
- **Simulation**: dev-only (`showSimulator = kDebugMode`); backend role checks remain the real authorization (`payment_detail_page.dart:28-33`).

---

## 4. Backend API Contract Comparison

The Flutter `ApiEndpoints` constants were compared against the backend handlers and the published OpenAPI spec (`swagger/swagger.json`). All Flutter-used endpoints exist on the backend with matching methods, auth, and payload shape.

### 4.1 Response envelope (verified)
Backend (`pkg/response/response.go:1-27`):
- Success: `{"success": true, "data": <payload>, "meta": {"request_id": ..., "page/limit/total/total_pages"?: ...}}`
- Error: `{"success": false, "error": {"code": "...", "message": "...", "details": {}}, "meta": {...}}`

Flutter (`dio_api_client.dart:334-365`): unwraps `success`/`data`/`meta`; on `success == false` throws `ApiException(statusCode, message, code)` carrying `error.code`. **Match.**

### 4.2 Endpoint-by-endpoint comparison (endpoints Flutter actually calls)

| Flutter call | Method | Route | Backend handler | Auth | Match? |
|---|---|---|---|---|---|
| Login | POST | `/api/v1/auth/login` | `AuthHandler.Login` | none | Yes — body `{email, password}`; resp `{access_token, token_type, expires_in, user}`; refresh via HttpOnly `Set-Cookie` |
| Logout | POST | `/api/v1/auth/logout` | `AuthHandler.Logout` | Bearer | Yes |
| Refresh | POST | `/api/v1/auth/refresh` | `AuthHandler.Refresh` | `X-Refresh-Token` / cookie | Yes |
| Me | GET | `/api/v1/auth/me` | `AuthHandler.Me` | Bearer | Yes — `DashboardUserResponse` |
| Health | GET | `/health`, `/health/ready` | `health_handler` | none | Yes |
| Create payment | POST | `/api/v1/dashboard/payments` | `DashboardPaymentHandler.CreatePayment` | Bearer + `Idempotency-Key` | Yes — body `{merchant_order_id, amount, currency, payment_method}` |
| Order payment create | POST | `/api/v1/dashboard/orders/{order_id}/payments` | `DashboardOrderPaymentHandler.CreatePayment` | Bearer + `Idempotency-Key` | Yes — body `{payment_method}` only; amount/currency/merchant/merchant_order_id derived server-side |
| Order payment list | GET | `/api/v1/dashboard/orders/{order_id}/payments` | `DashboardOrderPaymentHandler.ListPayments` | Bearer | Yes — read-only, newest first |
| Get payment | GET | `/api/v1/dashboard/payments/{payment_id}` | `DashboardPaymentHandler.GetPayment` | Bearer | Yes — `DashboardPaymentDetailResponse` (embeds `PaymentResponse` + `timeline` + `order_items`); Flutter reads needed fields, ignores extras |
| List payments | GET | `/api/v1/dashboard/payments` | `DashboardPaymentHandler.ListPayments` | Bearer | Yes — Flutter omits page/limit; backend defaults page=1, limit=20 |
| Simulate success/fail | POST | `/api/v1/dashboard/payments/{id}/simulate/success\|fail` | `DashboardPaymentHandler.SimulateSuccess/Failure` | Bearer | Yes — returns `{"status": "PAID\|FAILED"}`; Flutter re-fetches payment |
| Create order | POST | `/api/v1/dashboard/orders` | `DashboardOrderHandler.CreateOrder` | Bearer + `Idempotency-Key` | Yes — body `{items:[{product_id, quantity}]}`; 201 created / 200 replay |
| Get order | GET | `/api/v1/dashboard/orders/{order_id}` | `DashboardOrderHandler.GetOrder` | Bearer | Yes |
| List orders | GET | `/api/v1/dashboard/orders` | `DashboardOrderHandler.ListOrders` | Bearer | Yes — page/limit query |
| List categories | GET | `/api/v1/dashboard/categories` | `DashboardCategoryHandler` | Bearer | Yes |
| List products | GET | `/api/v1/dashboard/products` | `DashboardProductHandler` | Bearer | Yes |
| Dashboard overview | GET | `/api/v1/dashboard/overview` | `DashboardOverviewHandler` | Bearer | Yes — `period, payments, revenue, refunds, recent_payments` |

### 4.3 Data model alignment (verified)
- **Statuses**: backend `TransactionStatus` = CREATED/PENDING/PAID/FAILED/EXPIRED/CANCELLED (`transaction.go:14-20`); Flutter `PaymentStatus` / `TransactionStatus` enums use identical API values (`payment.dart:73-79`, `transaction.dart:86-92`). **Match.**
- **Amounts**: int64 minor units (IDR); Flutter casts `(json['amount'] as num).toInt()` (`payment_model.dart:43`). **Match.**
- **Timestamps**: RFC3339 ISO-8601; Flutter `DateTime.parse` / `DateTime.tryParse` with defensive defaults.
- **`updated_at` absent on create**: Backend `CreatePaymentResponse` has no `updated_at` (`transaction.go:164-177`). Flutter handles this explicitly — `updatedAt` falls back to `createdAt` (`payment_model.dart:32-36, 57-59`). **Match (defensive, already handled).**
- **Nullable fields**: `provider`, `providerTransactionId`, `paymentUrl`, `expiredAt`, `paidAt`, `orderId` are nullable in both backend (`*string` / `*time.Time` with omitempty) and Flutter (`String?` / `DateTime?`). **Match.**
- **Error codes**: Flutter `classifyOrderPaymentError` handles every backend code: `PAYMENT_PROVIDER_ERROR`, `PAYMENT_PROVIDER_TIMEOUT`, `INVALID_TRANSACTION_STATE`, `IDEMPOTENCY_KEY_REUSED`, `IDEMPOTENCY_REQUEST_IN_PROGRESS`, validation codes, `UNAUTHORIZED`/`INVALID_API_KEY`/`FORBIDDEN`/`MERCHANT_INACTIVE`, `RESOURCE_NOT_FOUND`/`TRANSACTION_NOT_FOUND`, plus HTTP status fallbacks (502, 504, 409, 400/422, 401/403, 404) (`payment_error_kind.dart:55-100`). Backend codes defined in `pkg/response/response.go:44-141`. **Match.**

### 4.4 Endpoints defined but not called by Flutter (not a gap — documented architectural choice)
- Merchant API `/api/v1/payments*` (requires `X-API-Key`): Flutter uses dashboard API instead (`payment_remote_datasource.dart:13`).
- Merchant simulator `/api/v1/simulator/payments*`: Flutter uses dashboard `/simulate/success\|fail` endpoints.
- Payment cancel (`/api/v1/payments/{id}/cancel`) and refunds (`/api/v1/payments/{id}/refunds`): backend exists; not exposed in Flutter UI (not in the M1 feature baseline).

---

## 5. End-to-End Payment Flow Assessment

### 5.1 Flow trace (all transitions implemented)

| Step | Flutter implementation | Relies on backend state? |
|---|---|---|
| Product selection | Products/catalog pages | Yes (live catalog) |
| Cart | `CartCubit`, client-side in-memory | No (device-only; no server cart) |
| Create order | `OrderCubit.createOrder()` → `POST /api/v1/dashboard/orders` | Yes (order created server-side; idempotency key per cart snapshot) |
| Order confirmation | `OrderConfirmationPage` → "Continue to Payment" | Yes (displays server order totals) |
| Create payment | `PaymentCheckoutPage` → `POST /api/v1/dashboard/orders/{order_id}/payments` | Yes (amount/merchant derived server-side; server-side active/paid guards) |
| Open payment URL | `PaymentDetailPage._openPaymentUrl()` via `payment_url_opener.dart` | Yes (URL from backend response) |
| Refresh / retrieve status | `PaymentDetailPage._refresh()` / pull-to-refresh / app-resume → `GET /api/v1/dashboard/payments/{id}` | Yes (authoritative backend status) |
| Display final result | `PaymentStatusIndicator` / `TransactionStatusChip` by `PaymentStatus` | Yes (backend status) |
| Transaction history | `TransactionCubit.loadTransactions()` → `GET /api/v1/dashboard/payments` | Yes (backend list) |

### 5.2 Status handling
Pending (`CREATED`/`PENDING`), Successful (`PAID`), Failed (`FAILED`), Expired (`EXPIRED`), Cancelled (`CANCELLED`) are all represented by closed enums that throw `ArgumentError` on unknown backend values (`payment.dart:90-95`, `transaction.dart:103-108`). This makes contract changes visible as typed parse errors rather than silent misclassification.

### 5.3 Error / edge handling (verified implemented)
- **Network timeouts**: 30s connect/send/receive (`network_config.dart:8-10`); mapped to `NetworkTimeoutException` → `TimeoutFailure` (`dio_api_client.dart:383-389`).
- **Connection failure**: `ConnectionNetworkException` → `ConnectionFailure` (`dio_api_client.dart:390-391`).
- **Duplicate submissions**: idempotency keys (`OrderCheckoutPage` deterministic `order:{orderId}:qris:v1` + `:retry:{n}`; order cubit per-cart-snapshot key); backend idempotency replays stored result, never duplicates (`dashboard_order_payment_handler.go:72-76`, `payment_handler.go:228-276`).
- **App background/resume**: `PaymentDetailPage` reloads payment on resume only when idle and cached for its own payment (`payment_detail_page.dart:86-121`).
- **Payment URL launch failure**: `isLaunchablePaymentUrl` rejects non-HTTP(S)/empty; `defaultLaunchPaymentUri` uses `launchUrl(externalApplication)`; failures show reachability hints for loopback/LAN (`payment_url_opener.dart:1-58`, `payment_detail_page.dart:259-290`).
- **Invalid/unexpected API responses**: `InvalidResponseException` for non-JSON / wrong shape; parse recovery in checkout (`payment_checkout_page.dart:251-298`); `ArgumentError` on unknown status → `InvalidResponseException` (`payment_remote_datasource.dart:121-135`).
- **Payment not belonging to this order**: §8 guard in `PaymentCheckoutPage` listener (`payment_checkout_page.dart:380-386`).

### 5.4 "UI shows success without backend confirmation" — verified NOT present
- `PaymentCreated` is emitted only after `_repository.createOrderPayment` returns a `Payment` (HTTP 201 from backend) (`payment_cubit.dart:61-70`).
- `PaymentSimulated` is emitted only after the simulate endpoint returns and Flutter re-fetches the payment (`payment_remote_datasource.dart:139-155`).
- PAID display in checkout requires a server-recorded paid payment in history (`payment_checkout_page.dart:176-178, 443-446`).
- Simulation buttons are disabled in terminal states (`payment_detail_page.dart:472-476`).

**No instance found where the UI could show success without backend confirmation.**

---

## 6. Authentication and Security Findings

### Verified security controls
- Access token (short-lived) as bearer header; refresh token (long-lived) via HttpOnly `Set-Cookie`, captured client-side, persisted in secure storage (`flutter_secure_storage`) — never in SharedPreferences/plain files/logs (`secure_token_storage.dart:7-14`, `dio_api_client.dart:33-42`).
- Tokens cleared on logout and on failed refresh (`auth_repository_impl.dart:36-39`, `dio_api_client.dart:321-323`).
- 401 → transparent refresh + single-flight retry; failed refresh → unauthenticated (`dio_api_client.dart:168-207, 283-291`).
- Safe logging interceptor in debug; no tokens/credentials logged (`safe_log_interceptor.dart`; `auth_handler.go` comments note tokens are NEVER logged).
- Base URL from `.env` only; `AppEnvironment.validate()` fails fast if missing — no silent default, no hardcoded LAN IP (`app_environment.dart:20-28`, `main.dart:65-67`).
- Debug-only diagnostics log the base URL (contains no credentials) (`main.dart:164-170`).
- Dev-only simulator UI gated by `kDebugMode`; release builds hide it (`payment_detail_page.dart:22-33`).
- Login errors return generic "Invalid email or password" to prevent enumeration (`auth_handler.go:63-69`).

### Observations (not defects)
- The refresh token is stored in the same secure-storage keys as the access token; a compromised device could read both. This is inherent to Flutter (no cookie jar) and is mitigated by secure storage + short access-token TTL. Documented in `token_storage.dart:9-11`.
- `AuthRepositoryImpl.restoreSession()` treats any `AppException` (including failed refresh) as unauthenticated rather than surfacing an error (`auth_repository_impl.dart:68-72`) — correct fail-closed behavior at startup.

No secrets appear in source; `.env.example` contains only `API_BASE_URL=http://localhost:8081` (non-secret placeholder).

---

## 7. Test and Static-Analysis Results

| Command | Result |
|---|---|
| `flutter analyze` | Passes; 1 INFO lint: `test/payment_detail_test.dart:135:14` `no_leading_underscores_for_local_identifiers` (local var `_backgroundAndResume`). Pre-existing; unrelated to payment logic. |
| `flutter test` | **363 passed, 0 failed** |

### Test coverage relevant to this audit
Test files cover: auth (cubit, repository impl), dio client (incl. auth), orders (cubit, repository, datasource, usecases, flow widget), payments (cubit, repository, remote datasource, model, parse recovery, error kind, checkout widget, detail), transactions (cubit, repository, datasource, model, display, history widget, product naming), products (model, remote datasource, repository, catalog/image widgets), cart (cubit), dashboard (overview model, home cubit, connectivity, pull-to-refresh), backend connectivity.

Notable payment-focused tests:
- `payment_checkout_test.dart` — checkout page behavior
- `payment_parse_recovery_test.dart` — **end-to-end** parse recovery: unparseable 201 clears loading with no resubmit; recovers created payment from history
- `payment_cubit_test.dart`, `payment_remote_datasource_test.dart`, `payment_repository_impl_test.dart`, `payment_usecases_test.dart`, `payment_error_kind_test.dart`, `payment_model_test.dart`, `payment_detail_test.dart`

### Coverage gaps (verified by inspection, not a test failure)
- No real-device/integration test against a live backend (all tests use mocked/fake `ApiClient`). This is standard unit/widget practice; no claim is made that a real-device integration test passed.
- No test exercises token refresh rotation end-to-end against a real auth server (refresh logic is covered at the `DioApiClient` level with mocks in `dio_api_client_auth_test.dart`).

No tests were added or modified in this phase.

---

## 8. Findings Classified by Severity

All findings below are separated into **verified facts** (evidence cited) and **assumptions/recommendations**. None is labeled a defect unless supported by evidence.

### Critical — 0
None.

### High — 0
None.

### Medium

**M1 — Idempotency-key retry logic complexity in checkout (maintainability risk)**
- Evidence: `lib/features/payments/presentation/pages/payment_checkout_page.dart` lines 109-362 (`_submitWithKey`, `_recoverAndContinue`, `_allowsFreshRetry`, `_autoChainUsed`, `_maxSubmittedIndex`).
- Verified fact: The page implements a multi-key retry strategy with a one-chained-submit-per-tap cap, fresh-key derivation above history length, and server-side active/paid guards. It is fully covered by widget tests (`payment_checkout_test.dart`, `payment_parse_recovery_test.dart`).
- Assessment: Not a defect — behavior is correct and tested. The complexity is a maintenance risk: future changes to retry semantics must be made carefully to preserve the "never blindly resubmit" invariant.
- Recommendation (M2/M3): document the state machine and keep test coverage; consider extracting key derivation into a pure, testable helper.

**M2 — Shared `PaymentCubit` across unrelated flows can emit foreign states**
- Evidence: `lib/main.dart:131-137` (single `PaymentCubit` provided app-wide); `payment_checkout_page.dart:82-85` (`_awaitingResult` guard) and `payments_page.dart:66-78` (`_lastPayments` retention) both defensively guard against cross-flow state bleed.
- Verified fact: Every consumer guards against foreign cubit emissions; no cross-flow bug was observed.
- Assessment: Not a defect. The shared cubit is a documented architectural trade-off (composition root comment `main.dart:69-71`). The defensive guards make it safe, but it increases reasoning complexity for new features.
- Recommendation (M3): keep the guards; when adding payment-related features, audit that each listener filters by its own in-flight flag.

### Low

**L1 — Payment list omits pagination query parameters**
- Evidence: `lib/features/payments/data/datasources/payment_remote_datasource.dart:109-110` (`GET /api/v1/dashboard/payments` with no `page`/`limit`).
- Verified fact: Backend defaults to page 1, limit 20 (`dashboard_payment_handler.go:368-383`); Flutter ignores the returned `meta` (`payment_remote_datasource.dart:111-136`). Only the first page is reachable from the UI.
- Assessment: Not a defect for current scope (list is a reference view); limit 20 is reasonable.
- Recommendation (M4): add pagination controls if the payment list grows beyond one page.

**L2 — Fixed 30s timeouts with no per-call override**
- Evidence: `lib/core/network/network_config.dart:8-10` (30s connect/send/receive); `dio_api_client.dart:71-73`.
- Verified fact: Payment creation can hit a 504 provider timeout; the 30s send/receive timeout applies uniformly. Timeout vs. provider-timeout distinction is preserved (`_mapDioError` → `NetworkTimeoutException`; backend 504 → `ApiException` with code `PAYMENT_PROVIDER_TIMEOUT`).
- Assessment: Not a defect; values are reasonable.
- Recommendation (M2): consider a longer or configurable timeout for payment creation to reduce ambiguous-timeout recovery paths.

**L3 — No environment flavor/staging/prod separation**
- Evidence: `lib/core/config/app_environment.dart:1-29`; `.env.example:1` (`API_BASE_URL=http://localhost:8081`); `pubspec.yaml:73` (`.env` as sole asset).
- Verified fact: A single `.env` is the single source of truth; no `--dart-define` or flavor mechanism.
- Assessment: Not a defect; deliberate replacement of the former `--dart-define` mechanism (`app_environment.dart:11-12`).
- Recommendation (M4): add flavor support if staging/prod builds are required.

### Informational

**I1 — Backend endpoints defined but unused by Flutter (documented)**
- Evidence: `lib/core/network/api_endpoints.dart:20-32` (`/api/v1/payments*`, `/api/v1/simulator/payments*`, cancel, refunds); `payment_remote_datasource.dart:13` comment explaining dashboard-API preference.
- Verified fact: These are backend capabilities not exposed in the Flutter UI (not in the M1 feature baseline).

**I2 — `CreatePaymentResponse` lacks `updated_at`; Flutter already handles it**
- Evidence: backend `transaction.go:164-177`; Flutter `payment_model.dart:32-36, 57-59` (`updatedAt` falls back to `createdAt`).
- Verified fact: Correctly handled; not a defect.

**I3 — `payment_url` nullability differs between create and detail responses**
- Evidence: backend `CreatePaymentResponse.PaymentURL string` (omitempty) vs `PaymentResponse.PaymentURL *string` (`transaction.go:174, 189`); Flutter treats both as `String?` (`payment.dart:52`).
- Verified fact: Safe in both directions; no mismatch.

**I4 — Simulator endpoints exist in backend but Flutter uses dashboard simulation**
- Evidence: backend `mock_payment_handler.go` (`/api/v1/simulator/payments/{id}/success\|fail`) vs Flutter `ApiEndpoints.dashboardPaymentSimulateSuccess/Fail` (`api_endpoints.dart:48-51`).
- Verified fact: Consistent; Flutter never calls the public merchant simulator.

**I5 — Dev-only debug base URL logging**
- Evidence: `main.dart:164-170`.
- Verified fact: Logs only the base URL (no credentials), gated by `kDebugMode`.

**I6 — Cart is device-only (no server-side cart)**
- Evidence: `lib/features/cart/domain/entities/cart.dart:6-7`.
- Verified fact: Documented design decision; cart state is lost on app reinstall.

**I7 — Single `.env` asset bundled with the app**
- Evidence: `pubspec.yaml:73`; `main.dart:63`.
- Verified fact: `.env` is bundled; developers edit `API_BASE_URL` per environment.

---

## 9. Evidence Index

| # | Finding | File | Lines |
|---|---|---|---|
| 1 | Entry point / composition root | `lib/main.dart` | 58-191 |
| 2 | Env config + fail-fast validation | `lib/core/config/app_environment.dart` | 1-29 |
| 3 | Endpoint constants | `lib/core/network/api_endpoints.dart` | 1-54 |
| 4 | Dio client: auth, refresh, 401 retry, envelope unwrap | `lib/core/network/dio_api_client.dart` | 43-418 |
| 5 | Token storage abstraction | `lib/core/network/token_storage.dart` | 1-29 |
| 6 | Secure storage impl | `lib/features/auth/data/datasources/secure_token_storage.dart` | 1-35 |
| 7 | Auth cubit state machine | `lib/features/auth/presentation/bloc/auth_cubit.dart` | 1-118 |
| 8 | Auth repository: login/logout/restore/refresh | `lib/features/auth/data/repositories/auth_repository_impl.dart` | 20-83 |
| 9 | Payment cubit + states | `lib/features/payments/presentation/bloc/payment_cubit.dart` | 1-204 |
| 10 | Payment entity + closed status enum | `lib/features/payments/domain/entities/payment.dart` | 1-96 |
| 11 | Payment error classification | `lib/features/payments/domain/entities/payment_error_kind.dart` | 1-101 |
| 12 | Payment repository + failure mapping | `lib/features/payments/data/repositories/payment_repository_impl.dart` | 1-116 |
| 13 | Payment remote datasource (endpoints used) | `lib/features/payments/data/datasources/payment_remote_datasource.dart` | 79-231 |
| 14 | Payment model incl. `updated_at` fallback | `lib/features/payments/data/models/payment_model.dart` | 1-82 |
| 15 | Checkout recovery-first flow | `lib/features/payments/presentation/pages/payment_checkout_page.dart` | 1-624 |
| 16 | Payment detail / URL open / resume / simulation | `lib/features/payments/presentation/pages/payment_detail_page.dart` | 1-649 |
| 17 | Payment URL opener + hints | `lib/features/payments/data/services/payment_url_opener.dart` | 1-58 |
| 18 | Order cubit + idempotency | `lib/features/orders/presentation/bloc/order_cubit.dart` | 1-94 |
| 19 | Order remote datasource | `lib/features/orders/data/datasources/order_remote_data_source.dart` | 1-129 |
| 20 | Cart cubit (client-side) | `lib/features/cart/presentation/bloc/cart_cubit.dart` | 1-63 |
| 21 | Transaction cubit + filters | `lib/features/transactions/presentation/bloc/transaction_cubit.dart` | 1-280 |
| 22 | Transaction entity + status enum | `lib/features/transactions/domain/entities/transaction.dart` | 1-109 |
| 23 | Settings page + logout | `lib/features/settings/presentation/pages/settings_page.dart` | 1-60 |
| 24 | Order confirmation → payment | `lib/features/orders/presentation/pages/order_confirmation_page.dart` | 1-208 |
| 25 | Backend: order payment create/list | `.../backend/internal/handler/dashboard_order_payment_handler.go` | 47-153 |
| 26 | Backend: payment list/detail/create/simulate | `.../backend/internal/handler/dashboard_payment_handler.go` | 1-542 |
| 27 | Backend: merchant payment API | `.../backend/internal/handler/payment_handler.go` | 1-398 |
| 28 | Backend: public mock payment | `.../backend/internal/handler/mock_payment_handler.go` | 1-108 |
| 29 | Backend: auth login/logout/me/refresh + cookies | `.../backend/internal/handler/auth_handler.go` | 1-289 |
| 30 | Backend: envelope + error codes | `.../backend/pkg/response/response.go` | 1-336 |
| 31 | Backend: DTOs + statuses | `.../backend/internal/model/transaction.go` | 1-239 |
| 32 | Backend: dashboard overview | `.../backend/internal/model/dashboard_overview.go` | 1-97 |
| 33 | OpenAPI spec | `.../backend/swagger/swagger.json` | — |

---

## 10. Recommended Development Roadmap

### M2 — Critical integration corrections
No Critical findings were identified. This phase is reserved for any integration corrections discovered during real-device or staging validation.
- Acceptance criteria:
  - `flutter analyze` remains warning/error-free (INFO lints acceptable if pre-existing and documented).
  - `flutter test` continues to pass (363 tests).
  - No payment path reports success without a backend-confirmed PAID/FAILED/terminal status.

### M3 — Payment-flow reliability
- Address M1/M2 (checkout retry logic documentation + shared-cubit guard audit).
- Consider L2 (configurable/longer timeout for payment creation).
- Acceptance criteria:
  - Checkout retry state machine covered by unit tests for each `PaymentErrorKind` branch.
  - Every payment-listener consumer guards against foreign cubit emissions (code review).
  - Payment-creation timeout configurable or ≥ backend provider timeout window.

### M4 — UI/UX improvements
- Address L1 (pagination controls for payment list if needed).
- Address L3 (flavor/staging/prod env separation).
- Acceptance criteria:
  - Payment list supports page/limit when result set exceeds one page.
  - Build can target multiple environments without editing `.env` manually.

### M5 — Automated integration testing
- Add real-device/emulator integration tests against a staging backend (not part of this phase; no real payments).
- Focus: token refresh rotation, 401→retry, payment creation → URL open → status refresh → terminal status, logout → session cleared.
- Acceptance criteria:
  - Integration suite runs in CI against a disposable backend instance.
  - No real payment instruments are used; simulation endpoints only.

---

## 11. Items That Could Not Be Verified

The following were **not** verified in this read-only, static-inspection phase. They are listed explicitly per the audit requirements and are **assumptions**, not findings:

1. **Live backend behavior** — The backend service was not started or queried; all contract comparisons were made by static inspection of handlers, models, repositories, and `swagger.json`. Runtime behavior (e.g., actual cookie handling, idempotency replay, provider timeout timing) was not observed.
2. **Real-device / emulator behavior** — `url_launcher` behavior on physical devices vs. emulator vs. host browser (reachability of development mock URLs) was not tested; `payment_url_opener.dart` documents this uncertainty explicitly (`payment_url_opener.dart:8-12`).
3. **Secure storage on physical devices** — `flutter_secure_storage` Keystore/Keychain behavior was not exercised on a real device.
4. **Token refresh rotation against a real auth server** — Covered at unit level with mocks (`dio_api_client_auth_test.dart`) but not end-to-end against live `/api/v1/auth/refresh`.
5. **Flutter web/macOS/linux/windows builds** — Only the Dart VM analysis and test suite were run; platform-specific builds were not compiled.
6. **Release-mode simulator UI suppression** — `showSimulator = kDebugMode` was read from source; release builds were not compiled to confirm the UI is absent (though `kDebugMode` is false in release by definition).
7. **Concurrent payment creation under load** — Backend idempotency single-flight and Flutter's `_awaitingResult` guard were read from source; not load-tested.

---

## 12. Conclusion

The Flutter application implements a complete, backend-grounded payment integration. The contract between Flutter and the Go backend is consistent across endpoints, payloads, envelopes, status values, and error codes. The payment flow never reports success without backend confirmation, and all failure modes (timeouts, connection loss, duplicate submission, unparseable responses, URL-launch failure, app resume) are handled. `flutter analyze` passes and all **363 tests pass**.

No source code, backend code, database, or Git state was modified in this phase. The only deliverable is this report at `docs/mobile-integration-audit.md`.

**Recommended next phase:** Proceed to **M2** (no critical corrections required; validate against a staging backend on a real device/emulator), then **M3** (payment-flow reliability documentation and timeout configurability).
