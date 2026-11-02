# Online Guest and Editorial Community Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align Toti's current source and documentation with the enabled Supabase Guest mode, add clearly labeled editorial Lounge/Voice content and verified asset records, and document truthful chat and RTC boundaries.

**Architecture:** Keep member-owned online records in Supabase and keep editorial records read-only and separately labeled. Update the existing UIKit projections and documentation without reviving local fallback or retired Live/Shorts routes.

**Tech Stack:** Swift 5, UIKit, Supabase Swift 2.55.5, PostgreSQL RPCs, JSON resource manifests, Python static checks.

**Spec:** `docs/superpowers/specs/2026-10-30-online-guest-editorial-content-design.md`

## Global Constraints

- Use the dedicated Supabase project `gjodhvpzkdnxdjmorjfw` and the existing Guest authentication path.
- Keep user-visible app content in English and mark editorial material as `From Toti / TOTI EDITORIAL`.
- Do not fabricate member identities, online counts, likes, replies, delivery receipts, earnings, or RTC success.
- Preserve the local archive independently and do not reintroduce Live, Shorts, or Phrase routes.
- Do not build, launch, or run tests without explicit authorization; static checks are allowed.

## Review Focus

- Stale documentation claiming rollout closed or email OTP: update current sections while retaining dated history in the appropriate records.
- Editorial records accidentally entering member-owned projections: test separation and zero personal state for a new guest.
- Chat copy claiming realtime or delivery when only RPC acknowledgement exists: test acknowledged, failed, and pending wording.
- Call entry accidentally starting camera or microphone online: test the unavailable guard.
- Asset manifest without matching credit/license/hash evidence: run manifest and media policy checks.

### Task 1: Normalize online Guest configuration and availability copy

**Files:**
- Modify: `TotiMusic/Toti/Backend/TotiBackendConfiguration.swift`
- Modify: `TotiMusic/Toti/App/AppStore.swift`
- Modify: `TotiMusic/Toti/Features/Calls/CallController.swift`
- Modify: relevant current-state sections in `README.md` and `docs/backend/*.md`
- Test: static source/configuration assertions in an existing test or a focused script check

**Interfaces:**
- Consumes: existing `TotiBackendConfiguration`, `TotiBackend`, and `AppStore` online guards.
- Produces: one documented state with Guest rollout enabled, RTC disabled, and online purchases disabled.

- [ ] Add explicit source comments and user-facing text for Guest mode, online chat acknowledgement, and unavailable RTC/payment state.
- [ ] Remove contradictory current-state claims from README and backend release documents while preserving dated historical records.
- [ ] Add static assertions that source flags and current documentation agree.
- [ ] Run the static assertions and `git diff --check`.

### Task 2: Add editorial Lounge and Voice content with asset provenance

**Files:**
- Modify: `TotiMusic/Toti/Domain/MusicEditorial.swift` or the current editorial source
- Modify: `TotiMusic/Toti/Features/Lounge/TotiEditorial.swift`
- Modify: `TotiMusic/Toti/Features/Parties/PartyModels.swift` or the current Voice catalog source
- Modify: `TotiMusic/Configuration/AssetCatalog.json`
- Modify: `TotiMusic/Configuration/AssetLayout.json`
- Modify: `TotiMusic/Configuration/RemoteAssets.json`
- Modify: the English media credits resource and relevant docs
- Test: editorial separation and stable-ID checks

**Interfaces:**
- Consumes: existing `OnlineEditorialPost`, editorial RPC projection, `PartyRoom`, and remote asset manifest format.
- Produces: read-only editorial posts/prompts/rooms with stable IDs, explicit labels, zero engagement, and registered source/license/hash metadata.

- [ ] Add a small set of editorial Lounge posts and Voice room descriptions without member IDs or synthetic engagement.
- [ ] Ensure editorial cards disclose illustrative photography and remain outside member-owned posts and personal state.
- [ ] Register only approved existing or newly sourced HTTPS assets with credits, licenses, byte counts, and SHA-256 values.
- [ ] Add tests for stable IDs, editorial labels, no fabricated counts, and no personal-state mutation.
- [ ] Run the focused checks and manifest/media policy checks.

### Task 3: Reconcile chat and RTC behavior documentation and tests

**Files:**
- Modify: `TotiMusic/Toti/Features/Chats/ChatControllers.swift`
- Modify: `TotiMusic/Toti/Features/Calls/CallController.swift`
- Modify: `TotiMusic/Toti/Backend/TotiBackend.swift` only if copy or state mapping requires it
- Modify: `docs/backend/release-checklist.md`, `docs/backend/contract.md`, `docs/backend/runtime-verification.md`
- Test: focused online chat and RTC-guard tests

**Interfaces:**
- Consumes: `sendOnlineMessage`, `loadOnlineThread`, `TotiBackendConfiguration.rtcEnabled`, and existing call guard.
- Produces: truthful online message status and an explicit unavailable RTC state.

- [ ] Verify message send uses the authenticated online mutation and never local fallback in online mode.
- [ ] Keep pending/retry handling visible and avoid claiming push, realtime presence, or guaranteed delivery.
- [ ] Ensure online call actions stop before camera/microphone startup and show the dependency message.
- [ ] Document provider, token/signaling, permissions, reconnect, session lifecycle, and acceptance prerequisites for RTC.
- [ ] Run focused static tests; do not claim runtime acceptance without the authorized simulator workflow.

### Task 4: Final documentation and verification ledger

**Files:**
- Modify: `README.md`
- Modify: `docs/backend/release-checklist.md`
- Modify: `docs/backend/runtime-verification.md`
- Modify: `docs/backend/media-acceptance.md` and `docs/payment-verification/README.md` where current-state wording is stale
- Create or update: a concise current-state verification record under `docs/`

**Interfaces:**
- Consumes: results from Tasks 1–3 and existing historical evidence.
- Produces: a single current-state account of enabled Guest mode, available features, unavailable features, verification scope, and remaining release dependencies.

- [ ] Separate current source truth from dated historical evidence.
- [ ] Record exact checks executed and any network/resource limitation.
- [ ] Run `git diff --check`, the media policy script, and focused static checks.
- [ ] Report that no build, simulator, or online acceptance was run unless separately authorized.
