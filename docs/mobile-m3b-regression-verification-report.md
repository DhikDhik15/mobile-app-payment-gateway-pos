# GO-SAAS Mobile — M3B Regression Verification Report

**Project:** GO-SAAS Payment Gateway Simulator (Flutter)
**Phase:** M3B — Regression Verification
**Report date:** Mon Oct 19 2026
**Report path:** `docs/mobile-m3b-regression-verification-report.md`
**Repository:** `/run/media/dhika/Dhika/payment_simulator`

---

## 1. Executive summary

This M3B regression verification confirmed that the Flutter application has no
regressions since M3A.2 maintenance:

- `flutter analyze`: No issues found (exit 0).
- `flutter test`: All 363 tests passed (exit 0).
- No application source code, test source code, configuration, dependencies,
  lockfiles, environment files, backend repositories, database records, or
  staging configuration were modified.
- No live payments were made; no secrets were exposed.

**Final status: PASS WITH BLOCKED ITEMS**

No observed regression failures. However, runtime integration testing against
the isolated staging backend could not be performed because the Flutter
`.env` is currently configured for the protected backend on port 8081
(`http://192.168.110.245:8081`), not the staging backend on port 18080
(`http://127.0.0.1:18080`). Per safety requirements, `.env` was not modified
without explicit approval. Android runtime verification could not be performed
(no Android device or emulator available). Flutter Web runtime verification
against staging could not be performed for the same `.env` reason.

All local regression tests pass; the blocked items are environmental
prerequisites, not code defects.

---

## 2. Repository baseline and safety confirmation

### Git state

| Item | Value |
|------|-------|
| Working directory | `/run/media/dhika/Dhika/payment_simulator` |
| Branch | `main` |
| HEAD commit | `6a51c35a284f29a53cb463eb0b11785c7dddd436` (add file mobile integration) |
| Remote tracking | `origin/main`, up to date |

### Existing modified and untracked files (preserved)

| File | Status | Notes |
|------|--------|-------|
| `docs/mobile-integration-test-results.md` | Modified | Pre-existing change (M2 initial report); preserved |
| `test/payment_detail_test.dart` | Modified | M3A.2 intentional lint fix (`_backgroundAndResume` → `backgroundAndResume`); behavior-preserving |
| `docs/mobile-integration-retest-results.md` | Untracked | Pre-existing (M2 retest report); preserved |
| `docs/mobile-m2-final-verification.md` | Untracked | Pre-existing (M2 final verification); preserved |
| `docs/mobile-m3a-read-only-audit.md` | Untracked | Pre-existing (M3A audit report); preserved |
| `docs/mobile-m3a2-maintenance-report.md` | Untracked | Pre-existing (M3A.2 maintenance report); preserved |

All pre-existing user changes were preserved. No files were reset, cleaned,
stashed, or discarded.

### Flutter toolchain

| Item | Value |
|------|-------|
| Flutter | 3.47.5 (channel stable) |
| Dart | 3.13.4 |
| Connected devices | Linux (desktop), Chrome (web) |
| Android device/emulator | None detected |

### Safety confirmation

- Backend repository: not modified.
- Production-like backend services: not modified, stopped, restarted, or reconfigured.
- Protected backend on port 8081: not modified (no changes made; a read-only connectivity attempt was made but the service is currently unreachable — see section 4).
- Databases: not deleted, reset, recreated, or directly manipulated.
- Docker resources: no destructive commands run; no volumes removed.
- `.env` / `.env.stage`: not modified.
- Dependencies: not installed or changed.
- Application code: not modified during M3B (the only source change, `test/payment_detail_test.dart`, was made in M3A.2).
- No live payments made; no secrets, tokens, or credentials printed.

---

## 3. Local test results

### flutter analyze

```
Analyzing payment_simulator...
No issues found! (ran in 5.8s)
```
**Exit code: 0**

Comparison with M3A.2 baseline: unchanged — no issues found.

### flutter test

