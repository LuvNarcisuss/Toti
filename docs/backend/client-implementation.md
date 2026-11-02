# Toti online client implementation

Current authentication update (2026-10-28): guest-sign-in.md supersedes the email OTP entry and SMTP prerequisites described in this earlier record.
Status: source integrated, dependencies resolved and current iOS Simulator application built successfully after explicit user authorization. Five isolated operation-journal tests passed. This does not verify authenticated cloud behavior; see runtime-verification.md.

## Identity and dependency evidence

The client uses the dedicated project `gjodhvpzkdnxdjmorjfw`, URL returned by the Supabase project URL tool, and its enabled modern publishable key returned by the publishable keys tool. No service key or other server credential is stored in the app.

`TotiMusic/project.yml` pins `Supabase` exactly to `2.55.5`. The official [release](https://github.com/supabase/supabase-swift/releases/tag/v2.55.5) was published on 2026-10-26. Its tagged Package.swift declares iOS 16 and swift-tools 6.1. Version-only inspection returned Xcode 26.0.1 (17A400) and Apple Swift compiler 6.2. The application keeps `SWIFT_VERSION: 5.0`; the SDK builds in its own declared language mode. Compilation succeeded with this toolchain and the iOS 26.0 Simulator SDK; iOS 16 runtime compatibility was not exercised.

Tagged sources inspected: `Sources/Supabase/{SupabaseClient,Types,Exports}.swift`, `Sources/Auth/{AuthClient,Types}.swift`, `Sources/Auth/Storage/{AuthLocalStorage,KeychainLocalStorage}.swift`, `Sources/Functions/{FunctionsClient,Types}.swift`, `Sources/PostgREST/PostgrestBuilder.swift` and the shared PostgrestError model. Initial tagged-source inspection did not invoke a compiler. The later authorized build resolved and compiled the SDK. The actual generated lockfile is retained at TotiMusic/Toti.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved, with a narrow Git ignore exception.

The official Supabase Auth and SDK documentation was consulted. The current TLS deprecation affects obsolete clients; the iOS 16 floor is retained. Anonymous Guest sign-in is the active authentication path, so SMTP and email OTP are not current dependencies.

## Boundaries

- `usesOnlineBackend = true` selects the intended product mode. `rolloutEnabled = true` enables the current Guest integration; production release remains blocked by the release checklist and must not cause local business fallback.
- A single MainActor service owns SDK/session state. A shared request gate serializes authentication and database requests. Authentication transitions increment a generation and clear visible account ownership before awaiting work. Every response is checked against its original generation.
- Initial SDK session events never authorize the UI. Restoration verifies the Auth identity and a server RPC's live-session/account checks before publishing `accountID`.
- Guest enrollment records the agreement version before exposing the account. An interrupted enrollment reuses the same Keychain-backed anonymous identity and protected operation payload instead of creating another Guest.
- Custom Keychain storage namespaces the session and uses `WhenUnlockedThisDeviceOnly`; secrets are absent from normal JSON, logs and backup files.
- A single actor owns account-scoped operation journals under `Application Support/TotiOnline/Operations/<account>/operations.json`. This path is independent of the legacy Toti library. Files use atomic writes, complete data protection and backup exclusion. Pending operation IDs, canonical payloads and payload digests are stored to allow exact recovery after termination; private message/Notebook content therefore remains in this account-protected, backup-excluded journal until acknowledgement.
- Recovery is explicit through `retryPendingOperations()`, behind the rollout gate and current account authentication. It serially replays original operation/action/entity/payload values, with generation checks before and after each request. Enrollment and account deletion are excluded, as are unknown future operation types. Each invocation processes at most 100 records; further pending records require another explicit invocation. Room-message retries include the destination room ID. Legacy digest-only journal records decode without data loss and can be hydrated by retrying identical original content; they are not fabricated or automatically discarded.
- Unknown mutation outcomes retain operation IDs. New-object actions match a pending action and payload even when a controller proposes a new UUID. PostgreSQL transaction rejections, including stale-version SQLSTATE `40001`, allow corrected resubmission. An acknowledged receipt is preserved before pending cleanup; failure to clean the local journal does not convert server success into failure.
- `page()` returns a server keyset cursor. `records()` allows at most four pages and throws if incomplete; it never presents a truncated collection as complete. Duplicate IDs are reconciled without trapping. Large screens must call `page()` and expose further pages.
- No Realtime subscription is created. The integration layer must perform bounded foreground authorization refreshes and clear revoked membership; no delivery/read/online status is inferred from polling.
- `accountDeletionEnabled = true` after the user explicitly authorized self-account deletion and the self-only `toti-delete-account` v1 deployment returned ACTIVE. The Guest integration gate is enabled; production release remains blocked. Automatic approval had initially rejected a broader deletion surface; no arbitrary-account operator HTTP path is shipped. The implementation invokes authenticated `toti-delete-account`. Pending cleanup closes visible access and signs out. Server-side recovery is required after session revocation; the client never claims pending cleanup is complete.
- RTC and purchases are explicitly disabled. No SDK wallet credit path exists.

## Pending acceptance

The local journal tests cover persistence across journal reinitialization, account/payload isolation and retry identity. The following end-to-end scenarios remain unexecuted: Keychain lock/unlock and relaunch, Guest enrollment restoration races, logout during queued reads and writes, two-account draft isolation, lost-acknowledgement replay, changed-payload rejection, disk-full retry persistence, long cursor pagination, revoked membership refresh, or interrupted account deletion. Run further authorized scenarios only after building/installing/launching current source on Toti UI Acceptance and configuring their external prerequisites.
