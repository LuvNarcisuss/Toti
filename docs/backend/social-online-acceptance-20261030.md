# Toti real online Lounge, Voice text, and Chat acceptance

Date: 2026-10-30. Project: `gjodhvpzkdnxdjmorjfw` in `ap-southeast-1`.

## Environment and authorization

- Two disposable Supabase anonymous Guest accounts were created with the current publishable client configuration.
- Both accounts enrolled with the test agreement marker `social-acceptance-not-user-consent`.
- The test used the deployed RPCs and read projections directly over HTTPS. No existing account, archive, Photos item, or wallet balance was used.
- Both disposable Guest accounts were deleted through the self-account deletion Edge Function after the scenario. Cleanup returned `status=complete` for both accounts.

## Results

| Area | Scenario | Result |
| --- | --- | --- |
| Lounge | Guest A publishes a published text post | Passed |
| Lounge | Guest B reads A's post by exact ID | Passed |
| Lounge | Guest B replies; A reads the reply | Passed |
| Lounge | Guest B likes the post; A reads the reaction count | Passed |
| Voice text room | Guest A creates a room with a four-seat limit | Passed |
| Voice membership | Guest B joins the room | Passed |
| Voice text room | Guest B sends stored room text; A reads it | Passed |
| Chat | A opens a direct conversation with B | Passed |
| Chat | B resolves the same canonical conversation | Passed |
| Chat | A sends an online message; B reads it | Passed |
| Cleanup | Both disposable accounts and owned records are deleted | Passed |

This confirms the real online text business path for the exercised operations. It does not establish pagination beyond the exercised reads, concurrent lost acknowledgements, revoked membership while a controller is open, Push delivery, RTC, or production readiness.

## Service boundary observed

- Lounge, Voice room membership/text, and Chat messages are authenticated Supabase RPC operations.
- The acceptance did not claim presence, typing indicators, Push notifications, delivered/read receipts, or audio/video media.
- `rtcEnabled=false` and `purchasesEnabled=false` remain correct for the current build.
