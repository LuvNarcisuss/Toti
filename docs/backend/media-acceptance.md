# Toti media acceptance — 2026-10-28

Later entry update on 2026-10-28: every cold launch now shows the original welcome/login before explicit Log in reuses the stored guest. This supersedes automatic navigation to tabs in the earlier restoration results below; secure session persistence is retained. See entry-launch-repair.md.

## Implemented and deployed

Real avatar and single-photo Lounge uploads use authenticated Edge validation, full JPEG decode/re-encode, immutable private Storage and authoritative attachment. Pending/rejected bytes have owner-only preview and owner feedback. Approved avatar projections feed existing UIKit portrait surfaces; a replacement does not withdraw the current approved avatar until actually approved. A real trusted SQL review decision is required for public use. There is no automatic content approval, external moderation provider or supplied review staffing.

Original `MusicStudioBackdrop`, `Portrait2` and `Portrait3` assets and six original music prompts are presented through authenticated `toti_editorial_posts()` as **From Toti / TOTI EDITORIAL**. Photography is disclosed as illustrative, and the pictured people are not member accounts. No Auth identities, reactions, audience counts or rooms were fabricated. Original asset manifests and credit records are retained.

Archive photo posts require an individual preview and explicit confirmation before copying as a private cloud draft. The original `Application Support/Toti` and source Photos files remain independent and untouched. No bulk migration or wallet transfer occurs. The original welcome/login artwork, one Log in button, consent checkbox and inline online PDF links remain the selected flow.

| Source | Deployed name | Remote version |
| --- | --- | --- |
| `TotiMusic/Backend/sql/007_validated_media.sql` | `toti_validated_media` | `20261028092119` |
| `TotiMusic/Backend/sql/008_editorial_content.sql` | `toti_editorial_content` | `20261028092148` |

Both media functions were read back ACTIVE, version 1, with gateway JWT verification. See media-backend-implementation.md for hashes, exact grants and the actual operator runbook. The media bucket stays private. An already issued signed URL is a bearer capability for at most 60 seconds; subsequent app reads always obtain fresh authorization, including cache hits.

## Actual verification

Environment: Xcode 26.0, Debug, signed simulator artifact, current workspace source, **Toti UI Acceptance** (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, iPhone 17 Pro, iOS 26.0.1 / 23A8464). Every test run built the current source, installed and launched it on this device before testing. No unsigned `CODE_SIGNING_ALLOWED=NO` artifact was used.

- Current-source build succeeded. Five `OnlineMediaRecoveryTests`, five `OnlineOperationRecoveryTests` and one `OnlineSecureSessionTests` passed: 11 tests, zero failures. Evidence: `/tmp/toti-media-recovery-tests.xcresult`.
- `OnlineMediaServiceAcceptanceTests.testGeneratedMediaPrivacyReviewRenderingAndCleanup` passed: one real cloud test, zero failures, 95.528 seconds. Evidence: `/tmp/toti-media-live-tests.xcresult`. It explicitly required `TOTI_LIVE_MEDIA_ACCEPTANCE=1` and an isolated Debug-only acceptance UUID.
- `OnlineReadinessUITests.testOriginalEntryAndLoginConsentDialog` passed: one UI test, zero failures. It exercised original artwork entry, Log in, both agreement links, checkbox and unchecked-login consent confirmation, then declined without creating an account. Evidence: `/tmp/toti-media-entry-tests.xcresult`.
- `OnlineReadinessUITests.testLiveGuestLoginReachesTabsRestoresAndCleansUp` passed: one real guest UI test, zero failures/skips, 56.765 seconds. It reached Lounge, scrolled to the restored official card and original photograph, relaunched to restore the same guest, then deleted only that disposable guest. Evidence: `/tmp/toti-editorial-ui-tests.xcresult`. Exported screenshots were visually inspected and retained at `Assets/Verification/Backend/restored-editorial.png` and `editorial-guest-lounge.png`. The structured result summary confirms zero failures; exported SDK initial-session diagnostics are warnings, not failing assertions.
- `git diff --check` and `plutil -lint` on the generated Xcode project and Info.plist passed. These are static checks, separate from compilation/runtime evidence.

The live media scenario created exactly two disposable guests, generated 96-by-96 coral/purple/blue color blocks with white centers, and used no Photos or private archive content. It verified owner pending preview and foreign post/image denial, actual review approval, foreign approved reads, six authenticated editorial records, and actual normalized remote avatar pixels reaching `TotiPhoto`. A real second review rejected the replacement fixture; the prior approved avatar and useful owner feedback remained. After blocking, previously cached images were denied by fresh server authorization.

The operator inspected the downloaded normalized fixture pixels before approving post revision `c443d55d-9966-4bf0-9135-cee8b658744d` and avatar `ccb6f0a3-9655-474e-b7ce-dfc3f0ec1752`, and before deliberately rejecting replacement `1b90d139-1ae3-491f-b50f-ceb6cf2e944e` for the feedback scenario. These decisions apply only to generated disposable fixtures, never user files.

Self-account cleanup completed for guest IDs `3eeb8eca-e3d9-467b-a253-34f1284cd22a` and `47b8c118-cf2a-43f5-974f-82e1ca87aa30`. Independent SQL read-back returned zero matching acceptance accounts, zero matching media revisions and zero matching Storage objects; both durable deletion jobs were complete. No existing user account or original file was deleted.

The separate UI guest `40720c04-b546-4e41-a14e-fff204fa4902` also has a complete deletion job; independent SQL returned zero matching Auth users, accounts, owned records and Storage objects. In total, the scoped run passed 14 tests: 11 storage/recovery, one live image scenario and two UI scenarios. No normal user session was used or deleted. The latest signed artifact was installed and launched again after acceptance.

## Remaining coverage and service boundaries

The acceptance matrix in `TotiMusic/Backend/acceptance/media.md` is broader than the executed scenario. Malformed/decompression-limit inputs, metadata stripping assertions, raw Edge duplicate replay/changed-byte conflicts, upload/deletion races, explicit attachment removal, superseded revision access, approved-current-avatar revocation, disk-full injection and real Photos picker/archive imports were source-reviewed but not runtime-tested in this run. Local retry tests cover exact persisted bytes and identities across reinitialization, definite SQL rejection correction and preservation after uncertain transport outcomes; they do not simulate every network failure.

Normal uploads remain pending until a trusted operator actually inspects them. RTC, Apple server-verified purchases, push delivery, staffed moderation and final publisher/contact/legal publication remain separate prerequisites. This is a tested integration stage, not production release acceptance. No commit, push or App Store publication occurred.
