# Validated private media implementation

Date: 2026-10-28. Target: dedicated Toti project `gjodhvpzkdnxdjmorjfw`, Singapore. This document records source preparation and static inspection. Deployment, decoder execution, SQL behavior tests and app acceptance are owned by the parent integration task and must be recorded separately with actual results.

## Deployment units

Apply ordered source `TotiMusic/Backend/sql/007_validated_media.sql` after deployed sources 001–006. Local numbered SQL files follow the established repository deployment-source convention; they are not invented Supabase CLI migration timestamps. The Supabase CLI is not present in this workspace. The parent deployer must record the returned remote migration version.

Deploy these authenticated Edge Functions with their own `deno.json` import maps and JWT verification enabled:

| Function name | Source folder | Pinned imports |
| --- | --- | --- |
| `toti-media-upload` | `TotiMusic/Backend/functions/media-upload` | `@supabase/supabase-js@2.57.4`, `jpeg-js@0.4.4` |
| `toti-media-read` | `TotiMusic/Backend/functions/media-read` | `@supabase/supabase-js@2.57.4` |

The functions need the project's existing runtime-provided `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY`. No new provider or moderation credentials are assumed. No secrets belong in source, normal logs or a mobile client. Imports are exact version pins. A deployment-resolved transitive dependency lock is not yet generated; capture it when the authorized deployment tooling supports it. Local decoder execution/typechecking has not been performed by the backend implementer.

Remote read-only schema inspection confirmed `media_revisions` had zero rows and the original minimal columns. SQL 007 adds kind/entity identity, original and normalized SHA-256 fingerprints, reserved/ready upload state and reviewer identity. A private RLS-enabled `media_review_events` table records actual decisions, operator identity, database login, reason and timestamp. Owned revisions and audit events cascade during the existing self-account deletion workflow. No client receives raw table access.

## Byte validation and retry boundary

Upload JSON is `{revision_id, kind: "avatar"|"post", entity_id, jpeg_base64}`. IDs remain stable across uncertain responses. The endpoint accepts only JSON; streams at most 1,400,000 request bytes; limits decoded input and normalized output to 1,048,576 bytes; rejects invalid base64 and checks JPEG start/end markers and supported frame dimensions before expensive decoding. Width/height must each be 1–2048 with at most 4,000,000 pixels.

Every accepted upload then runs a real complete `jpeg-js` pixel decode with `tolerantDecoding:false`, `maxResolutionInMP:4`, `maxMemoryUsageInMB:64`, typed RGBA output and matching pixel/frame dimensions. JPEG magic or supplied MIME/dimensions alone never authorize an upload. A fresh quality-82 JPEG encoder receives only `{width,height,data}`. EXIF/GPS, ICC, comments and other original metadata are not copied. Decoder-provided metadata is deliberately excluded from encoder input. This is file validation and metadata normalization; it does not claim to detect harmful visual content. Client preparation must apply orientation before upload because original EXIF orientation is intentionally removed. Large or malformed files are rejected before any reservation is written. Normalized output over the limit requires a smaller selection.

The Edge Function verifies `getUser(token)`, then calls the caller-context RPC. The database derives actor/session from the verified JWT. Service-only reserve/finalize RPCs additionally recheck the exact live `auth.sessions` row, active account and guest-or-confirmed-user identity; stale JWTs cannot bypass sign-out or account deletion. No `user_metadata` participates in authorization.

Reservation atomically fixes original hash, normalized hash, owner, kind, entity, dimensions, byte size and private path `OWNER/REVISION/NORMALIZED_SHA256.jpg`. Another request cannot change any field for that revision. The reservation is durable before Storage work. Storage uploads use the caller JWT and `upsert:false`. After every upload attempt, including successful writes and retries meeting an existing object, the Edge Function downloads with its trusted service client and hashes the actual stored bytes rather than replacing them. A caller racing its own reserved-path INSERT cannot get different bytes finalized. An immutable object containing different bytes is never marked ready; recovery requires an explicitly newly selected revision, while account cleanup retains ownership of the abandoned object. Finalization requires matching stored metadata and a live session, and returns `{id,entity_id,kind,status,sha256,owner_feedback}` only after the upload is ready. A lost response or interrupted finalize resumes with the same exact JPEG and revision. An unacknowledged revision is never attached automatically.

