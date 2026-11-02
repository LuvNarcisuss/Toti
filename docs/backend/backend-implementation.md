# Toti backend deployment and implementation record

Post activity update (2026-11-02): ordered source 015 deployed as `toti_editorial_post_activity`, version `20261102074537`. Real Guest reactions/comments/reports and request receipts use four private RLS tables and an authenticated wrapper; account-deletion cascades and active-session/ownership checks apply. Member media projections retain review conditions while adding save_count. See [post detail parity and verification](../post-detail-bibi-parity.md).

Voice portrait update (2026-11-02): ordered source 014 deployed as `toti_voice_music_portraits`, version `20261102061858`, changes only the six room materials' people artwork arrays. Eighteen unique music portraits, eighteen catalogs and updated credits passed anonymous public download checks. A current-source UI case passed for three room-seat-to-profile routes; all other routes share the same participant mapping. See [exact sources, verification and limits](../voice-room-music-portraits.md).

Music cover update (2026-11-02): ordered source 013 was deployed as `toti_lounge_music_scene_photos`, version `20261102054628`. Only the editorial photo-name constraint and six existing editorial cover fields changed. Six licensed scene JPEGs, six catalog records and updated credits are publicly hosted in the existing build-assets bucket; anonymous byte/hash checks passed. See [sources and exact verification scope](../lounge-music-scene-photos.md).

Current authentication update (2026-10-28): guest-sign-in.md supersedes the email OTP entry and SMTP prerequisites described in this earlier record.
Date: 2026-10-27. This record covers source, cloud deployment and metadata inspection only. No backend behavior tests, deletion request or production acceptance were performed. Subsequent authorized app builds and limited simulator checks are recorded separately in runtime-verification.md.

## Target and applied objects

Dedicated project: `gjodhvpzkdnxdjmorjfw` (Toti), `ap-southeast-1`, organization `gwnugmhdrcxecfbujcvr`. The parent task created this target after user selection and a USD 0/month quote. Initial public schema and migration/function inventories were empty.

| Ordered local source | Remote migration name | Returned remote version |
| --- | --- | --- |
| `TotiMusic/Backend/sql/001_authoritative_service.sql` | `toti_authoritative_service` | `20261027060430` |
| `TotiMusic/Backend/sql/002_account_cleanup.sql` | `toti_account_cleanup` | `20261027060443` |
| `TotiMusic/Backend/sql/003_scoped_projections.sql` | `toti_scoped_projections` | `20261027061120` |
| `TotiMusic/Backend/sql/004_exact_entity_refresh.sql` | `toti_exact_entity_refresh` | `20261027061848` |

Local filenames are ordered source documents, not invented Supabase CLI migration timestamps. The migration inventory was read immediately before each application. An initial SQL deployment returned a syntax error; inventory and private-schema checks confirmed rollback before the corrected source was applied. The corrected initial migration and the subsequent migrations returned success and were read back in inventory. This is DDL deployment evidence, not behavioral verification of PL/pgSQL branches.

Edge Function `toti-delete-account`: ID `a1fb24e0-fb87-44f3-8b0b-09a425189b2f`, version **1**, status **ACTIVE**, `verify_jwt: true`. Source is under `TotiMusic/Backend/functions/delete-account`. Deployment SHA-256: `274913ab89c5bb28ace01bcb3c06d39a2de909ddb2926cf343dcb8746fa193bd` was confirmed by the subsequent function inventory; recheck inventory when releasing. The function pins `@supabase/supabase-js` to `2.57.4` in `deno.json`; the deploy service resolved its imports. No local dependency installation or typecheck ran.

The first deletion deployment was rejected by automatic approval because permanent deletion needed explicit authorization. The user subsequently authorized authenticated users deleting their own Toti cloud account, associated data and Storage, while retaining the local archive. A second review identified an overly broad operator HTTP branch. That branch was removed. The deployed function derives the account exclusively from `getUser(token).user.id`; no client-selected account ID or operator deletion route exists. Deployment itself deleted no user or file.

## Security boundary

