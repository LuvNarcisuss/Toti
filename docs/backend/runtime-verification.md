## Current-state correction — 2026-10-30

The current source enables the Supabase anonymous Guest integration (`usesOnlineBackend=true`, `rolloutEnabled=true`). The dated evidence below was collected for earlier closed-rollout or limited-scope runs and must not be read as current full online acceptance. Text chat, Lounge, Notebook, relationships, reports, invitations, room membership and room text use real authenticated RPCs when a Guest session is active. RTC, server-verified purchases, Push, true delivery receipts, staffed moderation, and production readiness remain unverified or unavailable.

## Current-source acceptance attempt — 2026-10-30

The user authorized a fresh build, install, launch, and Guest/Lounge/Voice/Chat acceptance on **Toti UI Acceptance** (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`).

- `xcrun simctl list devices available` failed because `CoreSimulatorService` returned `Connection invalid` / `Connection refused`; no simulator install or launch was performed.
- The first `totiUI` build-for-testing attempt could not resolve GitHub SwiftPM hosts because `github.com` DNS was unavailable.
- A retry using the existing Toti SwiftPM cache progressed through dependency compilation but remained in remote-resource preparation. The pinned R2 origin could not be resolved, so the run was stopped before a successful build result.
- No current-source app was installed or launched, and no Guest, Lounge, Voice, or Chat UI test was counted as run. Existing older simulator artifacts were not substituted.

This is a blocked verification attempt, not a compiler or runtime pass. Re-run the same workflow after CoreSimulatorService and HTTPS/DNS access to GitHub and the pinned R2 origin are restored.

## Current-source acceptance — 2026-10-30 (completed)

After CoreSimulatorService and HTTPS/DNS access were restored, the current working tree was rebuilt and tested on **Toti UI Acceptance** (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`).

| Check | Result | Evidence |
| --- | --- | --- |
| Current `totiUI` signed Simulator build-for-testing | Passed | `/tmp/toti-current-build-final5.log`, `** TEST BUILD SUCCEEDED **` |
| Authorized disposable Guest login/relaunch/editorial/delete flow | **1 passed, 0 failed** | `/tmp/TotiCurrentGuestLive.xcresult` |
| Lounge, Notebook, Voice, and Chats UI suite | **5 passed, 0 failed** | `/tmp/TotiCurrentCommunity4.xcresult` |
| Latest app installed and relaunched after tests | Passed | PID `39477` on the required simulator |

The Guest test created and deleted one disposable anonymous account and confirmed the six-record editorial feed, illustrative artwork, cold-launch welcome, secure-session restoration, and self-account deletion. The five UI cases exercised Lounge post/reply persistence, Notebook conversion and pinning, Voice room text and creation, Chat keyboard/outbox behavior, and all five tabs/profile. The Community UI harness was updated to follow the current agreement checkbox → `Log in` flow; no product behavior was changed for that test-only correction.

The separate dual-Guest backend scenario is recorded in `social-online-acceptance-20261030.md`. It passed Lounge post/reply/like, Voice room membership/text, canonical direct Chat conversation/message, and self-cleanup. A post-test SQL read confirmed six published editorial rows, zero remaining social objects from the scenario, and only the pre-existing project account row.

# Toti backend migration: limited client acceptance

Current authentication verification: session-persistence-repair.md records the later unsigned-build Keychain failure, signed repair and actual live login/relaunch acceptance. Earlier build and UI-only evidence below is historical within its original scope.
Date: 2026-10-27. The user explicitly authorized dependency resolution, compilation, installation, launch and acceptance on Toti UI Acceptance. SMTP is not configured, so this session verifies only runnable client portions. Production release remains blocked; Guest integration is enabled in the current source.

## Environment and artifact

- Workspace: `/Users/apple/Desktop/Toti`, current working tree; no commit or push.
- Xcode 26.0.1 (17A400), Swift compiler 6.2, project Swift language 5 and iOS 16 deployment target.
- iPhone Simulator: **Toti UI Acceptance**, UUID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, iOS 26.0.
- DerivedData: `/tmp/TotiBackendAcceptance`.
- Latest app: `/tmp/TotiBackendAcceptance/Build/Products/Debug-iphonesimulator/toti.app`, bundle ID `com.toti.music`.
- Supabase Swift 2.55.5 resolved and compiled. Actual resolver output retained in `TotiMusic/Toti.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`; narrow ignore exceptions preserve this lockfile without admitting unrelated workspace state.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Current-source Simulator build | Passed | `/tmp/toti-backend-build-retry.log`, `BUILD SUCCEEDED` |
| Rebuild before UI acceptance | Passed | `/tmp/toti-backend-ui-prerequisite-build.log`, `BUILD SUCCEEDED` |
| OnlineOperationRecoveryTests | 5 passed, 0 failures | `/tmp/toti-backend-operation-tests.xcresult`, matching `.log`, `TEST SUCCEEDED` |
| OnlineReadinessUITests | 1 passed, 0 failures | `/tmp/toti-backend-readiness-tests.xcresult`, matching `.log`, `TEST SUCCEEDED` |
| Latest-source install and launch | Passed before tests and again after tests | final launch returned PID 17395 on the specified simulator |
| Preparation entry screenshot | Captured and visually inspected | `Assets/Verification/Backend/online-preparation.png` (ignored local evidence) |

