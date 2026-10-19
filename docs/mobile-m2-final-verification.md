# GO-SAAS — M2 Final Verification: Expired and Cancelled Payment States

**Project:** GO-SAAS Payment Gateway Simulator
**Phase:** M2 Final Verification — Expired and Cancelled Payment States
**Report date:** Mon Oct 19 2026
**Report path:** `docs/mobile-m2-final-verification.md`
**Previous reports:**
- `docs/mobile-integration-test-results.md` (M2 BLOCKED)
- `docs/mobile-integration-retest-results.md` (M2 PARTIALLY VERIFIED, 19 PASS, 0 FAIL, 2 BLOCKED)
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
- No application source code was modified.
- Staging services were not stopped.
- Staging configuration was restored to its original values after testing.

---

## Phase 1 — Revalidate Staging

| Check | Result | Evidence |
|---|---|---|
| Staging backend identity/port | PASS | `http://127.0.0.1:18080`, process PID 146490 (`/tmp/opencode/paygate-stage`) |
| Staging backend `/health` | PASS | HTTP 200 `{"success":true,"data":{"status":"ok"}}` |
| Staging backend `/health/ready` | PASS | HTTP 200 |
| Staging PostgreSQL container | PASS | `go-saas-m2-staging-db`, `postgres:16-alpine`, Up healthy, `127.0.0.1:55433->5432/tcp` |
| Database name | PASS | `go_saas_m2_staging`, user `go_saas_m2_staging` |
| Schema version | PASS | `version=25`, `dirty=false` (>= 22 required) |
| `PAYMENT_PROVIDER=mock` | PASS | Staging `.env.stage` |
| Protected backend port 8081 | PASS | HTTP 200 on `/health`, untouched |
| Flutter git status | PASS | Clean except docs changes |
| Backend git status | PASS | Only `.env.stage` modified (CORS + temporary expiry toggle, restored) |

Staging isolation positively verified. Proceeded to testing.

---

## Phase 2 — B9: Payment Expiration

### Investigation findings

The payment expiry mechanism consists of:

| Component | Detail |
|---|---|
| Config flag | `PAYMENT_EXPIRY_ENABLED` (default `true`; staging was `false`) |
| Worker interval | `PAYMENT_EXPIRY_INTERVAL=30s` |
| Worker batch size | `PAYMENT_EXPIRY_BATCH_SIZE=100` |
| Expiry service | `ExpiryService.ProcessExpired(ctx, batchSize)` — finds PENDING transactions where `expired_at <= NOW()` |
| Expiry worker | `ExpiryWorker` — runs `ProcessExpired` immediately on startup, then every 30s |
| Transaction table | `transactions` (status column, `expired_at` column) |
| Terminal-state protection | `tx.Status.CanTransitionTo(model.TransactionStatusExpired)` — only PENDING → EXPIRED is allowed; PAID/FAILED/CANCELLED cannot transition to EXPIRED |
| Update method | Optimistic conditional UPDATE: `WHERE id = $2 AND status = $3` — no-op if already terminal |
| Verification endpoint | `GET /api/v1/dashboard/payments/{id}` (dashboard API, Bearer JWT) |

### Actions taken

1. Preserved original staging config (`PAYMENT_EXPIRY_ENABLED=false` backed up to `/tmp/opencode/backend.env.stage.bak`)
2. Set `PAYMENT_EXPIRY_ENABLED=true` in staging `.env.stage`
3. Restarted only the verified staging backend (PID 102872 → 132884)
4. Verified health/readiness after restart (both HTTP 200)
5. Confirmed expiry worker started (log: `"expiry worker started","interval":30000000000,"batch_size":100`)
6. Verified effective setting: `PAYMENT_EXPIRY_ENABLED=true` in `.env.stage`

### Blocker encountered

After enabling expiry and restarting, the worker found **zero PENDING transactions** to expire:

| Table | PENDING rows |
|---|---|
| `transactions` | 0 |
| `mock_payments` | 5 (but expiry worker does not query this table) |

All 5 transactions in the `transactions` table are in terminal states:
- `69d39dcd-...` → PAID (Oct 16)
- `80479258-...` → FAILED (Oct 16)
- `101cc397-...` → PAID (B7 simulate success)
- `9f2768ee-...` → FAILED (B8 simulate fail)
- `2502a7cb-...` → CANCELLED (B10 cancel, this session)

Creating a fresh payment via the supported API sets `expired_at = now + 30 minutes` (hardcoded in `MockPaymentProvider.expiredAt()`; `ExpiryDuration` is not set in server wiring, defaulting to 30 min). There is no API parameter to shorten this TTL, and no on-demand expiry endpoint exists.

Waiting 30 minutes for a fresh payment's `expired_at` to pass is impractical for this test session. Direct database modification is prohibited (safety rule #5). Source code modification is prohibited (safety rule #12).