Source validation failures use 400/413/415/422 before reservation. Reserve refusal uses 409 and preserves the retry identity for diagnosis. Infrastructure/finalization failures use 503 and retain the durable reservation. The client must retain bytes/UUID on uncertain responses, 409 and 503, and may only discard them when the user explicitly replaces/removes the selection or a definitive pre-reservation rejection permits correction. Original bytes must never be logged. Per-account reservations are bounded to 30 per hour and 50 MiB total normalized bytes; failed reservations also count until account cleanup. There is no automatic media garbage collector or external queue.

## Storage and deletion ordering

The bucket remains private, JPEG-only and capped at 1 MiB. SQL 007 removes the original owner SELECT policy. There is no client Storage SELECT/UPDATE/DELETE policy, public bucket, public URL or client signing policy. One INSERT RLS policy accepts only the exact path of a live caller's server-validated reservation; the Edge upload uses that caller JWT so this policy actually executes. Only Edge-held service credentials can read back or sign private objects. Storage bytes are never trusted until the Edge's unconditional normalized-hash read-back succeeds.

`toti_media_reserved_insert` invokes the private `VOLATILE` helper `media_insert_allowed(name)`. The helper acquires the existing business advisory transaction lock and then checks the current caller through `actor()`, including the live session, active account and exact owned reserved path. A fresh post-lock query snapshot prevents an upload waiting behind account deletion from using pre-deletion account state. No Storage schema/table trigger is introduced. The Storage API performs the insert under the supported RLS policy, and there is no UPDATE/upsert policy.

Account deletion takes the same lock before changing account status, so actual metadata inserts are ordered with deletion. The existing deletion plan reads actual Storage paths dynamically and the existing Edge cleanup removes them through Storage API before Auth deletion. Neither new function directly deletes Storage metadata. Pending/ready revisions and review evidence are associated owned cloud data, never local archive files or original Photos assets. Normal immutable upload behavior still needs live compatibility acceptance; do not broaden UPDATE access to work around an unexpected Storage failure.

A caller knows its own reservation path and can try a raw INSERT before Edge upload. This creates no extra authorization: only that caller's already validated reservation is usable, ready revisions cannot be overwritten, owner reads deny reserved uploads, and the Edge always reads/hash-checks stored bytes before its service-only finalizer. Wrong bytes can therefore strand only the caller's own immutable revision. They never become an approved or readable image. Do not eagerly delete an uncertain object, because another concurrent matching retry may have succeeded. Retry the same exact bytes/ID on transient failures; a hash mismatch requires an explicitly new revision. The existing durable account cleanup removes abandoned owned reservations and objects.

## Attachment semantics and projections

`post.save` / `profile.save` accept `media_revision_id`: absent preserves the selected attachment; JSON `null` explicitly removes it; a UUID selects a ready revision owned by the current actor and bound to the matching kind/entity. Raw `photoJPEG` and local `photoAsset` remain rejected. Client approval/status fields are ignored. Existing operation IDs, exact payload receipts, optimistic versions and unrelated business actions retain their contract. The old business implementation is renamed to a private ungranted delegate; the public wrapper explicitly resolves the new media-aware implementation.

Photo-bearing non-draft posts stay `pending` or `rejected` and owner-only until the attached revision is actually approved. Drafts stay private even after image approval. Text-only posts keep the established published behavior. Text edits do not autoapprove pending images. Removing an image is an explicit authenticated save. Existing comment/reaction rules require a published post, so pending/rejected images do not permit foreign interactions.

Post projections add `media_revision_id`, `media_status` and owner-only `media_feedback`; `media_review_status`/owner-only `media_review_reason` are equivalent review aliases. A status value is `pending`, `approved`, `rejected`, or null for no photo.

