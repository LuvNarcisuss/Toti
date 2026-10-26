# Community redesign verification — 2026-10-26

## Build and tests

Xcode 26.0.1, Debug, iPhone 17 Pro simulator on iOS 26.0.1. Command: `xcodebuild -project Toti.xcodeproj -scheme toti -destination 'platform=iOS Simulator,id=05FF5F0E-DA1F-4BFD-9D19-59887F2380FF' -derivedDataPath /tmp/TotiCommunityDerivedData CODE_SIGNING_ALLOWED=NO test`.

All **20 XCTest tests passed**, 0 failures: 2 AppStore workflow tests, 4 repository/migration tests, 7 Lounge tests and 7 Notebook tests. [Test summary](community-tests.txt). Full result bundle for this run: `/tmp/TotiCommunityDerivedData/Logs/Test/Test-toti-2026.10.26_12-50-42-+0800.xcresult`.

Coverage includes independent private-note/post identities, draft visibility, likes/saves/comments after relaunch, report filtering across feed/saved/profile, stored relationship counts, old snapshots with absent new fields, corrupted-file preservation, failed saves, deletion confined to an isolated owned root, Unicode limits, pin/search/duplicate/edit, JPEG normalization and invalid-photo rejection. Tests use temporary roots and do not erase user data.

The invalid-image test deliberately supplies malformed bytes; ImageIO logs a thumbnail error and the app returns nil as expected. App Intents extraction emits a warning because the app does not use AppIntents. Neither is a failing test.

## Fixes and inspection

- First integration build identified shared PulseRing/FrameMarks definitions in retired Live source. Moved them to VoiceRoomDecoration.swift to keep Voice independent.
- Review found inherited invented relationship counts and stale local author avatars. Counts now derive from local records; own Lounge portraits use the current profile image.
- Lounge and Notebook protect unsaved editors from close/back/swipe paths, retain input on save failure and copy notes to independent editable post drafts only.
- Xcode project excludes Live discovery, VideoFeedController, video CreationController and Resources/MusicMedia. The built app contains **zero MP4 files**. Historical private library data stays decodable and intact.
- In-app media credits contain 82 active photographic records. Retired video source/license evidence remains outside the target.
- New navigation bitmap originals, prompts and hashes are in `Design/GeneratedCommunity/`; generated using built-in image_gen, exported with transparent padding.

## Runtime

Invoked Run in the Toti Xcode window with scheme toti and iPhone 17 Pro selected. The latest Xcode GUI build activity log (`C4103EB0-4071-480A-B067-F6E5A2234FD3.xcactivitylog`) contains Build succeeded and no compiler error records. Simulator launchctl confirms com.toti.music running (PID 47829 during verification). The simulator's actual framebuffer shows the welcome page: [screenshot](../Assets/Screenshots__community-runtime__welcome.png).

The installed bundle was checked independently of the command-line test bundle: both new controller symbols are present, photographic credits match the new version, and MP4 count was inspected. That initial run stopped before the service agreements. The subsequent user-authorized interactive pass below accepted them and exercised the five pages; exhaustive accessibility acceptance remains unverified. Previous runtime-verification.md and runtime/ screenshots describe the retired version.

## Scope

No remote authentication, publishing/moderation, real voice RTC, messaging delivery or configured purchases were added. Full physical-device, accessibility, camera and StoreKit testing remain outside this verification. All activity described above uses local state.


## Interactive five-page pass — 2026-10-26

Performed through native computer control on the existing iPhone 17 Pro simulator. The user explicitly confirmed accepting the local service agreements. Early coordinate actions failed with `noWindowsAvailable` and a sheet accessibility snapshot was stale; after reconnecting and continuing through accessible controls, coordinate input recovered and the room picker was successfully retested. A proposed XCTest UI harness was compiled but never executed; it was removed when the user chose computer control. The earlier 20 unit/integration test results are separate from this interactive pass.

| Page | Observed checks |
| --- | --- |
| Lounge | Feed/detail layout; like and save; Saved filter; reply saved and count updated; note-to-post draft restored from Me; room picker selection; draft saved as a post; post, like, save and reply survived restart. |
| Voice | Genre filter; room entry; microphone toggle; local text input/send; create a named Jazz room and confirm it appears in Me and discovery; reopened existing room after removing generated messages and verified only the manually entered message appears. |
| Notebook | Empty/list/editor layout; screen keyboard clearance; create title/body; unsaved-exit alert and Keep editing; save/pin; explicit separate Lounge draft conversion; original private note remains and survives restart. |
| Chats | Inbox and Pinned filter; conversation layout; input/send; screen keyboard clearance; saved local message survives restart; final status explicitly says Saved locally · Not delivered. |
| Me | Profile layout; unchanged profile saved successfully; note count, drafts and My posts sync; room creation; settings and wallet render; unconfigured purchase controls remain disabled. |

Corrections made and rechecked:

- Removed the room's periodic fictional chat generator and prefilled incoming lines; kept user-entered local messages and added a connection/storage notice.
- Replaced ambiguous chat Pending copy with Saved locally · Not delivered, without changing the persisted outbox state.
- Corrected wallet's retired live-room/floating-comment wording to voice rooms/replies.
- Corrected singular reply, idea, post and draft counts.

The final simulator build completed with BUILD SUCCEEDED and was installed/launched. Build evidence: `/tmp/toti-ui-fixes-build.log`; build output: `/tmp/TotiCommunityUI/Build/Products/Debug-iphonesimulator/toti.app`. No blocking overlap or clipped action area was observed on the inspected iPhone 17 Pro pages. Screen keyboard layouts were visually checked in Notebook and Chats. This does not claim coverage of every screen size, Dynamic Type setting, photo import, deletion, moderation or actual network/RTC/purchase behavior.

Saved screenshots: [Lounge](../Assets/Screenshots__community-runtime__interactive__lounge.png), [Notebook](../Assets/Screenshots__community-runtime__interactive__notebook.png), [Me](../Assets/Screenshots__community-runtime__interactive__me.png), [Voice fix](../Assets/Screenshots__community-runtime__interactive__voice-fixed.png), [Chat fix](../Assets/Screenshots__community-runtime__interactive__chat-fixed.png).

QA-only local content remains available for inspection: QA Rain melody note/post, QA Piano Room, QA piano reply and QA local melody check chat outbox message. No existing private content was deleted. The app was left running on Lounge.

## Subsequent XCTest UI automation

The user subsequently requested XCTest UI automation explicitly. A persistent `totiUITests` target and `totiUI` scheme now exercise all five pages using isolated Debug libraries. This is separate from the earlier removed proposal and from the 20 unit/integration tests. The UI run exposed and fixed Notebook's Clear filters action leaving the software keyboard open over the bottom navigation. Full scope, harness corrections, result summaries and screenshots are recorded in the [XCTest UI acceptance report](xctest-ui/README.md).
