# Post detail parity with Bibi

Date: 2026-11-02. The user requested the complete Bibi-style post-detail experience, explicitly including author avatars, comments, likes, bookmarks and forwarding, with Toti's existing music theme. The screenshot showed `TotiEditorialDetailController`: an independent, read-only illustration page that bypassed the member post discussion. That route now has a real authenticated discussion rather than a content-only page.

## Reference and delivered behavior

Reference files: `/Users/apple/Desktop/Bibi/BibiApp/Bibi/Features/Circles/CircleControllers.swift` (`CirclePostController`, `circleAuthorRow`, `circleStoryArtwork`), `AppStore+Community.swift`, `docs/IMPLEMENTATION.md` and `docs/STATIC-AUDIT.md`. Bibi's circle detail contains author navigation, counts, post media/source credit, bookmark state, discussion, a 500-character reply, own-reply deletion and other-content report/block. Like and sharing on detail are also explicit user requirements here. Bibi's retired video attachment routes and earlier diamond tipping are excluded under the current Toti product rules.

| Detail | Editorial post | Genuine member post |
| --- | --- | --- |
| Author/avatar opens the matching profile | Stable editorial-author portrait and profile | Actual authorized member profile/avatar |
| Follow | Existing account-scoped device editorial preference; no fake reciprocal relationship | Existing real follow controls in the author profile |
| Topic, body, photograph, date | Title/topic/date/body/photo; original source/photographer link | Topic/body/date and authorized post photo |
| Counts | Actual server likes/saves and viewer-visible replies | Existing real likes/replies plus server save total |
| Like/unlike | Explicit server reaction state, acknowledged before update | Existing authoritative reaction mutation |
| Save/unsave | Server bookmark, Lounge Saved and Me Saved | Existing server bookmark and saved routes |
| Comment entry | Focuses the reusable editor; empty/oversized replies are disabled | Focuses existing validated reply editor |
| Discussion | Up to 40 replies per page, earlier-page action, refresh, empty/error state | Existing authorized thread loading and pagination controls |
| Reply identity and date | Real commenter avatar/profile/date | Real commenter avatar/profile/date |
| Delete own reply | Confirmation and server ownership check | Existing confirmation and server ownership check |
| Report/block another reply author | Private report form and real member block | Existing Safety flow |
| Report/block post author | Private report form; device editorial-author block with Settings recovery | Existing Safety flow for other people's posts |
| Edit/delete own post | Editorial content is not owned by a Guest | Existing edit and destructive delete confirmation preserved |
| Share/forward | Copy, system share entry and real chat forward | Same shared controller |
| Open a forwarded post | Chat bubble resolves the exact editorial ID | Chat bubble resolves an authorized member post ID |

Photo sources remain in MediaCredits.json; no images, authors, room material or resource URLs were changed in this revision. The four primary actions use the existing generated Toti icons with an iPhone-friendly vertical icon/caption arrangement. Accessibility text sizes switch the action group to stacked rows. Replies remain in the same editor instance through count, safety and loading refreshes; only the acknowledged unchanged reply is cleared. Repeated taps are disabled while sending, and a failed comment retry retains its stable comment ID.

## Server contract

Ordered source `TotiMusic/Backend/sql/015_editorial_post_activity.sql` deployed as `toti_editorial_post_activity`, remote version `20261102074537`. It adds private editorial reactions, comments, report receipts and request receipts, plus the authenticated `toti_editorial_activity` wrapper. It also extends the deployed member-post media document with received save count while retaining media-review and owner-feedback conditions.

Every interaction derives the caller through the existing active Guest/session validator. The wrapper has no anonymous EXECUTE grant; all four tables have RLS enabled with no direct anon/authenticated table privileges. Private post-document execution is not exposed to authenticated clients. Writes use the existing business advisory lock, validate published parent IDs, reject changed request-ID payloads, enforce comment ownership, preserve deletion tombstones and use stable comment IDs to reject mismatched replay. Comment pages filter inactive/blocked authors and carry approved/current-viewer-safe profile projections. The client's embedded profile cache fills missing directory entries without overwriting versioned profiles used for editing.

All four tables reference the real actor account with ON DELETE CASCADE. Deleting a Guest through the existing authenticated self-deletion flow will therefore remove their new editorial interactions and request/report data. No arbitrary-account deletion route, service key, new author Auth identity or seeded community interaction was introduced. Reports are received privately; staffing and operational moderation remain release dependencies. No false report is submitted during acceptance.

## Sharing and privacy

Forwarding lists mutually followed direct contacts and existing groups. It repeats eligibility and account-generation checks before sending, calls the existing authenticated chat service and displays success only after acknowledgement. Shared messages contain bounded post text and an internal `toti://post/<uuid>` or `toti://editorial-post/<uuid>` reference. Chat bubbles validate that reference and open the corresponding post through the existing account context. The reference is an in-app navigation marker; it is not a public website or an OS-registered universal link. Private, removed, blocked or unavailable content is not promoted to public access by forwarding. Other applications receive the shared text/reference, not an unrestricted private media URL.

## Retained acceptance fixtures

The existing isolated Guests remain `d1ae68c2-d6eb-495c-bf2b-a1b4b430a629` (Notebook Acceptance) and `cded9cf8-1182-4802-ac9b-334c1c7d3040` (Acceptance Partner), run `26F9BA6F-44AC-4A36-9B37-DF739B215A3C`. Existing accounts, notes, attachments, original draft and relationship data are preserved.

New authorized fixtures are the owner's real like/save on editorial post `16f40c60-5dc2-4db5-bf99-000000000006`, retained comment `1ac20ba3-7cd6-4c7e-b989-ce3773957310`, UI reply text explicitly identifying acceptance, and forwarded post messages in the retained pair's existing conversation. A genuine published member post `48c301f2-2dcc-4964-93bd-b2ea67e75bc4` and partner reply `b00cf06a-dbdc-42d7-a9f9-ce69ba8cc48c` are retained for manual detail testing. The partner's actual like/save on this member post now makes the owner's received Likes/Saves equal to at least 1/1; earlier screenshots of 0/0 are dated evidence, not the current fixture state. A separate throwaway reply was deleted only while exercising the requested own-reply deletion behavior; the final retained reply remains.

Fixture metadata is in `/private/tmp/toti-post-detail-fixtures.json`. Do not remove the retained accounts or final fixtures until the user confirms cleanup.

## Verification status and boundaries

Current-source builds use Toti UI Acceptance, iPhone 17 Pro, iOS 26.0, device `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, Bundle ID `com.toti.music`, with simulator ad-hoc signing and the unchanged pinned Supabase dependency.

The initial live service cases passed for reaction/request replay, save/read persistence, two-Guest comment visibility, foreign-delete denial, overlength rejection, partial-cursor rejection, own-delete visibility and genuine post save totals. The first UI pass validated genuine member detail and reached editorial like/save/comment/report form/share/forward/relaunch; its final inbox step failed because the test expected a Button rather than the actual UITableViewCell. That selector was corrected. Final current-source results are recorded below after completion.

Coverage limits: no real moderation report is filed, no external share is published, no OS deep-link registration is claimed, no 40+ comment pagination fixture/concurrent load is executed, and every Dynamic Type size/device is not covered. RTC, purchases, moderation staffing and production release acceptance are separate from these post-detail changes.
