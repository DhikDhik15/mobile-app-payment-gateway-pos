# GO-SAAS Mobile — M3B.1 Staging Configuration Plan

**Project:** GO-SAAS Payment Gateway Simulator (Flutter)
**Phase:** M3B.1 — Staging Configuration Preparation
**Report date:** Mon Oct 19 2026
**Report path:** `docs/mobile-m3b1-staging-configuration-plan.md`
**Repository:** `/run/media/dhika/Dhika/payment_simulator`

---

## Safety statement

This task is strictly read-only. No files were created or modified other than this
report. No `.env`, `.env.stage`, application source, backend files, database
records, or runtime configuration were changed. No secrets or environment file
contents are printed.

---

## Task A — Repository baseline

### Git state

| Item | Value |
|------|-------|
| Working directory | `/run/media/dhika/Dhika/payment_simulator` |
| Branch | `main` |
| HEAD commit | `6a51c35a284f29a53cb463eb0b11785c7dddd436` (add file mobile integration) |
| Remote tracking | `origin/main`, up to date |

### Existing modified and untracked files (preserved)

| File | Status |
|------|--------|
| `docs/mobile-integration-test-results.md` | Modified (pre-existing M2 report change) |
| `test/payment_detail_test.dart` | Modified (pre-existing M3A.2 lint fix) |
| `docs/mobile-integration-retest-results.md` | Untracked (pre-existing M2 retest report) |
| `docs/mobile-m2-final-verification.md` | Untracked (pre-existing M2 final verification report) |
| `docs/mobile-m3a-read-only-audit.md` | Untracked (pre-existing M3A audit report) |
| `docs/mobile-m3a2-maintenance-report.md` | Untracked (pre-existing M3A.2 maintenance report) |
| `docs/mobile-m3b-regression-verification-report.md` | Untracked (pre-existing M3B regression report) |

All pre-existing changes are preserved. Nothing is discarded or altered.

---

## Task B — Configuration discovery

### How API_BASE_URL is loaded

`lib/main.dart:63`:
```dart
await dotenv.load(fileName: '.env');
```
The file name is hardcoded to `'.env'`. Loading happens before any network
client is created and before `AppEnvironment.validate()`.

`lib/core/config/app_environment.dart:20`:
```dart
static String get apiBaseUrl => dotenv.env['API_BASE_URL']?.trim() ?? '';
```
`validate()` (lines 24-28) throws `StateError` if `API_BASE_URL` is missing
or empty — fail-fast, no silent default.

### Alternate environment file support

**No.** `main.dart` unconditionally loads `'.env'`. There is no conditional
logic to load `.env.stage` based on build mode, flavor, or environment
variable. `.env.stage` exists as a tracked template but is never selected by
code.

### `--dart-define` or Flutter flavors

**Neither is supported.**
- `app_environment.dart:11` states: "This replaces the former
  `--dart-define=API_BASE_URL` mechanism. The single source of truth for the
  value is `.env`."
- `payment_detail_page.dart:30` states: "There is no flavor configuration in
  this project."
- No `.flavors` file exists in the repository.

### `.env` as a Flutter build asset

**Yes.** `pubspec.yaml:72-73` declares:
```yaml
flutter:
  assets:
    - .env
```
`API_BASE_URL` is bundled into the app artifact (observed at
`build/flutter_assets/.env`). `.env` is gitignored (`.gitignore:51`) — local
only, not committed.

### Configuration selection without modifying `.env`

**No supported mechanism exists for runtime.** The only ways to change the
effective `API_BASE_URL` at runtime are:
1. Edit `.env` (the file `main.dart` loads), or
2. Use `dotenv.testLoad(...)` — but this is only available in `flutter_test`
   (test mode), not in `flutter run`. Examples:
   - `test/dio_api_client_test.dart:196`:
     `dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://test-server:8081'})`
   - `test/product_image_widget_test.dart:184`:
     `dotenv.testLoad(fileInput: 'API_BASE_URL=$_testBaseUrl')`

These test harness overrides apply to unit/widget tests only and do not affect
a running Flutter application.

### Existing staging-related documentation

