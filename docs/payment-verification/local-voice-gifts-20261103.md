# Local Voice gift debits — November 3, 2026

## Scope and cause

Online Guest accounts already supported a separate Debug simulator StoreKit wallet, but the gift screen, AppStore eligibility and WalletStore debit path still rejected online mode unconditionally. Material rooms were also absent from recipient validation. As a result, local test diamonds could be purchased but not spent in Voice.

The repair enables local gift effects and wallet records only when the explicit Debug simulator testing flag is enabled and the wallet belongs to the current authenticated account and session generation. Release builds and ordinary online wallets still require a server payment verifier. This change neither transfers money to recipients nor creates cloud gift records.

## Behavior

- Opening the gift picker initializes the account-scoped test wallet without requiring a prior Wallet visit.
- The Voice picker opens at a fixed medium sheet size, keeps the room visible, supports individual recipients and Everyone, and excludes the current account. Scrolling does not expand the sheet. Material-room recipients are checked against their source room.
- Confirmation displays the selected recipient, quantity, total and remaining diamonds. Everyone creates one shared effect at the stated total; recipient count does not multiply the charge.
- Cancel performs no spend. Insufficient balance offers Wallet without changing the ledger.
- Wallet actions reject overlapping UI requests. Gift debits and StoreKit credits use the existing serialized persistence queue. Balance and activity publish only after atomic persistence succeeds.
- Failed persistence leaves balance and activity unchanged. Success records gift ID, quantity and recipient context, dismisses the Voice picker, then displays the local effect inside the originating room. The room rechecks its account context and visibility before playing the effect.
- Stale account screens cannot confirm or publish a successful result after an account change.

## Verification

The current signed source was built, installed and launched on **Toti UI Acceptance**, UDID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. Payment tests use local StoreKit transactions; no real charge is made.

Four payment service cases passed with zero failures:

- Concurrent gifts preserve both debits and records.
- Gift metadata survives persistence/restart and older activity still decodes.
- Insufficient balance, invalid/self recipients, failed persistence and ended payment sessions do not spend diamonds.
- A purchase credit arriving during a gift save preserves both operations.

Service result: `/private/tmp/toti-gift-service-1103.xcresult`.

The first UI attempt bought 400 test diamonds and selected Avery, but its scrolling helper targeted the underlying room's avatar scroll view instead of the gift sheet. It failed before spending. Evidence: `/private/tmp/toti-gift-ui-1103.xcresult`. That earlier repair used a large sheet; the subsequent user-requested half-height presentation supersedes it. The test selects the explicit `gift.scroll` identifier.

The final focused UI rerun passed: **1 test, 0 failures**, after rebuilding and reinstalling the latest source. It verified purchase credit of 400 diamonds, confirmation cancellation retaining 400, one Rose reducing the balance to 390, five Roses reducing it to 340, an unaffordable Galaxy leaving 340 unchanged, and process relaunch retaining 340 with exactly three activity records. Final result: `/private/tmp/toti-gift-ui-final-1103.xcresult`. Together with the four service cases above, the selected final runs total **5 passed, 0 failed**. This is focused local-wallet acceptance, not a complete payment or social regression. The Supabase SDK emitted its existing initial-session behavior warning; it did not fail these cases.

The focused UI case reuses retained Guest namespace `26F9BA6F-44AC-4A36-9B37-DF739B215A3C` and a fresh local wallet UUID. Existing Guest accounts, private notebooks, social data and the separate manual test wallet are preserved. No backend deployment or account deletion is performed.

## External dependencies

This verification does not establish Apple sandbox/production purchases, server-verified balances, cloud gift delivery, recipient earnings or RTC. Local test credit cannot become cloud credit. For interactive local purchases, use Xcode's **toti** Run scheme on **Toti UI Acceptance** so the StoreKit fixture is active; a direct simulator launch does not activate that fixture.

Evidence screenshots are retained under `Assets/Verification/VoiceGifts20261103/` (ignored local media archive). The latest signed app was left running on Toti UI Acceptance after verification.

## Half-height picker and room-owned effects

The user requested that Voice gifting keep the room visible and play the effect in the room. Voice now has only a medium detent, with scroll-to-expand disabled. On successful persistence, GiftsController dismisses its navigation sheet and invokes a weak room callback from the dismissal completion. The room renders GiftBurst in its own view, not the window or gift picker. Cancellation and failures retain the picker without effects. Post gifting retains its existing presentation.

The first half-height UI attempt failed because full-velocity automation swipes overshot the gift row (`/private/tmp/toti-gift-room-ui-1103.xcresult`). The test now uses bounded drags within the sheet. Existing local Voice expectations were also updated for automatic dismissal.

The latest half-height UI rerun passed **1 test, 0 failures** in 102.732 seconds after a fresh build/install/launch on Toti UI Acceptance. It asserts the sheet starts below 40% of screen height, checks cancellation, two successful dismissals and reopens, insufficient funds, and the persisted 340-diamond balance with three records after relaunch. Result: `/private/tmp/toti-gift-room-ui-final-1103.xcresult`. Screenshots were visually inspected: the room remains visible above the half-height picker, and the Rose effect appears over the room after the picker closes. The payment core was unchanged; its four earlier service passes are not counted as a new run. The separate legacy-local Voice test expectation was updated and compiled, but was not rerun in this online-Guest selection.

Current screenshots: `Assets/Verification/VoiceGifts20261103/half-height-picker.png` and `room-gift-effect.png`.