Eight tables are in `toti_private`: accounts, objects, relationships, reactions, members, operations, deletion_jobs and media_revisions. All have RLS enabled. Read-back metadata confirmed `anon` lacks SELECT and `authenticated` lacks direct SELECT/INSERT/UPDATE/DELETE privileges on every application table. No shared-schema default privileges were changed.

Public business wrappers `toti_read` and `toti_mutate` are security invokers with an empty search path and explicit authenticated grants. Privileged implementations reside in the non-exposed private schema with an empty search path, reject missing/expired/revoked/non-confirmed/anonymous sessions, derive the actor from Auth and validate active account status. Raw client documents cannot select an owner or manufacture counts. All ownership and visibility decisions are made server-side. Table RLS deliberately defaults to deny; only narrowly granted authenticated transaction functions enter the private implementation.

`auth.sessions.id`, `user_id` and `not_after` were confirmed present by schema metadata. Sensitive reads and writes require a current matching session row. Neither user-editable metadata nor a stale role flag authorizes operations.

Business mutation and its receipt are in one database transaction. The same actor/operation ID returns the original result only for identical action, entity and payload. Changed payloads fail. An app-specific transaction advisory lock serializes mutations, including account deletion, block/send races, group invitation acceptance and first-contact limits. This favors correctness for the initial deployment and is a throughput limitation; replace only with reviewed lock ordering and concurrency acceptance before larger traffic.

## Implemented API behavior

- Enrollment and editable text profiles with real account IDs and server relationship/post counts.
- Lounge drafts and text posts, text replies, likes and personal saves. Private Notebook notes with existing category, mood and validation limits.
- Two-direction blocks, follows, private reports marked received without fictitious moderator assignment.
- Canonical direct conversations; one first-contact message per sender until mutual follow; real persisted messages without delivered/read claims.
- Atomic group creation and pending invitations, explicit accept/decline, acceptance sequence watermark, owner removal and member leave. Owner departure closes the group.
- Voice room records, capacity-checked active membership, text messages and owner closure. No RTC service is asserted.
- Per-account conversation draft, pin, mute, hide and personal read preferences.
- Server-issued cursor pages of at most 50 records with stable created-at/UUID ordering.
- Cloud deletion first denies business access and creates a durable job, then authenticated Edge cleanup revokes sessions, removes owned Storage objects, removes Auth and completes the job. A job survives Auth removal for trusted dashboard reconciliation after an interrupted final bookkeeping step.

All Swift-body dates use seconds since 2001, matching the existing JSONEncoder behavior; outer record timestamps are ISO8601. Read conversation bodies include `kind`, `is_group`, `member_ids`, caller-relative `peer_id`, `is_owner` and group `name`. Message bodies include `sender_id`, `author_id`, `conversation_id`, `text`, `createdAt` and `sequence`. Profile counters are `follower_count`, `following_count`, `post_count` and `like_count`; post counters are `like_count`/`likeCount` and `comment_count`.

The scoped-projections review added exact-profile reads through `p_parent_id`, per-record `owner_profile`, profile `my_following`/`follows_me`, post `my_liked`/`my_saved`, conversation `preference`/`peer_profile`/`member_profiles`, and room `member_profiles`. These fields prevent page-one truncation from silently producing wrong identities, follow states, like toggles or drafts. Message acknowledgement now clears the sender's draft in the same transaction. A blocked former member's messages remain hidden even after they leave the conversation.

The exact-entity refresh review extends `p_parent_id` to select the exact ID for profile, post, room, conversation and note reads. Comment and message reads continue to filter by their actual parent ID. All paths retain the same session and visibility checks. This lets an open older detail revalidate its parent independently of the first feed page without treating absence from that page as deletion.

## Explicitly unavailable capabilities

- Photo/avatar publication: the `toti-media` bucket is private, capped at 1,048,576 bytes with JPEG allowlisting, and owner read policy requires a live session. No client upload/upsert policy is granted. The media revision table retains pending/approved/rejected structure and owner feedback, but actual byte validation, review workers, approved-media attachment/rendering and operator workflow are not connected. Photo-bearing posts and custom avatar mutations fail explicitly; no unsafe image is silently stripped or approved.
- RTC, push notifications, real delivery/read receipts, Apple receipt verification, wallet credits, gifts/earnings and refunds. There is no client-callable wallet mutation endpoint.
- Automatic archive import. The backend never reads or mutates the device's old library.
- Operational moderation staffing and final agreements/age policy. Reports are stored privately; receipt does not imply external review completion.
- Production OTP email delivery. Custom SMTP and the code-bearing email template have not been configured or verified here.