- `docs/mobile-local-staging-execution.md` — M2A Phase A staging
  infrastructure report. Staging backend binds to `127.0.0.1:18080`
  (loopback only, not LAN). Staging uses `PAYMENT_PROVIDER=mock`.
- `docs/mobile-local-staging-plan.md` — staging plan documentation.

---

## Task C — Network context

### Staging backend binding

Per `docs/mobile-local-staging-execution.md`:
| Service | Host Address | Bound Interface |
|---------|-------------|-----------------|
| Staging backend | `127.0.0.1:18080` | Loopback only (not LAN) |
| Protected backend | `0.0.0.0:8081` | All interfaces (protected — untouched) |

The staging backend listens only on loopback (`127.0.0.1`), not on the LAN
interface.

### Flutter Web on the same host as staging

Flutter Web runs in Chrome on the host machine. From the browser's
perspective, `http://127.0.0.1:18080` refers to the host itself, so the
staging backend is reachable **if** CORS permits the Flutter Web dev-server
origin. From M2 retest results, staging `CORS_ALLOWED_ORIGINS` includes
`http://localhost:35597` (the Flutter Web dev-server origin observed in that
session). However, the Flutter Web dev-server port changes per session, so the
CORS origin must be re-added for each test session. This requires modifying the
backend's `.env.stage` (`CORS_ALLOWED_ORIGINS`) — which is out of scope for
this read-only preparation task and would require separate approval.

### Android emulator accessing a host-local backend

From an Android emulator, `127.0.0.1` refers to the emulator itself, not the
host. The host is reachable at `10.0.2.2` from the emulator. Therefore:
- `http://127.0.0.1:18080` would **not** work from an emulator.
- It would need `http://10.0.2.2:18080`, but the staging backend binds to
  `127.0.0.1` only (not LAN), so it would not accept emulator connections
  without re-binding the backend (out of scope).
- Android debug `network_security_config.xml` permits cleartext HTTP
  (`cleartextTrafficPermitted="true"`), so HTTP to the host would be allowed
  at the platform level if the backend were reachable.

### Physical Android device accessing a host-local backend

From a physical device, `127.0.0.1` refers to the device itself. The device
would need the host's LAN IP (e.g., `192.168.x.x:18080`). However:
- The staging backend binds to `127.0.0.1` only (not LAN), so a physical
  device cannot reach it without re-binding the backend (out of scope).
- Android release `network_security_config_release.xml` disallows cleartext
  (`cleartextTrafficPermitted="false"`), so HTTP would be refused on release
  builds regardless.

---

## Task D — Safe reversible test plan

### Can configuration be selected without changing `.env`?

**No.** For runtime (`flutter run`), there is no supported mechanism to
override `API_BASE_URL` without editing `.env`:
- No flavors
- No `--dart-define` support (replaced by `.env`)
- `main.dart` hardcodes `fileName: '.env'`
- `.env` is bundled as a build asset

The only runtime option is to temporarily modify `.env`, run the tests, then
restore it byte-identically.

### Recommended reversible test method

#### Preconditions

1. Staging backend is running and healthy on `127.0.0.1:18080` (verified via
   `GET /health` and `GET /health/ready`, both HTTP 200).
2. Staging uses `PAYMENT_PROVIDER=mock` (verified via backend `.env.stage`).
3. Flutter `.env` currently contains `API_BASE_URL` pointing at the protected
   backend (port 8081).
4. User approval has been obtained to temporarily modify `.env`.

#### Exact files that would be affected

| File | Action |
|------|--------|
| `payment_simulator/.env` | Temporarily overwritten with `API_BASE_URL=http://127.0.0.1:18080`, then restored from backup |
| `payment_simulator/.env.bak` | Temporary backup copy (created and deleted during the procedure) |

No other files are affected. No backend files, no `.env.stage`, no database,
no Docker resources.

#### Restoration procedure

1. **Before any change:** Record the byte-identical original `.env` (e.g.,
   `cp .env .env.bak` and/or compute `sha256sum .env`).
2. **Modify:** Write `API_BASE_URL=http://127.0.0.1:18080` to `.env`.
3. **Test:** Run Flutter runtime regression tests against staging
   (`flutter run -d chrome` for Web, or appropriate device target).
