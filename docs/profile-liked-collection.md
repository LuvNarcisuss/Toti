# Me liked-post collection

Date: 2026-11-02.

Update: the user subsequently authorized deletion of the retained member post. It was soft-deleted at 2026-11-02 09:50:24 UTC and verified removed; accounts and other fixtures remain. Me collection refresh buttons were removed in favor of automatic reads on entry/return and every 30 seconds while visible. The acceptance record below describes the earlier version. Me now has Works / Liked / Saved / Drafts / About. Liked is the caller's outgoing post history; the Likes statistic in the profile header remains likes received on that member's own published posts. The two values describe different things and are not interchangeable.

The white Lounge card in the user's screenshot is the retained published acceptance post `48c301f2-2dcc-4964-93bd-b2ea67e75bc4`, authored by the isolated Notebook Acceptance Guest. It was preserved under the user's explicit instruction to retain test accounts and data for manual testing. It is not a newly introduced home-page UI placeholder. This change does not delete that post or any other retained fixture.

## Collection behavior

Both ordinary member posts and the six editorial posts participate in Liked and Saved. Editorial rows use the current caller's real server `liked` / `saved` flags, never the authored profile display figures. Ordinary member rows come from the caller's authoritative reaction records and use the existing authorized post/media/profile projection. Likes are not limited to whatever happened to be loaded in the discovery feed. The collection has a 30-member-post page, an explicit Load more action, refresh/loading/error states and account-bound cursors. Editorial content is a separate small published collection and uses the existing server reader.

Each card opens its existing post detail; author badges open the corresponding author profile. Returning from detail re-reads the selected collection, so unliked/unsaved posts disappear and later likes/saves appear. A direct read fetches an older post before opening if it is no longer in the ordinary feed cache. Existing block/report filtering remains. Empty states explain how to add a liked/saved post. The horizontal category strip preserves Drafts and About routes; explicit collection identifiers replace numeric branch indexes to prevent tab-index drift.

Liked and Saved are owner-only categories on Me. Other members' profiles do not expose their outgoing histories. Drafts, private Notebook, existing works, wallet, received counters, avatars and relationships remain unchanged. The UI acceptance toggles the retained editorial like off and back on rather than cleaning up the account or deleting content.

## Deployed read contract

Ordered source `TotiMusic/Backend/sql/016_profile_reaction_collections.sql` deployed as `toti_profile_reaction_collections`, version `20261102091252`. It introduces only the authenticated `toti_profile_reactions` read wrapper/private reader, with no new tables or content writes. The reader derives the active actor through the existing session validator, filters their `like` or `save` rows to visible published posts, reuses `read_records` for the full authorized projection, and validates pagination kind, actor and keyset coordinates. Anonymous EXECUTE is denied; existing table grants/RLS are unchanged.

The client refuses mixed-account results and deduplicates collection pages. Old collection tasks cannot replace a newly selected category. The app's backend project, credentials, SDK version, signing and resource URLs are unchanged.

## Verification

Static checks include cursor scoping, caller-only query conditions, current-user collection filtering, named category routing and `git diff --check`. Large 31+ fixture pagination, every Dynamic Type/device layout, and a lost network connection during each page are not covered by this focused run. Existing production release and unrelated RTC/payment dependencies are unaffected.


### Current-source acceptance

- Device: Toti UI Acceptance, iPhone 17 Pro, iOS 26.0, `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. Debug ad-hoc signed application; unchanged retained Guest override. Latest source built with schemes `totiUI` and `toti`, installed and launched on this device before testing.
- Service case `ProfileReactionCollectionAcceptanceTests/testPrivateCollectionProjectionAndCursorValidation`: passed, 1 test / 0 failures, 5.877 seconds. Read the owner's private collections, verified the partner's existing member-post Like and Save projections, and rejected cross-account/malformed cursors. No service fixture writes or deletions. Result: `/private/tmp/toti-liked-service-retry-1102.xcresult`.
- The first UI run failed because its assertion incorrectly assumed the owner had liked the retained member post. Read-only inspection showed its likes belonged to other accounts. The assertion was corrected to require absence from this owner's Liked and continued presence in Works. No reaction records were changed to satisfy that assertion.
- UI case `NotebookCallsAcceptanceUITests/testMeLikedCollectionUnlikeRestoreAndRelaunch`: passed, 1 test / 0 failures, 92.994 seconds. Verified editorial unlike/removal, re-like through Saved, return to Liked, cold-relaunch persistence, exclusion of another account's member-post likes, continued Works/Drafts/About navigation. Result: `/private/tmp/toti-liked-ui-retry-1102.xcresult`. [Verified Liked screen](backend/profile-liked-evidence-20261102/me-liked.png).
- Final builds passed: `/private/tmp/toti-liked-ui-build-retry-1102.log` and `/private/tmp/toti-liked-model-build-retry2-1102.log`. A test-only optional-Bool assertion compile error during preparation was corrected before the final build.
- Latest installed build relaunched after test teardown on the designated simulator, PID `58898`. Retained accounts, member post, drafts, notes, conversations and existing relationships were not deleted. The editorial like was restored to its original enabled state. `git diff --check` passed.
