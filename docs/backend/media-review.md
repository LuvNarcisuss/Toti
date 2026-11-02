# Media integration static review

Date: 2026-10-28. Scope: the current media integration source, against `media-integration-plan.md`, the backend contract and current repository rules. This independent review changed documentation only. It did not build, typecheck, run tests, deploy, approve media, upload photos or alter account data. Runtime and cloud acceptance belong to the parent integration task and must be recorded separately.

## Findings

### P2: Revoking a previously approved avatar loses owner feedback

In `TotiMusic/Backend/sql/007_validated_media.sql`, `review_media` removes `avatar_media_revision_id` when an approved current avatar is later rejected (lines 258–259). With no replacement pending, `profile_document` can then find neither the pending revision nor an approved current revision (lines 289–294). The owner receives null status and feedback, so the avatar disappears without the rejection notice or reason required by the media plan. Foreign access is correctly denied after the current reference is removed.

Keep an owner-only rejected review reference when withdrawing the current avatar, without replacing a newer pending selection. Continue to omit it from foreign projections and retain the explicit current-attachment check in media reads. Acceptance should cover approve, reject the same current avatar, owner feedback/private preview, foreign denial, and rejection while a newer replacement is pending.

### P2: Pre-reservation validation rejection can leave an orphan retry lock after disk failure

`TotiBackend.executeMediaUpload` ignores failure to durably remove a definitively rejected media entry before throwing `invalidMedia`. Both `mutateWithMedia` and `retryPendingOperations` then independently attempt to remove the associated operation. If media cleanup fails but operation cleanup succeeds, `OnlineMediaJournal.begin` still rejects different bytes for that entity/kind, while Retry has no owning mutation to finish. This is a failure-path limitation, distinct from uncertain network outcomes which correctly retain identity and bytes.

Require durable media cleanup before releasing the corresponding operation for these validation rejections. Propagate `localPersistence` when cleanup fails so both submitted records remain recoverable. Cover the direct save and explicit pending-retry paths with an injected media-persistence failure and a successful operation-persistence path.

## Findings fixed during review

- A definite SQL rejection previously removed only the operation and left an uploaded-media intent blocking a replacement. The reviewed `OnlineMutationRecovery.discardRejectedIntent` now accepts only authoritative PostgreSQL rejection codes, matches the precise action/entity/revision/kind, durably removes the media intent first and then removes the operation. Both direct saves and pending replay call the same `executeMutation` recovery boundary. Timeouts and other unknown outcomes retain the original identities and exact bytes.
- Opening the signed-in author's online comment previously constructed the local `signedIn` identity and default photograph. `LoungeControllers.swift` now uses that helper only in local mode; online comments retain their account UUID and approved remote-avatar projection.

These closures are source inspection conclusions, not executed regression results.

## Reviewed protection boundaries

- Media upload journals are account-specific, actor-owned, atomically written, protected on disk and excluded from backup. They read only explicitly submitted JPEG data. Repeated matching bytes reuse the revision ID. A record intent is persisted before upload starts.
- Every `mediaImage` request, including an in-memory cache hit, obtains fresh authorization. The download session is ephemeral, disables HTTP caches/cookies/credentials, bounds incoming bytes/dimensions and refuses redirects. Account generation changes clear the memory cache. Signed URLs are not journaled or normally logged.
- `TotiPhoto` cancels obsolete work and checks the request UUID, account generation, cancellation and visible window before rendering a late result. Its generation observer withdraws already displayed remote photos on an account transition. Pickers check their originating account generation; Lounge additionally checks a preparation token.
- Adapters strip local JPEGs, local asset names, client-authored status/feedback and untrusted author identities from record mutations. Post null explicitly removes media; profile omission preserves the selected attachment. The server independently checks revision owner, entity, kind and ready state. Acknowledged writes stay successful when the subsequent refresh fails.
- Approved avatars are projected into owner profiles, post/comment owner profiles, conversation peers/groups and room members, then rendered through the shared remote-capable portrait helpers. Avatar replacements remain owner-only while the existing approved avatar remains current.
- Final source `007_validated_media.sql` uses a volatile security-definer reservation callback with an empty search path and the existing application advisory lock. The sole new Storage policy permits authenticated INSERT only for the live caller's exact server-reserved path. It adds no Storage trigger, SELECT or UPDATE policy. The Edge Function uploads with the caller JWT and `upsert:false`; it unconditionally downloads the stored object with service credentials and verifies normalized size/hash before finalizing. A direct caller racing its own reservation cannot make mismatched bytes ready through the reviewed endpoint.
- The upload endpoint bounds request and decoded sizes, performs an actual pinned JPEG pixel decode, and re-encodes only decoded pixels. Original EXIF/GPS/comments/other metadata are not copied. Validation is distinct from visual approval.
- Foreign reads require an active unblocked owner, an approved ready revision, current attachment identity and current entity visibility. Explicit `IS DISTINCT FROM` comparison prevents absent attachment fields from authorizing via SQL NULL. The read Edge Function checks access before and after signing. A previously issued bearer URL retains its documented maximum 60-second capability window.
- Trusted review is private SQL only, records the reviewer/reason/database identity and promotes only the currently selected revision. Pending/rejected post images remain owner-only; drafts remain private after approval. Removing or superseding an attachment does not restore an old public revision.
- Archive browsing directly decodes the independent original snapshot and does not instantiate its migrating repository. Each copied item requires explicit consent; image posts show the selected prepared pixels and become private drafts. Stable account/source-derived import IDs avoid creating a new item after an uncertain retry. Original archive files, original Photos items and old wallet credits are not modified or imported.
- Migration 008 stores official editorial content separately from member accounts. Its UI labels the content and illustrative photography, has no fabricated people/engagement, and creates a separate editable composer only on a user action.

## Verification boundary

No deployment blocker was identified in the final reviewed RLS/caller-upload/hash-readback design. That statement does not establish deployed grants, Storage API behavior, decoder runtime compatibility, deletion race handling, two-account behavior or signed-simulator UI acceptance. The parent must use current source and Toti UI Acceptance, exercise authorized generated disposable pixels, and record actual results separately. Outstanding findings above remain source findings until their fixes are read back and their targeted checks are run.

## Integration closure — 2026-10-28

The parent fixed both remaining P2 findings before deployment: withdrawing a currently approved avatar retains its owner-only rejected reference unless a newer selection exists, and authoritative upload validation rejection now requires durable media-journal cleanup before releasing its business operation. Cleanup failures propagate rather than silently orphaning the photo intent. The online comment identity correction is also present.

Eleven signed simulator storage/recovery tests passed, including five media tests for restart-stable bytes/IDs, account isolation, durable acknowledgement/attachment, definite rejection correction and uncertain outcome preservation. One actual two-guest cloud image test passed for pending denial, real review, approved reads/rendering, replacement rejection, owner feedback and cached-read denial after blocking. Fixture cleanup was independently confirmed. These tests do not inject a disk failure or execute the approved-current-avatar revocation variant; those closures remain source-reviewed rather than runtime-covered. See media-acceptance.md.
