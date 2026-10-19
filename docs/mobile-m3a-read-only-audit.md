# GO-SAAS — M3A Read-Only Mobile Integration Hardening Audit

**Project:** GO-SAAS Payment Gateway Simulator (Flutter)
**Phase:** M3A — Read-Only Mobile Integration Hardening Audit
**Report date:** Mon Oct 19 2026
**Report path:** `docs/mobile-m3a-read-only-audit.md`
**Repository:** `/run/media/dhika/Dhika/payment_simulator`

---

## Safety compliance (read-only)

This audit was performed strictly read-only. No application source, test source,
dependency declarations, lockfiles, environment files, backend repositories,
database records/schemas, or configuration were modified. No backend services
were started, stopped, rebuilt, or reconfigured. No payment transactions were
created, cancelled, expired, or otherwise modified. No live payment operations
were performed. No credentials, tokens, passwords, or sessions were changed.
No migrations or destructive commands were run. No files were removed,
overwritten, reset, or reformatted. No packages were installed or upgraded.

Commands run were limited to `flutter analyze` and `flutter test` (both
read-only, local, no network dependency downloads). Secret values from
environment files were never printed.

---

## M2 baseline note

Per the audit tasking baseline, M2 was reported as **M2 INTEGRATION PASS**.
However, the actual M2 final verification report on disk
(`docs/mobile-m2-final-verification.md`) records a final status of
**M2 PARTIALLY VERIFIED** — 20 of 21 tests passed, 0 failed, 1 blocked
(B9 — payment expiration, no supported mechanism to trigger expiry within a
practical timeframe). This audit makes no new claim about runtime behavior
beyond what static analysis and the local test suite actually verify.

---

## 1. Executive summary

This read-only audit (M3A) reviewed the GO-SAAS Payment Gateway Simulator
Flutter application's architecture, configuration, authentication/session
management, API contract and networking, payment and order lifecycle, error
handling/resilience, mobile security/privacy, testing, and build/release
configuration. The implementation was inspected against the actual source code
and cross-checked against the backend OpenAPI specification
(`pay-gate-backend/docs/api/openapi.yaml`) and backend documentation.

**Overall impression:** the codebase is well-structured, follows clean
architecture (data/domain/presentation), uses a single shared Dio API client,
stores tokens in platform secure storage (flutter_secure_storage), implements
single-flight token refresh with failed-refresh token clearance, performs
fail-fast configuration validation, redacts sensitive headers in debug logs,
and uses release-specific network security config that disallows cleartext.
The payment enum covers all six backend statuses and checkout uses
idempotency-key-based duplicate-submission prevention with server-state
recovery.

**No CRITICAL or HIGH findings were identified.** One MEDIUM finding (iOS App
Transport Security missing for cleartext HTTP backend URLs), two LOW findings,
and six INFO-level observations were recorded. The local test suite passes
(363 tests) and `flutter analyze` reports only a single info-level lint.

**Final status:** M3A AUDIT COMPLETE — FINDINGS IDENTIFIED

---

## 2. Audit scope and limitations

### Covered (code inspection)
All areas in the audit scope were inspected via static code reading:
- Application configuration (A)
- Authentication and session management (B)
- API contract and networking (C)
- Payment and order lifecycle (D)
- Error handling and resilience (E)
- Mobile security and privacy (F)
- Testing quality (G)
- Build and release configuration (H)

### Covered (runtime verification, local only)
- `flutter analyze` — static analyzer (7.0s, 1 info-level lint)
- `flutter test` — full local test suite (363 tests, all passed)

### Not covered / not run
- No live API calls were made (safety rule). Backend contracts were verified
  only by read-only inspection of the OpenAPI spec and backend docs, not by
  invoking live endpoints.
- No Android emulator or physical device was available; mobile-specific
  runtime behaviors (secure storage on-device, ATS enforcement on iOS, URL
  launcher behavior) could not be exercised at runtime.
- No production-like services were connected to.
- Dependency vulnerability scanning (e.g. `flutter pub audit`) was not run
  because it is not part of the installed/local tooling evidence and would
  require network access; dependency security posture is reported as a
  limitation, not a verified claim.
- The `dart-define`/`--dart-define=API_BASE_URL` mechanism is reported as
  replaced by `.env`; no alternative build-time injection was verified beyond
  reading code.

### Distinction maintained throughout
Every finding and statement is labeled as either **code inspection**
(verified against source) or **runtime verification** (verified by
`flutter analyze`/`flutter test`). No runtime claim is made for behaviors not
exercised by the local test suite.

---

## 3. Repository baseline

| Item | Value |
|------|-------|
| Working directory | `/run/media/dhika/Dhika/payment_simulator` |
| Git branch | `main` |
| HEAD commit | `6a51c35a284f29a53cb463eb0b11785c7dddd436` (add file mobile integration) |
| Remote tracking | `origin/main`, up to date |
| Pre-existing working-tree changes | `docs/mobile-integration-test-results.md` modified (190 insertions, 122 deletions) |
| Untracked files | `docs/mobile-integration-retest-results.md`, `docs/mobile-m2-final-verification.md` |
| Ignored environment files | `.env` (gitignored at `.gitignore:51`); contains only key `API_BASE_URL`, value not printed |
| Tracked env templates | `.env.example` (`API_BASE_URL=http://localhost:8081`), `.env.stage` (key `API_BASE_URL` only) |
| Build artifacts containing env | `build/flutter_assets/.env`, `build/unit_test_assets/.env` (generated, not source) |

All pre-existing user changes were preserved; nothing was reverted or
modified.

---

## 4. Architecture overview

The Flutter app follows a clean layered architecture:

- **`lib/main.dart`** — composition root. Loads `.env` via `flutter_dotenv`,
  validates `API_BASE_URL` (fail-fast), builds one shared `DioApiClient`,
  instantiates all feature cubits/repositories/use cases, and runs
  `authCubit.checkSession()` before `runApp`.
- **`lib/core/network/`** — `ApiClient` abstraction + `DioApiClient` (Dio),
  `NetworkConfig` (30s connect/receive/send timeouts), `api_endpoints.dart`
  (endpoint constants), `token_storage.dart` (secure-storage abstraction),
  `safe_log_interceptor.dart` (debug-only, redacts sensitive headers),
  `network_response.dart` (normalized response), `app_exception.dart`,
  `failure.dart` (domain failure types).
- **`lib/core/config/app_environment.dart`** — `API_BASE_URL` from `.env`,
  `validate()` fail-fast.
- **Features** (auth, cart, orders, payments, products, transactions, home,
  settings): each has `presentation/` (bloc/cubit + pages/widgets),
  `domain/` (entities, repositories, use cases), `data/` (models, remote
  datasources, repository impls).
- **State management:** `flutter_bloc` cubits; shared `PaymentCubit` and
  `AuthCubit` provided via `MultiBlocProvider` above `MaterialApp`.
- **HTTP client:** a single `DioApiClient` instance created in `main.dart`
  and injected into every feature; features never instantiate HTTP clients
  directly.
