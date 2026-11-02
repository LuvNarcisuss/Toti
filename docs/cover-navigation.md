# Lounge and Voice cover navigation

Updated on 2026-10-30.

Lounge post covers open the same `LoungeDetailController` as the existing Read & reply action. Both bundled images and validated remote photo revisions use this cover control. Existing media visibility and account-generation checks remain in place.

Official Lounge editorial covers open `TotiEditorialDetailController`, showing the selected title, photograph, complete text and editorial disclosure. Opening editorial content does not create a post, join a room, start a call or imply member activity. Existing Write about this actions remain separate.

The initial Voice editorial-to-article route was superseded by the user's correction on 2026-10-30. Voice follows the reference Teto flow: genre filtering, two-column room cards and direct full-screen entry into `PartyRoomController`. Editorial article cards were removed. Real room entry resolves the current backend record and rejects unavailable or hidden rooms; member seats, invitations and text continue to use the backend. Existing full-cover hit testing preserves actual member profile actions.

The user subsequently requested room materials stored in Supabase without creating accounts. Six published material records now provide distinct covers and eighteen illustrative character portraits. Their `community-artwork:` IDs and explicit flag keep them separate from real room UUIDs. They enter the same room layout. The later Teto-parity correction restores local messages, replies, scripted illustrative conversation, local microphone/speaker state, character details, sharing and the plus-avatar invitation picker. Invitations use real Chats; material-room text remains local. They do not create backend membership, fake profile identities, audio transport or gift transactions. See `docs/voice-room-interaction-parity.md`. Room-artwork portraits are not labeled as member counts. An empty list still offers real room creation. See `docs/backend/official-community-rooms.md` for deployment and media verification.

Reference source inspected: `/Users/apple/Desktop/Teto/Teto/Features/Parties/PartyControllers.swift`, `PartyModels.swift`, and the existing Toti room controller, model and backend projections. Teto's authored rosters and local counts are not valid Toti online activity and are not copied. Actual Toti membership and room text continue to use the backend. The user's no-RTC decision remains in effect: microphone/audio transport is unavailable and must not claim successful transmission.

The cover is a full-size accessible button. Its visual children are excluded from hit testing and duplicate accessibility navigation so the entire image surface activates the route. No whole-card gesture competes with the existing author, reaction, save or composer controls.

Verification for this change is limited to source/diff inspection and whitespace checks. At the user's request, no build, typecheck, simulator launch or tests were run after the modification. Runtime navigation and VoiceOver behavior still require acceptance on a fresh current-source build on Toti UI Acceptance.
