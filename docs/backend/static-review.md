# Migration static review

Reviewed 2026-10-27 using source inspection only. No compiler, typecheck, resolver, tests, simulator, backend behavior requests or destructive operations were run. This is a concurrent implementation review; the owner must reconcile fixes before final handoff.

## Findings sent to implementation owner

1. **P1: Missing returns after online branches.** `AppStore.messages(for:)`, `isChatPinned`, `isChatMuted` and `LoungeStore.loungeVoiceRooms` were changed from single-expression bodies to multi-statement bodies without adding `return` to the legacy path. This is a source-level Swift compilation blocker. Add explicit returns. The implementation owner is applying these fixes.
2. **P1: Partial directory pages used as authoritative account state.** `OnlineAppStore.refreshOnline` loads only the first page for every kind. The signed-in profile drops out once 50 newer users exist, and `projectOnlineRecords` then presents default profile data which can overwrite the real profile on Save. Missing older profile rows also lose author identity. Missing older reaction/follow/preference rows make existing personal state appear false or empty. Fetch the signed-in and referenced profiles explicitly, and return viewer-specific state with each affected visible record; do not infer absence from a partial directory or personal-state page.
3. **P1: Unknown writes cannot always be recovered after relaunch.** `OnlineOperationJournal.Entry` originally stores only a payload digest, while `begin` rejects a different payload for the same non-event action/entity. A timeout before commit followed by application termination loses the editor text; a later save of that note/post can remain permanently blocked by `pendingChange`. Persist the exact pending payload in the account-protected journal and offer original-request recovery, or use an authoritative operation-receipt reconciliation protocol that can safely settle the pending intent. Documenting the limitation does not restore editability.
4. **P1: Expired sessions leave an unusable signed-out tab stack.** The original generation subscriber only cleared AppStore state; the coordinator routed to login only on `accountExitRevision`, which automatic expiration did not change. This left empty screens and disabled logout. The owner has added an exit revision when an already-projected account loses its generation; verify routing does not race initial OTP/restore transitions.
5. **P1: Editor ownership needs a uniform account-generation guard.** Chat and room drafts have entry-generation checks, but Notebook, Lounge, profile and room-creation save callbacks originally did not. A retained editor or queued callback must never submit old-account content through a newly signed-in account. Capture ownership when the screen is created; check immediately before invoking a store write and after awaits, and disable stale screens. A guard inside transport only protects the account at invocation, not the account that originally owned the editor.
6. **P2: Message insertion does not clear the sender's draft atomically.** SQL `message.send` inserts the message but leaves the existing `preference.draft`; setting `input.text = ""` does not emit editingChanged. Termination immediately after a successful send can restore the already-sent text as an unsent draft. Clear only the sender's conversation draft in the same transaction as message/receipt persistence.
7. **P2: Read and write generations can interleave.** The client serializes individual RPCs but `refreshOnline` assembles a 14-request projection. A mutation can commit between its reads, then the older collected projection can overwrite the acknowledged view. Track a data revision or serialize full snapshot refresh with mutations, and discard stale snapshots. Global refresh also drops active-thread and loaded older pages unless those authorized scopes are reread.
8. **P2: Reported-comment IDs have mismatched case.** Server report target UUID strings are lowercase, while `loungeComments` checks `UUID.uuidString` (uppercase) against a case-sensitive `isContentReported`. Compare parsed UUIDs or normalized strings online. Map report `target_kind=message` consistently rather than the default post kind.

## Source checks without new findings

The inspected Swift SDK API calls match the downloaded `2.55.5` source signatures for AuthLocalStorage, OTP, signOut, user, PostgrestError and RPC responses. Keychain session storage, fixed search paths, scoped RPC grants, actor-derived ownership, current Auth session checks, private Storage defaults and transactional operation receipts were present. This inspection does not prove runtime isolation or successful deployment behavior. Production release must remain blocked until the documented authorized acceptance is completed; the Guest integration flag is enabled in the current source.

## Follow-up source review

