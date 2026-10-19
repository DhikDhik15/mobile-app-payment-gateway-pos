# M3B.2 Flutter Web Runtime Verification

Date: 2026-10-19 (Asia/Jakarta)  
Final status: **PASS WITH BLOCKED ITEMS**

## Scope and safety

This verification used only the approved isolated staging endpoint at
`http://127.0.0.1:18080` and the existing Flutter Web/Chrome installation.
The protected backend on port 8081 was not modified. No backend, staging,
CORS, database, Docker, application-source, test-source, dependency, or
Android-runtime configuration was modified. No live payment was made.

The initial repository state was:

| Item | Recorded value |
| --- | --- |
| Repository | Flutter repository (`payment_simulator`) |
| Branch | `main` |
| HEAD | `6a51c35a284f29a53cb463eb0b11785c7dddd436` |
| Pre-existing modified files | `docs/mobile-integration-test-results.md`; `test/payment_detail_test.dart` |
| Pre-existing untracked files | `docs/mobile-integration-retest-results.md`; `docs/mobile-m2-final-verification.md`; `docs/mobile-m3a-read-only-audit.md`; `docs/mobile-m3a2-maintenance-report.md`; `docs/mobile-m3b-regression-verification-report.md`; `docs/mobile-m3b1-staging-configuration-plan.md` |

All listed pre-existing changes remained present after testing.

## Preconditions

| Check | Result | Evidence |
| --- | --- | --- |
| Staging identity | PASS | Approved loopback staging target: `127.0.0.1:18080`; its existing staging documentation identifies this isolated endpoint. |
| Staging health | PASS | `GET /health` returned HTTP 200 before and after testing. |
| Staging readiness | PASS | `GET /health/ready` returned HTTP 200 before and after testing. |
| Mock provider | PASS | Existing staging verification documentation records the staging provider as `mock`; no configuration values or environment-file contents were exposed during this run. |
| Protected backend health | PASS | Read-only `GET http://127.0.0.1:8081/health` returned HTTP 200 before and after testing. |
| Flutter Web runtime | PASS | Flutter 3.47.5 detected Chrome Web as an available device. |

`main.dart` loads `.env` before constructing the application graph, then
validates `API_BASE_URL`. `DioApiClient` consumes that value as its base URL.
The `.env` asset is declared in `pubspec.yaml`.

## Temporary `.env` control and restoration

Before the approved edit, a private uniquely named temporary backup was made
outside the repository with preserved file attributes where practical. The
backup SHA-256 matched the original before any edit. Exactly one
`API_BASE_URL` line was temporarily changed to the approved staging URL; all
other lines were retained. The backup was removed only after restoration
verification.

| Check | SHA-256 / result |
| --- | --- |
| Original `.env` | `e6af8b738daf94da804d796b803e1ae76fb83f0bfd9b4c648ea44cc62be748b5` |
| Backup matches original | Yes |
| Restored `.env` | `e6af8b738daf94da804d796b803e1ae76fb83f0bfd9b4c648ea44cc62be748b5` |
| Byte-for-byte comparison | Match |
| `.env` diff after restoration | None |
| Temporary backup after verification | Removed |

No environment-file contents, credentials, tokens, cookies, or other secrets
were logged.

## Flutter Web execution and browser evidence

The supported workflow, `flutter run -d chrome --web-port 35597`, launched
successfully. Chrome opened the application at the actual origin
`http://localhost:35597`; the page reported title `GO-SAAS Merchant POS`.

A read-only browser-equivalent CORS preflight from that exact origin to
staging `/health` returned HTTP 204 and allowed the origin, credentials, and
the application's required HTTP methods/headers. Thus no CORS failure was
observed. The browser runtime inspection did not observe a staging API request
while the app was in its initial unauthenticated state, so no UI/API operation
is represented as passed merely from startup.

## Runtime test matrix

| Scenario | Result | Evidence / reason |
| --- | --- | --- |
| Application startup | PASS | Flutter launched Chrome; app origin and page title confirmed. |
| Browser CORS path | PASS | Preflight from `http://localhost:35597` to staging returned 204 with that origin allowed. |
| Backend connectivity through application UI | BLOCKED | Staging health/readiness passed, but no application API request occurred during the unauthenticated startup view. |
| Login | BLOCKED | No authorized staging test-account credentials or pre-authenticated browser session were available to this run; none were invented or exposed. |
| Session restoration | BLOCKED | Requires an authorized existing session; none was available. |
| Product list | BLOCKED | Authentication-dependent flow not reachable without the authorized session. |
| Product details | BLOCKED | Authentication-dependent flow not reachable without the authorized session. |
| Cart interactions | BLOCKED | Authentication-dependent flow not reachable without the authorized session. |
| Checkout validation | BLOCKED | Authentication-dependent flow not reachable without the authorized session. |
| Mock payment creation | NOT RUN | Avoided because the authorized merchant/session prerequisite was unavailable; no payment was created. |
| Payment detail / transaction history | BLOCKED | Requires a permitted authenticated flow and payment/transaction context. |
| Logout / unauthenticated behavior | BLOCKED | Logout requires an authenticated session; unauthenticated visual state was not asserted from the Flutter canvas alone. |

## Post-test checks

The Flutter process created by this task was stopped before `.env` restoration.
Post-test staging health/readiness and protected-backend health each remained
HTTP 200. Git status after restoration matched the initial set of user changes
and untracked files; this report is the only file created by this task. No
backend process was stopped, restarted, rebuilt, or reconfigured.

## Remaining work

Provide an authorized staging test session/account through an approved secure
mechanism, then rerun the blocked authenticated Web scenarios against the same
isolated mock-provider staging backend. Android runtime verification remains
explicitly out of scope and unperformed.

The final status is **PASS WITH BLOCKED ITEMS**: no executed scenario showed a
regression, but the required authenticated runtime scenarios could not be
meaningfully verified.