- **Dependency injection:** manual composition root in `main.dart`; no DI
  package.

The app authenticates against the backend **Dashboard API** surface
(`/api/v1/dashboard/...`) using a Bearer JWT. It deliberately does **not**
use the Merchant API (`/api/v1/payments`, `X-API-Key`) from the mobile
client; the merchant API remains backend/dashboard-only.

---

## 5. Configuration audit

### 5.1 API base URL resolution
- `main.dart:63`: `dotenv.load(fileName: '.env')` — loads the bundled `.env`
  asset at startup, before any network client is created.
- `lib/core/config/app_environment.dart:20`: `apiBaseUrl` reads
  `dotenv.env['API_BASE_URL']?.trim() ?? ''`.
- `app_environment.dart:24-28`: `validate()` throws
  `StateError('API_BASE_URL is not configured in .env')` when missing/empty —
  fail-fast, no silent default.
- `dio_api_client.dart:68-70`: `Dio(BaseOptions(baseUrl:
  AppEnvironment.apiBaseUrl, ...))`.

### 5.2 Environment loading
- `.env` is gitignored (local-only), contains only `API_BASE_URL`.
- `.env.example` (tracked): `API_BASE_URL=http://localhost:8081`.
- `.env.stage` (tracked): key `API_BASE_URL` only (value not printed).
- `main.dart` hardcodes `fileName: '.env'` — `.env.stage` is **not**
  auto-selected; environment switching requires manually copying/swapping the
  `.env` file. No `--dart-define`, no flavor-based selection, no environment
  variable override.

### 5.3 Dev vs staging vs production
- No Flutter flavors are configured (no `.flavors` file, no flavor
  directories in pubspec).
- Environment specificity is achieved solely by editing `.env`.
- The same `.env` is used for debug and release; there is no build-type
  branching of the base URL in Dart code.

### 5.4 Hardcoded URLs/ports/hosts
- No host, port, or IP is hardcoded in Dart source (confirmed by grep across
  `lib/` for `http://`, `localhost`, `192.168`, `10.`, `8081`). The base URL
  comes entirely from `.env`.
- `api_endpoints.dart` contains only path constants (no hosts).

### 5.5 HTTP vs HTTPS assumptions
- The client makes no TLS assumption; it uses whatever scheme is in
  `API_BASE_URL`. The Dio client uses default Dio TLS behavior (system trust
  anchors, certificate validation enabled). `validateStatus: (_) => true` so
  all statuses are handled manually.
- Android `network_security_config.xml` (debug/main): `cleartextTrafficPermitted="true"` —
  permits cleartext HTTP for LAN/dev; HTTPS endpoints keep default secure
  behavior (system CAs, cert validation not disabled).
- Android release `network_security_config_release.xml`:
  `cleartextTrafficPermitted="false"`, system trust anchors only — release
  builds refuse plaintext HTTP before credentials are sent.
- iOS `Info.plist`: **no `NSAppTransportSecurity` dictionary** — iOS blocks
  cleartext HTTP by default; an HTTP `API_BASE_URL` will fail on iOS.

### 5.6 Debug-only behavior
- `main.dart:164-170`: `kDebugMode` debugPrint of `API_BASE_URL` (public URL,
  no credentials) and a `developer.log` of the effective base URL. Safe — no
  secrets logged.
- `SafeLogInterceptor` added only in `kDebugMode`; redacts
  `authorization`, `cookie`, `set-cookie`, `x-api-key`, etc.; never logs
  request/response bodies.
- `PaymentDetailPage.showSimulator` defaults to `kDebugMode` — simulator
  controls hidden in release. Backend role checks remain the real
  authorization.

### 5.7 Release build configuration
- Release Android manifest overrides network security config to the strict
  release variant (no cleartext, system CAs only).
- No signing configuration references in source inspected (keystore/key alias
  not present in Dart; signing is handled by Gradle, not modified here).
- No flavor configuration.

### 5.8 Missing/unsafe defaults
- If `API_BASE_URL` is missing, the app throws at startup before any network
  call — no unsafe fallback to localhost. This is a positive control.
- The `.env` file is declared as a Flutter asset
  (`pubspec.yaml:72-73: assets: - .env`), so `API_BASE_URL` is bundled into
  the app artifact (observed at `build/flutter_assets/.env`). `API_BASE_URL`
  is public configuration, not a secret, so this is acceptable; however it
  means the base URL ships inside the APK/app bundle and no secret should ever
  be added to `.env`.

### 5.9 Configuration precedence and validation
- Single source of truth: `.env` (via `flutter_dotenv`). No
  `--dart-define` fallback, no env-var override, no build-config override.
- Validation: `AppEnvironment.validate()` at startup, fail-fast.

**Configuration audit result:** PASS (code inspection). No unsafe defaults,
no hardcoded hosts, fail-fast validation, public URL only in `.env`.

---

## 6. Authentication and session audit

### 6.1 Login/logout flows
- `lib/features/auth/presentation/pages/login_page.dart` — email/password form,
  calls `AuthCubit.signIn(email, password)`.
- `lib/features/auth/domain/usecases/login_usecase.dart` →
  `AuthRepositoryImpl.login` → `AuthRemoteDataSourceImpl.login`
  (`POST /api/v1/auth/login`, body `{email, password}`).
- `logout_usecase.dart` → `POST /api/v1/auth/logout` with Bearer token;
  repository clears local tokens **even if the backend call fails**
  (`auth_repository_impl.dart:36-39`).

### 6.2 Token storage
- Access token: persisted in `flutter_secure_storage`
  (`lib/features/auth/data/datasources/secure_token_storage.dart`),
  key `auth_access_token`. Android Keystore / iOS Keychain — not
  SharedPreferences, not plain files.
- Refresh token: delivered by backend via `Set-Cookie: refresh_token=...`
  on login/refresh; captured by `DioApiClient._captureRefreshToken`
  (`dio_api_client.dart:255-267`) and persisted to the same secure storage,
  key `auth_refresh_token`. Never exposed outside the network layer.
- `AuthSession` domain entity intentionally excludes the refresh token
  (`auth_session.dart:7-8`).

### 6.3 Refresh-token handling
- The client implements refresh-token functionality (contrary to a possible
  assumption that mobile has none).
- On HTTP 401, `DioApiClient._request` transparently refreshes the session
  using `X-Refresh-Token` header (`POST /api/v1/auth/refresh`), persists the
  rotated token pair, and retries the original request once (`allowRetry:
  false` on the retry to prevent loops).
- **Single-flight refresh:** concurrent 401s share one in-flight
  `_refreshFuture` (`dio_api_client.dart:65, 283-291`).
- **Failed refresh:** clears stored tokens and in-memory access token, so the
  app falls back to unauthenticated instead of looping forever
  (`dio_api_client.dart:298-305, 321-328`).

