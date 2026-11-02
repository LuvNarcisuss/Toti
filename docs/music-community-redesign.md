# Toti: Lounge and Notebook redesign

Status: approved local feature design from 2026-10-26. Navigation, product theme and feature-retirement decisions remain current. The device-local service/persistence behavior and earlier execution authorization below are historical: the 2026-10-27 backend contract and current AGENTS.md now govern online behavior and verification permissions. See `docs/backend/contract.md` and `docs/backend/release-checklist.md`.

## Intent and confirmed direction

The user requested removal of Live and Shorts, preservation of Voice, Chats and Me, and two new music features. The user chose **music community + music inspiration notebook** over playlist collection + music diary. This document specifies the proposed implementation; details below are builder recommendations, not previously approved requirements.

Keep UIKit, Swift 5, iOS 16+, existing Toti identity, cream/plum/coral palette, English interface text, real sourced portraits, generated bitmap icons and atomic local persistence. No backend credentials or new third-party SDK is required. The earlier user instruction to build and run in Xcode remains applicable after implementation.

## Navigation and removal

Five equal bottom tabs: **Lounge / Voice / Notebook / Chats / Me**, with Lounge as the landing page. Make dock sizing and selection gestures depend on item count; retain safe-area clearance and independent navigation stacks.

Remove Live/Shorts discovery, playback, video comments, recording cards, video creation and their routes from the active product. Also remove video Works/Liked/Saved/Pending review sections from Me and other member profiles, video opening actions on historical chat cards, and video terminology in settings, agreements and onboarding. Historical shared video messages remain readable text with no playback action. Video-specific packaged recordings and covers leave the app target. Retain source/license evidence outside the runtime bundle.

Do not delete user-imported files, historical wallet entries, message records or private library data as part of feature retirement. Retain decoding-compatible legacy models/keys where required, without reachable video screens. Existing account deletion remains the user's explicit control for erasing owned data. Preserve audio/video call behavior already present in Chats; removing public Live/Shorts does not remove private calls.

## Feature 1: Lounge — music community

An editorial-style scrolling feed for music discussion, concert photographs and finding musical collaborators. Current navigation update (2026-10-30): retain one **For you / Following / Saved** row and move **All topics / Listening / Concerts / Making music / Find a bandmate** into the adjacent topic-filter menu. The permanent search field is replaced by an expanding search button beside the plus action at the top right, matching Chats. Search matches post text, topic and author. Show clear empty states with a relevant action. See `navigation-search-and-filters.md` for the current source and verification scope.

Each post contains stable ID, author identity, topic, text, optional one photo, created date, and optional linked voice-room ID. Feed cards show author/portrait, topic, body, photo if present, and like/comment/save actions. Opening a card presents the full post and comments. No fabricated audience, view counts or automated incoming interactions.

Composer: topic, text (1–1,000 characters), optional single photo selected with PHPicker, optional existing voice room selected from current visible rooms. Save incomplete work as a draft; edit or delete owned posts. Final action **Save post** records the post locally and shows **Saved on this device**. Avoid implying network publication. Add a concise feed notice: **Posts and replies are stored on this device.** No file upload or photo-library-wide permission is needed.

Like/unlike and save/unsave persist; comments (1–500 characters) are free and persist on the same device. Counts reflect stored interactions only. Author headers open the existing member profile, which retains follow/block/message rules. Linked-room cards open an available Voice room; deleted or blocked rooms show unavailable state. Comments and foreign posts support report/hide; blocking an author removes their posts/comments from visible collections and uses the existing shared blocked list. Owned posts/comments support confirmed deletion.

Seed a small, clearly authored editorial collection using fictional identities consistent with existing app content and already credited real photographs. Seed IDs remain stable; no claim that photographed people wrote posts or have accounts. Initial engagement counts are zero. User data stays separate from seed content. New external images are optional and require source/license registration if used.

## Feature 2: Notebook — private music inspiration

A private writing workspace with **All / Lyrics / Chords / Ideas**, text search from the upper-right Search button, pinned items, last-edited dates and topic/mood tags. With no private notes, hide categories and show welcome, first-note, writing-prompt and privacy cards. Existing notes replace the welcome state with the note list; unmatched filters have a separate reset card. A visually distinct paper-card layout uses the same palette and typography.

Notes have stable ID, title (up to 80 characters), body (up to 10,000 characters), category, optional mood tag, pinned flag and timestamps. Empty title is allowed for drafts and displayed as **Untitled idea**. Create, edit, save, pin/unpin, duplicate and delete notes. Save uses atomic storage before confirming success; preserve unsaved editor contents after failures. On leaving a dirty editor, offer Save / Discard / Keep editing. Do not silently drop changes or save every keypress.

Provide starter prompts such as an opening lyric, a chord progression and a songwriting idea as optional templates. Templates create editable private notes and are not user-authored content until saved. No AI generation, audio recording, notation editor, music instruction, licensed music catalog or playback is implied.