### Restoration

7. Restored `PAYMENT_EXPIRY_ENABLED=false` in staging `.env.stage`
8. Restarted only the verified staging backend (PID 132884 → 146490)
9. Verified health/readiness (both HTTP 200)
10. Verified `.env.stage` contains `PAYMENT_EXPIRY_ENABLED=false`

### B9 result: BLOCKED

| Test | Result | Reason |
|---|---|---|
| B9. Verify expired payment | BLOCKED | No PENDING transactions exist; new payments get `expired_at = now + 30 minutes` (hardcoded, not API-configurable); cannot wait 30 minutes; cannot modify DB or source code |

---

## Phase 3 — B10: Payment Cancellation

### Investigation findings

| Item | Detail |
|---|---|
| HTTP method/route | `POST /api/v1/payments/{id}/cancel` |
| Authentication | `X-API-Key` header (merchant API key, compound `pk_<hex>:sk_<hex>` format) |
| Middleware | `middleware.Auth` (new key system) with `LEGACY_API_CREDENTIALS_ENABLED=true` fallback |
| Required permissions | Merchant must be ACTIVE; API key must be valid |
| Allowed source states | PENDING (cancel transitions PENDING → CANCELLED) |
| Expected response | HTTP 200, payment object with `status: "CANCELLED"` |
| Idempotent | Yes — conditional UPDATE `WHERE status = 'PENDING'`; cancelling an already-cancelled payment is a no-op |
| Dashboard API reflects status | Yes — `GET /api/v1/dashboard/payments/{id}` returns `status: "CANCELLED"` |

### Actions taken

1. Recovered staging owner credentials via supported password-reset flow (from retest)
2. Logged in as staging owner → obtained Bearer access token
3. Created a new merchant API key via `POST /api/v1/dashboard/api-keys` (Bearer auth) → received `key_id` and plaintext `secret` (returned once)
4. Created a fresh order via `POST /api/v1/dashboard/orders` → order `a6c25617-...`, status CREATED
5. Created a fresh payment via `POST /api/v1/dashboard/payments` → payment `2502a7cb-...`, status PENDING
6. Verified payment is PENDING via `GET /api/v1/dashboard/payments/{id}`
7. Cancelled via `POST /api/v1/payments/2502a7cb-.../cancel` with `X-API-Key` → HTTP 200, `status: "CANCELLED"`
8. Verified via dashboard API `GET /api/v1/dashboard/payments/{id}` → `status: "CANCELLED"`
9. Verified merchant scoping: payment's `merchant_order_id` belongs to staging merchant `b80f9794-...`

### B10 result: PASS

| Test | Result | Action | Expected | Actual |
|---|---|---|---|---|
| B10. Verify cancelled payment | PASS | `POST /api/v1/payments/{id}/cancel` with X-API-Key | HTTP 200, status CANCELLED | HTTP 200; payment `2502a7cb-...` status CANCELLED; confirmed via dashboard API |

### API key created (for testing only)

| Field | Value | Classification |
|---|---|---|
| Key ID | `pk_ed7c088508f026b33287d596a848a5994beaf7fd` | Non-secret identifier |
| Secret | NOT RECORDED | Returned once via dashboard API; not stored in report |

---

## Phase 4 — Regression Checks

| Check | Result | Evidence |
|---|---|---|
| Existing successful payments remain PAID | PASS | `69d39dcd-...` → PAID; `101cc397-...` → PAID |
| Existing failed payments remain FAILED | PASS | `80479258-...` → FAILED; `9f2768ee-...` → FAILED |
| Cancelled payment stays CANCELLED | PASS | `2502a7cb-...` → CANCELLED |
| Expired payments do not revert to PENDING | PASS | No EXPIRED payments exist; no expiry worker running (config restored) |
| No unrelated merchant data changed | PASS | All transactions belong to staging merchant `b80f9794-...` |
| Protected backend port 8081 healthy | PASS | HTTP 200 on `/health`, untouched |

---

## Phase 5 — Configuration Restoration

| Configuration | Original | During test | Restored | Verified |
|---|---|---|---|---|
| `PAYMENT_EXPIRY_ENABLED` | `false` | `true` | `false` | PASS (grep confirmed) |
| Staging backend health | 200 | 200 | 200 | PASS |
| Staging backend readiness | 200 | 200 | 200 | PASS |
| Staging backend process | Running | Restarted (PID 132884) | Running (PID 146490) | PASS |
| Staging services stopped | No | No | No | PASS |

The `.env.stage` file still contains the CORS change from the retest phase (`http://localhost:35597` added to `CORS_ALLOWED_ORIGINS`). That change was made during the retest and is reversible; it is unrelated to this final verification.

The Flutter `.env` was verified restored to its original value (`API_BASE_URL=http://192.168.110.245:8081`) in the retest phase and was not modified in this session.

