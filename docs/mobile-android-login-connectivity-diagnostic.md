# Mobile Login Connectivity Diagnostic

Date: 2026-10-19 (Asia/Jakarta)  
Scope: read-only source, artifact, and repository inspection; no network test was sent from the phone.

## Repository baseline and safety

| Item | Value |
| --- | --- |
| Branch / HEAD | `main` / `6a51c35a284f29a53cb463eb0b11785c7dddd436` |
| Pre-existing modified files | `docs/mobile-integration-test-results.md`; `test/payment_detail_test.dart` |
| Pre-existing untracked files | Existing M2/M3 reports, including M3B.1–M3B.3 reports |

All pre-existing changes were preserved. No source, test, backend, Docker, database, firewall, CORS, or service configuration was changed by this diagnostic. No authentication or payment request was sent.

At the start of this task, the prior interrupted M3B.4 workflow still had its approved temporary Flutter `.env` swap in place. It was restored from its already verified private backup before the audit; byte-for-byte SHA-256 verification succeeded and the temporary backup was removed. This was mandatory cleanup of the prior task, not a configuration change for this diagnostic.

## Confirmed facts

| Finding | Evidence |
| --- | --- |
| Flutter loads its API base URL from a bundled `.env` asset at startup. | `lib/main.dart:58-67`; `pubspec.yaml:64-73`; `lib/core/config/app_environment.dart:5-26` |
| There is no active `--dart-define` override path in Flutter source. | `lib/core/config/app_environment.dart:11-12`; `lib/main.dart:61-67` |
| Login is a relative `POST /api/v1/auth/login`; Dio resolves it against the `.env` API base URL. | `lib/features/auth/data/datasources/auth_remote_datasource.dart:49-54`; `lib/core/network/dio_api_client.dart:67-81` |
| Android Internet permission is present. | `android/app/src/main/AndroidManifest.xml:1-7`; merged debug/release manifests also contain it. |
| Debug/profile builds permit cleartext HTTP. | `android/app/src/main/res/xml/network_security_config.xml:5-18`; debug merged manifest uses that config. |
| Release builds block cleartext HTTP before credentials are sent. | `android/app/src/release/AndroidManifest.xml:3-8`; `android/app/src/release/res/xml/network_security_config_release.xml:5-19`; release merged manifest uses it. |
| Dio uses 30-second connect, send, and receive timeouts. | `lib/core/network/network_config.dart:8-15`; `lib/core/network/dio_api_client.dart:67-81` |
| Existing debug and release APK artifacts contain bundled `.env` assets. | `build/app/outputs/flutter-apk/app-debug.apk`; `build/app/outputs/flutter-apk/app-release.apk` |
| The existing debug APK's bundled `.env` is byte-identical to the restored repository `.env`; the release APK's bundled asset differs. | SHA-256 comparison performed without emitting environment-file contents. |
| Staging health and readiness on the development computer returned HTTP 200 before this audit. | Read-only checks of the approved staging health endpoints. |

## API base URL source used by Android

The app has one source of truth: the `.env` asset bundled into the APK at build time. `main()` loads that asset before constructing `DioApiClient`, and `AppEnvironment.apiBaseUrl` supplies Dio's `baseUrl`. It is not selected from the phone's network, Android manifest, or a runtime LAN-discovery mechanism.

The available debug APK is evidence of one exact bundled configuration: its `.env` asset matches the current restored repository `.env`. The available release APK is configured differently. This does **not** prove which artifact is installed on the phone; this audit did not query, pull, rebuild, or reinstall the device package. Therefore the exact value used by the installed phone build remains **unconfirmed** until the operator identifies its build variant/APK hash or supplies sanitized runtime evidence. No environment-file contents are included here.

## What “Cannot reach server” does and does not prove

The observed wording is consistent with the app's `ConnectionFailure` path. `DioExceptionType.connectionError` becomes `ConnectionNetworkException`, then becomes `ConnectionFailure` in the auth repository (`lib/core/network/dio_api_client.dart:383-416`; `lib/features/auth/data/repositories/auth_repository_impl.dart:20-27,85-94`).

This category can cover a socket-level failure such as unreachable route, connection refusal, or name/address connection failure. It does **not** prove which one occurred. It also does not prove invalid credentials: HTTP error envelopes are mapped as `ApiFailure`, while HTTP timeouts map separately to `TimeoutFailure` (`dio_api_client.dart:383-407`). Certificate verification has a distinct connection message. The login UI displays the mapped safe message and returns to the usable unauthenticated state (`lib/features/auth/presentation/bloc/auth_cubit.dart:50-61`; `lib/features/auth/presentation/pages/login_page.dart:63-69`).

No device logs were read because they can contain sensitive request or session material. Accordingly, the precise socket/DNS/timeout cause is not confirmed.

## Network interpretation

A physical phone's `127.0.0.1` is the phone itself, not the development computer. Pointing the phone at the development computer's loopback staging address therefore cannot reach the host service unless a separate device-port forwarding mechanism is deliberately configured.

Further, the isolated staging backend currently binds to loopback only. Even if a phone were given the computer's current LAN address, the backend would not be listening on that LAN interface. Thus a LAN URL alone cannot make this staging service reachable. This is intentional isolation behavior, not an application-login defect.

## Most likely causes (not confirmed)

1. **Most likely:** the installed build carries a stale or otherwise unreachable host API base URL. The historical LAN address must not be assumed to remain assigned to the development computer.
2. **Also likely if the app was built for staging:** a physical device cannot use host loopback directly; it would call itself instead.
3. **Also likely after substituting a host LAN address:** staging's loopback binding prevents inbound LAN connections.
4. **Possible for a release APK:** HTTP itself is blocked by the release network-security policy, independently of routing.
5. **Unknown:** Wi-Fi isolation, VPN, mobile-data routing, host firewall, or a timeout. No phone-side evidence was gathered to distinguish these.

The protected backend on port 8081 must not be exposed or used to resolve this staging-device test issue.

## Minimum safe remediation options (not implemented)

1. **Preferred for a USB-debuggable physical device:** in a separately approved debug-only test, bundle the isolated staging endpoint in a debug APK and use an ADB reverse port mapping from the phone's loopback port to the host's loopback staging port. This preserves staging's loopback-only isolation and does not expose the protected backend. It requires an authorized build/install and a temporary device-side forwarding action.
2. **Private LAN staging alternative:** in a separately approved staging-only change, bind only the isolated staging service to a dedicated private LAN interface/port and restrict access to the test phone/subnet; build a debug APK with that current host address. Do not bind or expose port 8081.
3. **Release-grade alternative:** provide an isolated HTTPS staging ingress with a valid certificate and use a release APK configured for that HTTPS origin. This is needed because release builds reject cleartext HTTP.

## Information needed from the operator

- Whether the installed app is debug, profile, or release, plus its version and APK hash/package provenance (no credentials).
- A sanitized exception category from the device (for example, timeout versus connection refused), with request headers, bodies, tokens, cookies, and credentials removed.
- Whether USB debugging/ADB reverse is permitted for the physical phone.
- The phone and development computer network relationship: same trusted Wi-Fi subnet, VPN state, and whether client isolation is enabled.
- Approval for one of the isolated staging options above, if physical-device testing is required.

## Final assessment

The connectivity failure is **not conclusively attributable to one cause** from the available evidence. The source and artifact inspection establishes that the APK bundles its API base URL and that Android policy differs by build variant. Physical-device access to a host-loopback-only staging backend is not possible without an approved forwarding or isolated-LAN/HTTPS solution.

