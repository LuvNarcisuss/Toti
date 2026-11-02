# Local StoreKit with an online account — 2026-10-30

## Scope and cause

The online migration deliberately disabled the device-only wallet because no server purchase verifier or online credit operation is deployed. The previous presentation repair restored the seven offers, but correctly left them unavailable. A StoreKit configuration alone could not bypass that online guard.

The user selected local StoreKit testing equivalent to the Bibi reference while retaining online accounts. This change gives Debug simulator builds a separate test wallet. It does not enable Apple sandbox, production purchases, online gifts or server credit.

## Implementation

- The `toti` Run scheme selects `Configuration/TotiDiamonds.storekit` and sets `TOTI_LOCAL_STOREKIT_TESTING=1`. `totiAppStore` has neither setting.
- Only Debug simulator code can open this wallet. The online backend remains enabled and authentication remains real.
- Wallet files live under `Application Support/TotiOnline/StoreKitTesting/<account UUID>/wallet.json`. Automated runs add their own UUID directory. Existing local archives and cloud balances are untouched.
- Each wallet has its own random transaction-owner UUID, passed through StoreKit 1 `SKMutablePayment.applicationUsername`. Queued transactions from other wallets cannot credit this wallet.
- Credits are written atomically before publication and transaction completion. Composite transaction identities prevent duplicate credit in the scoped Debug simulator wallet, including when Xcode reuses a numeric ID after a history reset. Legacy activity metadata is migrated without resetting credit; see [the November 2 repair](local-transaction-collision-20261102.md). Account/session changes suspend the observer and invalidate pending work. Corrupt saved files produce a retryable error instead of resetting the balance.
- The wallet displays local testing/no-charge/account-scope notices, actual StoreKit prices, balance and activity. Test diamonds cannot be spent online. Without the testing flag, the existing unavailable online-wallet presentation remains.

## Manual use

1. Open `TotiMusic/Toti.xcodeproj` in Xcode.
2. Select **toti** and **Toti UI Acceptance**.
3. Choose **Product > Run**, then log in and open **Me > Wallet**.
4. Select a package and continue to the native local StoreKit payment sheet.

The fixture is attached by Xcode's Run action. Launching only with `simctl launch` or from the home-screen icon does not establish that Xcode testing session. If prices are unavailable, run from Xcode again and use **Retry prices**.

## Verification record

Environment: Xcode 26.0.1 (17A400), iOS 26.0.1, iPhone 17 Pro simulator **Toti UI Acceptance**, UDID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. Simulator builds retain ad-hoc signing for Keychain access.

The first signed build succeeded. The initial native-sheet test passed, showing **400 Diamonds / $0.99** and cancellation without credit. The initial seven-tier run credited 400 and 800 before another simultaneous simulator acceptance switched the same app into a chat; the failure hierarchy shows **Acceptance Partner**, not the wallet. This interrupted run is not a seven-tier pass. Further testing waits for the other task to release the simulator.

After the other task completed, the latest source was rebuilt, installed and launched before each suite. Both final `xcodebuild` commands exited successfully and the result bundles report **19 passed, 0 failed, 0 skipped**:

| Suite | Result | Observations |
| --- | --- | --- |
| `totiPurchases` (two selected purchase cases) | 2 passed | All seven exact prices, seven purchases totaling 112,700 diamonds, app confirmation cancellation, StoreKit cancellation, native 400 Diamonds / $0.99 sheet, process relaunch preserving the balance and seven activity records |
| `totiPayments/StoreKit1PaymentTests` | 17 passed | Exact tier credits, repeated consumables, failures/cancellation, deferred approval, failed-save recovery and duplicate delivery, account-owner rejection/recovery, catalog partial/empty/error/timeout/retry, stale callbacks, session end during loading and existing local gift serialization/metadata regressions |

The new owner-isolation case proves a purchased transaction with failed persistence stays unfinished, cannot credit another wallet owner, and credits the original owner exactly once when persistence recovers. The gift service cases cover legacy local compatibility, not online gifting.

Native-sheet evidence now waits for hittable product/dismiss controls before capture; the previous screenshot had been taken before the presentation animation completed. Final screenshots were visually inspected: the native Xcode sheet states no charge, and the reopened wallet shows 112,700 diamonds with all seven complete, enabled price cards.

UI tests reused the already authorized retained Guest namespace `26F9BA6F-44AC-4A36-9B37-DF739B215A3C`. Each run used a fresh local wallet UUID and cleared only local StoreKit test transactions. No cloud account was created or deleted; existing account and social data were preserved.

Evidence:

- Machine-readable summaries and screenshot hashes: [online-local-results.json](online-local-results.json).
- UI result: `/private/tmp/toti-local-wallet-final-ui.xcresult`.
- Service result: `/private/tmp/toti-local-wallet-service.xcresult`.
- Local screenshots and attachment manifest: `Assets/Verification/OnlineStoreKit/FinalUI/` (ignored media archive).
- Interrupted-run evidence: `Assets/Verification/OnlineStoreKit/InterruptedRun/`.

The UI selection uses scheme `totiPurchases`, setting `TOTI_PURCHASE_GUEST` to the authorized retained namespace, with only `testSevenPurchasesPricesCancellationAndRelaunchHistory` and `testNativePaymentSheetShowsProductPriceAndCancelsWithoutCredit`. Service regression uses scheme `totiPayments`, selecting `totiPaymentTests/StoreKit1PaymentTests`. Both destinations explicitly use the UDID above and disable parallel testing. Do not run another suite or manipulate this simulator concurrently.

After testing, Xcode **toti > Run** built and launched the latest app on the same simulator. The existing signed-in account was opened through **Me > Wallet**. Visual inspection confirmed seven loaded, enabled cards and the local/no-charge notice. The app was left running on that wallet. Its separate manual test balance starts at zero; the automated run's 112,700 diamonds were not copied into it. Final screenshot: `Assets/Verification/OnlineStoreKit/manual-xcode-wallet.png`.

## Unverified external capabilities

Apple-hosted product availability, registered Bundle ID/signing, Apple sandbox transactions, server receipt verification and production delivery are not established by these local tests. No backend payment endpoint or cloud wallet migration was deployed for this change.
