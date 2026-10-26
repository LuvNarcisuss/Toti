# XCTest UI acceptance — 2026-10-26

Environment: Xcode 26.0.1, iPhone 17 Pro simulator, iOS 26.0.1. Tests drive the actual UIKit screens through XCTest. The user explicitly authorized running the app, accepting its local agreements, and performing UI automation.

## Final outcome

All five cases have passing results after targeted rechecks. This is **not a claim that one full run passed without failures**. On the independent simulator, the full run passed 4/5; the initial Chat input did not acquire keyboard focus. Its screenshot showed no blocking alert. Re-running that case on the same simulator with the same binaries, without source changes, passed all keyboard, local-send and restart assertions in 43.189 seconds. The precise cause of that one focus failure remains unconfirmed; keep it as an automation reliability observation.

| Case | Latest independent-device result |
| --- | --- |
| Five pages and profile | Passed · 76.541 s |
| Lounge post/reply persistence | Passed · 218.101 s |
| Notebook exit/save/pin/conversion | Passed · 91.259 s |
| Voice room/local message | Passed · 57.637 s |
| Chat keyboard/local outbox | Passed on targeted recheck · 43.189 s |

Evidence: [full-run summary: 4 passed, 1 failed](isolated-summary.json), [Chat recheck: 1 passed, 0 failed](chat-recheck-summary.json), [initial Chat focus screenshot](../../../Assets/Screenshots__xctest-ui__chat-initial-focus-failure.png). Complete bundles: `/tmp/TotiUI-Isolated.xcresult` and `/tmp/TotiUI-ChatRecheck.xcresult`. The screenshot index uses the independent run for the four passing cases and the successful Chat recheck. These are the frozen build products recorded below; subsequent asset-migration changes are verified separately.

## Coverage

| Test | Assertions |
| --- | --- |
| `testFivePagesAndProfile` | All five tabs select correctly; Live/Shorts absent; unchanged profile saves; wallet reports purchases unavailable; settings and credits entry render. |
| `testLoungePostReplyAndPersistence` | Compose, link a voice room, save/reopen draft, save post, like, save and reply; post, like and reply survive relaunch. |
| `testNotebookExitSavePinAndConversion` | Unsaved-exit protection, Keep editing, pin/save, explicit conversion to a separate post draft, original private note retained after relaunch, empty search and Clear filters, navigation restored. |
| `testChatKeyboardAndLocalOutbox` | Pinned conversation, input remains above keyboard, send saves locally with Not delivered status, message remains after relaunch. |
| `testVoiceRoomCreationAndLocalMessage` | Genre filter, enter room, disconnected-service notice, microphone toggle, local send, no extra generated message during a four-second observation, create a room and find it in discovery. |

## Product fix

Notebook's Clear filters action previously left the search field focused, so the software keyboard covered the bottom navigation. The action now ends editing before resetting filters. The keyboard Search key also dismisses editing. The regression asserts that the keyboard is absent after clearing filters and then navigates to Me. It failed before the fix and passed in Run 2. [Before screenshot](../../../Assets/Screenshots__xctest-ui__notebook-keyboard-before.png).

## Harness corrections and earlier runs

- Run 1: 3 passed, 2 failed. Notebook exposed the keyboard issue. Lounge used an incorrect draft locator.
- Run 2: 3 passed, 2 failed. Notebook fix passed; Lounge needed to handle retained feed scroll position, and Voice setup assumed the welcome screen would always appear.
- Run 3: 1 passed, 1 failed. Voice passed; Lounge's reply button was not reached by the scroll helper.
- Run 4: Lounge failed again. The accessibility tree identified a keyboard prediction-bar ScrollView being selected by `firstMatch`.
- Run 5: Lounge passed. The helper now selects the largest scroll region in the main application window and drags along its edge, avoiding nested text editors and keyboard surfaces. Startup waits for one of the supported entry states.

Earlier result summaries are preserved without changing their failure counts: [Run 2](run2-summary.json), [Run 3](run3-summary.json), [Run 5](run5-summary.json). Full diagnostic bundles remain at `/tmp/TotiUI-Run1.xcresult` through `/tmp/TotiUI-Run5.xcresult` while temporary storage exists.

The subsequent full run on the shared simulator was interrupted by a separate asset-migration task installing/running the same bundle ID. Simulator logs show `installcoordinationd` terminating the Notebook process at 14:22:59; the process list also showed another `xcodebuild` using `/tmp/toti-asset-migration/DerivedData` and the same device. That run is retained as [shared-simulator summary](shared-simulator-summary.json), with [termination evidence](shared-simulator-interference.txt). It is not counted as a clean full-suite result. Verification then moved to a new independent simulator, `Toti UI Acceptance` (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`), using the already-built test products to avoid concurrent source/resource changes.

## Reproduce

Open `Toti.xcodeproj`, select **totiUI** and iPhone 17 Pro, then **Product → Test** (⌘U). Or run:

```sh
xcodebuild -project Toti.xcodeproj -scheme totiUI \
  -destination 'platform=iOS Simulator,id=05FF5F0E-DA1F-4BFD-9D19-59887F2380FF' \
  -derivedDataPath /tmp/TotiCommunityUI -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

Source: [CommunityUITests.swift](../../UITests/CommunityUITests.swift). Screenshots are indexed in [screenshots.json](screenshots.json). Each test uses an app-owned UUID library, retained for its restart checks. The override is compiled only in Debug. The original user library is not reset.

Use a simulator that no other build/test task is installing to. The isolated acceptance invocation was:

```sh
xcodebuild test-without-building \
  -xctestrun /tmp/TotiCommunityUI/Build/Products/toti_iphonesimulator26.0-x86_64.xctestrun \
  -only-testing:totiUITests \
  -destination 'platform=iOS Simulator,id=98658066-C6E0-45B3-A1E7-E8FBD950F0DB' \
  -parallel-testing-enabled NO -resultBundlePath /tmp/TotiUI-Isolated.xcresult
```

The tested app executable, Debug dylib, UI test executable and source hashes are in [tested-artifacts.sha256](tested-artifacts.sha256). These identify the already-built artifacts from this task, rather than a later build from the concurrent asset-migration task.

This verifies local behavior on this simulator. Remote publishing, RTC, message delivery and real purchases remain unconnected/unverified. Photo import, destructive account actions, full accessibility settings and other device sizes are outside this suite. The earlier 20 unit/integration tests are a separate run, documented in [community verification](../community-verification.md).
