# Nightly verification — 2026-10-27 00:00 Asia/Shanghai

## Outcome

**Blocked before building. Zero XCTest cases executed. This is not a passing application or purchase test run.**

The scheduler fired at `2026-10-26T16:00:54.981Z`. The working tree was initially clean at commit `79a981180642d791165a0e04488fe7269370e783`. Current global instructions, root AGENTS.md, README, approved community design, and existing payment, gift and UI verification records were inspected. Historical results were not counted as current results.

The designated Toti UI Acceptance simulator (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, iPhone 17 Pro, iOS 26.0 runtime) was available and booted. A read-only process inspection found no active xcodebuild or XCTest process. Initial sandboxed simulator/process inspection was denied; approved read-only inspection then succeeded.

Automatic approval review rejected the requested `xcodebuild ... -scheme toti ... build-for-testing` before process creation. Its stated reason was that the earlier human request authorized changing the automation, but did not establish explicit authorization to execute a build now. No alternate build tool or indirect execution was attempted. No app was installed, launched or terminated; no user library or StoreKit history was changed. Explicit execution approval is required to resume the blocked runtime work.

## Completed static checks

- All seven configured consumable product IDs match TotiIdentity and the local StoreKit fixture. Diamond quantities and reference USD prices match WalletCatalog. This does not establish Apple catalog availability.
- All 416 asset-catalog source references point to existing files. This is a file-presence check, not an image-quality or rendered-layout verification.
- Shared schemes parse as XML. The local payment and purchase UI targets exist, alongside core and community UI targets.
- Test inventory: 23 core cases, 16 local StoreKit service/gift cases, one separate Apple catalog probe, five community UI cases, and five purchase/gift UI cases. These are source methods, not test results.
- Payment code statically separates purchasing, deferred and failed transactions from fulfillment, checks product/quantity/transaction identity, persists before publishing, and tracks credited transaction IDs. Runtime behavior was not verified this round.

Machine-readable evidence: [static inspection and test inventory](static-inspection.json), [tracked-source SHA-256 snapshot](source-sha256.json).

## Findings requiring follow-up

1. **Stale community UI assertions.** `TotiMusic/UITests/CommunityUITests.swift:93–94` expects `Diamond purchases are not available yet.` and a voice-only gift sentence. The current WalletController in `TotiMusic/Toti/Features/Community/CommunityControllers.swift:119–158` exposes `wallet.balance`, seven `wallet.package.*` controls, catalog status and copy describing local gifts on posts and in voice rooms. Those old strings are absent from current application sources. Update this smoke case to assert the current stable wallet controls and service wording, without depending on live Apple catalog availability; keep actual price/purchase assertions in the isolated StoreKit UI suite. This is a confirmed source mismatch, not an observed XCTest failure. No test-source change was made in this blocked run.
2. **Existing payment-service boundary.** StoreKit 1 fulfillment does not implement cryptographic receipt validation, server order confirmation, refund reconciliation or cross-device wallet recovery. Product mapping, quantity and durable ID checks alone do not establish those capabilities. This limitation is already documented in `docs/storekit1-integration.md`; it is not a newly observed production failure.
3. **Automation instructions had drifted from project rules.** Updated the existing automation to require the designated simulator, current-build installation/launch before tests, and latest-build launch after tests. Removed permission to substitute a simulator. Added the current payment schemes and aligned artifact locations with root `docs/nightly/` and flat `Assets/` filenames. Schedule, enabled state and associated chat were preserved. Authorization wording was not expanded to work around the approval rejection.

## Coverage ledger for this run

| Surface or state | Existing source coverage inspected | Current runtime result / outstanding work |
| --- | --- | --- |
| Entry, agreements, five tabs, profile, settings | Community UI setup and five-page case | Not run; wallet assertions need updating |
| Lounge compose, linked room, draft, post, like, save, reply, restart | Community UI and core workflow cases | Not run; photo UI, edit/delete, report/block and all secondary states remain unverified |
| Notebook editing, exit guard, pin, separate draft conversion, search clearing, restart | Community UI and Notebook core cases | Not run; complete template, duplicate/delete, boundary and error UI coverage remains outstanding |
| Voice genre, room entry, microphone, local message, no fabricated messages, creation | Community UI case | Not run; seats, drafts, invitations, permissions and other secondary flows remain unverified |
| Chats keyboard, local outbox, restart | Community UI case | Not run; groups, relationship limits, drafts, calls and permission branches remain unverified |
| Me, wallet and settings | Community smoke and purchase UI cases | Not run; full content management, credits, logout and isolated account deletion remain unverified |
| Seven consumables and prices | Static ID/amount/price mapping; service and UI case definitions | Static mapping matches; no transaction performed |
| Success, cancellation, failure, deferred approval, repeat purchase | Local StoreKit service/UI definitions | Not run |
| Save failure, unfinished delivery, duplicate callback, restart | Local StoreKit service definitions | Not run |
| Partial/empty catalog, timeout, retry, stale callback, session end | Controlled-fetcher service definitions | Not run; these definitions do not prove Apple network behavior |
| Gift debit, insufficient balance, invalid target, concurrency and purchase interleaving | Gift service/UI definitions | Not run |
| Large text and native purchase sheet | Purchase UI definitions | Not run; no new screenshots or visual inspection |
| Refund/revocation and server verification | Known implementation gaps | Unsupported/unverified; no service was fabricated |
| Subscription/non-consumable restoration | No configured products of those types | Not applicable |
| Additional screen sizes, iOS 16, permissions, background recovery and full accessibility | No execution this round | Unverified; do not substitute a different simulator against current rules |

## Resume requirements and artifacts

After explicit execution approval, reread current rules and confirm the designated device is free. Rebuild from the then-current working tree, install and launch that build on the designated device before each suite. Use serial destinations for `toti`, `totiUI`, `totiPayments` restricted to `StoreKit1PaymentTests`, and `totiPurchases`, preserving UUID-isolated libraries. Keep the Apple catalog probe separate from local StoreKit results. Correct the stale wallet smoke assertions and verify them at runtime. Archive first failures separately from targeted reruns and inspect page/state screenshots individually. Finish by ensuring the latest app build is running on the same device.

No xcresult bundle or current screenshot exists because execution never began. The reserved temporary output directory is `/private/tmp/toti-nightly-20261027-000054/`. This report intentionally does not invent build artifacts, test pass counts, screenshots, transactions or a final-launch claim.
