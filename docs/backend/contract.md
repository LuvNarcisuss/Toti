# Toti backend migration contract

Current extension (2026-10-30): private Chat photos/files use the authenticated `toti_send_attachment` RPC and the private `toti-chat-attachments` bucket. Message send restrictions, stable operation receipts, membership/join history, block and current-session checks remain in force. This is separate from public editorial/build assets and moderated profile/Lounge media. See [attachment contract and acceptance](chat-attachments.md).

Current override (2026-10-28): the user replaced email OTP with one-tap Supabase anonymous guest sign-in and enabled the guest integration entry. SMTP is no longer a dependency. Read guest-sign-in.md for the current authentication/recovery contract; the original OTP design below is historical where it conflicts. Business ownership, session isolation and archive rules remain current.

Confirmed on 2026-10-27: create a dedicated Toti project in the selected organization, Singapore; migrate profiles, Lounge, private Notebook, relationships, reports, text chat and room state. RTC and Apple verification remain unavailable until separately configured. The user subsequently authorized dependency resolution, compilation and acceptance on Toti UI Acceptance. With SMTP not configured, acceptance is limited to runnable portions; real login and cloud business acceptance remain pending. Do not commit or push. Preserve all preexisting working-tree changes.

Project: `gjodhvpzkdnxdjmorjfw`. Organization: `gwnugmhdrcxecfbujcvr`. Returned quote: USD 0/month; creation returned ACTIVE_HEALTHY. No previous project configuration is reused.

## Architecture and rollout

Keep UIKit, Swift 5, iOS 16+, the five existing tabs, identity and products. Use the official pinned Supabase Swift SDK. The current integration build sets `TotiBackendConfiguration.usesOnlineBackend=true` and `rolloutEnabled=true`. This enables the Guest path for integration testing; it is not production release acceptance. The online path must never initialize LocalLibraryRepository against the legacy Toti directory, import local balances, use authored accounts, or fall back to local business mutations. An independent read-only archive can expose explicit per-item imports later. No bulk import is authorized.

Use existing model-shaped JSON documents inside server-owned records, with normalized ownership, kinds, parent references, memberships, relationships and operation receipts. The server validates all fields and enforces authorization; JSON is not a trusted client snapshot. No raw table writes by clients. No hard-coded illustrative photographs as real user avatars. Images are private pending revisions until actual media review; deployment is not moderation approval.

## Shared wire contract

`OnlineRecord: Codable` has `id: UUID`, `owner_id: UUID`, `kind: String`, `parent_id: UUID?`, `body: [String: JSONValue]`, `version: Int`, `created_at: String`, `updated_at: String`. Time strings are ISO8601; dates inside existing Swift model-shaped body are JSONEncoder default seconds since 2001. Client must replace author from real profile records and owner_id, never trust supplied author.

RPC `toti_read(p_kind: String, p_cursor: String? = nil, p_parent_id: UUID? = nil)` returns `{records: [OnlineRecord], next_cursor: String?}`. The cursor is server-issued, stable `(created_at,id)` keyset. Supported kinds: profile, post, comment, note, room, conversation, message, follow, block, reaction, report, preference, invitation. Results are authorized for the current active session. Conversations may have `body.peer_id` for direct chats, or `body.name` and `body.member_ids` for groups. Invitations are separately visible without message access.

RPC `toti_mutate(p_operation_id: UUID, p_action: String, p_entity_id: UUID, p_payload: JSON)` returns `{entity_id: UUID, version: Int, status: String}`. All actions require a current auth session and active account; enroll is the exception that creates the active account after anonymous Guest enrollment. Same operation + identical payload returns original receipt; changed payload fails. Supported actions:
- `enroll`: `{agreement_version: String}`; entity ID is the anonymous Guest auth user ID.
- `profile.save`: existing LocalProfile fields; ID is auth user ID.
- `post.save`: LoungePost fields excluding trusted author; owner ID and timestamps authoritative; `isDraft` respected. `post.delete`.
- `comment.save`: `{postID: UUID, body: String}`. `comment.delete`.
- `note.save`: InspirationNote fields. `note.delete`.
- `room.save`: VoiceRoomDraft fields. `room.delete`, `room.join`, `room.leave`, `room.message` with `{text: String}`; room member/seat state is real, RTC remains unavailable.
- `follow.set`: entity target account UUID, `{enabled: Bool}`.
- `block.set`: entity target account UUID, `{enabled: Bool}`.
- `reaction.set`: entity post UUID, `{kind: "like"|"save", enabled: Bool}`.
- `report.save`: `{target_id: UUID, target_kind: String, reason: String, details: String}`; owner-only status.
- `conversation.open`: entity proposed conversation UUID, `{peer_id: UUID}`; unique canonical pair, receipt may return an existing ID.
- `group.create`: entity group UUID, `{name: String, member_ids: [UUID]}`; creates pending invitations atomically, no messages accessible before acceptance.
- `invitation.accept`, `invitation.decline`: entity invitation UUID; acceptance watermark under conversation send lock.
- `conversation.leave`, `conversation.remove`: conversation UUID; remove payload `{member_id: UUID}` requires owner.
- `message.send`: entity message UUID, `{conversation_id: UUID, text: String}`; server limits first contact to one message until mutual following, checks both-direction blocks and accepted membership under lock.
- `preference.save`: entity conversation UUID, `{draft: String?, pinned: Bool?, muted: Bool?, hidden: Bool?, read: Bool?}`; account-owned state, read is personal marker, not remote delivery proof.
- `account.delete`: deny business access immediately and create durable cleanup work; trusted Edge Function completes Auth/Storage cleanup. Never touch local archive.

