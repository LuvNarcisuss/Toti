# Toti online release checklist

## Current source state — 2026-10-30

- Guest authentication is the active online path. `usesOnlineBackend=true` and `rolloutEnabled=true` in the current source. This is an integration build, not production acceptance.
- New Guests start with empty personal posts, Notebook, wallet, authored rooms, and chat history. Read-only `From Toti / TOTI EDITORIAL` Lounge and Voice prompts may appear and are not member activity.
- Editorial expansion migration `009_editorial_content_expansion.sql` adds three more read-only Lounge prompts; it is deployed as `toti_editorial_content_expansion` and read back with six published records.
- Authenticated text chat, Lounge, Notebook, relationships, reports, invitations, room membership, and room text mutations use Supabase RPCs and protected retry journals.
- RTC audio/video calls remain unavailable: no provider, token/signaling service, room lifecycle, reconnect implementation, or acceptance evidence is configured. **RTC remains unavailable** until those dependencies are delivered. Call entry points open Bibi-style pages with local microphone/speaker state and video-only local camera preview; no remote media or microphone capture is started. The user explicitly selected this page-only scope and removed unavailable notices. See [call page presentation](call-page-presentation.md).
- Server-verified Apple purchases and Diamond gifts remain unavailable. StoreKit 1 code and local fixtures are historical/local-only behavior until receipt verification and account ownership are implemented.
- Push notifications, true delivered/read receipts, staffed moderation, and production media review remain unavailable.
- Current verification includes the dual-Guest social acceptance recorded below, Guest/session recovery, operation recovery, selected media privacy/recovery, editorial/entry UI, and historical local suites. It does not establish the full online matrix, RTC, Apple sandbox, production, or iOS 16 acceptance.
- Current real online social acceptance is now recorded in `docs/backend/social-online-acceptance-20261030.md`: dual-Guest Lounge post/reply/like, Voice room membership/text, Chat conversation/message, and self-cleanup all passed.

## Scoped Notebook and call acceptance — 2026-10-30

Current-source build/install/launch on Toti UI Acceptance completed. Fourteen model/recovery/live-backend tests and three final UI cases passed, covering the Notebook lifecycle, version conflict and two-account privacy, retained real friend/chat fixtures and unavailable voice/video call entry. This does not satisfy RTC media or the entire release matrix. The user explicitly requested retaining the two temporary accounts and final fixtures for manual testing; do not delete them before separate confirmation. See [exact scenarios, initial harness failures, retained IDs and uncovered scope](notebook-and-calls-acceptance-20261030.md).

## Private Chat attachment extension — 2026-10-30

Migration 011 and the user-authorized owner-only deletion function v2 are deployed. Generated photo and harmless file send/download, anonymous public-read denial and block revocation passed using the two retained test Guests. No account deletion or fixture cleanup was performed. The final right-side Add composer/picker/photo-view/file-export-entry UI case passed; actual selected-file/photo UI sending, device/provider matrices, orphan/quota handling, attachment lost-ack/process-kill recovery and destructive cleanup remain separately scoped. See [exact attachment evidence](chat-attachments.md).

## Remaining release dependencies

- Complete two-account RLS/session isolation, pagination, revoked-session, concurrent edit, retry, membership, invitation, deletion, disk-full, and Keychain-locked acceptance on **Toti UI Acceptance**.
- Select and configure an RTC provider, server token/signaling service, room lifecycle, permission UX, reconnect behavior, abuse controls, and device/simulator acceptance before enabling calls. See `docs/backend/rtc-evaluation.md`.
- Implement server-verified StoreKit ownership, idempotent credits, refunds, account synchronization, and Apple sandbox/production acceptance before enabling purchases or gifts.
- Complete operator media review, moderation workflow, publisher identity, legal/consent/age requirements, Push delivery, and final production monitoring.

## Dated deployment and historical evidence

Community room materials (2026-10-30): migration `20261030070809` publishes six Supabase-hosted room material records, six distinct cover assets and eighteen distinct illustrative portraits. No Auth accounts, actual room objects, member relationships or message history were created. Reader grants and RLS were read back; app build and UI acceptance remain unexecuted by user request. See `official-community-rooms.md`.

Current media update (2026-10-28): migrations 007/008 and both authenticated media functions are deployed. Real generated-image acceptance covers pending isolation, actual review, public reads, remote UIKit avatar rendering, replacement rejection, block denial and self-cleanup. The 11 scoped storage/recovery tests also pass. Original resources return as official editorial content. See media-acceptance.md for current scope and untested scenarios. The older unavailable-media and SMTP requirements below are historical and superseded; guest login has no SMTP dependency. Normal images require an actual reviewer, and the pilot is not production acceptance.

