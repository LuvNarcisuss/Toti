# Returning-guest entry repair — 2026-10-28

The user reported that startup skipped the original welcome/login pages and opened Lounge. The pages were present, but `TotiCoordinator.start` automatically restored a saved guest and installed the tab controller after refresh. This was the exact branch exercised by the earlier session-restoration UI acceptance and conflicts with the requested explicit entry sequence.

Every cold launch now displays the existing welcome, then login. Only the user's Log in action enters the tabs. Secure guest storage is preserved, and `signInAsGuest` reuses the stored session instead of creating a replacement. The existing consent checkbox, unchecked-login confirmation and online PDF links remain. Background resume does not recreate entry. No server configuration or schema change is needed.

The scoped UI regression uses a disposable isolated guest, reaches Lounge, terminates and relaunches the app, requires Get started and Log in again, then continues and cleans up only that guest. The pre-fix run reproduced the missing welcome assertion; verification of the corrected source is recorded below. Existing user sessions, private archives and Photos are not deleted.

## Verification

Pre-fix regression: `/tmp/toti-entry-returning-red-build.log` built successfully; `/tmp/toti-entry-returning-red.log` and `.xcresult` recorded the exact failing assertion: A saved guest session must still show the original welcome on cold launch. The test continued to clean up its disposable guest. Its deletion job for `47284a5f-e8c2-4907-bbe4-26523d5fc316` was independently read back complete.

Post-fix verification uses the current signed source on Toti UI Acceptance (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`). The build succeeded in `/tmp/toti-entry-returning-green-build.log`. `/tmp/toti-entry-returning-green.log` and `.xcresult` report two UI tests passed, zero failures and zero skips. The returning guest scenario passed in 47.206 seconds; original login/consent passed in 10.552 seconds. The structured result summary confirms the same result on iPhone 17 Pro, iOS 26.0.1 / 23A8464. Returning-guest welcome and original login screenshots were exported and visually checked.

The post-fix disposable guest `40d473ab-2d71-4918-b1b3-7aa00ad47961` was deleted through its own authenticated UI. Independent read-back confirmed its deletion job complete and zero matching Auth users/owned records. The pre-fix fixture was also removed, and zero accounts with the UUID-scoped UI acceptance marker remain. No server settings or migrations were changed.

The final artifact passed `codesign --verify --strict`, was reinstalled on the required simulator, and was cold-launched without the test environment override. `git diff --check` and project/Info.plist `plutil -lint` passed. This verifies this entry correction, not all backend modules or real-device acceptance. No commit or push occurred.
