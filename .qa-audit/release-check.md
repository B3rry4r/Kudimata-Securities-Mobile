# Phase 5 — Release-artifact check

Auditor pass only. No files under `lib/`, `test/`, or `android/` were modified.
Build tooling (Android SDK, Gradle cache, `gradle.properties` overrides) was installed
entirely outside the repo, under `/var/tmp/kudimata-audit/`. The only repo-adjacent
file touched was `android/local.properties`, which is git-ignored
(`android/.gitignore:6: /local.properties`) and untracked before and after — it is
machine-local SDK-path plumbing, not a source or config change, and was necessary to
run the real `flutter build apk --release` this phase exists to perform.

## 1. Variant-diff table (Android manifests)

Source read: `android/app/src/main/AndroidManifest.xml`,
`android/app/src/debug/AndroidManifest.xml`, `android/app/src/profile/AndroidManifest.xml`.
Debug/profile manifests are merge fragments over `main`, not standalone manifests —
only entries they *add* are listed; everything in `main` applies to all three variants
unless overridden.

| Capability | debug | profile | release (main) | Verdict |
|---|---|---|---|---|
| `INTERNET` | declared (dev-tooling comment) | declared (dev-tooling comment) | **declared**, with an explanatory comment recording the exact prior incident ("Flutter's template declares INTERNET only in the debug and profile manifests... a RELEASE build without this line is denied every socket") | PASS — fixed in `main`, confirmed present in all three source manifests. Verified in the packaged artifact too (§4). |
| `CAMERA` | inherited from main | inherited from main | declared (kyc-liveness live preview, `camera` plugin) | PASS — present on the variant that matters |
| `allowBackup` / `fullBackupContent` | inherited from main (`false`/`false`) | inherited from main | `false` / `false`, with a detailed comment tracing this to a live bug (backup-restored passcode/token state bypassing on-device passcode creation) | PASS — explicit `false` in the base manifest that all variants inherit; no variant re-enables backup |
| `queries` (PROCESS_TEXT, VIEW https/mailto/tel) | inherited | inherited | declared, needed by `url_launcher` (legal doc download, help/support email & call rows) | PASS |
| Any debug/profile-only capability absent from main | — | — | — | **None found.** Debug and profile manifests contain *only* the redundant `INTERNET` line (harmless duplicate, already in main) and add nothing else. There is no capability declared in debug/profile and missing from release. |

**Verdict: PASS.** The specific defect this phase exists to catch — a permission
present in debug/profile and silently absent from release — is not present today.
Git blame (`git log -- android/app/src/*/AndroidManifest.xml`) shows this was an
actual incident, fixed in commit `27b9fc1` ("Release APKs had no INTERNET permission
and could not reach the backend"), with the current `main` manifest carrying an
explicit comment documenting the failure mode so it isn't reintroduced silently.

### Minor finding (not the INTERNET-class bug, but release-only behavior)

`CAMERA` being declared with no `android:required="false"` on the implied
`android.hardware.camera` feature means the **Play Store will filter out any device
without a camera from even seeing this app's release listing** (confirmed in the
packaged artifact, §4: `uses-implied-feature: name='android.hardware.camera'
reason='requested android.permission.CAMERA permission'`, with no
`required="false"` override). Camera is used only for the KYC liveness/document
flow, not core app usage — a debug/sideloaded install never surfaces this because
Play Store feature filtering only applies to store distribution, not `adb install`.
Whether this is intended (require a camera to invest at all) or should be
`android:required="false"` with a graceful in-app fallback is a product call, not
an auditor call — flagging it because it is exactly the kind of release-only,
store-distribution-only behavior that debug/web testing structurally cannot see.

## 2. Plugin-vs-declaration table

Cross-checked `pubspec.yaml` against the Android release manifest (source and
packaged, §4) and `ios/Runner/Info.plist`.

