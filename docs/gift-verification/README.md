# Existing-surface diamond gifts verification

Date: 2026-10-26.

## Delivered scope

- Lounge post details now open the existing nine-gift picker for the post author.
- Voice retains gifting and now records the selected member or Everyone roster. Everyone creates one shared effect for the displayed price; the price is not multiplied by member count.
- Profiles and Chats have no new gift entry point, as explicitly requested. Notebook, basic posts, replies and messages remain free. No new product module, currency or IAP product was added.
- Confirmation shows recipient, quantity, cost and remaining balance, with an explicit local-only service boundary. The picker uses a large sheet and a system alert that supports long text.
- Optional activity metadata stores source ID, recipient IDs/names, gift ID and quantity while preserving existing ledger decoding.
- Gift debits and StoreKit credits share one serialized persistence queue. Overlapping UI actions are blocked; save failures do not change the visible balance or play an effect. Saving disables Close, interactive dismissal and session exit through the wallet busy state.
- Self, blocked, missing and unavailable destinations are rejected before spending.

## Environment and final results

Toti UI Acceptance, UUID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, iPhone 17 Pro, iOS 26.0.1 (23A8464), x86_64 simulator. UIKit, Swift 5, StoreKit 1, bundle `com.toti.music`. All test invocations explicitly selected this device and disabled parallel simulator testing.

| Suite | Passed | Failed | Skipped | Evidence |
| --- | ---: | ---: | ---: | --- |
| Local StoreKit service and gift regressions | 16 | 0 | 0 | [Service summary](service-summary.json) |
| Gift UI acceptance | 3 | 0 | 0 | [UI summary](ui-summary.json) |
| Existing core regressions | 23 | 0 | 0 | [Core summary](core-summary.json) |

Total: 42 passing tests. Each run used a current build installed and launched on the specified simulator before testing. Final installed and built binary hashes, device family and launch result are in [build identity](build-identity.json).

### Gift service coverage

- Two concurrent gifts preserve both debits and both history entries.
- A purchase credit arriving during a gift save preserves both changes.
- Post context and balance survive repository reload and payment-service restart.
- Legacy gift entries without context continue decoding.
- Selected Voice member and Everyone persist their exact recipient IDs; five Roses cost 50 diamonds in either case.
- Insufficient funds, invalid self target, failed persistence and closed wallet leave balance unchanged.
- App-level destination validation rejects own, blocked and missing posts and use after logout.
- Existing seven-product purchases, repeat consumables, cancellation, failure, deferred approval, interrupted persistence recovery, catalog retries, timeouts and stale callbacks remain covered.

### UI coverage

- Buy 400 local StoreKit diamonds; cancel a post gift without spending; confirm a 10-diamond Rose; verify 390 diamonds and the gift record after relaunch.
- Select Maya in Voice; attempt a gift with zero balance; cancel the top-up prompt; add 400 diamonds through the existing wallet; return with the selection preserved; give five Roses and verify 350 diamonds.
- At the largest accessibility text category, confirm that Everyone's gift alert keeps Spend and Cancel reachable; cancel and retain all 400 diamonds.

### Review and development evidence

The original concurrent-spend test failed with 390 instead of 380 diamonds and one rather than two gift entries. It passed after serializing debits with credits. An independent code review identified the fixed-size confirmation-card risk; this was replaced with a system alert and covered by the large-text UI test. Close is now disabled while saving. The initial gift UI attempt assumed tabs were available inside the wallet detail; that failed run was stopped, the test was corrected to return first, and the final three UI tests passed. Failed/interrupted runs are not counted above.

## Screenshots

- [Post gift confirmation](post-gift-confirmation.png)
- [Post gift debit](post-gift-debit.png)
- [Persisted post gift and balance](post-gift-relaunch.png)
- [Voice insufficient balance](voice-insufficient-balance.png)
- [Voice selected recipient after top-up](voice-selected-recipient.png)
- [Accessibility text confirmation](large-text-confirmation.png)
- [Final normal app launch](final-launch.png)

## Evidence bundles

- `/private/tmp/toti-gift-service-final.xcresult`
- `/private/tmp/toti-gift-ui-final.xcresult`
- `/private/tmp/toti-gift-core.xcresult`

The JSON summaries and selected screenshots are retained here; temporary result bundles may be removed by the operating system.

## Service boundaries and untested cases

Gifts currently consume device-local diamonds for an effect and a local record. They do not deliver a gift or funds to another person, create recipient earnings or cash-out rights, or synchronize across accounts/devices. The UI states this before spending. App Store sandbox/production purchases, server receipt verification and authoritative balances remain outside this verification. No real-money charge occurred.

The full historical community UI suite, physical devices, iOS 16 runtime and other screen sizes were not rerun. The final direct simulator launch does not activate the StoreKit fixture; run the `toti` scheme in Xcode for interactive local purchases, and `totiAppStore` for an Apple-catalog run without a fixture.
