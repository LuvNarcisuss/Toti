# Supabase community room materials

Updated on 2026-10-30. The user's final instruction is to publish room materials without creating accounts. The earlier proposed system-owner provisioning was rejected and superseded; that script was removed and no Auth identities, live room objects, memberships or messages were created.

## Published content

Migration `20261030070809` (`toti_community_room_materials`) creates a private, read-only materials table and authenticated reader RPC. It publishes six illustrated room records:

| Room | Genre | Unique cover |
| --- | --- | --- |
| The Pop Lounge | Pop | RoomCoverHipHop |
| Soul After Hours | Soul | RoomCoverKPop |
| Blue Note Room | Jazz | RoomCoverJazz |
| Acoustic Corner | Acoustic | RoomCoverFreestyle |
| Piano & Strings | Classical | MusicPianoRoom |
| Electronic Frequencies | Electronic | MusicProductionRoom |

Each record has three different portrait photographs, for eighteen distinct portraits across the collection. Existing licensed images include upper-body, seated and lifestyle compositions. Names are illustrative character captions, not Auth identities. The visual selection does not establish subjects' nationality or ethnicity. Actual member-uploaded photographs and existing private profiles are unchanged.

`TotiMusic/Configuration/CommunityRoomAssets.json` records every filename, public Supabase URL, byte count, SHA-256, source and license evidence. Covers extracted from the archived music footage retain their source-video ID and frame-time evidence. Existing images were reused from the public build-assets bucket; no duplicate image upload or new service key was needed.

## Application behavior

Voice fetches `toti_community_room_materials` during authenticated refresh and shows these cards alongside real backend rooms. Photos load from public Supabase URLs at runtime. The reader validates URL scope, unique covers, unique portraits and supported genres before constructing cards. A read failure shows Retry and does not pretend that unpublished local records are online data.

Cover taps enter the existing `PartyRoomController` layout. The subsequent Teto-parity correction restores the current-user seat, plus-avatar Invite control, local microphone/speaker toggles, composer, quoted replies, scrolling, sharing, character detail views and gift catalog entry. Material IDs remain separate from real room UUIDs. An illustrative conversation loop runs only for material rooms and never generates cloud messages or presence. Material-room messages remain in memory for the visit; invitations use real Chats and require successful acknowledgement. Character portraits are not Auth accounts. Online gift sending and live audio remain unavailable. See `../voice-room-interaction-parity.md` for the exact reference behavior and service boundaries.

Room data comes from authenticated RPC; image URLs are public and need no bearer header or upload credential. The materials table has RLS and no direct client grants. The privileged private reader follows the existing editorial-reader pattern, uses an empty search path, requires a valid active session and returns published material content only. The public wrapper is security invoker, executable only by authenticated clients. No grants on existing tables were broadened.

## Verification and limits

SQL read-back confirmed six published records, six unique covers, eighteen unique portrait assets, RLS enabled, no authenticated direct table SELECT, authenticated RPC EXECUTE and no anonymous RPC EXECUTE. Account count remains one and actual live room-object count remains zero. These records are room materials, not six active hosted voice sessions.

The security advisor reports the expected default-deny RLS informational finding for the new private table, together with the existing project findings and leaked-password-protection warning. No access policy was loosened to address an informational finding.

All 24 public Supabase image URLs returned HTTP 200 and matched their local byte counts and SHA-256 values. Verification used system curl with normal TLS validation; the initial Python downloader lacked a usable local CA chain, so it was replaced without disabling certificate checks. Results are recorded in `community-room-assets-verification.json`. Media inspection and source/whitespace checks were also performed. At the user's request, no app build, typecheck, simulator launch or tests were run. Current-source UI navigation and remote-image rendering still require future authorized acceptance.

## Music portraits — 2026-11-02

The earlier portrait selection is superseded by eighteen distinct music-person photographs. Migration `20261102061858` changes only the six materials' people artwork arrays. Public images, credits, source records and matching seat/profile routing are documented in [Voice music portraits](../voice-room-music-portraits.md). All 37 new resources passed anonymous byte/hash verification. Current-user and actual-member avatars remain unchanged.