Profile projections expose only approved `avatar_media_revision_id` publicly. Owners additionally get `avatar_pending_media_revision_id`, `avatar_media_status` and `avatar_media_feedback` plus the review aliases. A replacement remains in the pending field through pending/rejected states, retaining the prior approved avatar for all public surfaces. Approval only promotes the currently selected replacement; reviewing a superseded upload cannot restore it. Explicit removal clears both current and pending references. The shared profile projection also supplies avatars in post/comment owner profiles, conversation peers/member profiles and room member profiles. A rejection of an already approved current avatar removes its public reference immediately.

## Authorized image reads

Read JSON is `{revision_id}`. `toti_media_access` verifies a live current actor on every call. An owner can preview a ready pending/rejected revision while their account is active; a deleted target denies preview. A foreign reader must have an active, unblocked owner and an approved revision still attached to an authorized current post/profile. An approved superseded revision or unapproved bytes never obtain a new foreign read URL. No owner feedback leaks into foreign profile projections.

The Edge Function checks access, signs for 60 seconds, then checks access again before returning `{signed_url,expires_at}` with `Cache-Control:no-store`. Signed URLs are short bearer capabilities: an already issued URL can remain usable until expiry after a block, rejection or sign-out; Storage object deletion invalidates the underlying file. This bounded capability window is an explicit limitation, not instantaneous URL revocation. The client should fetch into an account/generation-scoped memory cache, never persist/log signed URLs, and reject late results after logout/account switches.

## Trusted review operations

There is no automated content decision, external moderation provider or client-callable review route. An operational reviewer must actually inspect normalized bytes and record a decision. Until a trusted operator does this, ordinary user uploads remain pending indefinitely. Deployment alone does not supply moderation staffing.

Use the authenticated Supabase dashboard SQL editor with its database owner/operator connection. `toti_private.review_media` is `SECURITY INVOKER` and has no `PUBLIC`, `anon`, `authenticated` or `service_role` EXECUTE grant. It is not exposed through the Data API. Do not grant it to mobile roles. The operator label identifies the actual human/process responsible; `session_user` separately records the database login.

Read the queue:

```sql
select id,owner_id,kind,entity_id,object_path,width,height,byte_size,sha256,created_at
from toti_private.media_revisions
where upload_state='ready' and state='pending'
order by created_at,id;
```

Open the exact private object through the trusted Storage dashboard or a short-lived operator-only API download. Inspect the normalized image and its intended use. Never approve a filename, hash, fabricated reviewer response or the upload's file-validity result without examining the pixels. Do not share private object URLs in issue text or logs. Generated disposable acceptance pixels may be reviewed only within authorized cloud-fixture scope; this never approves real user files.

Record one real decision, replacing all placeholders with the reviewed revision, operator and specific English owner-facing reason:

```sql
select toti_private.review_media(
  '00000000-0000-0000-0000-000000000000'::uuid,
  'approved',
  'Named Toti reviewer',
  'Reviewed the normalized image and approved its use.'
);
-- A rejection uses the same function with 'rejected' and a useful specific reason.
```

The decision, audit event, relevant attachment promotion/takedown, object state and version update commit together under the existing mutation lock. Review does not publish an unattached revision, restore a removed/superseded avatar or publish a draft. Reinspection may later reject an approved revision; that creates another immutable audit event and withdraws its current public use. The private JPEG is retained for owner feedback/retry and removed by self-account cleanup. For an interrupted review, inspect the audit log and revision before repeating the operation; another invocation records another actual event, rather than claiming idempotent review receipts.

Read back:

```sql
select id,state,upload_state,reviewed_by,reviewed_at,owner_feedback
from toti_private.media_revisions
where id='00000000-0000-0000-0000-000000000000'::uuid;
select decision,operator_identity,database_identity,reason,created_at
from toti_private.media_review_events
where revision_id='00000000-0000-0000-0000-000000000000'::uuid
order by created_at,id;
```

## Parent deployment and verification — 2026-10-28