Follow/block/reaction/preference/invitation records returned by read have generated IDs and `body` containing `target_id`, `kind`, `enabled`, `conversation_id`, `status` as relevant. Profile bodies use displayName/biography/avatarSymbol, no synthetic counters. Read profile is authenticated, excludes blocked/deleting accounts. Post/comment reads respect blocks and moderation state. Notes are owner-only. Reports are owner-only. No local credits or wallet mutation API.

## Client service interface

`@MainActor final class TotiBackend: ObservableObject` exposes `static let shared`, `@Published private(set) var accountID: UUID?`, `@Published private(set) var generation: Int`, `var isAuthenticated: Bool`, `func restore() async throws`, `func signInAsGuest(agreementVersion: String) async throws`, `func signOut() async throws`, `func records(kind: String, parentID: UUID? = nil) async throws -> [OnlineRecord]`, `func mutate(action: String, entityID: UUID, payload: [String: JSONValue]) async throws -> OnlineMutationReceipt`, `func deleteAccount() async throws`. Session storage is Keychain. Serialize authentication and reject late results across generations. `records` must enforce bounds and expose pagination rather than pretending an incomplete fetch is complete. A separate `page(kind:cursor:parentID:)` returns OnlinePage for explicit load-more flows.

Provide `JSONValue` Codable plus `static func object<T: Encodable>(_ value: T) throws -> [String: JSONValue]` and `OnlineRecord.decode<T: Decodable>(_ type: T.Type) throws -> T`. Durable retry journal is account-specific, atomic and single-writer; matching action/entity/payload reuses pending operation ID. On explicit server rejection allow corrected payload; on transport uncertainty preserve ID. Client refresh failures after acknowledged writes must not be reported as failed writes.

## Acceptance boundaries

Author isolated denial/replay/account-switch scenarios but do not execute tests without authorization. Keep production release blocked until current source builds and runs on Toti UI Acceptance, RLS isolation and retry checks pass, RTC and payment dependencies are resolved, and final privacy/consent/publisher requirements are configured. Guest integration itself is enabled in the current source. SMTP secrets are never requested in chat. Initial verification covered metadata, grants, advisors and source only; the later authorized client acceptance is recorded in runtime-verification.md. No fake seed users, incoming messages, online counts or delivery statuses. Editorial Lounge and Voice prompts are read-only Toti content and must be labeled as such.

## Implemented wire refinements

- Exact `p_parent_id` reads select the entity ID for profile/post/room/conversation/note; message/comment use it as a parent filter.
- Read bodies include authorized `owner_profile`; profile `my_following`/`follows_me`, post `my_liked`/`my_saved`, conversation `preference`/`peer_profile`/`member_profiles`, and room `member_profiles` avoid treating a partial directory page as account state.
- Editable models carry optional `backendVersion`; save payloads translate it to `expected_version` (0 for a new record). Editors adopt receipt versions even when refresh fails.
- Journals retain protected payloads for explicit `retryPendingOperations()`, excluding enrollment and account deletion.
- The deletion function was narrowed after approval review to verified self-account requests only; no arbitrary-account HTTP operator route exists.

## Current media and editorial extension — 2026-10-28

Update on 2026-10-30: the user selected Supabase-hosted room materials without new accounts. Migration 010 adds six read-only room-artwork records with six unique covers and eighteen unique portrait characters, returned by authenticated `toti_community_room_materials`. These are separate from actual room objects, memberships, message history and presence. Covers enter the existing room layout; material-only rooms cannot issue business mutations. Public images require no client upload credential. See `official-community-rooms.md` for actual deployment and verification scope.

One-tap Guest authentication is the current entry; the earlier OTP entry is historical. The media request, normalized JPEG validation, private reservation/attachment, review states and owner/foreign projections are specified in media-backend-implementation.md. `uploadMedia`, `mutateWithMedia` and `mediaImage` use protected account-specific retry journals and generation-scoped authorization. Editorial migrations 008 and 009 now return six authenticated official editorial records, with no Auth accounts, member activity or social counters. Local illustration names are accepted only from the editorial asset whitelist, never client-authored member records. See media-acceptance.md for actual evidence and remaining coverage.

## Profile received metrics — 2026-11-02

Profile documents, including embedded owner/peer/member profile projections, expose `like_count`, `save_count`, `following_count` and `follower_count`. Likes/Saves are received reactions across the author's published, non-deleted posts; they are not the viewer's own liked/saved collection sizes and do not depend on a partial feed page. Unknown client metadata remains distinguishable from zero. The private projection keeps existing avatar-review and visibility rules. Profile safety reports use target kind `profile` through the existing authenticated `report.save` operation; this is submission, not completed moderation. See `../profile-bibi-parity.md`.

## Editorial post activity — 2026-11-02

Authored posts now accept real Guest likes, saves and replies through `toti_editorial_activity`; their author identities remain editorial material, not Auth accounts. Four private, default-deny tables hold account-owned reactions, comments, reports and idempotency receipts, with account-deletion cascades. Server counts and viewer flags flow through `toti_editorial_posts`. Member post documents now include save_count without changing media-review conditions. See [the complete contract, retained fixtures and verification boundaries](../post-detail-bibi-parity.md). The earlier read-only editorial description refers to publishing/author ownership, not the newly enabled real Guest interaction surface.