4. **Restore:** Copy `.env.bak` back to `.env` (or restore the recorded
   content).
5. **Verify restoration:** `diff .env .env.bak` must produce no output, or
   `sha256sum .env` must match the pre-change hash.
6. **Clean up:** Remove `.env.bak`.

#### Verification that protected port 8081 remains untouched

No requests are sent to port 8081 during this procedure. The `.env` change
only redirects the Flutter app to port 18080. After restoration, `.env`
returns to its original value pointing at port 8081 — but no actual
connection to port 8081 is made, so the protected backend is untouched
regardless.

#### Verification that staging continues to use the mock provider

The backend's `.env.stage` (`PAYMENT_PROVIDER=mock`) is not modified in any
step of this procedure. The staging backend continues to run with its
existing configuration.

#### Risks and limitations

| Risk | Description | Mitigation |
|------|-------------|------------|
| Forgetting to restore `.env` | App would remain pointed at staging after testing | Restore and verify byte-identical in steps 4–5; treat `.env.bak` as the source of truth until deletion |
| `.env` left in modified state if interrupted | Interruption between steps 2 and 4 leaves `.env` modified | Use a script that restores on exit (trap), or perform in a single session |
| Flutter Web CORS | Dev-server port changes per session; CORS origin must match | CORS origin (`http://localhost:<port>`) must be in backend `CORS_ALLOWED_ORIGINS`; this requires backend `.env.stage` modification (out of scope, separate approval) |
| Android emulator | `127.0.0.1` is the emulator, not host; staging binds to loopback only | Emulator cannot reach staging without backend re-binding (out of scope) |
| Physical Android device | `127.0.0.1` is the device; staging binds to loopback only; release disallows cleartext | Physical device cannot reach staging without backend re-binding and HTTPS (out of scope) |
| Release build | Cleartext disallowed in Android release network security config | Runtime testing against staging HTTP must use debug build only |

---

## Task E — Report

### Final status

**READY FOR APPROVAL**

The staging configuration plan is complete and documented. No configuration
changes have been made. User approval is required before any `.env`
modification.

### Can configuration be selected without changing `.env`?

**No.** For runtime (`flutter run`), there is no supported mechanism:
- No flavors, no `--dart-define` support, `main.dart` hardcodes
  `fileName: '.env'`. The only runtime option is to temporarily modify `.env`
  and restore it byte-identically.

### Recommended reversible test method

Temporarily modify Flutter `.env` to set
`API_BASE_URL=http://127.0.0.1:18080`, run Flutter runtime regression tests
against staging, then restore `.env` from a byte-identical backup and verify
restoration via `diff` or hash comparison. Full procedure documented in Task D
above.

### Android and Web networking limitations

**Android:**
- Emulator: `127.0.0.1` is the emulator itself; staging binds to `127.0.0.1`
  only (not LAN), so emulator cannot reach staging without backend re-binding.
- Physical device: same loopback limitation; release builds disallow cleartext
  HTTP.
- Debug builds permit cleartext, but reachability still requires the backend
  to listen on an interface the device can access.

**Flutter Web:**
- Reachable from Chrome on the same host via `http://127.0.0.1:18080`.
- CORS must allow the Flutter Web dev-server origin, which changes per
  session; requires backend `CORS_ALLOWED_ORIGINS` modification (separate
  approval, out of scope for this task).

### Required user approval before configuration changes

Approval is required to:
1. Temporarily modify Flutter `.env` to point `API_BASE_URL` at
   `http://127.0.0.1:18080` (staging).
2. (Optional, for Flutter Web runtime testing) Modify backend
   `CORS_ALLOWED_ORIGINS` to include the current Flutter Web dev-server
   origin.

No configuration changes are made without this approval.

---

## Acceptance criteria confirmation

| Criterion | Status |
|-----------|--------|
| No configuration changes | Confirmed — `.env` and `.env.stage` untouched |
| No backend or database changes | Confirmed |
| No payment operations | Confirmed |
| Existing changes preserved | Confirmed — all pre-existing modified/untracked files preserved |
| Documented, reversible staging test plan produced | Confirmed — this report |
| Report created | `docs/mobile-m3b1-staging-configuration-plan.md` |

No files other than this report were created or modified.