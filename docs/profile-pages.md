# Profile pages and post-based works

## Reference and current design

The user selected Bibi's user-profile structure, with Toti members' published Lounge posts as works. References read: `/Users/apple/Desktop/Bibi/BibiApp/Bibi/Features/Profile/ProfileControllers.swift`, including the Me/Creator controllers, pinned category implementation and profile post cards. Toti retains its cream/plum/coral theme, generated icons, sourced photography, account configuration and existing UIKit architecture.

The Me page has a rounded identity/biography/statistics card, a Wallet action, and Works / Liked / Saved / Drafts / About categories. Edit profile is available only in Settings to avoid a duplicate entry on Me. The category row uses a real scrolling slot initially and moves into a clipped overlay when pinned, following the Bibi approach. It remains one category control with a 44-point height, matching Toti's StudioChoice constraints.

Works shows the current owner's visible, non-draft Lounge posts, excluding editorial prompts. Saved uses the existing saved-post state. Drafts is owner-only and opens the existing composer for continuation. About contains the private Notebook shortcut and the existing owned Voice room/edit/create routes. Settings and the pending-avatar review preview remain available. No saved content, drafts, notes, relationships or wallet data are migrated, reset or deleted by this UI change.

Other member profiles show a rounded avatar/name/biography/statistics card and preserve the existing Follow/Following, mutual-follow Message, and Block flows. Works contains only that author's currently visible, non-draft, non-editorial Lounge posts; private Notebook content and owner-only category controls are not rendered there. IP information is shown only when actually supplied.

## Post cards and data boundaries

A shared post card shows topic or PRIVATE DRAFT, an available photo, a three-line excerpt, author/date, and existing like/reply counts. The main card content, including its image, opens the post detail or owner draft composer. A separate lower-left author footer displays the author avatar/name/date and opens that post author's profile. The avatar footer has its own accessible 44-point target outside the post-opening control; it cannot accidentally trigger both routes. The owner avatar uses the shared Me configuration. Tapping the author when already on that same author's profile returns to its top instead of stacking duplicate profiles. Stable post IDs are retained as accessibility identifiers. Owner photo-review notices remain visible; other members do not receive pending/rejected photos through this UI. Photo reads still use Toti's existing authorized media path.

Profiles resolve current online identity/avatar information through the existing AppStore projection. The owner's avatar uses the same shared configuration as Me and the rest of the app. Online Likes/Saves/Following/Followers statistics use supplied profile metadata; unavailable values display an em dash rather than inventing counts. Received Saves is now supplied by the private server profile projection, independently of the viewer’s own saved collection.

Online post lists describe loaded records. This change does not add an author-filtered backend endpoint or claim that the initial global feed page contains every historical post. Existing online pull-to-refresh, Retry and Load more controls remain available. Public visibility, block/report filtering, reaction data and posting/draft persistence retain their existing store/backend rules.

## Historical runtime verification — 2026-10-30

Static source/data-flow inspection and `git diff --check` completed. The current combined source subsequently passed `build-for-testing` and one focused UI test on Toti UI Acceptance (iPhone 17 Pro, iOS 26, device `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`). `NotebookCallsAcceptanceUITests/testOfficialEditorialAvatarOpensPublisherWorks` passed in 37.321 seconds with zero failures. It verified the official card footer, publisher Works page, cover-to-detail navigation and return to Lounge. This does not cover the full Me/member profile matrix, sticky-category timing, Dynamic Type or changing online state. Result bundle: `/private/tmp/toti-editorial-avatar-ui.xcresult`.

The focused UI case contains no post, note, relationship or account deletion actions. Retained acceptance accounts and business data were not cleaned up.

Lounge member post cards retain their real author profile route. As of 2026-11-02, the six existing editorial cards instead use six distinct photographic author portraits and stable authored identities. Each avatar opens its corresponding author page; Works filters the loaded editorial posts by that exact author ID. Both card and profile read the same author definition. The previous shared Toti logo/publisher collection is superseded for these six posts. No member account or follower total is created for editorial identities. The corrected action update follows the mutual-follow gate and exposes no editorial Message destination, as described below. Unknown future editorial post IDs retain the Toti publisher identity until explicitly assigned. See `lounge-editorial-authors.md` for mappings and current verification scope.

The generated Xcode project used for this build resolves the app Bundle ID to `im.seex.sao2-neiku-30`, while `project.yml` and the root rules still declare `com.toti.music`. This task preserved that existing configuration difference rather than regenerating the project or changing identifiers. Runtime acceptance used the actual built application identifier; configuration reconciliation remains separate work.

## Current source verification — 2026-11-02

