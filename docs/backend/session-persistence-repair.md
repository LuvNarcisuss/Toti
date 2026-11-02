# Guest session persistence repair

Later entry update on 2026-10-28: every cold launch now shows the original welcome/login before explicit Log in reuses the stored guest. This supersedes automatic navigation to tabs in the earlier restoration results below; secure session persistence is retained. See entry-launch-repair.md.

Date: 2026-10-28. User reproduction: after tapping Log in on the original login page, Toti displayed Auth session missing and could not enter the app.

## Diagnosis and change

The installed acceptance artifact had been built with CODE_SIGNING_ALLOWED=NO. codesign reported that the app was not signed at all. A random-key storage regression test reproduced the Keychain write failure in that same simulator process, without creating a cloud identity. Supabase Swift 2.55.5 SessionStorage catches local storage errors and returns no stored session; anonymous signup can therefore complete over HTTP while the following auth.session read throws sessionMissing.

The only experimental change was simulator ad-hoc signing. The identical Keychain test then passed. project.yml now records CODE_SIGN_IDENTITY[sdk=iphonesimulator*]="-" and CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]=YES. XcodeGen regenerated the project. Real-device team/provisioning configuration was not changed; no signing credential was added. Actual artifact verification uses codesign --verify --strict.

TotiKeychainStorage verifies a disposable local probe before cloud guest creation. The backend also verifies that the SDK persisted the newly returned identity before proceeding to enrollment. Secure session failures have their own readable error and no longer masquerade as a retry-journal failure. There is no disk JSON token fallback. Existing user tokens, journals and local archives are not removed.

The backend initializer accepts an internal storage key/journal root so live service tests can use a unique namespace. Debug UI acceptance additionally recognizes a UUID-valued TOTI_GUEST_ACCEPTANCE environment override, isolating both the shared backend and agreement test marker; Release ignores it. This does not provide a production bypass or accept terms on a user's behalf. Live tests skip by default unless the test scheme receives TOTI_LIVE_GUEST_ACCEPTANCE=1 after explicit authorization.

## Evidence

- Unsigned reproduction: /tmp/toti-session-repro-build.log and /tmp/toti-session-repro.log; one Keychain test failed with localPersistence.
- Single-variable signed comparison: /tmp/toti-session-signed-build.log and /tmp/toti-session-signed-tests.log; same Keychain test passed, one test, zero failures.
- Persisted project configuration: /tmp/toti-session-fix-build.log built without signing overrides and succeeded. /tmp/toti-session-fix-tests.log and /tmp/toti-session-fix-tests.xcresult report seven selected tests passed, zero failures and no skips: five existing operation-recovery tests, one secure-storage test, and one real guest service test.
- The live service test created one explicitly authorized temporary guest under a random Keychain key, enrolled with a non-user-consent test marker, read its exact profile, restored the account using a new backend instance and read its empty notebook, then completed its own cloud deletion. Its test Keychain item and journal directory were cleaned separately. Existing users were not targeted.
- All simulator work used Toti UI Acceptance, 98658066-C6E0-45B3-A1E7-E8FBD950F0DB, iOS 26.0, with current-source build/install/launch before tests.

The actual live UI scenario passed: it used a fresh UUID-only Debug acceptance namespace, tapped Get started, the checkbox and Log in, waited for real signed-in Lounge tabs, terminated and relaunched the app, verified restored tabs, and completed deletion of only that test guest through Settings. The test marker avoids accepting terms on a user's behalf. The second selected test covers the original unchecked-login consent dialog. Final UI result: 2 tests passed, 0 failures and no skips; TEST SUCCEEDED in /tmp/toti-live-login-ui-tests.log and /tmp/toti-live-login-ui-tests.xcresult. The signed-in Lounge screenshot was exported to Assets/Verification/Backend/signed-in-lounge.png and visually inspected. The signed artifact passed codesign --verify --strict, then was installed and launched again on the required simulator without the disposable-test override. Server read-back found zero remaining accounts with the acceptance marker after both temporary guest tests. This is simulator evidence, not real-device signing or full social/chat/payment acceptance.