---

## Created staging record identifiers (this session)

| Record type | Identifier | Status | Purpose |
|---|---|---|---|
| API key | `pk_ed7c088508f026b33287d596a848a5994beaf7fd` | ACTIVE | Used for B10 cancellation test |
| Order | `a6c25617-c057-40e1-ac59-d5309900e45c` | CREATED | Order for B10 cancel test |
| Payment | `2502a7cb-4db2-47f2-a4de-da91967c0e4e` | CANCELLED | B10 cancel test payment |

All records exist only in the isolated staging database `go_saas_m2_staging`.

Pre-existing staging records (from earlier phases, untouched):
| Transaction | `69d39dcd-9eca-45cd-90a7-cc50379855e6` | PAID |
| Transaction | `80479258-adde-4e27-b31b-72db68493abc` | FAILED |
| Transaction | `101cc397-21ce-489e-8a2f-03c3de42c3df` | PAID |
| Transaction | `9f2768ee-90ca-4c9c-b000-1e6f72411825` | FAILED |

---

## Updated test results

### All 21 M2 tests

| Group | Passed | Failed | Blocked | Not Run | Total |
|---|---|---|---|---|---|
| A: Connectivity & Auth | 6 | 0 | 0 | 0 | 6 |
| B: Order & Payment | 9 | 0 | 1 (B9) | 0 | 10 |
| C: History & Session | 5 | 0 | 0 | 0 | 5 |
| **Total** | **20** | **0** | **1** | **0** | **21** |

### B9 detail

| Test | Result | Reason |
|---|---|---|
| B9. Verify expired payment | BLOCKED | No PENDING transactions exist; per-payment `expired_at` TTL is hardcoded to 30 minutes (not API-configurable); no on-demand expiry API; cannot wait 30 minutes; cannot modify DB or source code |

### B10 detail

| Test | Result | Evidence |
|---|---|---|
| B10. Verify cancelled payment | PASS | `POST /api/v1/payments/2502a7cb-.../cancel` → HTTP 200, `status: CANCELLED`; confirmed via `GET /api/v1/dashboard/payments/2502a7cb-...` → `status: CANCELLED` |

---

## Remaining blockers

| Blocker | Description | Impact |
|---|---|---|
| B9 — Payment expiration | No supported mechanism to trigger expiry within a practical timeframe. `PAYMENT_EXPIRY_ENABLED=true` works but there are no PENDING transactions; new payments expire after 30 minutes (hardcoded TTL). | M2 cannot achieve INTEGRATION PASS until B9 is resolved |
| Flutter `.env` hardcoded `fileName: '.env'` | `.env.stage` not auto-selected; must be manually copied | Minor operational limitation |
| Flutter Web CORS origin is dynamic | Dev-server port changes per session; CORS origin must be re-added | Minor operational limitation |
| No Android emulator/physical device | Mobile-specific behaviors untestable | Out of scope for this verification |

---

## Confirmation that protected resources were untouched

| Resource | Status |
|---|---|
| Protected backend port 8081 | Healthy (HTTP 200), not modified |
| Protected backend configuration | Not modified |
| Existing databases | Not modified |
| Existing Docker containers/volumes/networks | Not modified |
| Flutter `.env` | Restored to original (not modified in this session) |
| Staging services | Still running (not stopped) |

---

## Final readiness decision

**M2 PARTIALLY VERIFIED**

20 of 21 tests passed, 0 failed, 1 blocked (B9).

### What was verified in this session
- Payment cancellation end-to-end: create payment (PENDING) → cancel via Merchant API (X-API-Key) → verify CANCELLED via dashboard API → confirm in transaction history
- All previously passing tests remain passing (regression checks)
- Staging configuration restored to original values after testing

### What remains blocked
- B9 — Payment expiration: no supported mechanism to trigger expiry within a practical timeframe. The expiry worker functions correctly when `PAYMENT_EXPIRY_ENABLED=true`, but there are no PENDING transactions to expire, and new payments have a hardcoded 30-minute TTL.

### Recommended next step
To achieve M2 INTEGRATION PASS, resolve B9 by either:
1. Enabling `PAYMENT_EXPIRY_ENABLED=true` in staging, creating a fresh payment, and waiting 30 minutes for it to expire; or
2. Making the per-payment expiry TTL configurable (e.g., via environment variable or API parameter) so short-lived test payments can be created; or
3. Adding an on-demand expiry trigger endpoint for testing purposes.

Do not proceed to M3 until B9 is resolved or explicitly accepted as out of scope.

**Report path:** `docs/mobile-m2-final-verification.md`

**Runtime or database state changed:** Staging records created (1 API key, 1 order, 1 cancelled payment). Original staging configuration restored (`PAYMENT_EXPIRY_ENABLED=false`). Protected port-8081 backend and all existing infrastructure untouched. Staging services remain running.
