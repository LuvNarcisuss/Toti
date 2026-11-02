# Online refresh controls — 2026-10-30

Normal online lists no longer render permanent Refresh or Refresh chats buttons. Lounge, Notebook, Me, and secondary lists using the shared online controls install a native pull-to-refresh control. Chats installs the same behavior on its inbox table. Voice retains its existing room refresh action. Empty lists allow vertical bouncing so the gesture remains available.

Read failures display the error and a Retry action. Retry is disabled during an active read or mutation; a successful read clears the error and removes the action when the screen updates. An editorial-only load failure also offers Retry. Pagination and scheduled foreground refresh retain their existing behavior. Existing screen-specific refresh controls are not replaced, and new actions respect the screen's account context.

## Verification

- Built the current working tree with the `toti` Debug scheme for Toti UI Acceptance (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`): BUILD SUCCEEDED, exit 0.
- Preserved simulator ad-hoc signing and verified the application signature.
- Installed and launched that build on Toti UI Acceptance. The observed screen is the expected original welcome page; the app remains running there.
- Static search found no remaining permanent `actionButton("Refresh"...)` or `Refresh chats` action in application source. `git diff --check` passed.
- Build log: `/private/tmp/toti-refresh-controls-build.log`. Derived data: `/private/tmp/TotiBackendAcceptance`. Local launch screenshot: `Assets/Screenshots/refresh-controls-20261030/latest-launch.png`.

This pass confirms compilation, signing, installation, startup and source-level control wiring. It does not claim authenticated gesture acceptance or a simulated network-failure/recovery run. No disposable cloud account was created, no cloud fixtures were written, and no XCTest suite was run for this change. The existing App Intents metadata warning remains unrelated to this UI change.
