# Toti media integration plan

Date: 2026-10-28. Continue the user-requested real backend migration by connecting existing avatar and single-photo Lounge surfaces and restoring appropriate existing artwork presentation. Preserve the original login layout, guest auth, signed simulator build and existing archives. No fabricated members, engagement, activity, review decisions, RTC or payments.

## Shared media wire boundary

- Authenticated Edge `toti-media-upload`: JSON `{revision_id: UUID, kind: "avatar"|"post", entity_id: UUID, jpeg_base64: String}`. Bound request/decoded size. Verify the live actor, actual JPEG bytes/dimensions, normalize or strip private metadata with a pinned real decoder. Store immutable bytes in private toti-media under the caller's UUID. Return `{id: UUID, entity_id: UUID, kind: String, status: String, sha256: String}`. Repeated ID/content returns the existing revision; changed content cannot overwrite it.
- Authenticated Edge `toti-media-read`: `{revision_id: UUID}` returns `{signed_url: String, expires_at: String}` with a short lifetime. Authorize owner pending/rejected preview or an approved currently visible attachment, including block/account status checks. Pending bytes never become public. No public media bucket or client read/replace policy; immutable INSERT requires an exact server-validated reservation.
- `post.save` and `profile.save` may carry `media_revision_id`. The server validates ownership, target/kind and validated revision. An unapproved post photo remains owner-only until a trusted operator actually approves it. Existing approved avatar remains visible while its replacement is pending. Removal is explicit; clients cannot mark approval themselves.
- Owner status/feedback and approved revision identity must reach read projections. Trusted review is an actual SQL/dashboard operation with recorded actor/reason, not an automatic approval claim. Document the operator steps and failure recovery. No external moderation provider is assumed configured.
- Swift backend: `uploadMedia(jpeg: Data, kind: String, entityID: UUID) async throws -> OnlineMediaRevision`; `mediaImage(revisionID: UUID) async throws -> Data` (or equivalent actor-safe image loader). Account/generation checks and durable exact retry bytes/IDs are mandatory. No token-bearing URLs or private data in normal logs.
- Models add optional media revision IDs/status fields with backward-compatible Codable decoding. Server payloads omit binary JPEG/local asset names. UI selection remains per-item explicit, retains prepared JPEG after failures, renders pending/rejected owner feedback, and renders approved remote avatars throughout existing surfaces.

## Tasks and ownership

1. Backend: ordered migration 007+, authenticated upload/read Edge functions, actual file validation, private storage authorization, revision attachment and trusted review. Backend implementer edits only TotiMusic/Backend and its implementation documentation. Root owns deployment.
2. Transport/adapters: Toti/Backend, OnlineAppStore and media model fields. Connect durable upload/retry, authorized memory-only cache and projections; no UI edits. Coordinate final SQL field names with backend.
3. UI: existing photo pickers, post preview and generic portrait/avatar rendering throughout Lounge/Profile/Chats/rooms; owner statuses and preserved prepared input. Coordinate model/transport contract. No project or shared AppStore adapter edits.
4. Root: integration review, asset presentation audit, deployment/read-back/advisors, signed builds, scoped unit and specified-simulator acceptance, temporary cloud fixture consent if expanded scope requires it, documentation and remaining dependencies.

## Verification and boundaries

Existing permission to compile/test the migration and use Toti UI Acceptance remains active; only root runs builds/tests and deployment to avoid shared-state races. Existing explicit disposable guest consent did not include image publication or approval of user files: use only generated disposable test pixels for cloud image acceptance and get concrete approval if automatic review requires it. Never upload private archive items in bulk. No commit/push. Preserve all unrelated dirty changes in this established workspace.

Progress: implementation and migrations 007/008 deployed. The signed current-source build, 11 storage/recovery tests and the authorized two-guest live image scenario passed on Toti UI Acceptance. Both generated-fixture accounts and all three images were cleaned up and independently checked. Both original-entry and real guest/editorial/session-restoration UI scenarios also passed; the additional disposable UI guest was cleaned up and independently checked. The total is 14 tests with no failures. Evidence is recorded in media-acceptance.md. Normal uploads still require actual trusted review before public display; no moderation staff/provider, RTC or purchase verification is supplied.
