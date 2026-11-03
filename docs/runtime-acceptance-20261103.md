# Current-source runtime acceptance — November 3, 2026

## Environment and authorization

The user authorized runtime testing after the post and Voice safety changes. The existing retained Guest accounts and data remain protected. This run does not authorize account deletion, real charges, or submission of moderation reports against real people.

- Xcode 26.0.1 (17A400), Debug, simulator ad-hoc signing.
- Toti UI Acceptance, iPhone 17 Pro, iOS 26.0.
- Device UUID: `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`.
- Current working-tree builds: `toti`, `totiUI`, `totiPayments`, and `totiPurchases`.
- DerivedData: `/private/tmp/TotiProfileAcceptance1102`.
- Current application installed and launched before runtime testing; no unsigned or historical app substituted.
- Retained Guest namespace: `26F9BA6F-44AC-4A36-9B37-DF739B215A3C`. Live UI plans enable `TOTI_LIVE_GUEST_ACCEPTANCE=1`. Local purchase tests use separate UUID-scoped wallets, leaving the manual wallet separate.

## Results

All 41 selected distinct cases have passing results after the isolated chat rerun. Across 42 executions there were 41 passes and one initial failure; the initial failure is retained below rather than counted as a clean first-pass run. No cases were skipped.

| Scope | Result | Evidence bundle in `/private/tmp/` |
| --- | --- | --- |
| Notebook model/storage and editorial preferences | 11 passed, 0 failed | `toti-runtime-1103-storage.xcresult` |
| Local StoreKit payment and gift services | 22 passed, 0 failed | `toti-runtime-1103-payments.xcresult` |
| Post/room safety, portraits, call controls, chat attachments | Initial run: 5 passed, 1 failed | `toti-runtime-1103-ui.xcresult` |
| Isolated rerun of the chat attachment case | 1 passed, 0 failed | `toti-runtime-1103-chat-rerun.xcresult` |
| Nine-package purchase UI and local Voice gift UI | 2 passed, 0 failed | `toti-runtime-1103-purchase-ui.xcresult` |

### Storage and payment services

Notebook checks cover edit identity, duplication, search/category/mood, Unicode limits, round trips, invalid-save preservation, and conversion without changing the original note. Preference checks cover account separation, legacy room-safety decoding, persistence, corrupt-file protection, and rejected oversized drafts. These are local model/storage checks, not new online Notebook CRUD acceptance.

The 22 payment cases cover exact nine-tier credits, repeat consumables, cancellation, failure, deferred approval, transaction deduplication, local history-reset collisions, failed-save recovery, owner isolation, product request failures/timeouts, concurrent debits/credits, insufficient funds, invalid recipients, and gift recipient metadata. They use local StoreKit Test; Apple catalog availability tests were excluded.

### Purchase and gift UI

The nine-tier UI case passed in 110.762 seconds. All nine prices and quantities matched, the total reached 172,200 test diamonds, confirmation cancellation and simulated StoreKit cancellation preserved the balance, and relaunch retained nine activity records and the same balance.

The Voice gift UI case passed in 96.610 seconds. It bought 400 local test diamonds, checked the medium sheet begins below 40% of screen height, selected Avery, canceled without spending, sent one Rose for 10 diamonds, then five Roses for 50 diamonds. Each successful spend dismissed the sheet. The unaffordable Galaxy left 340 unchanged; relaunch retained 340 and three activity records. Inspected screenshots show the room above the picker and the Rose effect over the room after dismissal.

### Safety and navigation UI

- Member-post detail: visible Report post / Block author, cancellation, and matching Post options actions. This case uses an isolated local test library and does not submit a live report or change real member relationships.
- Editorial-post detail: report form opens without submission; cancel block, confirm block, hide the post, unblock through Settings > Blocked, and restore visibility. Existing follow preference is restored when applicable.
- Material-room information: Block room / Report room, hide/unblock, local report/save/remove, and restored discovery visibility. These reports are explicitly device-local preferences; no server moderation submission occurs.
- Voice portraits: three distinct music photographs open their corresponding author profiles with matching portrait identifiers.
- Calls: voice/video pages, local microphone/speaker/camera controls, and dismissal. No remote call is placed and RTC remains unconnected.
- Chat rerun: input occupies over half the screen width; Send precedes Add attachment; photo/file selection opens and cancels; an existing private photo opens; an existing file reaches the native Files save entry. No new attachment was uploaded or exported to a chosen destination.

### Initial chat failure and diagnostic limit

The initial chat case failed at `OnlineReadinessUITests.swift:361` because Add attachment was disabled. Its screenshot and accessibility hierarchy show an empty message list and **This conversation is no longer accessible. Refresh Chats to continue.** Both input and send were disabled as well. XCTest logged an unusually long animation-idle wait before the assertion.

The source intentionally disables composition when the authorized conversation projection is absent. Failed online reads can clear that projection. This explains the visible state but does not establish the original network/session cause. The retained conversation subsequently opened successfully, and the same unmodified test passed in 85.018 seconds on a separate run. No application or test source was changed to force a pass. The initial failure remains recorded; this is not proof that intermittent online-read failures have been eliminated.

## Evidence and boundaries

Logs, selected screenshots, and the initial failure screenshot are archived under ignored `Assets/Verification/Runtime20261103/`. The `.xcresult` bundles remain at the paths listed above. Build logs use `/private/tmp/toti-runtime-1103-*.log`.

This is scoped simulator regression, not a whole-application or production launch certification. It does not verify Apple sandbox/production payments, server wallet credit or recipient settlement, RTC media, delivery to a second live device, new attachment uploads, real report submission, account deletion, every room/author, every screen size, or failure recovery under controlled network faults. Existing retained accounts, posts, chats, notes, and manual test data were not deleted.

The current signed app was relaunched on Toti UI Acceptance after testing with the retained Guest namespace and local-wallet flag. Cold launch intentionally shows the welcome/login flow; Log in reuses the retained Guest. Interactive local purchases require Xcode's `toti` Run scheme to activate the StoreKit fixture; direct `simctl launch` alone does not activate it. No application source changes were needed during this regression. README and this report record the new evidence.
