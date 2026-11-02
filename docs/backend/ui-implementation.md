# Online UIKit integration

Current authentication update (2026-10-28): guest-sign-in.md supersedes the email OTP entry and SMTP prerequisites described in this earlier record.
Status: source integrated and statically inspected on 2026-10-27. Following explicit user authorization, the current app built and the preparation-entry UI test passed on Toti UI Acceptance. Authenticated screens and business flows remain unverified; see runtime-verification.md.

## Entry and account lifecycle

- The online coordinator opens `OnlineEntryController` without calling legacy `store.load()`.
- The current Guest-enabled entry displays the original welcome, agreement consent, and online enrollment state, with no local-data fallback. Production release blockers remain visible in the release checklist.
- The current Guest entry uses explicit consent to the bundled agreement version, then anonymous Supabase enrollment, session persistence, progress, and visible errors. The earlier email/code flow is historical. Restored sessions still require a successful authorized data refresh before opening tabs.
- Settings account actions use online-specific wording. A Local archive entry opens the root-owned read-only archive/import controller.

## Existing surfaces

- Lounge and Notebook retain existing layouts and editors. Online saves/replies use account/community wording. List refresh/load-more controls expose bounded reads and errors.
- Me identifies owned posts by `author.isLocalOwner`, uses a neutral Toti mark for unconfigured portraits, and does not show fabricated profile counters. The account list count says how many items are shown.
- Chats uses real profile records for finding friends and creating groups. Invitations have accept/decline controls; group members support owner removal and leaving. Conversation history is read for its parent ID on entry and pull-to-refresh. Load-more is explicit.
- Delayed chat draft writes are bound to the controller's original session generation. A removed/inaccessible conversation clears editable input and disables sending. No controller snapshot is used as a remote history fallback.
- Voice discovery uses online rooms. Room entry performs join and fetches its authorized history; closing/leaving requests membership removal. The member strip uses real member records. Text message success follows backend acknowledgement. Microphone and speaker actions explain unavailable live audio; text does not animate a speaking indicator.
- Online room counts describe members, never online presence. Room reporting/blocking resolves the actual owner through the adapter.
- Reports are described as submitted, not reviewed. Submitted report cards do not offer local deletion as if it reversed server submission.

## Unavailable dependencies

Photo selectors, calls, diamond purchasing and gifts fail closed in online mode. They do not fall back to existing local actions or initiate camera/payment flows. Media-review/RTC/Apple configuration and acceptance remain release dependencies.

## Static checks and remaining acceptance

`git diff --check` completed without whitespace errors. Source inspection traced the online entry, known catalog uses, mutation controls, delayed drafts, photo/call/payment guards and server-message wording. These observations do not establish compilation, layout, Guest enrollment, server authorization or multi-device behavior.

Pending acceptance: current-source build/install/launch on Toti UI Acceptance; OTP expiry/resend/sign-out races; large Dynamic Type and keyboard layouts; member removal/revoked access while open; pagination during refresh; join/leave on sheet dismissal; server acknowledgement followed by refresh failure; offline drafts; group invitation acceptance watermark; legacy archive preservation. Parent-specific cursors and periodic reconciliation are owned by `OnlineAppStore` and require joint integration verification.

## Static review follow-up: retained controllers

A subsequent source review identified retained editor and photo-picker callbacks as an account-switch boundary. Notebook editors/list actions, Lounge composers/replies/room selectors, profile editing, room creation, active room actions and report forms now capture the backend generation when constructed. Saves check that generation both when scheduling and immediately before entering the store; asynchronous completions check again before updating their controller. Notebook-to-post conversion and pending photo callbacks cannot move previous-account content into a new editor/account. Online room creation explicitly sets the voice room type.

These fixes were inspected in source and `git diff --check` passed. Runtime account-switch, delayed picker and suspended-save scenarios remain unexecuted. The shared `TotiScreen.save` confirmation wrapper is additionally guarded by the parent integration task.