The per-author change has static verification only: six stable post/author assignments, unique portrait assets and SHA-256 values, no reuse of the Voice character portraits, valid local image decoding/dimensions, retained credit/license records, Supabase resource manifest hashes and catalog references, author filtering and whitespace checks. The previous shared-publisher runtime result above does not verify this revision. The focused UI case has been updated to visit two distinct authors and reject foreign Works, but was not run. No build, typecheck, app launch, installation or runtime test was performed for this revision; the installed app remains from the preceding build.

## Profile visual refresh — 2026-11-02

The user clarified that the requested home redesign means Me and user profiles, not the Lounge root. This update refers to Bibi's profile identity cards, statistic hierarchy, pinned collection controls and two-column saved-post tiles. It preserves Toti's UIKit architecture, English copy, cream/plum/coral theme and generated bitmap icons; Bibi's anime artwork, video features, cosmetics and configuration are not imported.

Me, authenticated member profiles and editorial-author profiles now share `totiProfileIdentityCard`: an inset photographic avatar with a coral outline, a horizontal identity/name group, biography and the existing StudioCanvas atmosphere inside a rounded card. Authenticated profiles add separate value/caption statistic blocks. Unknown server statistics remain an em dash, and editorial identities gain no invented social totals. Edit profile in Settings, Wallet, Settings, avatar review, Follow, mutual Message and Block retain their existing routes and authorization checks.

Member Works, Saved and Drafts now show compact two-column photo/text tiles, with relative cover sizing, short excerpts and independent lower-left author controls. Odd rows keep a half-width final tile. Accessibility text sizes use a single column and stack the identity group vertically. Empty owner collections gain a generated icon, heading, descriptive copy and the existing creation action when relevant. Works / Saved / Drafts / About remain the same pinned categories; the private Notebook and owned Voice routes stay in About.

Editorial author pages use the same identity card and compact two-column Works layout. Their full tile content opens the actual editorial detail; the independent author footer remains a separate control. The Lounge feed still uses its original full editorial cards. Each author's Works remains filtered by stable author ID, and disclosures remain visible. No account, post, note, wallet, relationship, asset URL or cloud record is reset or migrated.

Verification for this visual refresh is limited to static source/layout/data-flow inspection, existing target membership and `git diff --check`. It has not been built, typechecked, installed or run. Runtime checks remain for small-phone layout, long names/biographies, photo and text tiles, odd grids, Dynamic Type/reflow, category pinning, account changes, photo review and all existing button destinations. Historical runtime results above do not verify this refresh.

## Editorial relationship action correction — 2026-11-02

The action logic follows Bibi: without mutual following, Follow/Following fills the space beside Block; Message is rendered only for real mutual relationships and rechecks eligibility on click. Editorial identities cannot follow back, so their local content-follow state never enables Message. The mistaken draft-only messaging page and its navigation route were removed. Historical draft data is preserved for decoding compatibility without being exposed as a conversation.

Editorial Follow and Block remain account-scoped device preferences with Following-feed filtering, shared state, confirmation and a Settings → Editorial preferences recovery route. Real user eligibility now excludes blocked/self profiles before either online or offline mutual checks; conversation navigation rechecks account context and mutual status around its asynchronous request. No incoming relationship, message delivery or new Auth account is fabricated. See `lounge-editorial-authors.md` for current behavior and verification limits. This correction has static checks only; updated regression code has not run.

## Runtime acceptance — 2026-11-02

The previously recorded static-only status is superseded for the scoped scenarios in [profile relationship acceptance](backend/profile-relationship-acceptance-20261102.md). The current source built and was installed/launched on Toti UI Acceptance (`com.toti.music`). Four storage/real relationship tests, three final UI cases and final restoration passed. The genuine block test found a Chats list array-bounds crash during navigation preparation; the inbox now uses a stable reload snapshot, and that same path passed after rebuilding. Original accounts, content, attachments, mutual following and editorial preferences are retained/restored. Screenshots and exact coverage limits are linked in the acceptance record. Current project/source/build identifiers agree on `com.toti.music`; the identifier mismatch above is historical evidence from the older generated project.

## Bibi metric and safety detail audit — 2026-11-02

The current metric order is Likes / Saves / Following / Followers. Received save totals now come from the private server projection (migration `20261102025816`) rather than a hardcoded adapter value; embedded profile metadata is resolved even outside the current directory page. Editorial values remain unknown instead of fabricated. A genuine member's Report or block entry now opens the existing Profile safety flow. Single-item captions use `1 post` / `1 draft`. The final current-source model build, UI build, installation, 3 model cases and one read-only UI case all passed. See [the full Bibi parity checklist and scope](profile-bibi-parity.md); older static-only or Posts-in-header descriptions are superseded for these changes.

