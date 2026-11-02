# Call page presentation — 2026-10-30

## Current user-selected behavior

The user selected Bibi-style call pages and local button interactions without any real call-service integration. The reference read was `/Users/apple/Desktop/Bibi/BibiApp/Bibi/Features/Calls/CallController.swift`; only its requested UI behavior is adapted. Toti retains its own theme, generated raster icons, real account portraits and dedicated backend settings.

Voice/video chat buttons directly present the existing full-screen CallController. The pages show the contact name, call type, portrait for voice calls, microphone/speaker controls and End call/Close actions. Calls are unavailable and No call has been placed notices are removed. There is no blocking connection popup, synthetic ringing/answer event, connected timer or successful remote-call record.

Microphone and speaker buttons behave like Bibi: enabled local on/off state, matching icons/highlights and accessible On/Off values. They do not capture audio, change a remote participant or establish audio routing. End call and Close return to the existing conversation.

Video uses the existing video-only AVFoundation local camera preview, Flip camera and Camera options with Try again/Settings/Cancel. The preview can ask for camera permission. Hardware/permission/interruption errors describe the actual local camera state. Capture starts only while the video page is active, stops on background/exit, and can resume when the active video page returns. This is local video input only: no microphone input, recording output or network media transport. Voice pages never start the camera.

`rtcEnabled` remains false. No RTC provider, signaling, remote stream, call push or credential was added. Preview capability and button state do not establish a real call.

## Verification

The current signed Debug UI-test build succeeded. Device: Toti UI Acceptance (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, iOS 26.0). The retained Notebook Acceptance/Acceptance Partner accounts are reused; no new account or fixture cleanup is performed. The first local-control UI run exposed an oversized Camera options button: the inherited layout supplied only a leading edge and the custom button expanded beyond the screen. A trailing safe-area constraint now bounds the button. The original failure is retained at `/private/tmp/toti-bibi-call-parity-ui.xcresult`; the corrected-source `NotebookCallsAcceptanceUITests/testRetainedFriendCallPagesAndLocalControls` passed (53.033 seconds, zero failures/skips). It verifies notice removal, microphone/speaker On/Off toggles, video controls, Camera options opening and cancellation, End call and Close returning to the same conversation. Evidence: `/private/tmp/toti-bibi-call-parity-ui-retry.log` and `/private/tmp/toti-bibi-call-parity-ui-retry.xcresult`. Exported screenshots were inspected; the camera-options button is contained within the screen. Simulator camera permission was granted during the initial run; the simulator correctly reports missing local camera hardware. No real camera flip or remote media success is claimed.

Real-device camera capture/flip quality, permission denial/revocation, hardware interruptions and background preview behavior still need dedicated device acceptance. A simulator flow does not prove that an actual camera or remote media stream works.

## Superseded acceptance

The earlier popup-only flow is recorded in notebook-and-calls-acceptance-20261030.md. The intermediate full-page flow with disabled controls and Camera off passed `testRetainedFriendVoiceAndVideoPagesWithoutPermissions` (70.756 seconds), with evidence at `/private/tmp/toti-call-pages-ui.xcresult`. These are historical for the current controls and copy; the original Notebook/privacy acceptance and fixture-retention instruction remain valid.