Build delivery update (2026-10-30): all 549 original resources are published under `toti-build-assets/ci-upload-20261030-guest5430/`. Anonymous readback verified every original hash and byte count; two large source videos use four parts. The bucket contains 551 objects totaling 297,084,652 bytes. All three resource manifests now use Supabase, and the temporary write policy, guest sessions and guest Auth record were removed. Codemagic pins Xcode 26.5 and publishes through the App Store Connect integration. Preparation succeeded for 419 runtime resources; this is not a new iOS build or publishing acceptance. See `docs/codemagic-supabase-assets.md`.

Update on 2026-10-28: user-requested guest sign-in supersedes email OTP and its SMTP prerequisites. The anonymous provider, actor validator and client guest entry are enabled for integration. This is not production acceptance. Authorized live guest Auth/enrollment, private-note isolation/retry, refresh and self-cleanup now pass. Migration 006 fixes the read cursor alias ambiguity found during testing. See guest-sign-in.md for exact scope and remaining tests; the initial closed-gate checklist below is retained as the earlier deployment record.

Status on 2026-10-27: cloud infrastructure deployed and client source integrated; that dated rollout record is historical. The current source Guest integration is enabled, while production release remains blocked. This is not a completed online release. The current source builds, and six limited client tests pass on Toti UI Acceptance. Authenticated cloud acceptance remains outstanding.

## Confirmed implementation and deployment

- [x] User selected the dedicated Toti project in the existing organization, Singapore, with the returned USD 0/month project quote.
- [x] User selected email OTP and initial online profiles, Lounge, private Notebook, relationships, reports, text chats/groups and room state. RTC and payments are separate dependencies.
- [x] Project `gjodhvpzkdnxdjmorjfw` returned ACTIVE_HEALTHY.
- [x] Migrations `20261027060430`, `20261027060443`, `20261027061120`, `20261027061848` were deployed and read back. Ordered source is under `TotiMusic/Backend/sql/`.
- [x] Editorial expansion migration `20261030020728` (`toti_editorial_content_expansion`) was deployed and read back; it adds no Auth identities or member activity.
- [x] `toti-delete-account` v1 ACTIVE; gateway JWT verification plus verified caller identity, no client-selected deletion account. The user explicitly authorized self-account cloud deletion after the first automatic-review rejection. An overly broad operator HTTP path was removed before successful deployment.
- [x] Metadata inspection found all eight private tables with RLS and no direct anonymous/authenticated table grants. Private Storage has no client upload policy. Advisors returned informational default-deny RLS and unused-index findings, documented in the cloud record.
- [x] UIKit adapters use server ownership, transaction receipts, individual paging and current session checks. Related personal state travels with visible records; the signed-in profile is fetched by exact ID.
- [x] The original library is retained without migration, cleanup, reset or automatic upload. Text-only per-item copying requires a signed-in user's explicit consent; copied posts remain private drafts.
- [x] Mutation journals retain protected account-specific payloads and IDs for explicit pending-request recovery. Account deletion/enrollment cannot be replayed by the generic recovery button. New edits carry optimistic server versions.
- [x] Static review fixes cover generation-bound editors, missing Swift returns, scoped related profiles, transactionally cleared message drafts, pending-operation recovery and serialized read/write projection.
- [x] `xcodegen generate --spec TotiMusic/project.yml` succeeded after source integration. This generated project metadata only.
- [x] `plutil -lint TotiMusic/Toti.xcodeproj/project.pbxproj TotiMusic/Toti/Support/Info.plist` returned OK for both files; `git diff --check` reported no whitespace errors. These are not compiler/type checks.

## Required before enabling online rollout