```
All 363 tests passed!
```
**Exit code: 0**

Comparison with M3A.2 baseline: unchanged — 363 passed, 0 failed.

### Test coverage (363 tests across 31 test files)

The local test suite uses mocked `ApiClient`/Dio, mocked secure storage, and
fake URL launchers. No tests depend on external services or the live backend.

| Area | Test files | Coverage |
|------|-----------|----------|
| Connectivity / API client | `dio_api_client_test.dart`, `dio_api_client_auth_test.dart`, `backend_connectivity_repository_impl_test.dart`, `check_backend_connection_test.dart` | Client behavior, auth token handling, error mapping, connectivity check |
| Authentication | `auth_cubit_test.dart`, `auth_repository_impl_test.dart` | Login, session restoration, refresh, logout, state transitions |
| Product and cart | `product_catalog_widget_test.dart`, `product_model_test.dart`, `product_image_widget_test.dart`, `cart_cubit_test.dart`, `order_cubit_test.dart` | Catalog, selection, cart changes, empty states, order creation |
| Checkout and payments | `payment_checkout_test.dart`, `payment_cubit_test.dart`, `payment_detail_test.dart`, `payment_model_test.dart`, `payment_parse_recovery_test.dart`, `payment_error_kind_test.dart`, `payment_remote_datasource_test.dart`, `payment_usecases_test.dart` | Checkout validation, payment creation, idempotency, detail loading, status rendering, error recovery |
| Transaction history | `transaction_history_widget_test.dart`, `transaction_repository_impl_test.dart`, `transaction_usecases_test.dart`, `transaction_remote_datasource_test.dart`, `transaction_product_naming_test.dart`, `transaction_display_test.dart` | History loading, detail loading, filters, pagination, merchant scoping |
| Error / recovery | `payment_parse_recovery_test.dart`, `pull_to_refresh_test.dart`, `widget_test.dart` | Parse recovery, unparseable 201, refresh, empty/error states |
| Navigation / shell | `widget_test.dart`, `order_flow_widget_test.dart`, `order_history_widget_test.dart` | App launch, route navigation, cart/checkout flow |

---

## 4. Staging environment verification

### Staging backend (port 18080) — reachable and healthy

| Check | Result | Evidence |
|-------|--------|----------|
| `GET /health` | PASS | HTTP 200, `{"success":true,"data":{"status":"ok"}}` |
| `GET /health/ready` | PASS | HTTP 200, `{"success":true,"data":{"status":"ok"}}` |
| Response time | < 5ms | Both endpoints responded within 5ms |

### Staging configuration (read-only inspection of backend `.env.stage`)

| Setting | Value |
|---------|-------|
| `APP_ENV` | `test` |
| `PAYMENT_PROVIDER` | `mock` |
| `PAYMENT_EXPIRY_ENABLED` | `false` |
| `CORS_ALLOWED_ORIGINS` | `http://127.0.0.1:18080,http://localhost:18080,http://localhost:35597` |

**Configuration verification result:** PASS — staging backend is healthy, ready, and uses the mock payment provider. The CORS configuration includes the Flutter Web dev-server origin (`http://localhost:35597`).

**Note:** `PAYMENT_EXPIRY_ENABLED=false` means expired-payment state (B9) cannot be reproduced against staging. This is a pre-existing condition documented in M2.

### Protected backend (port 8081)

| Check | Result |
|-------|--------|
| `GET /health` on `http://192.168.110.245:8081` | Connection failed (timeout after 5s) |

The protected backend on port 8081 is currently unreachable from this environment. **No modifications were made to it.** This does not affect staging verification since M3B targets the isolated staging backend on port 18080. However, it means the current `.env` (which points to port 8081) cannot be used for successful runtime integration testing.

### `.env` configuration (blocker for runtime testing)

| Item | Value |
|------|-------|
| Current `.env` `API_BASE_URL` | `http://192.168.110.245:8081` (protected backend) |
| Staging `.env.stage` `API_BASE_URL` | `http://127.0.0.1:18080` (staging backend) |
| `.env` modifiable? | No — safety rule prohibits modification without explicit approval |

