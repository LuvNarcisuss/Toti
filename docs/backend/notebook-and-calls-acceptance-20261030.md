# Notebook and calls acceptance — 2026-10-30

## Authorization and environment

The user authorized current-source build, installation and comprehensive tests, then authorized two isolated temporary Guest accounts and cloud fixtures. The later instruction supersedes automatic cleanup: retain both accounts, their sessions and final test data until the user completes manual testing and explicitly confirms deletion. No account deletion or fixture-cleanup endpoint is run by these acceptance cases. Dedicated deletion probes are exercised as part of note-management testing.

Device: **Toti UI Acceptance**, iPhone 17 Pro, iOS 26.0, `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. Current-source signed Debug build, Supabase Swift 2.55.5, dedicated Toti backend `gjodhvpzkdnxdjmorjfw`. The ordinary sandbox could not connect to CoreSimulatorService; authorized service access resolved device discovery. No alternative simulator or earlier binary was substituted.

## Model, recovery and live backend results

`NotebookTests`: 7 passed. Unicode/length boundaries, Codable round trip, stable identity/creation time on edit, rejection without data loss, distinct unpinned duplicates, category/mood/body search with pinned ordering, and separate post-copy content.

`OnlineOperationRecoveryTests`: 5 passed. Uncertain operation identity survives relaunch, acknowledgement permits new intent, destination separation, conflicting payload recovery, and private journal separation.

`OnlineSecureSessionTests`: 1 passed. Keychain persistence and removal use only that test's dedicated probe key, not either retained Guest key.

`NotebookOnlineAcceptanceTests`: 1 passed. Real Guest/session restoration, create/read/edit/pin, expected-version conflict rejection, duplicate/delete probe, denial of another Guest's private read/write/delete, fresh backend instance restoring saved private content, mutual follows, canonical direct conversation, and a real stored message. One signup request timed out and the SDK recovered; read-only Auth inspection confirmed exactly the two accounts listed below were created during this acceptance window.

Total for this layer: **14 passed, zero failures or skips**. Evidence: `/private/tmp/toti-notebook-service-acceptance.log` and `/private/tmp/toti-notebook-service-acceptance.xcresult`.

## UI acceptance

Initial runs exercised no-friend Chats, hidden call actions without a conversation, Notebook welcome cards, dirty-editor Keep editing/Discard, actual opening-lyric template content, online save, pin/unpin, edit/save, search no-results/reset, duplicate, and cancellation of deletion. Two initial automation failures are retained in the evidence: iOS 26's prompt popover omitted the expected Cancel button; the subsequent direct Delete tap occurred before the confirmation alert was stable. The harness now selects a real prompt and waits for the Delete control. These initial runs are not reported as fully passing suites.

Final independent UI runs passed:

| Case | Result | Duration |
| --- | --- | --- |
| Delete confirmation and cancellation coverage, retained note count, process termination, same-Guest login and reopened saved text | Passed | 91.386 s |
| Chord template, Reflective mood, online save, category filter, body search, separate saved Lounge draft, original note retained | Passed | 83.240 s |
| Actual mutual friend conversation, Voice call notice, Video call notice, conversation remains available | Passed | 35.199 s |

The final selected runs contain **3 passing UI tests**, with no failures or skips in those runs. Combined with the model/service layer, **17 tests passed**. This does not erase the two initial harness failures or claim that the original combined UI case completed as a single passing run; the successful assertions before its failure and the independent passing continuation establish the listed scenario coverage.

Evidence: `/private/tmp/toti-notebook-ui-acceptance.xcresult` (initial prompt-menu locator failure), `/private/tmp/toti-notebook-ui-acceptance-retry.xcresult` (initial delete timing failure), `/private/tmp/toti-notebook-ui-resume.xcresult` (passing deletion/relaunch), and `/private/tmp/toti-notebook-calls-final-ui.xcresult` (two passing final cases). Corresponding `.log` files use the same base names, except the passing resume log is `toti-notebook-ui-resume.log`.

At the time of the initial acceptance, the actual online call buttons both displayed **Voice and video calls are not available yet.** and return to the existing conversation after OK. This is a passing unavailable-state test, not a passing voice/video connection test. That earlier online guard returned before `CallController` construction and camera/microphone startup. The subsequent user-requested [full call page change](call-page-presentation.md) supersedes this popup behavior while keeping actual RTC unavailable.

## Retained fixtures for manual acceptance

- Acceptance run: `26F9BA6F-44AC-4A36-9B37-DF739B215A3C`.
- Primary Guest, display name Notebook Acceptance: `d1ae68c2-d6eb-495c-bf2b-a1b4b430a629`.
- Test partner, display name Acceptance Partner: `cded9cf8-1182-4802-ac9b-334c1c7d3040`.
- Retained private chorus note: `b60271e3-3cb0-4dd1-9350-203d47aab9e0`.
- Retained UI Acceptance Melody note: `b366d785-8983-4eaa-b947-468f74d39a4d`.
- Retained A progression to explore note: `cfe215a4-bfd6-4c19-9a86-7bf9f1cb768a`.
- Retained private Lounge draft: `ce96de05-dd15-42df-b126-1f5ced7455a0`.
- Direct conversation: `ace0a7c3-5a24-4051-8079-244937122078`.

A final read-only database check confirmed both Guest accounts still exist, the three listed notes and one Lounge draft remain private and active, and the direct conversation remains active. Two dedicated note deletion probes are soft-deleted as expected. No post was publicly published by these scenarios.

These identifiers are not credentials. Sessions remain in simulator Keychain; no bearer tokens, refresh tokens, upload keys or private API keys are exported into the repository. The primary isolated session uses the existing Debug-only UUID override. Existing normal sessions and local archives are preserved.

To reopen the installed acceptance build with the same primary test session after process termination:

```sh
SIMCTL_CHILD_TOTI_GUEST_ACCEPTANCE=26F9BA6F-44AC-4A36-9B37-DF739B215A3C xcrun simctl launch --terminate-running-process 98658066-C6E0-45B3-A1E7-E8FBD950F0DB com.toti.music
```

Cold launch still shows welcome/login. Explicit Log in restores this Guest. Do not log out or delete either test account before manual acceptance is finished. Launching without the Debug override selects the normal session rather than this test session.

## Service limits and uncovered scope

Real voice/video connection remains unavailable: `rtcEnabled=false`, and no RTC provider, token/signaling service or media lifecycle has been integrated. An acknowledged text conversation or a call-button notice is not evidence of an audio/video connection. No provider was added under this test authorization.

This run does not establish physical-device behavior, iOS 16 compatibility, camera/microphone transmission, reconnect/poor-network media behavior, background calls/CallKit, push calls, hardware permission denial, backend outage UI, concurrent-device editing UI, disk-full handling or production release acceptance. Model/version/journal checks do not replace those runtime scenarios.
