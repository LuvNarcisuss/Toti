# Online Guest Mode and Editorial Community Content

## Intent

Make the repository describe and implement one consistent product state: Toti runs through the dedicated Supabase Guest integration, preserves account-scoped online data, and never falls back to fictional member activity. Add enough clearly labeled Toti editorial content and licensed visual assets to make Lounge and Voice useful on a first visit without inventing users, presence, engagement, delivery receipts, or earnings.

## Goals

- Align README, backend documentation, release checklist, and source comments with the current Guest rollout configuration.
- Keep guest authentication, Keychain session reuse, online text chat delivery, online Lounge/Notebook/relationship/report flows, and online room text membership behavior truthful.
- Add editorial Lounge posts, prompts, and Voice room descriptions with stable IDs and explicit `From Toti / TOTI EDITORIAL` labeling.
- Register editorial image sources, credits, licenses, and resource hashes in the existing asset manifests.
- State the exact RTC, payment verification, moderation, push, and production acceptance dependencies.
- Preserve new-user personal data as empty until the user creates it.

## Non-goals and anti-goals

- Do not fabricate member accounts, online counts, likes, replies, delivery receipts, or chat history.
- Do not present editorial content as user-authored content or imply that photographed people are members.
- Do not claim voice or video calls work while `rtcEnabled` is false and no RTC provider or token service is configured.
- Do not enable Apple server-verified purchases, staff moderation, push delivery, or production release acceptance.
- Do not migrate or delete the legacy local archive.

## Selected approach

The selected approach combines the real online Guest path with a small editorial content layer. Editorial records remain separate from member-owned records and are read-only in the client. Lounge and Voice screens may show editorial material immediately after a new guest signs in, while personal posts, notes, chats, and room membership remain empty until created or received through the real backend.

Chat sending continues through the existing authenticated Supabase mutation and read projection. The UI must describe it as online conversation delivery only after the server receipt is acknowledged; it must not imply push or realtime presence.

RTC remains an explicit unavailable state. The docs and UI copy will name the missing provider, token/signaling service, session lifecycle, permission handling, reconnect behavior, and simulator/device acceptance as release dependencies.

## Implementation areas

1. Update source configuration comments and user-facing availability text so Guest mode, chat, payments, media review, and RTC agree with the current flags.
2. Reconcile README and backend docs, removing stale closed-rollout/email-OTP claims while preserving dated historical evidence.
3. Add editorial Lounge and Voice records using stable identifiers, explicit editorial labels, zero engagement, and no member identity references.
4. Add or register only approved visual resources with HTTPS source, byte hash, credit, and license evidence; keep the runtime bundle free of retired video assets.
5. Update tests or static checks that verify editorial separation, empty personal state, real chat mutation wording, and unavailable RTC state.

## Acceptance evidence

- Source and current documents report the same Guest mode and rollout state.
- A new authenticated guest receives editorial Lounge/Voice content but no personal posts, notes, messages, wallet credits, or authored rooms.
- Chat send uses the real online mutation path and displays a truthful acknowledged state; failed or pending writes remain recoverable.
- Call entry points clearly report unavailable RTC and do not start camera, microphone, or fake connection state in online mode.
- Editorial media has visible disclosure and matching manifest credit/license/hash evidence.
- Static checks pass. Build, simulator, and online acceptance remain subject to the repository's explicit authorization and required Toti UI Acceptance workflow.
