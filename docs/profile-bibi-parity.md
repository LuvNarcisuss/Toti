# Profile parity with Bibi — 2026-11-02

## Reference and audit scope

Reference: `/Users/apple/Desktop/Bibi/BibiApp/Bibi/Features/Profile/ProfileControllers.swift` and `BibiApp/Bibi/App/AppStore.swift`. The audit compares the identity block, metric meanings, relationship conditions, safety actions, Works content and owner-only collections. Toti retains its music theme, UIKit architecture and approved feature set.

| Detail | Bibi behavior | Current Toti behavior |
| --- | --- | --- |
| Received engagement | Likes and Saves across the author's works | Likes and Saves across published, non-deleted music posts; these are not the viewer's personal collections |
| Metric order | Likes / Saves / Following / Followers | Same order, shared by Me, member and editorial profile layouts |
| Online count source | Author work/relationship records | Server profile projection; no sum of a partial feed page or hardcoded received-save zero |
| Pagination | Counts describe works/relationships | Received totals use all matching posts; Works list captions explicitly describe loaded records |
| Unknown statistics | Requires an actual data source | Missing member metadata displays an em dash; the six authorized editorial profiles use separately disclosed fixed illustrative figures |
| Mutual following | Message only when both sides follow | Same member-profile display/click gate; account/block/mutual status checked around async navigation |
| Unilateral following | Wide Follow/Following plus Block | Same layout; an editorial content follow cannot manufacture incoming following |
| Safety | Report or block from a member profile | Existing safety sheet now supports a Profile target through the authenticated reporting path; submission does not imply completed moderation |
| Works | Author's visible published works | Author's visible music posts; editorial Works filtered by fixed author ID; private notes/drafts excluded |
| Owner collections | Own private collections/categories | Toti's Works / Saved / Drafts / About retained; private Notebook and owned Voice routes remain owner-only |
| Portraits and biography | Identity consistently shown | Shared Toti identity card and owner-avatar resolver; distinct illustrative portraits retained for editorial authors |
| IP information | Provided region or unavailable text | Only genuinely supplied region is shown; no location inferred from photography |
| Collection captions | Singular/plural text | Shared count formatter uses `1 post`, `1 draft`, `0 posts` and correct plural forms |
| Retired modules | Bibi has Shorts/Circles/Challenges | Not imported into Toti; no video/cosmetic routes or copied account configuration |

## Root causes corrected

The old header substituted Posts for Saves. The online adapter returned `saves: 0` unconditionally and read only the direct profile page, missing valid profile metadata embedded in posts/conversations. The server projection supplied received likes but no received-save field. All three layers now agree on the four metrics. `TotiProfileMetric` centralizes order/field names; `onlineStatistics` uses the same profile resolver as the visual metrics.

Ordered source `TotiMusic/Backend/sql/012_profile_received_saves.sql` was deployed as `toti_profile_received_saves`, remote version `20261102025816`. It extends the existing private profile projection with `save_count`, counting real `save` reactions to the author's published, non-deleted posts. It preserves the current approved-avatar joins, owner-only pending-review fields, active-account/block filters, security-definer context and revoked direct client execution. No accounts, reactions, posts, wallet values, media policies or relationship rows are seeded or changed. The existing `(post_id, kind)` reaction index and `(owner_id, kind)` object index support the aggregate.

Read-back on the two retained Guests returned Likes = 0 and Saves = 0, matching independent SQL counts. Missing and unsupported statistics remain unknown rather than displaying an invented zero. Six editorial identities remain material presentations, not authenticated accounts. Their initial unknown-value presentation was subsequently replaced, at the user’s explicit request, with fixed illustrative figures documented in `lounge-editorial-authors.md`. These figures are separate from member statistics and relationships. Unconfigured publishers still show unknown values, and local Follow/Block preferences never change real community totals.

The source audit also found the missing member-profile Report or block entry. `ContentSafetyTarget.Kind.profile`, the online target-kind mapping and the reported-item rendering now preserve the profile target instead of treating it as a post. The existing server already accepts visible foreign profile reports; no new report endpoint or claim of staffed moderation is added. The runtime check opens/closes the form without submitting a report.

## Verification

Three `ProfileMetricTests` cover metric order/value mapping, nonzero received likes/saves embedded outside the profile directory page, unknown editorial values and singular/plural captions. The read-only `testProfileReceivedMetricsAndReportEntryReadOnly` checks Me and the retained partner's four metric values/order, the still-visible mutual Message button, Report profile/Submit report entry without submission, and the editorial profile's four unknown values with no Message. The final model suite passed all 3 cases (0 failures), and the final read-only UI case passed in 75.286 seconds (0 failures). The final UI also asserts `1 post loaded`. Both current-source schemes built, and the latest package was installed and relaunched on Toti UI Acceptance, iPhone 17 Pro / iOS 26.0 (`98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, Bundle ID `com.toti.music`).

A first UI attempt completed the Me/member metrics and safety checks but could not determine the activation point of a Lounge author footer after scrolling. The same author profile is reached through the existing Settings → Editorial preferences path for the scoped metrics check. This does not replace the separately passed Lounge avatar/navigation acceptance recorded in `backend/profile-relationship-acceptance-20261102.md`.

No live reaction fixture, positive server-count mutation, report submission, relationship mutation, account cleanup or production acceptance is part of this read-only update. Nonzero received values are verified in isolated in-memory unit records, not represented as real community engagement. Full pagination/load/stress, concurrent engagement, device/iOS-version, accessibility-size and report-submission matrices remain separate coverage.

## Final evidence

- UI build: `/private/tmp/toti-profile-metrics-final-ui-build-1102.log`.
- Model build: `/private/tmp/toti-profile-metrics-final-model-build-1102.log`.
- Three model tests: `/private/tmp/toti-profile-metrics-final-model-1102.xcresult`.
- Final UI case: `/private/tmp/toti-profile-metrics-final-ui-1102.xcresult`.
- Installation/binary verification: `/private/tmp/toti-profile-metrics-installed-1102.json`.
- [Final editorial metric layout](backend/profile-relationship-evidence-20261102/editorial-profile-metrics.png).

The read-only UI pass asserts received Likes/Saves = 0 and Following/Followers = 1 on the two real retained profiles, matching server state, then asserts four unknown values on the editorial profile. The first pass through the stable Settings entry passed before visual review found the singular caption issue; the caption was then corrected, rebuilt and verified in the final pass above. No metric interactions, reports or relationships were submitted by this test. Normal existing-chat read preferences may refresh when entering the retained conversation.

Security advisor review still reports the existing private default-deny table notices and Guest-policy/password-protection advisories; no auth/RLS setting was changed in this task. Direct execution of the private projection remains denied to anon and authenticated roles. This is a targeted implementation/acceptance record, not a full security or release certification.

Both existing Guests remain active and mutually following; retained data checks show 3 notes, 1 post, 3 messages and no new reports. Earlier account/content retention evidence remains at `backend/profile-relationship-acceptance-20261102.md`. No account or user-content cleanup was performed.

## Subsequent illustrative-data authorization

The user then requested plausible simulated data. Six fixed editorial-only figure sets now replace the preceding em-dash presentation for those named material authors, with an explicit illustrative-figure disclosure and accessibility hints. Real Guest/member statistics, received-save SQL, mutual-follow rules, accounts and personal records remain unchanged. Source/manifest consistency and isolation tests cover all six records. Values and current validation are in `lounge-editorial-authors.md`; the unknown-value screenshot above is historical evidence from before this request.