### 6.4 Token expiration behavior
- Access token lifetime (`expires_in`) is captured from login
  (`auth_session_model.dart:20`) but `restore_session_usecase.dart`/
  `auth_repository_impl.dart:65` hardcodes `expiresIn: 0` on restoration —
  the client does **not** track remaining lifetime and cannot proactively
  refresh before expiry; it reacts to 401 responses. This is a common
  reactive-refresh pattern, not a defect, but means a brief 401+retry latency
  occurs when a token expires mid-use.

### 6.5 Session restoration after restart
- `main.dart:174`: `authCubit.checkSession()` runs before the first frame.
- `AuthRepositoryImpl.restoreSession` (`auth_repository_impl.dart:45-73`):
  requires a stored refresh token; calls `GET /api/v1/auth/me`; the client
  attaches the stored access token and refreshes+retries on 401. On any
  failure returns unauthenticated (no crash, no infinite loop).

### 6.6 Unauthorized responses
- 401 → refresh + single retry. If refresh fails → tokens cleared →
  `AuthUnauthenticated` → login screen.

### 6.7 Concurrent refresh requests
- Handled via single-flight `_refreshFuture`; no duplicate refresh storms.

### 6.8 Secure storage vs ordinary preferences
- Tokens use `flutter_secure_storage` (platform secure storage). Confirmed no
- SharedPreferences usage for tokens.

### 6.9 Exposure of tokens in logs/exceptions/UI
- `SafeLogInterceptor` redacts `authorization`, `cookie`, `set-cookie`,
  `x-api-key` headers; debug-only; never logs bodies.
- Exceptions carry user-safe messages via `Failure` types; raw exceptions
  never escape data-layer boundaries.
- `AuthSession` excludes refresh token from domain/UI layers.

### 6.10 Auth state consistency
- `AuthCubit` sealed state hierarchy:
  `AuthInitial` → `AuthCheckingSession` → `AuthAuthenticated` /
  `AuthUnauthenticated` / `AuthLoading` / `AuthFailure`.
- `AuthPage` (`auth_page.dart`) routes on state: `AuthCheckingSession` →
  splash, `AuthAuthenticated` → `HomePage`, else → `LoginPage`.
- `GoSaasApp` builds `BlocListener<AuthCubit>` that resets `orderCubit` on
  `AuthUnauthenticated` (`main.dart:246`).

### Authentication contract verification against backend
- Backend auth endpoints exist
  (`pay-gate-backend/internal/handler/auth_handler.go` routes
  `/api/v1/auth/login`, `/logout`, `/me`, `/refresh`; confirmed in backend
  handler tests and `docs/api.md`).
- **These auth endpoints are NOT present in the OpenAPI spec**
  (`pay-gate-backend/docs/api/openapi.yaml` covers Payments, Refunds,
  Webhooks, Dashboard Orders/Products/Categories, and Dashboard Auth limited
  to password-reset + dev-recovery — not login/logout/refresh/me). The mobile
  auth contract is therefore implemented but not formally documented in the
  project's OpenAPI spec. This is a documentation gap (F-04), not a code
  defect.

**Authentication audit result:** PASS (code inspection). Secure storage,
refresh with single-flight, fail-safe logout, session restoration, no token
leakage in logs. Auth endpoints missing from OpenAPI spec (documentation gap,
F-04).

---

## 7. API contract and networking audit

### 7.1 API client abstraction
- `lib/core/network/api_client.dart` — abstract `ApiClient`
  (`get`/`post`/`put`/`patch`/`delete` + `setAuthToken`). Single concrete
  `DioApiClient` shared by all features.

### 7.2 Request/response serialization
- Bodies sent as JSON (`Content-Type: application/json`).
- Dio `responseType: ResponseType.plain` so bodies are decoded manually;
  malformed JSON → `InvalidResponseException`.
- Backend success envelope `{"success": true, "data": ..., "meta": ...}`
  unwrapped by `_toNetworkResponse`; error envelopes
  (`{"success": false, "error": {...}}`) → `ApiException(statusCode,
  message, code)`.

### 7.3 Error model consistency
- `AppException` subtypes: `ServerException`, `NetworkException`,
  `CacheException`, `NetworkTimeoutException`, `ConnectionNetworkException`,
  `ApiException(statusCode, code)`, `InvalidResponseException`.
- Data-layer repositories map `AppException` → domain `Failure`
  (`ServerFailure`, `NetworkFailure`, `TimeoutFailure`, `ConnectionFailure`,
  `ApiFailure(statusCode, code)`, `InvalidResponseFailure`,
  `UnexpectedFailure`) with user-safe messages. Failure messages never contain
  raw exceptions or stack traces.

### 7.4 HTTP status handling
- `validateStatus: (_) => true` — every status handled manually.
- 2xx success → unwrap envelope. `success: false` → `ApiException`.
- Non-envelope payloads (e.g. plain health) returned raw.
- Empty/blank body → `_decodeBody` returns `null` (no crash).

### 7.5 Timeouts
- `NetworkConfig`: connection/receive/send = 30s each
  (`network_config.dart:8-9`). Mapped to `NetworkTimeoutException` on any
  timeout type.

### 7.6 Cancellation of in-flight requests
- Dio supports `CancelToken`, but **no explicit cancellation of in-flight
  requests on page/route dispose** was found. Cubits/pages guard state with
  `_awaitingResult`, `mounted` checks, and `_isBusy` flags, so late responses
  are handled gracefully, but network resources are not explicitly released
  on navigation away. Observation (F-06).

### 7.7 Retry policies
- **No automatic retry** for non-idempotent requests at the API-client level.
- The only retry is the 401→refresh→retry-once flow (idempotent-safe because
  it retries the same request with a rotated token).
- Payment retry logic lives in `PaymentCheckoutPage` and is explicitly
  idempotency-key driven (see section 8). No blind retries of non-idempotent
  requests.

### 7.8 Malformed/empty responses
- Malformed JSON → `InvalidResponseException`.
- Missing required fields (`transaction_id`, `created_at`) → `FormatException`
 /`TypeError`/`ArgumentError` caught → `InvalidResponseException`.
- Unknown `status` enum value → `ArgumentError` from
  `PaymentStatus.fromApi` / `TransactionStatus.fromApi` → caught →
  `InvalidResponseException`. Closed contract; unknown status signals a
  contract change.

### 7.9 Base URL consistency
- Single `AppEnvironment.apiBaseUrl` used by the sole `DioApiClient` instance.
- All endpoints are relative paths in `api_endpoints.dart`. Consistent.

### 7.10 Endpoint/DTO consistency with backend (OpenAPI cross-check)
The mobile app uses only the **Dashboard API** (Bearer JWT). Cross-checks
against `pay-gate-backend/docs/api/openapi.yaml`:

