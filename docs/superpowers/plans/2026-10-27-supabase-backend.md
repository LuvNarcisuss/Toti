# Toti Supabase Backend Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans. Project verification restrictions override test and commit defaults.

**Goal:** Replace authorized local business flows with an account-isolated Supabase path while preserving the existing library.
**Architecture:** Validated transaction RPCs, normalized RLS ownership, pinned Swift client, account-scoped adapters behind a closed rollout gate.
**Tech Stack:** Swift 5, UIKit, iOS 16+, Supabase Auth/Postgres/Storage/Edge Functions.
**Spec:** docs/backend/contract.md

## Global Constraints

English project content; preserve five tabs, product identity and private archive. No commits or pushes. Initial build/test restrictions were superseded by explicit user authorization for dependency resolution, compilation and acceptance on Toti UI Acceptance; SMTP-dependent login and business acceptance remain pending. No RTC/payment success. No server secrets in app.

## Review Focus

Late auth responses; cross-account reads and drafts; changed-payload operation replay; blocked/membership-revoked chat; lost acknowledgement and irreversible archive changes.

### Task 1: Authoritative service
- [x] Implement ordered SQL and authenticated cleanup Edge Function under TotiMusic/Backend using contract RPCs.
- [x] Inspect permissions and deploy to the dedicated healthy Toti project through migrations; record returned identities and advisors.
- [x] Author isolated acceptance scenarios without running them.

### Task 2: Auth and transport
- [x] Pin and inspect the Swift SDK; implement the exact TotiBackend interface, Keychain, retry journal and generation checks.
- [x] Keep configuration source and project metadata consistent through permitted XcodeGen generation.
- [x] Record dependency and OTP/SMTP limitations.

### Task 3: Existing screen integration
- [x] Route AppStore and the entry flow through the online service; use server identities and remove authored data from online views.
- [x] Route Lounge/Notebook/profile/relationships/safety/chat/room operations, retain server acknowledgement and isolate account drafts.
- [x] Expose pagination and invitation/member controls; preserve archive independently; disable unavailable RTC and payments.

### Task 4: Review and handoff
- [x] Review authorization, mutation coverage and archive isolation against the contract; fix findings.
- [x] Perform permitted static/metadata checks, update README and deployment/release checklist.
- [x] Leave rollout disabled with exact outstanding acceptance/configuration dependencies.

Implementation/source and metadata tasks are complete at the documented static scope. Online release acceptance is not complete: see `docs/backend/release-checklist.md`. Media publication remains explicitly unavailable pending its validation/review workflow; SMTP and cloud behavioral verification are outstanding. See docs/backend/runtime-verification.md for the subsequently authorized client checks.