| Plugin | Permission/capability needed | Android release manifest | iOS `Info.plist` usage-description | Verdict |
|---|---|---|---|---|
| `camera: ^0.11.2` | `CAMERA` (+ implied `RECORD_AUDIO` from CameraX's video-capable session) | `CAMERA` declared explicitly; `RECORD_AUDIO` present in **packaged** APK (auto-merged from the `camera_android_camerax` plugin's own manifest, not source-declared — confirmed via `aapt dump badging`) | `NSCameraUsageDescription` present ("...capture documents and liveness photos for KYC verification"); `NSMicrophoneUsageDescription` present, with a comment clarifying no audio is actually recorded — required only because the camera library links mic APIs | PASS on both platforms |
| `file_picker: ^8.1.2` | `READ_EXTERNAL_STORAGE` (API ≤32), scoped storage on 33+ (no manifest permission needed there) | `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=28`) present in **packaged** APK, auto-merged from the plugin's own manifest — not source-declared in `android/app/src/main/AndroidManifest.xml` | No plist key needed (file_picker's iOS path uses `UIDocumentPickerViewController`, no usage-description key required by Apple) | PASS |
| `local_auth: ^3.0.2` | `USE_BIOMETRIC` (Android); Face ID entitlement (iOS) | `USE_BIOMETRIC` + `USE_FINGERPRINT` present in **packaged** APK, auto-merged from `local_auth_android`'s own manifest (verified by reading that plugin's manifest directly in the pub cache: it declares `USE_BIOMETRIC` unconditionally) — not source-declared in the app's own manifest, and doesn't need to be | `NSFaceIDUsageDescription` present ("Kudimata uses Face ID to unlock your investment account on this device.") | PASS |
| `flutter_secure_storage: ^9.2.2` | No manifest permission (uses Android Keystore / iOS Keychain directly) | N/A | N/A | PASS — no declaration required |
| `url_launcher: ^6.3.2` | `<queries>` entries for `https`/`mailto`/`tel` (Android 11+ package visibility) | All three declared in main manifest, inherited by release | N/A (no usage-description needed) | PASS |
| `share_plus: ^12.0.2` | None (OS share sheet, no special permission) | N/A | N/A | PASS |
| `socket_io_client: ^3.1.2` | Needs `INTERNET` (same socket as REST) | `INTERNET` declared, confirmed in packaged APK | N/A | PASS — this is exactly the permission the whole phase exists to check, and it is present |
| `dio` / `http` | Needs `INTERNET` | Same as above | N/A | PASS |
| `permission_handler` | **Not a dependency** — not in `pubspec.yaml` | — | — | N/A, not used |
| Any geolocation plugin (`geolocator` etc.) | — | — | — | **Not a dependency.** `NSLocationWhenInUseUsageDescription` is present in `Info.plist` ("...verify regional compliance and security requirements") but `grep -r "geolocator"` across `pubspec.yaml`/`pubspec.lock`/`lib/` finds nothing, and no runtime location-permission call exists in `lib/`. This is a plist key with **no corresponding code path** — the opposite risk direction (an unused declaration, not a missing one) but worth recording since it means either a planned feature never got wired, or a stale key that should be removed. Not the class of bug this phase targets, so not scored as a failure. |

**No plugin's permission or iOS usage-description is missing on the release
manifest or on either platform.** Every plugin that needs a declared capability has
it, on the variant that ships.

## 3. Signing and minification

Read: `android/app/build.gradle.kts`.

- **Signing config:** `signingConfigs.create("release")` reads `key.properties`
  (git-ignored, present in this checkout: `android/key.properties`,
  `android/app/upload-keystore.jks`, both correctly excluded from git by
  `android/.gitignore` and root `.gitignore`). The `release` buildType conditionally
  selects `signingConfigs.getByName("release")` when `key.properties` is present,
  falling back to **debug** signing only when it's absent — i.e., on a contributor
  machine without the keystore, `flutter run --release` silently debug-signs. That
  fallback is intentional per the comment and does not affect what CI/release
  actually ships, **but it does mean a local `flutter build apk --release` run by
  someone without the keystore produces a debug-signed artifact with no warning**,
  which could be mistaken for a real release build. Verified in the packaged
  artifact (§4) that *this* build used the real release key, not the fallback.
- **Minification (R8):** `build.gradle.kts`'s `release` block sets **only**
  `signingConfig` — no explicit `minifyEnabled`/`isMinifyEnabled` line. Despite
  that, the actual build **did run R8**: `build/app/outputs/mapping/release/mapping.txt`
  was generated (202,887 lines, real class/method renaming, not an empty stub),
  meaning Flutter's Gradle plugin is defaulting release to minified+shrunk in this
  Flutter/AGP version even though the project's own `build.gradle.kts` never asks
  for it explicitly. Debug and profile builds get no such default — this is a real,
  undocumented-in-source behavior difference between the release artifact and
  everything the 29 tests / 188 screenshots / gates exercise.