## User-authorized editorial display figures — 2026-11-02

The six material-author profiles now have distinct fixed illustrative Likes/Saves/Following/Followers values, requested by the user after the real-count audit. This supersedes the earlier em-dash treatment for those six profiles only. The profile and accessibility hints disclose the figures as illustrative rather than live activity. Unknown real/member metadata and unconfigured editorial publishers still use an em dash. The shared native layout remains unchanged. No Supabase reaction, relationship, incoming follow or Auth record is generated; real users retain server-derived counts. In particular, displayed editorial followers never enable Message. See `lounge-editorial-authors.md` for exact figures and validation.

The illustrative-figure update has current-source build/install evidence, four passing model tests and one passing profile UI case on Toti UI Acceptance. Actual Guest metrics and mutual Message remained intact, while the editorial numbers remained separate and did not expose Message. The latest app was relaunched with the existing retained test session. See the figure table and screenshot in `lounge-editorial-authors.md`.

## Full online post detail — 2026-11-02

Editorial publishing and author identities remain separate from member accounts, while their post details now support real Guest likes, saves, comments and private reports. Saved editorial posts appear in Lounge Saved and Me Saved; real chat forwards open the corresponding detail. This supersedes the earlier content-only/read-only interaction description. Device-only editorial follow/block remains unchanged. See [Bibi post-detail comparison, deployed contract and exact verification](post-detail-bibi-parity.md).

## Outgoing liked and saved posts — 2026-11-02

Me now includes Liked for the caller's outgoing likes, separate from the received Likes profile metric. Liked/Saved include ordinary and editorial posts, read authoritative reaction-index pages independent of discovery, and reload after returning from detail. Named category routing preserves Drafts and About. See [the collection contract, retained test-post explanation and exact verification](profile-liked-collection.md).


## Cover and collection refinement — 2026-11-02

Me has no manual refresh buttons. Online collections refresh on entry/return and every 30 seconds while visible and active; in-flight requests are guarded. Liked/Saved keep the previous content during refresh and replace it after a successful read. Empty Works shows a Create your first post card and opens the existing composer. Settings is the sole Edit profile entry.

Lounge editorial cards preserve their previous content-driven dimensions and spacing. Photos use aspect-fill cropping without determining card size. Cards use edge-to-edge cover photography with a dark readability overlay, title, excerpt and real counts. The footer uses two equal-width columns: author/avatar and Create post. Cover, author and composer remain separate tap targets. Profile collection tiles retain their compact layout.

Verification: latest-source `totiUI` build passed (`/private/tmp/toti-cover-verified-build-1102.log`). Installed and launched on Toti UI Acceptance (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`). The focused `testCoverCardsAndAutomaticProfileCollections` case passed: 1 test, 0 failures, 43.480 seconds (`/private/tmp/toti-cover-verified-ui-1102.xcresult`). It exercised cover/author visibility, first-post creation and editor dismissal, absence of Me Edit profile and manual Liked/Saved refresh buttons. Visual evidence: [Lounge cover](backend/cover-collection-evidence-20261102/lounge-cover.png), [first post card](backend/cover-collection-evidence-20261102/first-post.png). The earlier size iteration was interrupted after user clarification; the first completed UI run used an incorrect Close label, corrected to Close editor for the passing run. Periodic refresh failure/recovery, large pagination and every Dynamic Type size were not exercised. The source-level collection service test was updated for the deleted fixture but not rerun this round. Static diff checks passed.


## Two-column Lounge covers — 2026-11-02

The user's latest size direction supersedes the full-width cover dimensions above. Lounge editorial covers now form two equal columns with 12-point spacing and a 1:1.5 width-to-height ratio, approximately half the former width and height (one-quarter area). Images retain aspect-fill cropping. Titles and excerpts use two-line previews; the author/avatar and accessible plus-only creation control each occupy half the footer. Full content remains available in post detail. Profile collection tiles retain their existing layout. This follow-up received static diff and constraint inspection only; the earlier runtime evidence predates this size change.

The Lounge footer creation control is a bare generated plus icon aligned to the trailing edge, with no white background or border. Its existing composer action and minimum 44-point touch target remain. This visual adjustment received static inspection only.


Me collection counts now appear only in Works (n), Liked (n) and Saved (n) chips. Standalone post-count rows and the explanatory Liked/Saved paragraphs were removed. Works uses the authenticated profile post total; outgoing reaction counts traverse the authorized pages and include editorial reactions, so the first loaded page is not presented as the total. Unread counts display an em dash until acknowledged. Chip updates preserve selection, scroll position and stable accessibility identifiers. This adjustment has static verification only.
