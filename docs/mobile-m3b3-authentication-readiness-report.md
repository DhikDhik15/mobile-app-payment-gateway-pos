# M3B.3 Staging Authentication Readiness Audit

Date: 2026-10-19 (Asia/Jakarta)  
Final status: **READY AFTER USER ACTION**

## Scope and repository baseline

This was a read-only audit of the Flutter authentication implementation and the repository's existing staging/integration documentation. No HTTP authentication request, credential recovery, password reset, onboarding, database access, configuration edit, or runtime testing was performed.

| Item | Recorded value |
| --- | --- |
| Repository | Flutter repository (`payment_simulator`) |
| Branch | `main` |
| HEAD | `6a51c35a284f29a53cb463eb0b11785c7dddd436` |
| Existing modified files | `docs/mobile-integration-test-results.md`; `test/payment_detail_test.dart` |
| Existing untracked files | `docs/mobile-integration-retest-results.md`; `docs/mobile-m2-final-verification.md`; `docs/mobile-m3a-read-only-audit.md`; `docs/mobile-m3a2-maintenance-report.md`; `docs/mobile-m3b-regression-verification-report.md`; `docs/mobile-m3b1-staging-configuration-plan.md`; `docs/mobile-m3b2-flutter-web-runtime-report.md` |

All baseline changes were preserved. This report is the only file created by this audit.

## Flutter authentication flow

| Concern | Confirmed implementation |
| --- | --- |
| Login | `POST /api/v1/auth/login` with `email` and `password`. The form validates non-empty fields and email format before submitting. |
| Login success | The success envelope supplies an access token, expiry, and user. The refresh token arrives in a `Set-Cookie` response header. |
| Storage | Access and refresh tokens use `flutter_secure_storage`, not plain files, logs, SharedPreferences, or compile-time constants. |
| Authorized calls | The client attaches the access token as a bearer authorization header. |
| Session restoration | Startup checks for a stored refresh token, then calls `GET /api/v1/auth/me`. A 401 triggers one refresh/retry; absent or invalid storage resolves fail-closed to unauthenticated. |
| Refresh | `POST /api/v1/auth/refresh` uses `X-Refresh-Token`; rotated tokens are persisted and concurrent 401s share one refresh operation. |
| Logout | `POST /api/v1/auth/logout` is attempted with the bearer token. Local tokens and the in-memory cart are cleared even if it fails. |
| Invalid/missing credentials | Empty or malformed user input is rejected locally. Backend/network failures become user-safe messages and return the form to a usable unauthenticated state. |

There is no Flutter-supported anonymous-test, credential-bypass, or seeded browser-session mechanism. The app correctly requires an authorized account.

## Documented backend contract

| Operation | Endpoint | Authentication / purpose |
| --- | --- | --- |
| Login | `POST /api/v1/auth/login` | Email/password login |
| Current user | `GET /api/v1/auth/me` | Bearer token; session validation |
| Refresh | `POST /api/v1/auth/refresh` | Refresh token via header or cookie contract |
| Logout | `POST /api/v1/auth/logout` | Bearer token; logout flow |
| Password reset request | `POST /api/v1/auth/password-reset/request` | Supported recovery route; state-changing workflow, not invoked here |
| Password reset confirmation | `POST /api/v1/auth/password-reset/confirm` | Changes a password; not invoked here |
| Merchant onboarding | `POST /api/v1/admin/onboarding/merchants` | Requires an admin key and creates merchant/user/API-credential state; not invoked here |

The mobile integration retest records a historical staging recovery using the password-reset request/confirmation flow. At that time outbound email was disabled and the reset token was obtained from the staging email outbox through a read-only database query. This establishes a past supported route, but does **not** prove that the account, password, outbox, or current configuration remains available or appropriate now. The outbox is not a safe self-service mechanism for this audit because obtaining a reset token exposes credential-like material and the reset workflow changes account state.

Onboarding is likewise not an appropriate next step for the requested regression run: it requires privileged material, creates staging state, and needs separate explicit authorization.

## Confirmed versus unknown

| Item | Status | Evidence / limitation |
| --- | --- | --- |
| Flutter login contract and fields | Confirmed | Current Flutter source. |
| Secure token persistence and cleanup | Confirmed | Current Flutter source. |
| No built-in Flutter test-session bypass | Confirmed | Current source and endpoint inventory. |
| Staging account previously existed | Historically documented | Existing reports; account status was not rechecked in this audit. |
| Prior password-reset recovery | Historically documented | Existing retest report; not exercised or revalidated here. |
| Current authorized password/session | Unknown | M3B.2 had neither; no credential was read, guessed, or tested here. |
| Current reset availability / outbox access | Unknown | Requires authorized, separately scoped validation. |
| Current onboarding authorization | Unknown | No admin key or authority was requested, assumed, or accessed. |

## Safest next action

The user or designated staging-account owner should choose one approved credential-safe path:

1. Provide a current, dedicated staging dashboard-user credential through the organization's approved secret-sharing channel, then enter it manually in Flutter Web without disclosing it to this agent.
2. Have the authorized staging owner complete the supported password-reset workflow outside this audit, then share the newly established staging credential through that approved channel.
3. If recovery is unavailable, explicitly authorize a separate staging-only onboarding task with privileged authority and a defined retention/cleanup decision.

Option 1 is least invasive and sufficient for the previously blocked Flutter Web scenarios. A valid account must be confirmed by the authorized operator, not inferred from historical reports. Authenticated runtime testing is deliberately not started by this audit.

## Safety confirmation

- No credentials, tokens, cookies, passwords, API keys, or environment values were printed, guessed, read, or modified.
- No login, reset, account creation, onboarding, logout, refresh, or payment operation was invoked.
- No `.env` or `.env.stage` file was modified.
- No backend, database, Docker, CORS, staging configuration, application source, tests, or dependencies were modified.
- No backend service was restarted or changed.

The environment is **READY AFTER USER ACTION**: the supported auth contract and a historically supported recovery path are documented, but an authorized human must provide or establish a current staging credential before authenticated regression testing proceeds.