- [x] Email OTP/SMTP is no longer a dependency for the current Guest path; retain the old SMTP items below only as historical OTP evidence. Never put SMTP credentials in chat, app configuration, Git or documentation.
- [ ] Historical OTP template evidence is not part of the current Guest release path; do not enable it as a substitute for Guest acceptance.
- [ ] Confirm publisher identity/contact, applicable consent/age policy and final online Terms/Privacy content. The bundled agreement hash is recorded at enrollment; the existing hash does not prove final publication/legal approval.
- [x] Explicit user authorization received for current-source compilation, dependency resolution and specified-simulator acceptance. The actual generated Package.resolved is retained.
- [x] Build the latest current tree, install and launch it on **Toti UI Acceptance**. Five isolated journal tests and one closed-entry UI test passed on that same simulator; the latest build was installed and launched again after testing. See runtime-verification.md.
- [ ] Run authenticated Guest backend and business UI scenarios after current-source build/install/launch prerequisites are ready. No substitution with another device or older binary.
- [ ] Exercise two-account RLS/session isolation, revoked/deleted accounts, cursor pagination beyond the first page, exact current-profile reads and per-post personal states.
- [ ] Exercise saved posts/replies/notes, concurrent edit conflicts, failed and lost acknowledgements, process termination and explicit pending-request recovery, duplicate sends and changed-payload rejection.
- [ ] Exercise follow/block in both directions; first-contact concurrency; group rollback, invitations without history access, acceptance watermark, removal/leave/reconnect; verify old content cannot leak through retained controllers.
- [ ] Exercise room membership/capacity/text messages, closure and membership loss. Audio and microphone indicators must remain unavailable.
- [ ] Exercise explicit self-account deletion, interruption and trusted dashboard cleanup reconciliation. Owned post/room/group containers and associated replies/messages are removed along with the account; unrelated users' identities, independent notes/content and local archives must remain.
- [ ] Exercise disk-full/Keychain-locked states and confirm no acknowledged server operation is represented as a wholly failed write.
- [ ] Verify foreground polling and explicit history navigation. Active thread history uses a bounded page window that is reread through current authorization; Refresh returns to recent messages. It is not realtime delivery or presence.
- [ ] Record actual acceptance results and only then change `rolloutEnabled` through a reviewed release change.

## Unavailable modules and independent later work

- Photo/avatar uploads: private bucket and revision schema exist, but byte-validation, moderation worker/operator review, approved media attachment and rendering are not implemented. Pickers and image-bearing imports are explicitly unavailable; no image is silently uploaded, stripped or approved.
- RTC: no service/provider is configured. Existing room records and text are not real audio/video calls.
- StoreKit wallet/gifts: product IDs stay unchanged, but the online path never starts local-credit purchasing. Apple server verification, environment separation, idempotent credits, refunds and sandbox/production acceptance are still required.
- Push notifications and true delivered/read receipts are not implemented. Polling re-reads authorized data only.
- Reports have durable received status but no staffed moderation claim. Private cleanup jobs require a trusted dashboard process if session revocation interrupts deletion.
- The application-scoped transaction lock is a deliberate pilot throughput limit. Capacity/concurrency work is required before larger traffic.

## Evidence classification

Source-written: yes. Cloud deployed: yes for the five named migrations including editorial expansion and the deletion function. Migration 009 was deployed and read back with six editorial rows. Metadata/static inspection: yes. Dependency-resolved: yes, actual lockfile retained. This turn did not build or launch the modified source. Limited client runtime: historical 5 journal tests and 1 preparation-entry UI test passed. Guest/authenticated business/RLS behavioral testing: limited; full release matrix remains outstanding. Apple Sandbox: no. Production verified: no.

## Profile relationships — 2026-11-02

Current-source build/install/launch and scoped acceptance on Toti UI Acceptance passed: four storage/online relationship tests, three final UI cases and final baseline restoration. Real mutual-follow gating, editorial follow/block preferences and block/unblock UI were covered. A Chats data-source bounds crash on returning from a blocked member profile was reproduced, fixed with a reload snapshot and passed on retest. Existing accounts/data/attachments are retained and original reciprocal follows restored. See [results and remaining scope](profile-relationship-acceptance-20261102.md). This does not complete the release checklist, global messaging authorization matrix, RTC or device-version coverage.

## Profile received Likes/Saves and safety entry — 2026-11-02

Migration `toti_profile_received_saves` (`20261102025816`) extends private profile metadata with real received saves. Existing avatar-review, relationship and execution boundaries are preserved. Current-source builds/install/launch and 3 metric/caption model tests plus one read-only Me/member/editorial UI case passed. Report profile was opened and closed without submission; no live positive reaction-count mutation or report submission was tested. See [parity checklist and evidence](../profile-bibi-parity.md). Retained accounts, content and reciprocal follows remain intact.

## Post detail integration — 2026-11-02

Editorial post publishing remains operator-owned; Guest reactions, bookmarks and comments now use real authenticated server state. Private report/request records have no client table grants and cascade with the actor account. Full detail, saved routes and chat forwarding are documented in [post detail parity](../post-detail-bibi-parity.md). Report intake does not establish staffed moderation, and shared internal references do not establish a public website/universal-link service. Current tests retain isolated acceptance fixtures for manual checking.