**Runtime integration testing against staging is BLOCKED** because the Flutter
`.env` is not configured for the staging backend and cannot be changed without
explicit approval. Running the Flutter app with the current `.env` would direct
it to the unreachable protected backend on port 8081.

---

## 5. Regression matrix

| Area | Scenario | Status | Evidence |
|------|----------|--------|----------|
| **A. Connectivity** | API reachability (local, mocked) | PASS | `dio_api_client_test.dart`, `backend_connectivity_repository_impl_test.dart` — 363 local tests pass |
| | API error handling | PASS | `dio_api_client_test.dart` maps DioException to typed failures |
| | Loading / empty / failure states | PASS | Widget tests for orders, payments, transactions, products |
| **B. Authentication** | Login | PASS | `auth_cubit_test.dart`, `auth_repository_impl_test.dart`, `dio_api_client_auth_test.dart` |
| | Session restoration | PASS | `auth_repository_impl_test.dart` — restoreSession success/failure paths |
| | Token refresh after expired access token | PASS | `dio_api_client_auth_test.dart` — 401 → refresh → retry flow |
| | Failed refresh handling | PASS | `dio_api_client_auth_test.dart` — refresh failure clears tokens |
| | Logout | PASS | `auth_cubit_test.dart`, `auth_repository_impl_test.dart` — logout clears tokens |
| **C. Product and cart** | Product list loading | PASS | `product_catalog_widget_test.dart`, `product_model_test.dart` |
| | Product selection | PASS | `product_catalog_widget_test.dart` — detail view navigation |
| | Cart quantity changes | PASS | `cart_cubit_test.dart`, `order_cubit_test.dart` |
| | Empty cart validation | PASS | `order_cubit_test.dart` — does not submit when cart empty |
| **D. Checkout and payments** | Checkout validation | PASS | `payment_checkout_test.dart` — recovery-first validation |
| | Payment creation using mock provider | BLOCKED | Requires runtime staging integration; `.env` not configured for staging |
| | Idempotency behavior | PASS | `payment_checkout_test.dart` — stable idempotency key, fresh key retry, history-derived keys |
| | Payment detail loading | PASS | `payment_detail_test.dart`, `payment_remote_datasource_test.dart` |
| | Payment status rendering | PASS | `payment_detail_test.dart` — all states render non-blank content; `PaymentStatusIndicator` |
| **E. Transaction history / session** | History loading | PASS | `transaction_history_widget_test.dart`, `transaction_repository_impl_test.dart` |
| | Detail loading | PASS | `transaction_display_test.dart`, `transaction_remote_datasource_test.dart` |
| | Unauthenticated state | PASS | `auth_cubit_test.dart` — AuthUnauthenticated transitions |
| | Recovery after API errors | PASS | `payment_parse_recovery_test.dart`, `pull_to_refresh_test.dart` — error states with retry |
| **F. Payment statuses** | CREATED | PASS | `payment_model_test.dart` — parses all status values including CREATED |
| | PENDING | PASS | `payment_model_test.dart` — parses PENDING |
| | PAID | PASS | `payment_model_test.dart` — parses PAID |
| | FAILED | PASS | `payment_model_test.dart` — parses FAILED |
| | EXPIRED | PASS (code only) | `payment_model_test.dart` — parses EXPIRED; runtime BLOCKED (PAYMENT_EXPIRY_ENABLED=false in staging) |
| | CANCELLED | PASS (code only) | `payment_model_test.dart` — parses CANCELLED; runtime BLOCKED (cancel not in Flutter dashboard API) |

### Summary counts

| Status | Count |
|--------|-------|
| PASS | All local regression checks |
| FAIL | 0 |
| BLOCKED | Runtime staging integration (`.env` misconfigured), Android runtime, Flutter Web runtime against staging |
| NOT RUN | N/A (all applicable local tests ran) |