The parent deployed ordered source 007 as `toti_validated_media`, remote version `20261028092119`, and 008 as `toti_editorial_content`, remote version `20261028092148`. Both versions were independently read back. The JWT-verified `toti-media-upload` and `toti-media-read` functions are ACTIVE at version 1, with deployment hashes `8dda846cb414d1bf0260783f9f99de66eba595628fb060f44da0b93358f1f914` and `6e4fe6a8a2f1fa69eb4c6a178c97f91ec7ffb027de90026c27e2c65284e364a9` respectively.

Read-back confirmed all ten private application tables have RLS and database-owner-only direct ACLs. Storage has only the exact-reservation INSERT policy for authenticated clients; no direct read or replacement policy exists. Review EXECUTE is database-owner-only; reserve/finalize are service-only. No shared-schema default privilege change was made. Security advisors report ten informational default-deny private-table notices and the existing leaked-password-protection warning; this guest pilot has no password entry. Performance advisors report three unused indexes. No RLS opening or unrelated password configuration change was made. See [RLS advisory](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [password advisory](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) and [index advisory](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).

The signed current-source build, eleven scoped recovery/storage tests and one live two-guest media scenario passed on Toti UI Acceptance. Real operator decisions were made only after inspecting the generated normalized fixture pixels. Cloud checks confirmed both accounts and all three fixture objects were removed. This proves the specific scenario in media-acceptance.md, not every case in the acceptance matrix. Normal uploads still require a real reviewer. The original implementer handoff below is historical; its untested scenarios remain outstanding unless explicitly covered by the parent record.

## Verification handoff

Backend implementer performed repository/spec/skill reads, current official documentation review and read-only remote schema inspection. No deploy, build, typecheck, decoder execution, runtime test, operator review or cloud mutation was performed. No historical SQL source was edited. The parent task owns these remaining checks:

1. Apply 007 transactionally and read back new functions/grants/private-table RLS, bucket policies and the private volatile INSERT helper. Run security/performance advisors. Verify `service_role` cannot execute review and authenticated clients cannot reserve/finalize, write unreserved paths, replace Storage objects or set approvals.
2. Deploy both Edge Functions with pinned imports and current project JWT verification. Inspect returned deployment identities/version/hash, and check decoder dependency resolution.
3. With authorized generated disposable pixels and disposable guest identities, verify malformed/non-JPEG/oversized/decompression-limit failures, actual normalized decode, metadata removal, exact duplicate replay, changed-content conflict and interrupted reservation recovery.
4. Verify owner pending/rejected preview, foreign pending denial, real reviewed approval publication, approved-avatar replacement retention, rejected feedback, explicit removal, wrong-owner/kind/entity denial, superseded revision denial, two-direction blocks and revoked-session denial.
5. Race deletion against upload, confirm no late Storage object remains; resume cleanup, remove all fixture bytes/owned rows/Auth and read back cleanup evidence. Preserve device archives and original Photos.
6. Run the latest signed app on Toti UI Acceptance and exercise per-item consent, network failure/retry, remote projections, account/generation cache isolation and UI feedback. Do not call source or deployment evidence production acceptance.

## Sources inspected

- [Supabase changelog](https://supabase.com/changelog) (markdown endpoint unavailable; current HTML inspected, including the announced TLS cipher retirement).
- [Edge Functions Auth context and getUser](https://supabase.com/docs/guides/functions/auth-legacy-jwt).
- [Storage from Edge Functions](https://supabase.com/docs/guides/functions/storage-caching).
- [Private Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
- [Signed URL API](https://supabase.com/docs/reference/javascript/storage-from-createsignedurl).
- [Managed Storage schema constraints](https://supabase.com/docs/guides/storage/schema/design).
- [jpeg-js 0.4.4 decoder/encoder options and license](https://github.com/jpeg-js/jpeg-js/blob/v0.4.4/README.md). Upstream decoder is Apache-2.0-derived and encoder retains its upstream Adobe BSD-style notice; deployment bundles should retain dependency notices.
