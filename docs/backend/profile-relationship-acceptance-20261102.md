# Profile relationship acceptance — 2026-11-02

## Result and environment

The current working tree was built, installed and launched on **Toti UI Acceptance**, iPhone 17 Pro, iOS 26.0, device `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. The actual built and installed identifier is `com.toti.music`, matching the current project configuration. Supabase Swift remains pinned to 2.55.5. No dependency version, backend schema, account identity or purchase configuration was changed for this acceptance.

Four storage/online relationship tests, three final UI cases and one final restoration case passed, with zero failures in those final runs. The genuine member test reproduced a Chats crash after blocking; the list data source was fixed and the complete related UI suite then passed on a fresh current-source build. The latest app was relaunched after restoration. Its installed executable and `toti.debug.dylib` hashes match the build products.

## Passing cases

| Case | Result | Scope |
| --- | --- | --- |
| `EditorialPreferenceStorageTests` (3 tests) | Passed, 0.036 s total | Reload/account separation, corrupt-file preservation and rejection of oversized historical draft updates without replacing saved bytes |
| `RetainedProfileRelationshipAcceptanceTests/testRetainedRelationshipGateAndPreferenceSnapshot` | Passed, 37.787 s | Strictly restore both existing Guest identities; incoming-only and outgoing-only follows reject mutual status; reciprocal follows enable it; block disables it; unblock does not restore it automatically |
| `NotebookCallsAcceptanceUITests/testEditorialAvatarsOpenOnlyTheirAuthorsWorks` | Passed, 61.830 s | Ava/Ethan avatar routes, corresponding Works only, unilateral editorial follow never exposes Message, cover/detail/return navigation |
| `NotebookCallsAcceptanceUITests/testEditorialFollowUnfollowBlockAndUnblock` | Passed, 48.793 s | Ava's Follow/Following, cancellation of block, actual block, hidden Works, Settings recovery/unblock and restoration of the original local follow state; Message remains absent |
| `NotebookCallsAcceptanceUITests/testRetainedMemberMutualMessageAndBlockUnblock` | Passed, 100.961 s | Existing mutual friends show Message and enter the retained chat; unfollow hides it; refollow restores it while the incoming follow exists; cancel/confirm block; return to Chats without crashing; Settings unblock; outgoing-only refollow still hides Message |
| `RetainedProfileRelationshipAcceptanceTests/testRestoreRetainedRelationshipsAndEditorialPreferences` | Passed, 4.599 s | Final restoration of original mutual following, no pairwise blocks, and original editorial preference bytes/absence |

The final three UI cases took 211.583 seconds, with no failures or skips. Editorial controls use one shared implementation for all six authored identities; full UI state cycling was performed on Ava, with Ava/Ethan route checks and static validation of all six mappings. This does not claim six separate end-to-end cycles.

## Defect found and fixed

The real-member block test crashed in `ChatsController.tableView(_:cellForRowAt:)`, originally at `ChatControllers.swift:778`, with `EXC_BAD_INSTRUCTION` from an out-of-range array access. Blocking removes the conversation from the live filtered collection. The custom navigation preparation then lays out the returning Chats table before a queued store refresh updates its rows, so an old row index was applied to a new collection.

Chats now captures one inbox snapshot when reloading; row counts, cells and selection all read that snapshot. Cell/selection bounds are checked, and opening a stale row revalidates account context, visibility and block state. Search/filter reloads use the same snapshot method. The original block/pop regression passed in the final UI run. Blocked-author rows also have stable UUID accessibility identifiers, so tests do not mistake a privacy-limited display name for the target identity.

Initial diagnostics are retained: a missing explicit `self` in a new UI-test closure was corrected before executing UI tests; the first UI run selected the obscured underlying Block control instead of the confirmation control; the selector was corrected to choose the hittable button. That retry exposed the actual application crash above. An intermediate restoration attempt ran no tests because switching build schemes had removed the unit-test plugin; rebuilding that test product resolved the harness issue. None of those failed attempts is counted as a passing acceptance run.

## Retention and restoration

The original retained run is `26F9BA6F-44AC-4A36-9B37-DF739B215A3C`:

- Primary Guest: `d1ae68c2-d6eb-495c-bf2b-a1b4b430a629`.
- Partner Guest: `cded9cf8-1182-4802-ac9b-334c1c7d3040`.
- Existing conversation: `ace0a7c3-5a24-4051-8079-244937122078`.

Both accounts were checked as active after testing. Read-only SQL confirmed the original two reciprocal follow rows and no block between these accounts. Visible business-record counts match the pre-test baseline: two profiles, one conversation, three messages, three notes, one post and one conversation preference. Both retained private attachment objects remain in Storage. No account, note, post, conversation, message or attachment was deleted; no new message or fictional incoming follow was created. Original editorial preference bytes were restored, including removal of only the test-created preference file if it did not exist at baseline. Previously saved private drafts, if any, remain untouched.

## Evidence and remaining scope

- Builds: `/private/tmp/toti-profile-crash-fix-ui-build-1102.log` and `/private/tmp/toti-profile-crash-fix-service-build-1102.log`.
- Storage/online relationship results: `/private/tmp/toti-profile-service-1102.xcresult`.
- Final UI results: `/private/tmp/toti-profile-ui-final-1102.xcresult`.
- Final restoration: `/private/tmp/toti-profile-final-restore-1102.xcresult`.
- Original crash: `~/Library/Logs/DiagnosticReports/toti-2026-11-02-103551.ips`.
- Installation verification: `/private/tmp/toti-profile-installed-1102.json`.
- Screenshots: [editorial author without Message](profile-relationship-evidence-20261102/editorial-author-no-message.png), [real member with outgoing-only follow and no Message](profile-relationship-evidence-20261102/member-outgoing-follow-no-message.png).

Acceptance concerns the profile Message entry and existing retained conversation. It does not prove a global prohibition on all existing chat routes, new message delivery, concurrent relationship revocation mid-request, every account/directory pagination case, full Dynamic Type/small-phone layout, iOS 16 runtime behavior, RTC, production release or App Store readiness. Earlier static-only profile records are superseded only for the scenarios explicitly tested here.