---

## 6. Android verification results

| Check | Result |
|-------|--------|
| Android device or emulator available | No — `flutter devices` reports only Linux (desktop) and Chrome (web) |
| `flutter emulators` | No emulators listed |
| Android runtime verification | NOT RUN — no Android device or emulator available |

No Android-specific runtime behaviors (secure token storage on-device, URL launching, app background/resume, network permissions) could be exercised. These were verified by code inspection during M3A but not at runtime.

---

## 7. Flutter Web verification results

| Check | Result |
|-------|--------|
| Chrome browser available | Yes — `Chrome (web)` detected via `flutter devices` |
| Flutter Web runtime against staging | BLOCKED — `.env` `API_BASE_URL` points to `http://192.168.110.245:8081` (protected backend, unreachable), not `http://127.0.0.1:18080` (staging). Modifying `.env` requires explicit approval. |
| Flutter Web local tests (widget tests) | PASS — included in the 363 passing tests |
| Runtime verification claim | Not made — per acceptance criteria, platform runtime verification is not claimed based solely on a successful build or local test suite |

No `.env` modification was made. No build was performed (building is outside the scope of regression verification and would not constitute runtime verification against staging).

---

## 8. Test evidence and limitations

### Evidence base

- All regression evidence comes from the local `flutter test` suite (363 tests, exit 0) and `flutter analyze` (no issues, exit 0).
- Tests use mocked dependencies; no live backend calls were made during local test execution.
- Staging backend health was verified via read-only HTTP `GET /health` and `GET /health/ready` (both HTTP 200).
- No database queries, payment creations, or state modifications were performed.

### Limitations

1. **Runtime integration against staging is BLOCKED.** The Flutter `.env` points to the protected backend on port 8081, not staging on port 18080. `.env` cannot be modified without explicit approval. All runtime scenarios requiring a live backend connection (payment creation, payment detail retrieval, authentication flows against staging, etc.) could not be executed end-to-end through the Flutter runtime.

2. **Android runtime verification is NOT RUN.** No Android device or emulator is available.

3. **Flutter Web runtime against staging is BLOCKED** for the same `.env` reason as #1.

4. **Expired payment (EXPIRED) runtime verification is BLOCKED.** Staging has `PAYMENT_EXPIRY_ENABLED=false` and no on-demand expiry API exists (documented in M2).

5. **Payment cancellation (CANCELLED) runtime verification via Flutter is BLOCKED.** The cancel endpoint is on the merchant API (`X-API-Key`), not the Flutter dashboard API surface (documented in M2).

6. **Protected backend on port 8081 is currently unreachable** from this environment. It was not modified by this task.

---

## 9. M2 documentation discrepancy

Three M2 reports contain conflicting information about the final M2 status and B10 cancellation:

| Report | Final status | B10 result | Total passed |
|--------|-------------|------------|--------------|
| `docs/mobile-integration-test-results.md` (initial) | M2 BLOCKED | BLOCKED | 3 |
| `docs/mobile-integration-retest-results.md` | M2 PARTIALLY VERIFIED | BLOCKED | 19 |
| `docs/mobile-m2-final-verification.md` (final verification) | M2 PARTIALLY VERIFIED | PASS | 20 |

**Conflict:** The final verification report marks B10 (cancelled payment) as **PASS** (HTTP 200, status CANCELLED for payment `2502a7cb-...`), while the retest report marks B10 as **BLOCKED** (cancel endpoint is on the merchant API, not exposed by the Flutter dashboard API). The total passed counts differ accordingly (20 vs 19).

**Resolution per M3B rules:** M2 did not "pass" — the final verification status is PARTIALLY VERIFIED, not INTEGRATION PASS. Therefore the Task B alignment condition ("if the final M2 verification report establishes that M2 passed") is not triggered. No M2 report was rewritten. The discrepancy is documented here as a separate documentation finding.