## Advisor and metadata results

Security advisors returned **8 informational** `rls_enabled_no_policy` findings, one per private table. These tables intentionally grant no direct client access and have default-deny RLS; the warning is documented rather than adding broad policies to silence it. See [RLS enabled without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

Performance advisors returned **7 informational** unused-index findings. The new database had no application traffic or executed acceptance tests; indexes support foreign keys, ownership and cursor queries and were retained. See [unused index guidance](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).

Read-back confirmed the private bucket's public flag is false, its configured size/type restrictions, empty search paths on all Toti functions, no anonymous EXECUTE grant on any Toti function, and service-only cleanup wrappers. An ACTIVE function and successful migration do not establish runtime correctness.

## Documentation checked and remaining release work

Current [Supabase changelog](https://supabase.com/changelog) and current [passwordless email documentation](https://supabase.com/docs/guides/auth/auth-email-passwordless) were inspected. The markdown index could not be fetched by the parent tool; the official HTML changelog was used. The [2026-06-03 email-template change](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier) states new free projects using default SMTP cannot customize templates; a custom SMTP provider restores customization. Toti's numeric OTP flow therefore needs an owned SMTP sender and a template including `{{ .Token }}` before rollout. No SMTP secret should be placed in chat or source.

Official [admin sign-out](https://supabase.com/docs/reference/javascript/auth-admin-signout), [admin deletion](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser) and pinned Auth client source were consulted for cleanup semantics. Current [authorization-header documentation](https://supabase.com/docs/guides/functions/auth-headers) explicitly supports both legacy HS256 and new asymmetric signing keys in the platform check and recommends keeping it enabled for signed-in user calls. The implementation therefore keeps JWT verification enabled and performs its own `getUser` check as well. Valid and invalid token behavior remains untested.

Run the scenarios in `TotiMusic/Backend/acceptance/README.md` only after explicit authorization and the required current-source build/install/launch on Toti UI Acceptance. Keep production release blocked until isolated access/replay/lifecycle checks, Guest business integration, RTC/payment dependencies, app integration and release requirements are actually accepted.

## Editorial expansion deployment — 2026-10-30

Migration `20261030020728` (`toti_editorial_content_expansion`) was applied to project `gjodhvpzkdnxdjmorjfw` and read back successfully. It adds three published, read-only editorial posts to the existing three records. The records contain no Auth identities, member ownership, social reactions, presence counts, chat history, or delivery claims. The database currently contains six published editorial rows. Security advisors continue to report the existing informational default-deny RLS findings and the project-level leaked-password-protection warning; the performance advisor returned no findings.

## Private Chat attachment extension — 2026-10-30

Migration `toti_private_chat_attachments` (`20261030091742`, source 011) adds private immutable chat storage and an authenticated attachment-send wrapper around the existing message policy/receipt path. After separate explicit user authorization, `toti-delete-account` was updated to version 2, ACTIVE, JWT verification enabled, deployment SHA-256 `46a5b597126cb8c11c2a5850292768d925f59428ff6d5f3d47dbd9dfd2871e91`, adding caller-owned attachment cleanup. No deletion was invoked. See [contract, successful backend/UI acceptance and retained fixtures](chat-attachments.md). The original function v1 record above is historical.

## Received profile Saves — 2026-11-02

Ordered deployment source `TotiMusic/Backend/sql/012_profile_received_saves.sql` extends the existing private `profile_document(uuid,uuid)` projection with received `save_count`. Applied migration: `toti_profile_received_saves`, version `20261102025816`. Counts include real saves on published, non-deleted posts by the target author, independent of the first client page. Existing avatar approval/pending-review visibility, account/block guards and revoked anon/authenticated direct function execution remain intact. Read-back on the two retained Guests matched independent aggregate counts (zero received likes/saves). No business records, users, media or relationships were created, modified or deleted by the migration. See `../profile-bibi-parity.md` for client changes and scoped validation.
