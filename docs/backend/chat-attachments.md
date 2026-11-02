# Private chat attachments and composer — 2026-10-30

## Current behavior

The chat composer is one full-width row: a flexible Message input, Send (44 points), then Add attachment (44 points) at the right edge, separated by 8-point gaps and 12-point outer margins. It follows the keyboard. Empty hints and the attachment strip do not reserve blank rows.

Add attachment opens Photo and File choices using PHPicker and UIDocumentPicker. One selected item is staged locally with filename/size and a Remove action. Selection does not upload anything; Send is the explicit transfer action. Photos are normalized with the existing ImageIO path to JPEG, at most 1 MB and 1,200 pixels. Files must be regular, non-empty files of at most 10 MB. Files are copied/read only after explicit picker selection; original Photos/Files items are not modified.

Sent photos have a bounded thumbnail and View photo action. Files have filename/size and an explicit Files export action. Downloads require current authorization. Incoming file contents are not executed or embedded into a WebView. Image previews are downsampled before rendering.

The existing text path and first-contact/mutual-follow rules remain authoritative. Attachment sends retain selected bytes and a stable message/operation identity through uncertain upload/finalization. A failed send keeps the selection. Its caption is frozen for retry; the user must retry a pending send before replacing/removing it. A successful send clears its staged item, and a durable journal completion releases its private local upload bytes. Unsent selections before Send are memory-only and are not restored after process termination.

## Backend contract and deployment

Dedicated project: `gjodhvpzkdnxdjmorjfw`. Migration `011_private_chat_attachments.sql` deployed as `toti_private_chat_attachments`, version `20261030091742`.

`toti-chat-attachments` is private, with a 10 MB object limit and JPEG/octet-stream content types. Paths are `<owner>/<conversation>/<message>.jpg|bin`. Authenticated insert checks a live Guest session, owner path and an accessible conversation. Authenticated reads recheck conversation membership, message join-sequence visibility, blocking and account status. Before publication, only the owner can read a staged upload. No client update/delete policy is granted, so published bytes cannot be replaced or removed by a chat participant. No public URLs or upload/private keys are used by the app.

The authenticated security-invoker RPC `toti_send_attachment` calls a non-exposed validating function. It checks the actual uploaded Storage metadata and fixed owner/conversation/message path, then calls the existing message mutation to enforce send limits and operation receipts. Message creation and attachment association commit together. Replays cannot change attachment metadata. Existing text mutations cannot insert attachment metadata directly. ChatMessage has an optional Codable attachment field, preserving older saved messages.

The existing durable operation journal now dispatches `message.attachment`, preserves its file bytes across uncertainty and recovers it within the same account scope. Pending bytes are held under that account's protected app storage, separate from the legacy archive.

## Account deletion integration

The owner-only deletion plan/completion checks include the new bucket. Initial automatic approval rejected replacing the production deletion Edge Function because the attachment task did not separately authorize that high-impact endpoint. The user then explicitly authorized deployment, while prohibiting actual account deletion. The updated `toti-delete-account` was deployed as version **2**, ACTIVE, JWT verification enabled, package SHA-256 `46a5b597126cb8c11c2a5850292768d925f59428ff6d5f3d47dbd9dfd2871e91`.

Only the authenticated caller's own paths are removed when that caller later requests account deletion. Empty bucket lists are skipped. No arbitrary-account/operator HTTP route is added. Deployment did not invoke account deletion, and retained acceptance accounts/data remain intact. Destructive deletion acceptance was intentionally not run under the user's retention instruction.

## Verification

The current signed Debug source builds on Toti UI Acceptance, iOS 26.0, device `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`.

`ChatAttachmentOnlineAcceptanceTests/testRetainedFriendsExchangePrivatePhotoAndFile` passed (35.863 seconds). It restored the two existing isolated Guests, sent generated orange JPEG pixels and harmless text bytes, verified the recipient downloads were byte-identical, rejected public download, revoked authenticated attachment access while blocked, and restored the original mutual relationship. No new Guest account was created and final fixtures were retained. Evidence: `/private/tmp/toti-chat-attachments-service.log` and `/private/tmp/toti-chat-attachments-service.xcresult`.

Retained conversation: `ace0a7c3-5a24-4051-8079-244937122078`. Photo message: `cf67d9ec-387c-4ad9-bc0d-8f585e8e2dee`. File message: `c6685741-5017-436f-8811-8c99bc453252`. These are identifiers, not credentials.

Two initial UI attempts lost their app connection because another purchase acceptance installed the same app on the same simulator. Device logs record installcoordinationd terminating the test process during installation; these runs are not passing UI acceptance. After the other build processes ended, the current working tree was rebuilt and installed again. The next isolated run passed row geometry but exposed a stale busy-state UI issue: `loadOnlineThread` did not publish read completion, and composing/attachment choice was tied to read activity. Read completion now publishes state; composing/choosing is independent of background reads while Send retains its mutation gate. A 45.743-second UI case then passed with the intermediate left-side plus layout.

The user subsequently moved the plus to the right of Send. The final `testChatComposerWidthAndAttachmentMenu` passed (65.826 seconds, zero failures/skips) against the current signed build. It asserts input width greater than half the screen, Input/Send/Add ordering and bounds, enabled composition, Photo/File choices, opening/cancelling both native pickers, opening a received image and opening the received file's native Save page. It does not save into the user's personal Files directory. Evidence: `/private/tmp/toti-chat-composer-verified-ui.log` and `/private/tmp/toti-chat-composer-verified-ui.xcresult`.

The earlier reordered run reached the file export page but failed an automation-only Cancel expectation; iOS 26 exposes Save/back controls there. The final assertion checks the actual Save entry instead. A test-only screenshot-method name collision was corrected and rebuilt; the mistakenly started old test process was stopped and is not counted as acceptance. No failed/interrupted run is counted as passing.

A final read-only check confirmed the bucket remains private with its 10 MB limit, anon cannot execute the attachment RPC, authenticated Guests can call the guarded RPC, and both retained accounts plus both attachment objects still exist. The latest build is relaunched on the specified simulator after acceptance.

Security advisors reported the existing private tables' intentional deny-by-default RLS/no-policy information, Guest-session access warnings for the new Storage policy, and the existing password-protection warning. The Storage policy intentionally supports authenticated anonymous Guest accounts, not the unauthenticated anon role, and validates the live session and membership in its guarded private function.

This scope does not establish physical-device/iOS 16 behavior, every document provider, large-file/background upload, attachment-specific process-kill/lost-ack recovery, third-party non-member/group-history matrices, malware scanning, storage quota/orphan expiration operations, or destructive account cleanup. No production or content-moderation acceptance is claimed.
