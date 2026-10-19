# M3B.5A Android Physical Device Staging Readiness

Date: 2026-10-19 (Asia/Jakarta)  
Decision: **READY AFTER DEVICE AUTHORIZATION**

## Scope and safety

This was a read-only readiness audit. No ADB reverse command, build, install, uninstall, app launch, authentication request, payment request, environment-file edit, service operation, or backend configuration change was performed.

## Working-tree baseline

| Item | Recorded state |
| --- | --- |
| Branch | `main` |
| HEAD | `6a51c35a284f29a53cb463eb0b11785c7dddd436` |
| Existing modified files | `docs/mobile-integration-test-results.md`; `test/payment_detail_test.dart` |
| Existing untracked files | Existing M2/M3 reports, including the Android connectivity diagnostic and M3B.1–M3B.3 reports |

All existing changes and untracked files were preserved.

## ADB availability and device status

| Check | Result |
| --- | --- |
| ADB installation | Available |
| ADB version | Android Debug Bridge 1.0.41; platform-tools version 37.0.1 |
| `adb devices -l` | Queried with identifiers redacted |
| Authorized/connected devices | 0 at audit time |

No device serial, transport ID, credential, or other unrelated identifier is recorded. A physical phone is therefore not currently available to ADB for implementation. This is a readiness blocker, not a project-code blocker.

## Android and Flutter configuration findings

| Finding | Evidence |
| --- | --- |
| Internet permission is declared. | `android/app/src/main/AndroidManifest.xml:1-7` |
| Debug/profile manifests retain development Internet access. | `android/app/src/debug/AndroidManifest.xml:1-7`; `android/app/src/profile/AndroidManifest.xml:1-7` |
| Debug network security allows cleartext HTTP with system trust anchors. | `android/app/src/main/res/xml/network_security_config.xml:5-18` |
| Release replaces that config with a cleartext-denying policy. | `android/app/src/release/AndroidManifest.xml:3-8`; `android/app/src/release/res/xml/network_security_config_release.xml:5-19` |
| The Gradle project defines normal debug/release build types only; no product flavors or staging build configuration exists. | `android/app/build.gradle.kts:17-38`; repository search found no `productFlavors` or `flavorDimensions`. |
| Flutter bundles `.env` as an asset. | `pubspec.yaml:64-73` |
| Startup loads `.env` before creating the shared API client. | `lib/main.dart:58-73` |
| The shared Dio client takes its base URL solely from `AppEnvironment.apiBaseUrl`. | `lib/core/config/app_environment.dart:5-26`; `lib/core/network/dio_api_client.dart:67-81` |

The comments in Android network-security XML referring to a dart define are stale documentation: current Flutter source explicitly identifies the bundled `.env` as the single source of truth. No environment-file contents were read or printed.

## Proposed debug-only staging configuration

The existing project has no flavor-specific asset selection. The safest supported procedure for a future, separately authorized implementation is therefore procedural and reversible:

1. Verify the isolated staging health/readiness endpoints on the development computer.
2. Make a private byte-for-byte backup of the Flutter `.env`, record its SHA-256, and confirm the backup hash.
3. Change only the API base URL line to the staging loopback address for a **debug-only** build/run.
4. Build/install/run only the debug variant, then restore `.env` immediately from the verified backup and confirm the original SHA-256.
5. Never create a release build while the temporary staging value is present.

This works because Flutter packages the asset into the debug artifact at build time. It is not an implementation action authorized by this audit.

A stronger long-term guard would be a deliberately designed debug-only staging flavor or separate debug asset, but that requires a separately scoped source/build-configuration change and is not needed to establish ADB reverse feasibility.

## Release-safety controls

- Release uses `network_security_config_release.xml`, where `cleartextTrafficPermitted="false"`; an HTTP staging URL would be rejected by Android before credentials are sent.
- The implementation procedure must additionally prohibit release build commands while the temporary staging `.env` is selected.
- No staging URL should be added to a release flavor, manifest, or permanent environment file.
- The protected backend on port 8081 is excluded from this plan entirely.

The Android release policy is an effective runtime safeguard against accidental HTTP use, though it is not a substitute for the build-procedure guard because a bundled value can still be packaged.

## Intended ADB reverse mapping

The proposed future command is:

```text
adb reverse tcp:18080 tcp:18080
```

It maps the device's local TCP port 18080 to the development computer's local TCP port 18080 through USB debugging. With a debug artifact configured to call device-loopback port 18080, the phone's request travels over ADB to the host's isolated staging listener at `127.0.0.1:18080`.

This preserves the staging backend's loopback-only binding and does not expose port 18080 to the LAN. It does not involve port 8081. The command was **not executed**.

## Non-mutating verification plan

After the future mapping and debug-only deployment are explicitly authorized, verify the transport path with safe endpoints only:

- `GET /health`
- `GET /health/ready`

The app's existing backend-connectivity path uses the health endpoint; success through that path would establish device → ADB reverse → host loopback → staging connectivity without an authentication or payment mutation. Only after that check succeeds should authorized login testing be separately considered.

## Preconditions and blockers

| Prerequisite | Status |
| --- | --- |
| ADB installed | Met |
| Phone physically connected by USB | Not met / unconfirmed at audit time |
| USB debugging enabled and authorization accepted | Not met / unconfirmed at audit time |
| Correct data-capable USB cable and host USB mode | Operator confirmation required |
| Isolated staging health/readiness | Previously confirmed; recheck before implementation |
| Explicit approval for temporary `.env` change, debug build/install, and ADB reverse | Required for implementation |
| Mock provider retained | Must be reconfirmed before implementation |
| No release command while temporary staging URL is selected | Required procedure control |

## Exact next-step recommendation

Connect the designated test phone by a data-capable USB cable, enable USB debugging, accept the host authorization prompt, and rerun the sanitized `adb devices -l` check until it reports one `device` state. Then obtain explicit approval for a bounded debug-only staging build/install and the single temporary ADB reverse mapping above. Do not use or expose the protected backend.

## Safety confirmation

No files were edited for this audit except this requested report. No device, ADB mapping, app installation, service, backend, Docker resource, database, firewall, CORS setting, or environment configuration was changed. No secrets were printed.

