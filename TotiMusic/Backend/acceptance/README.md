Current update (2026-10-28): one-tap guest auth replaces OTP. Authorized guest registration/enrollment, private note isolation/retry, refresh and self-cleanup passed. See docs/backend/guest-sign-in.md. guest_auth.py runs real disposable cloud operations only with explicit --allow-disposable-cloud-data authorization. The broader scenarios below remain pending unless explicitly covered by that record.

# Backend acceptance scenarios — not executed

These scenarios require explicit test authorization. First follow the repository prerequisite: build current source, install and launch it on **Toti UI Acceptance**, and use that same device for every simulator destination. Never run against real customer accounts. Use at least three disposable confirmed email accounts (A, B, C) and a separate observer/operator. Provisioning metadata checks are not substitutes for these scenarios.

## Identity and permissions

1. Anonymous `toti_read` and `toti_mutate` calls fail; direct REST table access does not expose `toti_private`.
2. Authenticated but unenrolled A cannot read business collections. Enrollment must use A's UUID and a nonempty, available agreement version.
3. An unconfirmed email user, anonymous Auth user, expired JWT and signed JWT whose `session_id` no longer exists cannot read or mutate.
4. A's profile UUID cannot overwrite B's profile. Spoofed author, owner, timestamps, counts and extra payload fields never replace server ownership fields.
5. After account deletion is requested, old still-signed access tokens cannot read or mutate any business data. Account deletion completion must remove Storage before Auth.
6. SQL inspection must show all application tables have RLS and no client table grants; only the two business wrappers are executable by authenticated callers. Cleanup wrappers are service-only.

## Receipts and concurrent writes

7. Replay one successful operation UUID with identical action/entity/payload: return the exact original receipt without another row, membership or message.
8. Replay the same operation UUID with changed action, entity or payload: reject. Restore a pending operation journal across app restart and repeat the same case.
9. Simulate a lost response after transaction commit: retry returns the durable receipt. A subsequent refresh failure must not trigger another publication.
10. Supply `expected_version` on an edited object and race two edits: the stale edit fails with a conflict and preserves editable client content.
11. Send two simultaneous first-contact messages from A to B before mutual following. At most one succeeds. Add a simultaneous block and verify serialized access checks.

## Content, Notebook and safety

12. A's drafts and notes are not visible to B. Notebook categories, title/body limits, mood enumeration and body dates decode correctly in the app.
13. Public posts and replies are readable by other active accounts; a blocked relationship in either direction hides the accounts' content and denies interaction.
14. Posts reject empty/overlong published text but retain allowed overlong drafts. Replies enforce 500 characters; notes enforce 80/10,000; profiles enforce 30/160.
15. Attempts to publish `photoJPEG`, `photoAsset` or `hasCustomAvatar=true` fail explicitly. No unsafe bytes become public. The bucket stays private and has no client upload/upsert policy.
16. An accepted report is private to its reporter, says `received`, and never claims a moderator was assigned. A user cannot report their own item or a target they cannot read.
17. Delete a post and confirm its comments disappear from authorized reads. Foreign-owner edits/deletes fail. Room deletion removes active membership and denies old detail views.
18. Capture every local legacy file hash before login, logout, failed import, online edits and cloud deletion; hashes and original paths remain unchanged. No legacy wallet credit is promoted.

## Chat and room membership

19. Concurrent A→B and B→A direct-open operations return the same conversation. No duplicates appear after lost acknowledgements.
20. A group with one invalid, blocked, duplicate or non-mutual invitee rolls back both group and invitations.
21. B can read a pending invitation but cannot read group messages before accepting. Acceptance records the message sequence watermark under the send lock, so earlier history stays inaccessible.
22. Invited B accepts while A sends: only messages with a sequence after B's accepted watermark are visible. Declining does not grant membership.
23. Removed or departed B loses access immediately, including while viewing the conversation. Refresh must clear the detail screen and prevent sending.
24. Only the group owner can remove another member; the owner cannot remove themself through that action. Owner leave closes the group. Direct chat removal is rejected.
25. Room joins respect 4/6/8 capacity and both-direction blocks. Repeated join does not duplicate or reset an active member's history watermark. Owner leave closes the room.
26. Room messages require active membership and are real stored text only. Microphone/camera/gift controls must not imply unavailable RTC/payment success.
27. Personal drafts/pin/mute/hide/read preferences cannot affect another account. A `read` preference is not a delivery or peer read receipt.

## Pagination, lifecycle and cleanup

28. Request more than 50 items, follow each returned cursor, and verify deterministic `(created_at,id)` order without duplicate IDs. Reject cursors from a different kind or parent.
29. During an in-flight page, mutation, OTP verification or draft task, sign out and log into another account. Late results must not appear or persist under the new account.
30. Stop deletion after Storage removal, after Auth removal and before final bookkeeping. Owner retries can resume while Auth exists. After Auth is gone, a trusted administrator reconciles the retained job through service-only cleanup APIs; no arbitrary-account HTTP deletion route exists.
31. Validate the deployed JWT verifier accepts the project's current signing-key algorithm and the function's `getUser` check rejects invalid tokens. Do not disable authentication to make a request work.
32. With more than 50 profiles, ensure the signed-in profile and all visible owners resolve through exact-profile/scoped projections; toggles and chat drafts must not depend on the first global page. Send a message, restart, and verify the acknowledged text is absent from the stored draft.
33. Open an older post, room or conversation beyond the first feed page, refresh the first page and verify its exact-ID parent read preserves the authorized detail. Then revoke access or delete that parent and verify the same exact read no longer reveals it; message/comment parent filters remain unchanged.
34. Verify custom SMTP sender/domain, OTP template `{{ .Token }}`, code expiry/reuse/rate limits and delivery to accounts outside the organization before opening rollout.

Record observed command, environment, server versions and result for each authorized scenario. None of these cases has been executed during source preparation/deployment.