**Recommendation:** The team should reconcile the B10 result across the M2 reports. The final verification report provides direct evidence (HTTP 200, `status: CANCELLED` confirmed via dashboard API) supporting B10 as PASS in that session, while the retest report notes the architectural limitation that cancel is not in the Flutter dashboard API surface. Both observations can be true simultaneously — B10 was verified via direct API call (not through the Flutter app) — but the reports should be aligned to avoid confusion.

---

## 10. New findings

No new code defects were found. All 363 local tests pass and `flutter analyze` is clean.

The following items are **environmental blockers**, not code defects:

| ID | Area | Severity | Description |
|----|------|----------|-------------|
| M3B-01 | Runtime integration | BLOCKED | `.env` `API_BASE_URL` points to protected backend (port 8081), not staging (port 18080). Cannot modify `.env` without approval. Prevents end-to-end Flutter runtime testing against staging. |
| M3B-02 | Android runtime | NOT RUN | No Android device or emulator available. |
| M3B-03 | Flutter Web runtime | BLOCKED | Same `.env` blocker as M3B-01; Chrome is available but cannot test against staging without config change. |
| M3B-04 | Expired payment (EXPIRED) | BLOCKED | `PAYMENT_EXPIRY_ENABLED=false` in staging; no on-demand expiry API. Pre-existing from M2 (B9). |
| M3B-05 | Payment cancellation (CANCELLED) via Flutter | BLOCKED | Cancel endpoint on merchant API (`X-API-Key`); not in Flutter dashboard API. Pre-existing from M2 (B10). |

---

## 11. Confirmation: no application code was changed

During M3B, no application source code, test source code, configuration, dependency declarations, lockfiles, environment files, or business logic were modified. The only modified source file in the working tree, `test/payment_detail_test.dart`, was changed during M3A.2 (behavior-preserving lint fix), not during M3B.

---

## 12. Confirmation: backend, database, Docker, and staging configuration not modified

- Backend repository: not modified.
- Backend services: not started, stopped, restarted, or reconfigured.
- Protected backend on port 8081: not modified (currently unreachable from this environment, but untouched).
- Databases: not deleted, reset, recreated, or directly manipulated.
- Docker containers/volumes/networks: no prune/cleanup commands run.
- Staging configuration (backend `.env.stage`): read-only inspection only; no changes.
- Flutter `.env` / `.env.stage`: not modified.

---

## 13. Final status

**PASS WITH BLOCKED ITEMS**

- No observed regression failures: `flutter analyze` reports no issues; `flutter test` passes all 363 tests.
- Some required scenarios could not be verified due to environmental prerequisites:
  - Runtime integration testing against staging (BLOCKED — `.env` not configured for staging, cannot modify without approval)
  - Android runtime verification (NOT RUN — no device/emulator)
  - Flutter Web runtime testing against staging (BLOCKED — same `.env` reason)
  - Expired payment (EXPIRED) runtime verification (BLOCKED — `PAYMENT_EXPIRY_ENABLED=false` in staging)
  - Payment cancellation (CANCELLED) via Flutter runtime (BLOCKED — cancel not in Flutter dashboard API)

### Approval needed for follow-up work

1. **Modify Flutter `.env`** to point `API_BASE_URL` at `http://127.0.0.1:18080` (staging) to enable runtime integration testing against the isolated staging backend. This requires explicit approval per safety rule #9.
2. **Android device/emulator** availability for mobile-specific runtime verification (secure storage, URL launching, background/resume).
3. **M2 documentation discrepancy** reconciliation (B10 PASS vs BLOCKED across reports).

Do not begin M3C.

---

## Files created

| File | Description |
|------|-------------|
| `docs/mobile-m3b-regression-verification-report.md` | This report — the only new file created during M3B |

## Files changed

None during M3B. The pre-existing modified file `test/payment_detail_test.dart` (M3A.2 lint fix) and `docs/mobile-integration-test-results.md` (pre-existing M2 report change) remain unchanged from their M3A.2 state.