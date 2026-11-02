# Lounge editorial author portraits — 2026-11-02

The six existing published editorial posts have separate stable presentation authors. Card footers and profile headers use the same portrait and name. Works includes only loaded posts assigned to the selected author; revisiting that author from their own card scrolls to the top. Covers retain their detail route. Authenticated member profiles retain their real account behavior.

| Author | Portrait | Post |
| --- | --- | --- |
| Ava Bennett | EditorialAvaMusic | Listening together |
| Ethan Cole | EditorialEthanMusic | A first line |
| Chloe Reed | EditorialChloeMusic | Finding a bandmate |
| Emily Hayes | EditorialEmilyMusic | A room for the chorus |
| Grace Miller | EditorialGraceMusic | The concert afterglow |
| Sophie Brooks | EditorialSophieMusic | Start with listening |

Current portraits are six distinct licensed music-scene photographs archived under Assets and referenced by the public Supabase build-resource manifests. They were visually inspected together before selection and do not reuse the Voice character portraits. Source URLs, license links, hashes, byte lengths, dimensions and stable post IDs are recorded in `TotiMusic/Configuration/EditorialAuthorAssets.json`. Builds resolve the catalog through the public Supabase asset pipeline. The latest avatar replacement uploads six new JPEGs, six catalog files and updated credits under the immutable `music-authors-20261102/` prefix. The downloader recognizes this explicit version prefix and continues rejecting arbitrary nested paths; old public credit objects remain intact. No nationality is inferred or verified from appearance.

The names and biographies are authored editorial identities; the photographed people are not represented as actual account holders, endorsers or the writers of the text. Feed and profile disclosures remain. No Auth identities, cloud ownership, engagement, presence or member relationships are created or changed. Editorial preferences and private drafts are separate account-scoped device records as described below. Unknown editorial post IDs retain the Toti identity until assigned explicitly, rather than borrowing a person's portrait.

Static checks verified all six mappings against migrations 008/009, unique portrait assets and SHA-256 values, no overlap with Voice portrait material, image decoding/dimensions, credit/license records, Supabase resource hash references, and asset-catalog entries. `git diff --check` passed. The focused UI case now checks two authors, one matching Works card per author, detail navigation and return, but was not executed. No build, typecheck, installation or runtime acceptance was performed for this revision. Retained test accounts and data were not deleted.

## Relationship-gated actions

The current rule follows Bibi's actual relationship logic: without mutual following, the profile shows a wide Follow/Following action plus Block; only genuine mutual following permits Message. The six editorial identities have no authenticated accounts or authoritative incoming follows. An editorial content follow never creates mutual status, so their pages never expose Message. The previously added draft-only messaging page and navigation route have been removed rather than used to bypass the rule. Previously persisted private draft fields remain decoding-compatible and are not deleted.

Follow toggles an editorial-content preference. Following editorial posts appear in Lounge's Following collection and the action state is shared across entry points. Block requires confirmation, removes the local editorial follow, and hides that author's feed cards, Works and already-open details. Successful blocking returns to the previous screen. Unblock restores visibility without silently following again. Settings → Editorial preferences lists all six authors with their actual preference state, including blocked authors. Accessibility text sizes stack the controls vertically. Existing Toti bitmap icons and pressed/confirmation feedback remain.

Preferences use atomically written, file-protected JSON under `Application Support/TotiOnline/EditorialPreferences/<authenticated-account-UUID>/preferences-v1.json`. Account-generation guards protect UI actions. These records never modify member follow/block RPCs, real follower totals, chat history or the preserved `Application Support/Toti` archive. Missing files initialize empty preferences; corrupt/unreadable files are preserved and prevent overwriting or exposing content whose block state cannot be determined. Changes are published only after a successful write.

Real member profiles continue to use the existing mutual-follow predicate for rendering Message and again on click. The predicate excludes blocked profiles and the owner in both online and offline paths. The asynchronous conversation-opening path also rechecks account context and mutual following before and after the request; a stale button or lost relationship cannot continue navigation. This does not change backend send permissions or invent incoming follows for editorial material.

Static source/data-flow inspection and `git diff --check` completed. Storage tests for reload/account separation, corrupt-file preservation and oversized historical-draft rollback remain written but unexecuted. The author UI case now checks that Message is absent before and after toggling a unilateral editorial follow, then restores the starting preference. It was not executed. No build, typecheck, installation, launch, backend deployment, cloud fixture creation or account deletion was performed. Runtime coverage remains for follow persistence/filtering, block confirmation/cancel, Settings unblock, real mutual-follow transitions, stale clicks, account changes and the asynchronous navigation guard.

## Runtime update — 2026-11-02

Current-source builds and the scoped storage, relationship and final UI cases now pass on Toti UI Acceptance. Editorial Follow/Unfollow, cancel/confirm Block, Settings Unblock, author-specific Works and absence of Message after unilateral following were exercised. Original preference bytes were restored after testing. The full UI cycle used Ava, with Ava/Ethan route checks; all six retain the shared implementation and static mapping validation. See [the complete acceptance record](backend/profile-relationship-acceptance-20261102.md) for evidence, an unrelated real-member block/pop crash fixed during acceptance, retained data and untested scope. Earlier static-only statements describe the implementation stage before this run.

## Authorized illustrative figures — 2026-11-02

The user's latest request authorizes plausible simulated display data for the six editorial authors. These fixed figures replace the previous unknown-value presentation for these six profiles only. They are disclosed as illustrative in the profile and accessibility hints; they are not live engagement, Auth accounts, incoming follows, online presence or message receipts. Genuine member profiles retain the authoritative Supabase received counts. An unconfigured editorial publisher still has unknown values.

