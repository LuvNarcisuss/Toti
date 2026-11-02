# Voice room interaction alignment with Teto

Date: 2026-10-30. Source inspection only; the user requested no build or app run.

The reference is `/Users/apple/Desktop/Teto/Teto/Features/Parties/PartyControllers.swift`, including `PartyRoomController`, `InviteSeatView`, the invite picker, composer, seat controls, message replies and share flow. Toti retains its cream/plum/coral theme, photographs, icons and button styling.

The earlier material-only room implementation hid Invite and gifts, disabled the composer and displayed a blocking microphone alert. Those restrictions were removed from the illustrative interaction path.

Current-user avatar correction: Profile, Edit profile and the current-user room seat share `AppStore.configureOwnerAvatar`. Online mode uses the current approved avatar revision or TotiMark, matching Me. Local mode uses the saved custom photo or the shared local fallback. Room refresh observes profile changes without recreating illustrative conversation state; unchanged avatar references do not restart image loads. A pending replacement does not replace the last approved avatar. Both the local-owner seat and authenticated UUID membership use this shared renderer.

| Reference behavior | Toti source behavior |
| --- | --- |
| Current user plus three seats | Restored for illustrative rooms; actual server rooms retain actual membership |
| Plus-avatar invitation control | Always present; opens the same friend picker and its Add a friend empty state |
| Invitation action | Uses `sendChatMessage` and waits for the real account acknowledgement in online mode |
| Microphone and speaker controls | Toggle local state and seat indication without repeated unavailable alerts in illustrative rooms |
| Text composer | Accepts local messages in illustrative rooms; actual room messages use authenticated mutations |
| Tap a message to reply | Quote chip, input focus and send-to-local-room behavior restored |
| Scripted room conversation | Runs only for clearly disclosed illustrative rooms; pauses on background, closes on departure and stops at account changes |
| Message scrolling | Existing capped list, scroll-to-bottom and New messages control retained |
| Character seats | Open photographic character details; no fictional Auth identity, follower count or message recipient is created |
| Gift entry | Opens the catalog with recipients and quantity controls; online sending is visibly disabled and cannot debit a balance |
| Share entry | Restored to the existing share flow |
| Comment safety | Illustrative messages can be hidden for the current visit; actual message reports keep the authenticated reporting path |

Illustrative room messages are memory-only and remain separate from real chat, room membership, wallet and personal data. The local conversation loop does not create cloud messages or delivered/read status. It never runs in an actual online room. Local microphone toggles do not claim audio transport; the existing no-RTC and unavailable-purchase decisions remain in force.

Actual member profiles, server moderation, persistent rooms, authenticated text delivery and purchases cannot be equated to Teto's authored local character interactions. These service differences are intentional and must not be reported as a completed real audio service.

Static validation: source comparison, event-route inspection and `git diff --check`. No compilation, typecheck, installation, simulator interaction or runtime tests were performed for this correction.

## Shared music portraits — 2026-11-02

Eighteen new distinct music-person photographs replace the material-character portraits. Cards, seats and character profiles retain the same PartyParticipant asset/artworkURL, while the current-user seat retains configureOwnerAvatar to match Me. Stable seat/portrait accessibility identifiers support the focused route verification. See [sources and current verification scope](voice-room-music-portraits.md).