- **ProGuard/keep rules:** No `android/app/proguard-rules.pro` exists anywhere in
  the project, and `build.gradle.kts` has no `proguardFiles`/
  `getDefaultProguardFile` call. R8 is running with **zero project-level keep
  rules** — entirely dependent on each AAR's bundled `consumer-rules.pro`
  (`camera`, `local_auth_android`, `flutter_secure_storage`,
  `socket_io_client`/its underlying `engine.io`/OkHttp stack, `file_picker`).
  Reputable, actively maintained plugins normally ship correct consumer rules, and
  this project's data layer does manual JSON parsing rather than
  reflection-based (`json_serializable`/`build_runner`) decoding on the **Dart**
  side — R8 cannot touch Dart AOT code at all, only the Java/Kotlin plugin glue —
  so the classic "ProGuard stripped my model class" failure mode has a much
  smaller surface here than in a typical Android app. That said, a clean R8 build
  is not proof of correct runtime behavior for the Java/Kotlin side (reflection
  breaks at run time, not compile time). **Not independently verified beyond
  build-time success** — see §4 for exactly what was and wasn't confirmed.

## 4. Packaged-artifact result

**RUN — succeeded**, after provisioning a full Android SDK (this environment ships
with none). Everything below is what was verified in the actual built `.apk`, not
read from source.

- Command: `flutter build apk --release` (from a clean `flutter pub get`).
- Environment note: the sandbox has no Android SDK and a container CPU/pid/memory
  cgroup tight enough that the default Gradle+Kotlin-daemon build OOM'd on the
  first two attempts (`pthread_create failed (EAGAIN)`, then a `jlink` spawn
  failure) purely from thread/process pressure — unrelated to this project. Fixed
  by pointing `GRADLE_USER_HOME` at a `gradle.properties` (outside the repo) with
  `org.gradle.daemon=false`, `org.gradle.parallel=false`,
  `org.gradle.workers.max=1`, and a capped heap. Recorded for whoever runs this
  again: a from-scratch release build in a constrained container needs those flags
  or it will misreport as a Kotlin-compiler crash rather than a resource limit.
- Result: **`build/app/outputs/flutter-apk/app-release.apk`, 62.7 MB**, built in
  ~2m30s.
- **Packaged manifest permissions** (`aapt dump badging`/`permissions` against the
  actual `.apk`, not the source XML):
  ```
  uses-permission: android.permission.CAMERA
  uses-permission: android.permission.INTERNET        <-- the one this phase exists to check
  uses-permission: android.permission.RECORD_AUDIO
  uses-permission: android.permission.WRITE_EXTERNAL_STORAGE (maxSdkVersion=28)
  uses-permission: android.permission.READ_EXTERNAL_STORAGE
  uses-permission: android.permission.USE_BIOMETRIC
  uses-permission: android.permission.USE_FINGERPRINT
  uses-permission: com.kudi.kudimata.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
  ```
  **`INTERNET` is present in the shipped artifact.** This is the artifact-level
  confirmation the source-file read in §1 cannot provide by itself — the source
  manifest could in principle diverge from what Gradle actually packages (merge
  bugs, flavor overrides, stale build cache); it did not.
- **Signing verified against the actual artifact:** `apksigner verify --print-certs`
  on the built APK gives certificate SHA-256
  `0655479cac8585cd58e65bd08a3886e670ef357e00bdc47bf4220c48d3e809bf`, which is
  byte-for-byte the same fingerprint as `keytool -list -v` on
  `android/app/upload-keystore.jks`. **This build used the real release key, not
  the debug-signing fallback.**
- **Not verified** (would require installing the artifact on a device/emulator,
  which this environment cannot do — no emulator, no Android SDK licenses for a
  system image, no physical device attached):
  - Whether `local_auth`'s biometric prompt, `camera`'s live preview, or
    `flutter_secure_storage`'s Keystore read/write actually work at runtime
    against the R8-shrunk release code (build-time success proves R8 didn't fail
    to *finish*, not that it didn't strip something a reflective call needs).
  - Whether the app can actually reach the real backend from a real release
    install (that's the live-gate's job, and the live gate — per this project's
    own CLAUDE.md — runs in debug/web, so it still would not catch a
    release-only regression; this phase's manifest+signing checks are the
    closest available substitute without a device).
  Recorded as **NOT RUN — no Android device or emulator available in this
  environment**, not silently omitted.

## Web

`web/index.html` has no `<meta http-equiv="Content-Security-Policy">` tag and no
other CSP/host-allowlist mechanism in the repo. There is nothing in the web build
that would block the API origin. PASS by absence of restriction — noted as a
first-class check rather than skipped.

## iOS

No Mac/Xcode toolchain is available in this Linux container, so `ios/Runner/Info.plist`
was checked by source read and cross-reference against `lib/`/`pubspec.yaml` only
(§2) — **NOT RUN: iOS build/archive, no macOS available in this environment.**
Every plugin that needs an `NS*UsageDescription` key on iOS has one; none are
missing on that platform.