| Author | Likes | Saves | Following | Followers |
| --- | ---: | ---: | ---: | ---: |
| Ava Bennett | 86 | 19 | 34 | 127 |
| Ethan Cole | 64 | 27 | 52 | 93 |
| Chloe Reed | 39 | 8 | 68 | 74 |
| Emily Hayes | 112 | 36 | 41 | 186 |
| Grace Miller | 153 | 14 | 87 | 241 |
| Sophie Brooks | 47 | 12 | 29 | 82 |

The values deliberately vary in scale and save-to-like ratio: writing/arrangement topics have relatively more saves, while the concert story has more likes. They remain stable across refresh, navigation and relaunch and do not increase when the viewer toggles a device-only editorial follow. `TotiEditorialAuthor.presentationStatistics` is the presentation source; matching author metadata is recorded in `TotiMusic/Configuration/EditorialAuthorAssets.json`. Existing portrait/credit records and public media URLs are unchanged. No synthetic interaction or relationship rows are written to Supabase, and no account or personal content is created, reset or deleted. Displayed follower numbers never participate in mutual-follow eligibility; editorial Message remains absent.

Static checks confirm six distinct, source/manifest-consistent records. Current-source builds and installation passed on Toti UI Acceptance (iPhone 17 Pro, iOS 26.0, device `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, Bundle ID `com.toti.music`). Four model tests passed, covering all six stable figure sets, their isolation from real member statistics and the absence of a mutual relationship. The final read-only profile UI case passed in 88.617 seconds: genuine profiles still show actual backend values, Ava shows 86 / 19 / 34 / 127 with an illustrative disclosure, and Message remains absent on the editorial profile. The initial UI attempt measured a zero-width metric during an asynchronous profile refresh; waiting for completed layout resolved the test timing failure. No application count or relationship defect was reported by that failure.

Evidence: `/private/tmp/toti-editorial-figures-model-1102.xcresult`, `/private/tmp/toti-editorial-figures-ui-retry-1102.xcresult`, `/private/tmp/toti-editorial-figures-installed-1102.json`, and [the final profile screenshot](backend/profile-relationship-evidence-20261102/editorial-profile-illustrative-figures.png). No backend schema/data migration, reaction insertion, follow mutation, report submission or account/content deletion was performed for this presentation update. Earlier unknown-value screenshots and tests describe the preceding version.

## Music cover update — 2026-11-02

The six portrait avatars remain unchanged. Editorial post images and matching Works covers now use six distinct licensed music scenes, with provenance, public resource verification and the scoped backend update recorded in [music scene photographs](lounge-music-scene-photos.md). Earlier descriptions of unchanged media transport/bytes above refer to their dated avatar-only revision.

## Music-scene avatar replacement — 2026-11-02

At the user's request, all six editorial-author avatars now use different real photographs showing music activities: vinyl listening, piano playing, guitar, vocal recording and violin. This replaces the earlier portrait-only selection. All surfaces derive the portrait from the same stable author mapping, including Lounge cards, author profiles, Works author badges and editorial preferences. Real Guest avatars and member profiles are untouched. No nationality is inferred from appearance. Names remain authored identities and the photographed people are not represented as members or endorsers.

Each original source and photographer was checked on Pexels; the [Pexels license](https://www.pexels.com/license/) and source URLs are retained in `TotiMusic/Configuration/EditorialAuthorAssets.json` and MediaCredits.json. Actual images and square avatar crops were visually inspected together. All 13 uploaded files were anonymously downloaded and matched the local bytes and hashes. See [public download verification](backend/music-author-evidence-20261102/public-download-verification.json). No cloud account, private media, relationship, database schema or bucket policy was changed.

![Selected author music photographs](backend/music-author-evidence-20261102/avatar-selection.jpg)

Current-source UI test build succeeded and was installed/launched on Toti UI Acceptance (iPhone 17 Pro, iOS 26.0, `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, `com.toti.music`). Static checks verified all six unique image hashes, valid JPEG decoding, source-to-author mappings, absence of duplicate post covers, matching generated catalog bytes, 573 pinned resource records and 443 runtime resources. `git diff --check` passed. Build log: `/private/tmp/toti-music-authors-build-1102.log`.

The final focused avatar/Works UI case passed: one test, zero failures, 65.210 seconds. Ava and Ethan each opened the matching author profile and one matching Works card, opened detail and returned; Message stayed absent and follow toggles restored the starting preference. All six avatar files were checked statically, but only these two author routes were exercised in this UI case. The first run encountered XCTest's invalid offscreen activation-point error; a retry using the scroll viewport also scrolled unnecessarily for the fixed header and was interrupted. The final helper checks the window-visible center before querying hittability, covering both offscreen feed rows and fixed header controls. No application navigation behavior was changed for that test issue. Final build/test logs: `/private/tmp/toti-music-authors-build-final-1102.log` and `/private/tmp/toti-music-authors-ui-final-1102.log`; result: `/private/tmp/toti-music-authors-ui-final-1102.xcresult`. The latest build was relaunched after testing (PID 22912); existing accounts and data remain retained.

![Latest Lounge with the new author avatar](backend/music-author-evidence-20261102/lounge-new-avatars.png)

![Uploaded public avatar resources](backend/music-author-evidence-20261102/supabase-upload.jpg)

## Full online post detail — 2026-11-02

Editorial publishing and author identities remain separate from member accounts, while their post details now support real Guest likes, saves, comments and private reports. Saved editorial posts appear in Lounge Saved and Me Saved; real chat forwards open the corresponding detail. This supersedes the earlier content-only/read-only interaction description. Device-only editorial follow/block remains unchanged. See [Bibi post-detail comparison, deployed contract and exact verification](post-detail-bibi-parity.md).