| Mobile usage | Backend OpenAPI | Consistent? |
|---|---|---|
| `POST /api/v1/dashboard/payments` (create, Idempotency-Key header) | `createDashboardOrderPayment`? No — mobile calls `/api/v1/dashboard/payments` which is not a listed path; the order-scoped path is `/api/v1/dashboard/orders/{order_id}/payments` | Partial — see below |
| `GET /api/v1/dashboard/payments/{payment_id}` | `getDashboardOrder` is `/dashboard/orders/{order_id}`; `/dashboard/payments/{payment_id}` is **not** in OpenAPI | Not in OpenAPI |
| `GET /api/v1/dashboard/payments` (list) | Not in OpenAPI | Not in OpenAPI |
| `POST /api/v1/dashboard/orders/{order_id}/payments` | `createDashboardOrderPayment` (line 924) | ✓ Matches (body `payment_method`, Idempotency-Key, 201/409/502/504) |
| `GET /api/v1/dashboard/orders/{order_id}/payments` | `listDashboardOrderPayments` (line 879) | ✓ Matches (read-only, newest first, empty array when none) |
| `POST .../simulate/success`, `.../simulate/fail` | `dashboardPaymentSimulateSuccess/Fail` endpoints | In api_endpoints.dart only; not verified against OpenAPI |
| Payment statuses `CREATED, PENDING, PAID, FAILED, EXPIRED, CANCELLED` | `PaymentStatus` enum (line 2184-2186) | ✓ Exact match |
| Idempotency-Key 1–255 chars, replay same key+payload | OpenAPI idempotency section (line 18) | ✓ Matches |
| Order-payment: 502 definitive failure (FAILED), 504 ambiguous (CREATED) | OpenAPI lines 992-999 | ✓ Matches `PaymentErrorKind` classification |
| At most one active + one PAID payment per order | OpenAPI line 941-944 | ✓ Matches checkout guards |

**Important observation:** Several mobile dashboard-payment endpoints
(`GET/POST /api/v1/dashboard/payments`, `/dashboard/payments/{id}`,
`/dashboard/payments/{id}/simulate/*`) are referenced in
`api_endpoints.dart` and used by `PaymentRemoteDataSourceImpl`, but the
corresponding paths do **not** appear in the backend OpenAPI spec
(`/api/v1/payments/*` exists under the Merchant API with `X-API-Key`, not
under `/api/v1/dashboard/payments` with Bearer JWT). Either the backend
serves these dashboard-payment paths undocumented, or the OpenAPI spec is
incomplete relative to the mobile client. This is a contract-consistency
observation requiring backend confirmation; it is not a code defect per se
because the local tests mock these endpoints and pass. Flagged for
investigation (F-04 related).

**API contract and networking audit result:** PASS (code inspection), with the
contract-documentation gaps noted above (F-04).

---

## 8. Payment and order lifecycle audit

### 8.1 Product and cart state
- `CartCubit` (`cart_cubit.dart`): in-memory cart, add/remove/setQuantity/
  clear. Device-scoped, not persisted across restarts (observation F-09).
- `OrderCubit` (`order_cubit.dart`): builds `OrderItemInput` from cart,
  posts `POST /api/v1/dashboard/orders` with an idempotency key
  (`order-${microseconds}-${random}`), clears cart on success, retains cart
  on failure, regenerates key when cart changes. `reset()` on logout
  invalidates pending results.

### 8.2 Checkout validation
- `PaymentCheckoutPage` (`payment_checkout_page.dart`): order-backed payment
  checkout. Only `payment_method` (QRIS, the sole backend-supported method)
  is sent; amount/currency/merchant/merchant_order_id derived server-side.
- Recovery-first: on entry and after every failed submit, reloads the order's
  recorded attempts from the read-only
  `GET /api/v1/dashboard/orders/{order_id}/payments` endpoint and derives
  everything from server state.

### 8.3 Payment creation
- `POST /api/v1/dashboard/orders/{order_id}/payments` with
  `Idempotency-Key: <key>` header, body `{"payment_method": "QRIS"}`.
- Stable base key `order:{orderId}:qris:v1`; retry keys `base:retry:{n}`.