Journal tests use disposable isolated directories and verify recovery after journal reinitialization, same-text/different-room identity separation, account-specific pending payload isolation, conflicting-edit payload preservation and a new operation identity for an intentional repeat after acknowledgement. They do not call Supabase or prove server idempotency.

The dated UI test launches the actual app with no local fixture and checks the earlier preparation entry. It does not represent the current Guest-enabled entry or authenticated business acceptance. The inspected screenshot shows the English cream/plum preparation entry. The test does not exercise authenticated tabs or follow agreement links.

## Executed command forms

Commands ran from the repository root with current AGENTS.md read before each build/test sequence. CoreSimulator required authorized access outside the filesystem sandbox. All simulator commands explicitly selected the required UUID.

```sh
xcodebuild -project TotiMusic/Toti.xcodeproj -scheme totiAppStore \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=98658066-C6E0-45B3-A1E7-E8FBD950F0DB' \
  -derivedDataPath /tmp/TotiBackendAcceptance CODE_SIGNING_ALLOWED=NO build

xcrun simctl install 98658066-C6E0-45B3-A1E7-E8FBD950F0DB \
  /tmp/TotiBackendAcceptance/Build/Products/Debug-iphonesimulator/toti.app
xcrun simctl launch 98658066-C6E0-45B3-A1E7-E8FBD950F0DB com.toti.music

xcodebuild -project TotiMusic/Toti.xcodeproj -scheme toti \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=98658066-C6E0-45B3-A1E7-E8FBD950F0DB' \
  -derivedDataPath /tmp/TotiBackendAcceptance -parallel-testing-enabled NO \
  -only-testing:totiTests/OnlineOperationRecoveryTests \
  -resultBundlePath /tmp/toti-backend-operation-tests.xcresult \
  CODE_SIGNING_ALLOWED=NO test

# Rebuild, install and launch above were repeated before this UI run.
xcodebuild -project TotiMusic/Toti.xcodeproj -scheme totiUI \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=98658066-C6E0-45B3-A1E7-E8FBD950F0DB' \
  -derivedDataPath /tmp/TotiBackendAcceptance -parallel-testing-enabled NO \
  -only-testing:totiUITests/OnlineReadinessUITests \
  -resultBundlePath /tmp/toti-backend-readiness-tests.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

The final install/launch was repeated after tests so the latest application remains running. Temporary logs/result bundles may be removed by system cleanup; the concise evidence is recorded here. Screenshots remain in the ignored local archive and were not uploaded.

## Build interruption and recovery

The initial build failed during HTTPS remote resource preparation with curl error 35 (TLS) for `Catalog-Portrait36.json`. Existing downloaded build caches were checked against the current RemoteAssets.json byte counts and SHA-256 values. Only matching entries were copied into the new DerivedData cache. The build phase subsequently reported all **419 verified remote resources** and succeeded. No source Assets fallback, manifest substitution or integrity bypass was introduced. A fresh machine still needs successful HTTPS access for its first download.

## Boundaries and remaining acceptance

- `usesOnlineBackend=true`, `rolloutEnabled=true`, `accountDeletionEnabled=true`, RTC and purchases disabled in the current source. The deletion endpoint was deployed earlier; no account deletion was executed.
- Email OTP and SMTP are historical and not required by the current Guest path. Guest business, RLS, retry, deletion, RTC, payment, and production acceptance still require the release checklist.
- No authenticated backend behavior, two-account authorization, server retry/concurrency, membership revocation, account deletion interruption, Keychain lock or disk-full behavior was tested.
- Existing historical local-feature suites were not rerun. The six selected checks do not establish full regression coverage, iOS 16 runtime behavior, real-device signing or production readiness.
- Media validation/publication, RTC, server-verified Apple purchases, push/delivery receipts and moderation operations remain unavailable as detailed in release-checklist.md.
- Review publisher/consent/agreement requirements and complete the release checklist before enabling online rollout.
