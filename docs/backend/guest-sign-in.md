# Toti guest sign-in

Current authentication verification: session-persistence-repair.md records the later unsigned-build Keychain failure, signed repair and actual live login/relaunch acceptance. Earlier build and UI-only evidence below is historical within its original scope.
Entry update: original-entry-restoration.md supersedes the temporary Continue as guest screen layout. The real guest authentication and session boundaries below remain current.

Decision on 2026-10-28: the user replaced email OTP with one-tap guest sign-in and declined SMTP setup. This supersedes the OTP rollout prerequisite in the earlier migration documents.

## Implementation

The existing UIKit entry displays Continue as guest, the existing agreement links and an explicit consent control. No email or code field is displayed. A tap after consent uses Supabase Swift 2.55.5 signInAnonymously(), verifies the server user, and enrolls that same identity through the existing transaction RPC. Enrollment failure retains the SDK session and original operation payload for retry instead of creating another guest. Session restoration reuses the Keychain identity and checks the live server session/account before loading tabs. Unknown outcomes never fall back to local success.

Migration 005_guest_authentication.sql replaces only the private actor validator. A live matching auth.sessions row plus either a real anonymous Auth identity or a confirmed-email identity is required. Active-account checks, ownership, blocks, membership authorization and transactional operation receipts continue to apply. Public unauthenticated clients receive no business-data grants. The remote migration inventory returned toti_guest_authentication version 20261028081747.

The dedicated project's Allow anonymous sign-ins setting was enabled and saved in the signed-in browser. Confirm email remains enabled for email identities. No SMTP account or template was configured. The client rollout gate is enabled for the user-requested guest integration build, not a declaration of production acceptance.

## User-visible limitations

Guest identities have no email/password recovery or cross-device sign-in. The entry and logout confirmation explain that logout/session loss loses access. Relaunch with an intact session preserves identity. No account linking, automatic cleanup or guest expiration is introduced. Existing local archives remain independent. Photos, RTC and payments retain their existing unavailable states.

## Verification

Current-source Simulator build succeeded, using Xcode 26.0.1 and Supabase Swift 2.55.5. Latest-source installation and launch use Toti UI Acceptance (98658066-C6E0-45B3-A1E7-E8FBD950F0DB). The selected entry UI test checks the guest action, absence of email controls, agreement links and refusal to authenticate without consent. Result: 1 UI test passed, 0 failures; TEST SUCCEEDED. The current source was installed and launched again after testing. No agreement was accepted and no guest login was initiated by this UI test.

The security advisor returned the existing eight informational default-deny RLS findings, plus anonymous-role Storage policy warnings. The sole media-owner policy still requires the caller's UID path and live active account. No client upload policy was added. See https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins.

The initial disposable-cloud-data test proposal was rejected by automatic approval pending explicit authorization. The user subsequently authorized two temporary guests and one private notebook item per test run, including permanent cleanup of those test identities/data. The authorized live acceptance then ran; see the results below. This authorization does not cover existing users or unrelated data.

After screenshot inspection, the consent label was given lower horizontal compression resistance and the switch retained its intrinsic width. The final rebuild succeeded and the same entry UI test passed again (1 test, 0 failures). Evidence: /tmp/toti-guest-layout-build.log, /tmp/toti-guest-layout-tests.log, /tmp/toti-guest-layout-tests.xcresult. Initial evidence: /tmp/toti-guest-build.log, /tmp/toti-guest-entry-tests.log, /tmp/toti-guest-entry-tests.xcresult. Browser settings and app screenshots remain in ignored Assets/Verification/Backend.

## Authorized live cloud results on 2026-10-28

Current-source prerequisite build succeeded in /tmp/toti-guest-cloud-prerequisite-build.log and the latest app was installed and launched on Toti UI Acceptance before testing. Python's initial HTTPS attempt failed because its own default CA path was missing; no Auth request reached the server. Setting SSL_CERT_FILE=/etc/ssl/cert.pem used the system trust bundle with certificate verification still enabled.

The first cloud run registered/enrolled two real anonymous identities, saved a private note and verified replay behavior, but the owner read failed with PostgreSQL 42702: column reference c is ambiguous. In read_records, the cursor JSON variable c shadowed the comment-row alias c. Migration 006_read_cursor_name.sql renames only the cursor variable to v_cursor, retaining authorization and read projections. Remote inventory confirmed toti_read_cursor_name version 20261028082619. Both first-run guests cleaned themselves up successfully before repeating the scenario.

After deployment, the same live scenario passed all 13 reported checks: two guest Auth sign-ins, two business enrollments, private note save, same-operation receipt replay, changed-payload rejection, owner read, other-guest invisibility, other-guest edit denial, refresh retaining identity and two self-cleanups. Logs: /tmp/toti-guest-cloud-tests.log (initial failure) and /tmp/toti-guest-cloud-tests-retry.log (passed, exit 0). The user approved the disposable-data scope; test enrollment used an explicit non-user-consent test marker, not acceptance of terms on a person's behalf.

Cleanup read-back covered both rounds (four temporary identities in total). Auth users, business accounts, owned objects, operation receipts and Storage files all returned count 0 for these IDs. Four completed deletion-job audit rows remain intentionally; they contain no live user account or notebook content. No existing user's account or data was targeted. The latest guest app remains running on Toti UI Acceptance after testing.

Reusable acceptance source: TotiMusic/Backend/acceptance/guest_auth.py. It requires --allow-disposable-cloud-data after explicit approval and does not print tokens. It creates real disposable cloud data and permanently cleans up its test accounts; it must not be included in routine offline test runs.

This verifies the selected REST/Auth/Edge behaviors, not the complete UIKit signed-in navigation, relaunch Keychain behavior, all social/chat flows, load/concurrency or interrupted deletion recovery. Those broader checks remain pending.