### 8.4 Idempotency / duplicate-submission prevention
- Idempotency-Key header on every payment creation.
- Checkout page guards:
  - `_awaitingResult` flag prevents concurrent submits; Pay button disabled
    while `isCreating`.
  - `_firstWhereOrNull(history, _isPaid)` / `_isActive` → Pay hidden when a
    paid or active (CREATED/PENDING) payment exists.
  - `PaymentCreated` listener guards `payment.orderId == widget.order.id`
    (§8 guard — never present another order's payment).
  - Failure recovery classified by `classifyOrderPaymentError`:
    `PAYMENT_PROVIDER_ERROR` → definitiveFailure; `PAYMENT_PROVIDER_TIMEOUT`
    / 504 → ambiguousTimeout (reconcile, do not blindly retry);
    `INVALID_TRANSACTION_STATE` / 409 → orderConflict;
    `IDEMPOTENCY_KEY_REUSED` / `IDEMPOTENCY_REQUEST_IN_PROGRESS`; 502 →
    definitiveFailure; validation/auth/notFound → no resubmit.
  - At most one chained auto-resubmit per explicit tap (`_autoChainUsed`).
  - Fresh fallback keys derived above all previously submitted indices and
    recorded history length, so they cannot collide with consumed keys.
- This is a strong, well-reasoned duplicate-submission prevention design.

### 8.5 Pending-payment presentation
- `PaymentDetailPage` shows status, expiry, paidAt, createdAt, updatedAt,
  payment URL, provider, provider transaction ID.
- `PaymentStatusIndicator` widget renders status visually.

### 8.6 Paid/failed/expired/cancelled states
- All six statuses are explicitly in the `PaymentStatus` and
  `TransactionStatus` enums, matching the backend OpenAPI `PaymentStatus`
  enum exactly.
- Simulator section (debug only) offers Success/Fail transitions for
  `PENDING`-like states; terminal states block simulation.

### 8.7 Payment detail retrieval
- `GET /api/v1/dashboard/payments/{payment_id}` via `GetPaymentUseCase` /
  `PaymentRemoteDataSourceImpl.getPayment`.

### 8.8 Order/payment status consistency
- Order status (`Order`) is only `CREATED` per OpenAPI `OrderStatus`
  (line 1753-1756); payments have a separate lifecycle. The client treats
  order status and payment status independently — consistent.

### 8.9 Application resume behavior
- `PaymentDetailPage` (`_PaymentDetailBodyState`):
  `AppLifecycleListener.onResume` → `_handleResumed` reloads the payment
  only when idle, cached, and for this payment's ID; never during
  simulation/loading, never for another payment, never in a loop.
- Checkout page re-derives state from history on reconstruction.

### 8.10 Refreshing transaction status after returning from payment page
- `PaymentDetailPage` pull-to-refresh (`RefreshIndicator`) and AppBar
  refresh button reload the payment by ID; never creates/simulates.

### 8.11 Handling unknown/new backend statuses
- `PaymentStatus.fromApi` / `TransactionStatus.fromApi` throw `ArgumentError`
  for unknown values; caught in datasources → `InvalidResponseException`.
- Backend contract is closed; unknown status = contract change, surfaced as a
  typed parsing error (not silently mapped).

### 8.12 Prevention of stale UI state
- `OrderHistoryCubit` and `TransactionCubit` use monotonic fetch epochs;
  stale responses are ignored. `TransactionCubit.loadMore` suppresses
  scroll-triggered requests when a load-more error is visible (prevents
  layout-shift retrigger).

### 8.13 Race conditions between user actions and async responses
- Cubits use `isClosed`/epoch checks; `_awaitingResult` guard on checkout;
  generation checks in `OrderCubit.createOrder`; `mounted` checks throughout.

**Payment lifecycle audit result:** PASS (code inspection). All six backend
statuses supported in Flutter and consistent with OpenAPI. Strong
idempotency and duplicate-submission prevention. Resume/refresh behavior
present. No payments were created or modified during this audit.

---

## 9. Error handling and resilience audit

### 9.1 Network-unavailable behavior
- `DioExceptionType.connectionError` → `ConnectionNetworkException` →
  `ConnectionFailure` ("Could not reach the server"). UI shows error state
  with retry (e.g. `_RecoveryErrorView`, `_ErrorView`, `OrderHistoryFailure`).

### 9.2 Timeout handling
- All timeout types → `NetworkTimeoutException` → `TimeoutFailure` ("The
  request timed out. Please try again.").

### 9.3 Server error handling
- `success: false` envelopes → `ApiException(statusCode, message, code)` →
  `ApiFailure` with the stable backend `code` for control flow (never message
  text).

### 9.4 Authentication failure behavior
- 401 → refresh + retry; failed refresh → tokens cleared → unauthenticated;
  login screen. Logout clears tokens even if backend call fails.

### 9.5 Malformed JSON
- `_decodeBody` catches `FormatException` → `InvalidResponseException`.
- Datasource `fromJson` catches `FormatException`/`TypeError`/`ArgumentError`
  → `InvalidResponseException`.

### 9.6 Empty responses
- Blank body → `null`; non-Map/non-List payloads → `InvalidResponseException`
  with a user-safe message.

### 9.7 Unexpected enum/status values
- `fromApi` throws `ArgumentError` → `InvalidResponseException`. Closed
  contract.

### 9.8 Concurrent submissions / duplicate taps
- Checkout: `_awaitingResult` flag + disabled `isCreating` button.
- OrderCubit: returns early if `state is OrderLoading`.
- Transaction/Order history cubits: epoch guards ignore stale responses.

### 9.9 Application background/resume
- `PaymentDetailPage` handles `onResume` (idle-only reload).
- No global background/resume token cleanup beyond the existing lifecycle
  listener on the payment detail page.

### 9.10 Empty/loading/success/error UI states
- All cubits emit `*Loading`, `*Loaded`, `*Failure` states; pages render
  corresponding spinners, content, and error views with retry actions.
- `PaymentDetailPage` never goes blank during refresh (retains last known
  payment with progress indicator).

### 9.11 Retry controls and retry safety
- Checkout retries are idempotency-key derived and server-state validated;
  no blind retries of 504/ambiguous outcomes; one chained resubmit per tap
  max.
- Order history refresh failure retains previously loaded entries.

### 9.12 Logging and diagnostics
- Debug-only `SafeLogInterceptor` (method + URL + redacted headers, no
  bodies). `developer.log` of base URL (public). No secrets in logs.

### 9.13 User-facing error messages
- All `Failure.message` values are user-safe. SnackBars and inline error
  cards show these messages with retry actions where appropriate.

### Recovery without restart or state loss
- Users can recover from network errors, timeouts, server errors, auth
  failures (re-login), and parse errors via retry actions, without restarting
  the app. Cart/order state retained across failures. **Confirmed via code
  inspection; partial runtime verification via widget tests (checkout
  recovery, parse recovery, refresh-retains-details tests all pass).**

**Error handling audit result:** PASS (code inspection; runtime-verified by
passing widget/unit tests for error, timeout, and recovery paths).

---

## 10. Mobile security and privacy audit

### 10.1 Token and credential storage
- Access + refresh tokens in `flutter_secure_storage` (Android Keystore /
  iOS Keychain). Not SharedPreferences, not plain files, not constants.

### 10.2 Sensitive data in logs
- `SafeLogInterceptor` redacts sensitive headers; debug-only; never logs
  bodies. No password/token/PII logging found.

### 10.3 PII exposure in error messages
- `Failure` messages are generic/user-safe; `ApiFailure` carries statusCode
  and backend `code` but the presentation layer shows `failure.message`
  (user-safe). No PII in messages found.

### 10.4 Debug logging in release builds
- `SafeLogInterceptor` and `kDebugMode` logs are gated by `kDebugMode` —
  excluded from release. Simulator UI hidden in release (`showSimulator`
  defaults to `kDebugMode`).

### 10.5 TLS configuration and certificate validation
- Dio default TLS (system trust anchors, cert validation enabled).
- Android release network security config: cleartext disallowed, system CAs
  only.
- iOS: no ATS config → cleartext HTTP blocked by default on iOS (F-03).

### 10.6 Insecure HTTP usage
- Android debug/main permits cleartext (LAN dev). Release disallows it.
- Default `.env.example` uses `http://localhost:8081`; current `.env` uses
  an HTTP LAN IP (per M2 report). Works on Android debug, blocked on iOS
  without ATS exception, refused on Android release. F-03.

### 10.7 Android manifest permissions
- `AndroidManifest.xml`: only `INTERNET` permission + `queries` for
  `PROCESS_TEXT` (Flutter text plugin). No dangerous permissions. No
  `ACCESS_FINE_LOCATION`, `CAMERA`, etc.

### 10.8 iOS transport-security
- `Info.plist`: no `NSAppTransportSecurity` dictionary (F-03).

### 10.9 Deep links / payment-return handling
- No deep-link configuration found in `AndroidManifest.xml` or `Info.plist`.
- Payment return is via the backend-provided `payment_url` opened in an
  external browser (`url_launcher`, `LaunchMode.externalApplication`); the
  user returns to the app manually and refreshes status. No custom scheme
  registered. Not a defect (out-of-band payment return), but no deep-link
  resumption exists.

### 10.10 WebView usage
- No WebView found. `url_launcher` opens the payment URL in an external
  browser/application. Safer than an in-app WebView for credentials.

### 10.11 Dependency security posture
- Dependencies: `dio ^5.8.0`, `flutter_secure_storage ^11.2.0`,
  `flutter_dotenv ^5.2.1`, `url_launcher ^6.3.3`, `flutter_bloc ^8.1.6`.
- No local vulnerability scan was performed (not part of available local
  evidence, would require network). Posture reported as unverified (F-08).
- Cannot claim the app is secure merely because no obvious issue was found.

### 10.12 Sensitive payment data stored on-device
- Only auth tokens stored (secure storage). No payment card data, no
  credentials, no PII persisted beyond the session. Cart is in-memory only.

**Security and privacy audit result:** PASS (code inspection), with F-03
(iOS ATS), F-08 (dependency scan not performed), and observations on deep
links/HTTP dev URL. No secrets in logs/UI/exceptions; secure token storage;
release config disallows cleartext.

---

## 11. Testing and build/release audit

### 11.1 Test structure
- `test/` contains 31 test files covering: auth, payments, orders,
  transactions, products, cart, API client (incl. auth), backend
  connectivity, checkout, payment detail, payment model/parse recovery,
  error kinds, pull-to-refresh, widget tests, cubit tests.

### 11.2 Test coverage areas present
- Unit tests: models, entities, use cases, repositories, datasources,
  cubits, `PaymentErrorKind` classification, `payment_url_opener`.
- Widget tests: pages, pull-to-refresh, navigation, empty/error states.
- API client tests: `dio_api_client_test.dart`, `dio_api_client_auth_test.dart`
  (auth behavior incl. token handling).
- Authentication tests: `auth_cubit_test.dart`, `auth_repository_impl_test.dart`.
- Payment lifecycle tests: `payment_cubit_test.dart`, `payment_checkout_test.dart`,
  `payment_detail_test.dart`, `payment_parse_recovery_test.dart` (201 without
  `updated_at`, unknown status, malformed payload — no spinner hang).
- Duplicate-submission tests: `payment_checkout_test.dart` (stable idempotency
  key, FAILED-history recovery, stale conflict replay + fresh key,
  ambiguous timeout key retention).
- Session restoration: implied by auth cubit/repository tests.
- Error/timeout tests: `payment_error_kind_test.dart`, `dio_api_client_test.dart`,
  connectivity tests.
- Configuration tests: none dedicated (configuration is validated at app
  startup via `AppEnvironment.validate()`).

### 11.3 Test isolation / external services
- Tests use mocked `ApiClient`/Dio (injected `Dio?` into `DioApiClient`),
  mocked secure storage (`FlutterSecureStorage()`), and fake URL launchers.
- No tests depend on external services or the live backend.
- `check_backend_connection_test.dart` and `backend_connectivity_repository_impl_test.dart`
  test the connectivity-check use case with mocked clients (not live calls).

### 11.4 Existing test reports
- `docs/mobile-integration-test-results.md` (modified, pre-existing changes)
- `docs/mobile-integration-retest-results.md` (untracked)
- `docs/mobile-m2-final-verification.md` (untracked, M2 PARTIALLY VERIFIED)

### 11.5 Commands actually run
| Command | Result |
|---|---|
| `flutter analyze` | 1 info-level lint issue: `test/payment_detail_test.dart:135` (`no_leading_underscores_for_local_identifiers`, local var `_backgroundAndResume`). Exit code 1 (analyzer returns non-zero on any issue). Ran in 7.0s. |
| `flutter test` | **All 363 tests passed.** Exit code 0. No failures, no skipped due to missing services. |

No `flutter clean`, `flutter pub upgrade`, `dart fix --apply`, or other
state-modifying commands were run.

### 11.6 Build/release audit
- Android debug: cleartext permitted (dev LAN). Android release: cleartext
  disallowed, system CAs only.
- iOS: no ATS exceptions (F-03).
- No flavors; release build uses the same `.env`-driven `API_BASE_URL`.
- If `API_BASE_URL` is missing, app throws at startup (no accidental
  localhost fallback).
- Release build pointing at an HTTP dev/LAN URL would be refused by the
  Android platform (cleartext disallowed) and by iOS ATS — this is a
  protective behavior, not a defect.

**Testing audit result:** PASS (363 tests passed). Build/release: PASS with
F-03 noted.

---

## 12. Findings table

| ID | Category | Severity | File | Confirmed? |
|----|----------|----------|------|------------|
| F-01 | Configuration | INFO | `lib/main.dart:63` | Yes (code inspection) |
| F-02 | Configuration | INFO | `pubspec.yaml:72-73`, `lib/main.dart:63` | Yes (code inspection) |
| F-03 | Security / Privacy | MEDIUM | `ios/Runner/Info.plist` | Yes (code inspection) |
| F-04 | API contract | INFO | `lib/core/network/api_endpoints.dart:14-17` vs backend OpenAPI | Yes (code inspection) |
| F-05 | Authentication | LOW | `lib/features/auth/data/repositories/auth_repository_impl.dart:65` | Yes (code inspection) |
| F-06 | Networking | INFO | `lib/core/network/dio_api_client.dart` | Yes (code inspection) |
| F-07 | Testing / Analysis | INFO | `test/payment_detail_test.dart:135` | Yes (flutter analyze) |
| F-08 | Security / Privacy | INFO | `pubspec.yaml` | Limitation (not run) |
| F-09 | Payment lifecycle | LOW | `lib/features/cart/presentation/bloc/cart_cubit.dart` | Yes (code inspection) |

**Severity totals:** CRITICAL=0, HIGH=0, MEDIUM=1, LOW=2, INFO=6. Total=9.

---

## 13. Evidence for each finding

### F-01 — `.env` not environment-switched automatically (INFO)
- **File:** `lib/main.dart:63` — `await dotenv.load(fileName: '.env');`
- **Evidence:** `main.dart` hardcodes the fileName `'.env'`; `.env.stage` is
  tracked but never selected by code. The M2 report and this audit confirm
  `.env.stage` must be manually copied/switched.
- **Reproducible scenario:** A developer intending to test against staging
  must manually replace `.env` with `.env.stage` contents; easy to forget and
  run against the wrong environment.
- **Impact:** Operational — risk of pointing the app at the wrong backend.
- **Remediation:** Support environment selection via build flavor, `--dart-define`,
  or environment variable, falling back to `.env`.
- **Verification:** Inspect `main.dart` load call; confirm no conditional on
  build mode/flavor selects `.env.stage`. (Code inspection.)

### F-02 — `.env` bundled as a Flutter build asset (INFO)
- **File:** `pubspec.yaml:72-73` (`assets: - .env`), `lib/main.dart:63`
- **Evidence:** `.env` is declared as a Flutter asset; the build output
  `build/flutter_assets/.env` exists, confirming `API_BASE_URL` ships inside
  the app artifact.
- **Reproducible scenario:** `API_BASE_URL` is embedded in every build.
- **Impact:** Public URL bundled (not a secret per task guidance). Risk only
  if a secret is ever added to `.env`.
- **Remediation:** Keep `.env` limited to public configuration; document that
  secrets must never be added; consider build-time injection (`--dart-define`)
  for release builds instead of bundling.
- **Verification:** `pubspec.yaml` assets section; `build/flutter_assets/.env`
  presence. (Code inspection.)

### F-03 — iOS lacks App Transport Security exceptions for cleartext HTTP (MEDIUM)
- **File:** `ios/Runner/Info.plist` — no `NSAppTransportSecurity` dictionary.
- **Evidence:** `Info.plist` (70 lines) contains no `NSAppTransportSecurity`
  key. iOS enforces ATS by default and blocks cleartext HTTP connections.
- **Reproducible scenario:** An iOS build with `API_BASE_URL=http://...`
  (the default in `.env.example`, and the current `.env` value per M2 report)
  would fail to connect to the backend on iOS, because ATS blocks cleartext.
- **Impact:** iOS builds cannot reach an HTTP dev/staging backend; the app
  would appear to have a connection error on iOS.
- **Remediation:** Add an `NSAppTransportSecurity` exception for development
  hosts, or require `API_BASE_URL` to use HTTPS for iOS release builds. The
  Android release config already enforces HTTPS-only; mirror that intent on
  iOS.
- **Verification:** Read `Info.plist`; confirm absence of ATS. (Code
  inspection. Runtime verification on iOS not possible — no device/simulator.)

### F-04 — Auth endpoints and several dashboard-payment endpoints missing from OpenAPI spec (INFO)
- **File:** `lib/core/network/api_endpoints.dart:14-17`
  (`/api/v1/auth/login`, `/logout`, `/refresh`, `/me`);
  `lib/core/network/api_endpoints.dart:20-28` (dashboard-payment paths);
  `pay-gate-backend/docs/api/openapi.yaml`
- **Evidence:** The backend implements `/api/v1/auth/login`, `/logout`,
  `/refresh`, `/me` (confirmed in `auth_handler.go` routes and backend
  handler tests, and `docs/api.md`), but these paths do not appear in the
  OpenAPI spec. Similarly, mobile-used dashboard-payment paths
  (`/api/v1/dashboard/payments`, `/{id}`, `/simulate/*`) are not in the
  OpenAPI spec (which lists `/api/v1/payments/*` under Merchant API with
  `X-API-Key`, not `/api/v1/dashboard/payments` with Bearer JWT).
- **Reproducible scenario:** A consumer of the OpenAPI spec cannot derive the
  mobile auth contract or the dashboard-payment contract from the spec.
- **Impact:** Contract documentation gap; mobile-auth contract not formally
  specified; risk of client/backend divergence on auth/dashboard-payment
  paths.
- **Remediation:** Add `/api/v1/auth/{login,logout,refresh,me}` and the
  dashboard-payment paths to `openapi.yaml`, aligned with `auth_handler.go`
  and the mobile `api_endpoints.dart`.
- **Verification:** Compare `api_endpoints.dart` against OpenAPI `paths`.
  (Code inspection.)

### F-05 — Access-token lifetime not tracked; no proactive refresh (LOW)
- **File:** `lib/features/auth/data/repositories/auth_repository_impl.dart:65`
  (`expiresIn: 0` in `restoreSession`)
- **Evidence:** `expiresIn` from login is captured in `AuthSessionModel`
  (`auth_session_model.dart:20`) but `restoreSession` constructs
  `AuthSession(..., expiresIn: 0)`. The client relies entirely on 401-driven
  reactive refresh (`dio_api_client.dart:168-178`).
- **Reproducible scenario:** When an access token expires mid-session, the
  next request fails with 401 before being refreshed and retried, adding one
  round-trip latency and a transient error state.
- **Impact:** Minor UX latency on token expiry; not a defect (reactive
  refresh is a valid pattern), but no proactive refresh before expiry.
- **Remediation:** Honor `expires_in` and proactively refresh shortly before
  expiry (e.g. at 80% of TTL).
- **Verification:** Inspect `restoreSession` and `_refreshSession`. (Code
  inspection.)

### F-06 — No explicit cancellation of in-flight HTTP requests on dispose (INFO)
- **File:** `lib/core/network/dio_api_client.dart` (Dio used without
  `CancelToken`; no cancellation on page/route dispose)
- **Evidence:** Dio requests are created without `CancelToken`; no dispose
  handlers cancel in-flight requests. Cubits/pages guard against late
  responses (`_awaitingResult`, `mounted`, `_isBusy`, epoch checks), so late
  responses are handled gracefully, but network resources are not explicitly
  released on navigation away.
- **Reproducible scenario:** User navigates away from PaymentDetail while a
  `loadPayment` is in flight; the request completes server-side and the
  response is discarded by state checks.
- **Impact:** Minor resource/bandwidth waste; no user-visible defect because
  of state guards. Low risk.
- **Remediation:** Attach `CancelToken`s to per-page requests and cancel on
  `dispose()` where a page owns a single in-flight request.
- **Verification:** Search `dio_api_client.dart` and feature cubits for
  `CancelToken`. (Code inspection.)

### F-07 — `flutter analyze` reports one info-level lint (INFO)
- **File:** `test/payment_detail_test.dart:135`
- **Evidence:** `flutter analyze` output: `info • The local variable
  '_backgroundAndResume' starts with an underscore ... no_leading_underscores_for_local_identifiers`.
- **Reproducible scenario:** Run `flutter analyze`; one info reported.
- **Impact:** None (lint only, not a defect). `flutter test` still passes.
- **Remediation:** Rename the local variable (out of scope — lint fixes
  deferred per audit rules).
- **Verification:** `flutter analyze` command output. (Runtime verification.)

### F-08 — Dependency security posture not locally verified (INFO / limitation)
- **File:** `pubspec.yaml` (dependencies: dio, flutter_secure_storage,
  flutter_dotenv, url_launcher, flutter_bloc)
- **Evidence:** No vulnerability scan (`flutter pub audit` or equivalent) was
  run; not part of available local evidence and would require network access.
- **Reproducible scenario:** Cannot confirm absence of known-vulnerable
  dependency versions locally.
- **Impact:** Unknown; cannot claim the app is dependency-secure.
- **Remediation:** Run `flutter pub audit` (or `dart pub audit`) and any IDE
  security tooling in M3C; record results.
- **Verification:** Not run (would require network/offline audit tooling).
  (Limitation.)

### F-09 — Cart state is in-memory only; lost on restart (LOW)
- **File:** `lib/features/cart/presentation/bloc/cart_cubit.dart`
- **Evidence:** `CartCubit` extends `Cubit<Cart>` with in-memory `items`;
  no persistence to secure storage or preferences. `clear()` emits empty
  `Cart()`. Cart is cleared on logout (`auth_cubit.dart:66`) and on
  successful order creation (`order_cubit.dart:47`).
- **Reproducible scenario:** App is backgrounded/killed and restarted; cart
  contents are lost.
- **Impact:** User loses an uncommitted cart on process death/restart.
- **Remediation:** Optionally persist cart to local preferences (non-secret
  data) and restore on startup.
- **Verification:** Inspect `CartCubit`. (Code inspection.)

---

## 14. Prioritized remediation backlog

| Priority | ID | Severity | Remediation | Phase |
|----------|----|----------|-------------|-------|
| 1 | F-03 | MEDIUM | Add iOS `NSAppTransportSecurity` config (dev exception or HTTPS requirement) | M3C |
| 2 | F-04 | INFO | Add auth + dashboard-payment endpoints to backend OpenAPI spec; confirm mobile-used paths exist on backend | M3B/M3C |
| 3 | F-01 | INFO | Support environment selection (flavor/`--dart-define`) instead of hardcoded `.env` | M3C |
| 4 | F-02 | INFO | Document that `.env` is public-config only; consider build-time injection for release | M3C |
| 5 | F-05 | LOW | Honor `expires_in` for proactive token refresh | M3B |
| 6 | F-06 | INFO | Add `CancelToken`/dispose cancellation for per-page requests | M3B |
| 7 | F-09 | LOW | Optionally persist cart across restarts | M3B/M3C |
| 8 | F-07 | INFO | Rename local variable in `payment_detail_test.dart:135` | M3B (lint cleanup) |
| 9 | F-08 | INFO | Run dependency vulnerability audit (`flutter pub audit`) | M3C |

---

## 15. Suggested M3B regression tests

These are suggested additions for the next phase; none were implemented
during this read-only audit.

1. **Duplicate-payment protection:** widget test simulating a double-tap on
   Checkout Pay while a request is in flight; assert exactly one
   `createOrderPayment` call and no duplicate submission.
2. **504 ambiguous-timeout no-blind-retry:** data-source test feeding a 504
   `PAYMENT_PROVIDER_TIMEOUT`; assert checkout classifies as
   `ambiguousTimeout` and does not auto-submit a fresh payment.
3. **502 definitive-failure permits retry:** data-source test feeding 502
   `PAYMENT_PROVIDER_ERROR`; assert `definitiveFailure` and a fresh-key
   resubmit is allowed.
4. **Unknown status parse safety:** repository test feeding a `status` value
   outside `[CREATED, PENDING, PAID, FAILED, EXPIRED, CANCELLED]`; assert
   `InvalidResponseException` (not a crash, not silent mapping).
5. **Malformed 201 without `updated_at`:** already covered by
   `payment_parse_recovery_test.dart` — keep as regression.
6. **Refresh-on-401 single-flight:** API-client test sending two concurrent
   401s; assert only one `/refresh` call is made.
7. **Failed-refresh clears tokens:** API-client test where `/refresh` returns
   401; assert stored tokens are cleared and the original request surfaces
   the failure (no infinite loop).
8. **Session restoration after restart:** cubit/repository test simulating
   stored tokens, `me()` success/failure; assert `Authenticated` /
   `Unauthenticated` transitions.
9. **iOS ATS / cleartext refusal:** (cannot run without iOS tooling) —
   document that an HTTP `API_BASE_URL` fails on iOS; add test only if iOS
   CI becomes available.
10. **Checkout recovery from unparseable 201:** already covered by
    `payment_parse_recovery_test.dart` — keep as regression.

---

## 16. Suggested M3C security/configuration work

1. Implement F-03: iOS `NSAppTransportSecurity` (dev exception or HTTPS-only
   for release), mirroring the Android release network-security config.
2. Implement F-01/F-02: environment selection and documentation that `.env`
   is public-config only.
3. Implement F-05: proactive refresh using `expires_in`.
4. Run `flutter pub audit` / dependency vulnerability check (F-08) and record
   results; pin versions if any vulnerabilities found.
5. Add auth + dashboard-payment endpoints to the backend OpenAPI spec (F-04),
   coordinated with the backend team (read-only coordination; no backend
   changes by this audit).
6. Review `flutter_secure_storage` configuration (e.g. Android
   `encryptedSharedPreferences` vs keystore) against organizational mobile
   security policy.

---

## 17. Suggested M3D release-readiness work

1. Confirm release builds target an HTTPS production `API_BASE_URL` (release
   network config already refuses cleartext).
2. Verify no secrets are present in `.env` or bundled assets before any
   release build.
3. Confirm `flutter analyze` is clean (address F-07 lint) in the release CI
   gate.
4. Confirm `flutter test` passes (363 tests) in the release CI gate.
5. Document the release build environment (`API_BASE_URL` must be HTTPS;
   `.env.stage` not used in release).
6. If iOS is a release target, validate the ATS configuration against the
   production HTTPS endpoint (requires iOS tooling — out of scope here).

---

## 18. Explicitly unverified areas

- **Live backend behavior:** no live API calls were made; backend contract
  consistency was verified only by read-only inspection of the OpenAPI spec
  and backend source/docs. Several mobile-used dashboard-payment paths are
  absent from the OpenAPI spec (F-04) — requires backend confirmation.
- **iOS runtime behavior:** no iOS device/simulator available; the iOS ATS
  impact (F-03) could not be exercised at runtime.
- **Android secure storage on-device:** `flutter_secure_storage` was
  inspected in code but not exercised on a real device/emulator.
- **Dependency vulnerabilities:** no local vulnerability scan run (F-08).
- **Release build artifacts:** no `flutter build` was performed; release
  signing, ProGuard/R8, and minified-release behavior were not verified.
- **Deep-link payment return:** no deep links configured; manual return from
  external browser was not tested at runtime.
- **M2 B9 (payment expiration):** remains BLOCKED per the M2 report; no new
  runtime verification was attempted.

---

## 19. Final audit status

**M3A AUDIT COMPLETE — FINDINGS IDENTIFIED**

- Findings by severity: CRITICAL=0, HIGH=0, MEDIUM=1 (F-03), LOW=2
  (F-05, F-09), INFO=6 (F-01, F-02, F-04, F-06, F-07, F-08).
- No CRITICAL or HIGH defects were found.
- The implementation supports the conclusion that the codebase is
  well-hardened for its mobile integration surface (secure token storage,
  single-flight refresh with fail-safe clearance, fail-fast config validation,
  full payment-status coverage matching the backend, idempotency-key based
  duplicate-submission prevention, comprehensive error/recovery states,
  debug-only logging with redaction, release config disallowing cleartext).
- This audit did **not** perform runtime verification against live services,
  and makes no claim about runtime behavior beyond `flutter analyze` and the
  363 passing local tests.
- M2 baseline: tasking states M2 INTEGRATION PASS; the on-disk M2 final
  verification report records M2 PARTIALLY VERIFIED (B9 blocked). This audit
  does not alter that determination.

**Commands actually run:**
- `flutter analyze` → 1 info-level lint issue, exit code 1, 7.0s.
- `flutter test` → all 363 tests passed, exit code 0.

**Files created:**
- `docs/mobile-m3a-read-only-audit.md` (this report) — the only new file.

**Confirmation of read-only execution:**
Application source code, test source code, dependency declarations/lockfiles,
environment files, backend repositories, database records/schemas, application
and backend configuration were **not** modified. No backend services were
started/stopped/rebuilt/reconfigured. No payment transactions were created,
cancelled, expired, or modified. No live payment operations were performed.
No credentials/tokens/passwords/sessions were changed. No migrations or
destructive commands were run. No files were removed, overwritten, reset, or
reformatted. No packages were installed or upgraded. No git branches were
changed and the working tree was not reset.

Do not begin remediation. Do not proceed to M3B. Awaiting user review and
approval.