An explicit **Turn into a post** action copies the note title/body into a Lounge draft. Show that this creates a separate draft and keeps the original note private; never publish or save the community post automatically. If text exceeds the post limit, keep the copied text in the editor with a length warning and require the user to shorten it before saving as a post. Private notes never appear in public member profiles or feed searches.

## Existing modules and Me

Keep Voice room discovery, creation/drafts, seats, local messages, invitations, gifts and safety controls. Keep Chats filters, conversations, drafts, groups, relationship sending limits and private calls. Real RTC and remote message delivery remain unconnected.

Me follows the selected Bibi profile structure with a rounded identity/statistics card, editable avatar/name/bio, wallet, and sticky **Works / Saved / Drafts / About** categories. Works contains the owner's visible Lounge posts; About preserves the private **My notebook** shortcut and voice-room drafts. Member profiles use the same card style and show only that author's visible, non-draft, non-editorial Lounge posts as Works, alongside the existing relationship controls. Their statistics reflect appropriate local post activity and relationships; remove video-derived metrics. Pending video submissions are archived data, not current product items.

## Storage and failure behavior

Add Codable community and notebook state with stable UUID/string identifiers to the existing owned storage root; older installations decode missing new state as empty. Use a shared app-owned state service and serialized, atomic writes so navigation always sees the same persisted state. Keep legacy data decoding intact. Publish success state only after disk commit. Failed saves retain previous data and editable input with Retry; avoid concurrent stale writes overwriting newer edits.

Implementation choice: each post embeds a normalized JPEG (at most 1,200 pixels per side and 1 MiB) in the atomic library snapshot. Photo and text commit together; failure preserves the existing snapshot and input. This removes separate-file orphan and cleanup hazards. Logout retains posts/notes; explicit account deletion clears new state and owned attachments with the existing durable-deletion flow. It never touches the original photo library.

New safety targets need backward-compatible decoding; reports and blocks remain local and must not claim external moderation. Deleted/blocked content must disappear consistently from feed, saved, author profile and linked detail views.

## Visual direction

Lounge uses clean cream cards, coral topic pills, author portraits and generous photo crops. Notebook uses paper-like cards, plum headings and restrained coral highlights. Voice, Chats and Me remain visually consistent. Generate two transparent bitmap navigation icons for community and notebook with the image model; avoid system symbols. Existing matching generated icons may be reused for secondary actions. Accessibility labels are English; controls retain usable hit areas and Dynamic Type behavior.

## Approaches considered

1. **Music community + private notebook (selected feature pair).** Connects social discovery to Voice while adding a useful personal creation space. Proposed implementation uses on-device state and honest delivery labels to match existing service capabilities.
2. **Playlist collection + music diary.** Simpler personal organization but weaker connection to conversations, and useful music playback would require a catalog and rights/service decisions. Not selected.

A network-first version of the selected pair would require authentication, storage, uploads, moderation and API decisions absent from this project. The recommended deliverable is the complete local interaction flow with explicit service boundaries; network integration is a separate scope.

## Verification and acceptance

- No reachable Live/Shorts routes, video composer, video grids or historical playback actions; no bundled performance MP4 assets.
- All five tabs render and remain reachable; navigation works with compact safe areas and keyboard presentation.
- Posts: create with/without photo, edit, draft restore, like/save/comment, search/filter, linked room, report/block, delete and relaunch persistence.
- Notebook: create, edit, unsaved-exit decisions, pin, duplicate, search/filter, delete, relaunch persistence and explicit draft conversion.
- Data roundtrip/migration, failed saves and deletion boundaries receive targeted meaningful tests; no fabricated service success.
- Build and run scheme toti on the existing iPhone simulator after implementation; inspect primary pages and exercise representative local flows. Do not purchase, upload, accept agreements or delete existing user data during validation.

Implementation was authorized by the user, including Xcode running and error repair.

## Editorial profile figures — 2026-11-02

The user explicitly requested plausible simulated data for the six material-author profiles. Approved scope: fixed, disclosed illustrative Likes/Saves/Following/Followers figures on those editorial profiles. This does not authorize fictional Auth identities, online activity, incoming follow relationships, message delivery, payments or modifications to real user statistics. Figures are presentation metadata and cannot enable Message. Values, provenance and validation are recorded in `lounge-editorial-authors.md`; genuine profiles keep their server-derived received counts.

## Full online post detail — 2026-11-02

Editorial publishing and author identities remain separate from member accounts, while their post details now support real Guest likes, saves, comments and private reports. Saved editorial posts appear in Lounge Saved and Me Saved; real chat forwards open the corresponding detail. This supersedes the earlier content-only/read-only interaction description. Device-only editorial follow/block remains unchanged. See [Bibi post-detail comparison, deployed contract and exact verification](post-detail-bibi-parity.md).