The following source fixes were observed without executing code:

- Missing legacy-path returns were added.
- The signed-in profile is read by exact ID; migration `003_scoped_projections.sql` embeds authorized owner/peer/member profiles, viewer follow/reaction state, and per-conversation preferences. This closes the identified partial-profile/toggle-state problem for loaded records.
- Pending operation entries now retain payloads in the account-protected journal. The explicit retry UI calls the bounded `retryPendingOperations` flow, excludes account deletion, and retains transaction identities. Permanent-rejection entries can be cleared for corrected retry.
- Notebook, Lounge, profile and room editors capture account generations. Shared `TotiScreen.save` now checks the screen context before and after work.
- Migration 003 clears the sender's conversation draft in the message transaction.
- Global reads and mutations now exclude one another; mutation refresh explicitly opts into the in-progress write boundary. UUID report comparison is normalized and message reports map to comment presentation.
- Optional model `backendVersion` is converted to `expected_version`, and profile editing captures the original profile snapshot.

Three follow-up findings were sent to the owner for correction:

1. **P1: Premature login routing races explicit logout/deletion.** AppStore's generation subscriber immediately increments `accountExitRevision` during `beginTransition`. The replacement `OnlineEntryController` automatically calls `restore`, which increments the generation again. If logout is queued behind an existing request, restoration can invalidate its epoch before SDK sign-out executes and then restore the old session. Distinguish explicit transitions from unexpected Auth invalidation; route explicit logout/deletion only once their service operation has settled.
2. **P1: Successful Lounge saves retain the previous backend version.** `LoungeComposer.persist` updates `isDraft` and `original` but does not adopt the confirmed version. Saving a new draft twice in the same editor resends expected version 0 after the server has reached version 1. Existing-post saves have the equivalent stale-version failure. Adopt the confirmed receipt version independently of read-refresh success.
3. **P2: Active containers beyond page one still disappear.** Active message/comment windows are re-read, but global refresh replaces the `conversation`/`post` collection with its first 50 rows. A conversation or post opened from a later page loses its parent record after the next refresh, causing the controller to treat still-authorized content as inaccessible and clear input. Re-read the active parent by exact ID through the same authorization boundary.

No additional SDK-signature or new model-memberwise-initializer issue was found in this source review. Runtime/build acceptance remains pending.

## Focused second follow-up

Source inspection observed the three requested corrections:

- `TotiBackend.beginTransition` sets `isTransitioning` before publishing a new generation. Each authentication transition ends it with an epoch-bound defer. AppStore automatically routes only unexpected loss of an already-projected account; explicit logout/deletion routes after the awaited operation. This addresses the identified restoration/exit race.
- `onlineMutation` records the acknowledged version before refreshing. Lounge and Notebook editors adopt that receipt version even if refresh fails; the map is cleared with account state. This addresses repeated saves in a still-open editor.
- Migration `004_exact_entity_refresh.sql` supports exact authorized reads of profile/post/room/conversation/note IDs. Active thread refresh and opening read the parent through that API before loading messages/comments, preserving authorized details beyond the first global page.

A final narrow authorization cleanup was requested: when the exact parent or child read fails, remove the parent record as well as its child records from the assembled/current projection. Otherwise a parent fetched just before a remote access revocation can remain visible as a sendable container. This is the remaining source-level follow-up from this focused review; no broader review was performed in this pass.

These are source-inspection conclusions, not build, runtime, deployment or isolation-test results.

## Final owner reconciliation

The final narrow cleanup is applied: `refreshOnline` removes `records[parentKind]` for the denied parent, and `loadOnlineThread` removes the matching `onlineRecords[parentKind]` before rebuilding the projection. Both paths also remove its messages/comments and active-thread cursor tracking. This was verified by reading the edited source; runtime revocation acceptance remains unexecuted.

All listed source findings now have corresponding changes. This closes the source review ledger only; it does not establish compilation or online behavior. The four deployment identities were independently read back after integration, and the rollout remains disabled.
