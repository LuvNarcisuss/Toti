# Local StoreKit transaction identifier reuse — November 2, 2026

## Reproduction and scope

The manual Xcode wallet retained a credited ID `0` from October 30 (400 diamonds).
Xcode transaction manager showed a new 800-diamond purchase at 14:37:55 on
November 2, also ID `0`, already finished. The old implementation treated it as
already delivered because its deduplication key contained only the numeric ID.
A later ID `1` purchase delivered 400 normally after its system confirmation;
the pre-change wallet therefore contained 800 diamonds and two activity records.

The original 19-test run used fresh isolated wallets and did not cover retaining
a wallet across a local StoreKit history reset. Those results remain valid only
for their documented scenarios; they did not establish collision safety.

## Repair

Only a Debug simulator service with a scoped local transaction owner uses the
new identity. StoreKit 1 remains the purchase API. Apple catalog/device paths
retain their existing raw transaction identifiers and server-verification guards.

Local delivery records include transaction ID, product, quantity, credited amount
and transaction date normalized to milliseconds. They are persisted with the
wallet in the same atomic write as balance and activity. Duplicate callbacks
match this durable identity; a reused numeric ID with a different purchase date
or product is a separate purchase.

Existing wallets decode without the new optional metadata. Known old activity
rows supply the original ID, date and amount for migration. Their IDs, titles,
dates, amounts, balances and credited-ID array entries are retained. New activity
uses a composite delivery ID. Identity metadata is retained even when
the existing 40-row visible-history limit removes a row. If a legacy raw ID has
already lost its activity details, delivery stays unfinished and returns an error
rather than claiming success or guessing whether to credit.

The manual wallet was backed up before changes to
`Assets/Verification/StoreKitCollision20261102/before/` (ignored local archive).
No cloud balances, accounts or social records are changed.

## Regression verification

Destination: **Toti UI Acceptance**, `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`,
iPhone 17 Pro, iOS 26.0.1, Xcode 26.0.1. Each invocation first builds current
source, verifies its ad-hoc signature, installs and launches it on this simulator.

- Red: `testReusedLocalIdentifierCreditsNewPurchaseAndPreservesLegacyWallet`
  failed with 400 instead of 1,200 diamonds and one record instead of two. The
  test confirmed the new StoreKit transaction actually reused ID `0`.
- Green: all **22** `StoreKit1PaymentTests` passed, zero failures/skips. New cases
  cover legacy ID collision, same-product purchase after a history reset, replay
  migration and deduplication after visible-history pruning, failed-save recovery
  with duplicate replay, and incomplete legacy history without false success.
- UI: the new retained-wallet/reset/rebuy/relaunch case passed. The balance
  reached 400, remained 400 after resetting StoreKit history, then reached 1,200
  after a new purchase reused the same ID. Both records survived a process relaunch.
- UI: all seven offers, purchases totaling 112,700 diamonds, cancellations and
  relaunch persistence passed.
- The native-sheet case initially failed at the online login prerequisite:
  `Logging in…` remained visible past the existing 30-second expectation. No
  purchase was attempted in that failed case. A separate native-sheet rerun
  passed with zero failures/skips at 15:03. The failed prerequisite attempt is
  retained in the initial UI result bundle; no login timeout or auth bypass was changed.
- The manual wallet was checked against the pre-change backup after the UI run:
  **800 diamonds and two records, byte-for-byte identical**. Isolated acceptance
  wallets and StoreKit transactions were used for regression tests.

The final coverage is **25 distinct passing cases**: 22 service cases plus three
UI cases, with zero skips. This is combined coverage across the service run,
the two passing initial UI cases and the separate native-sheet rerun; the initial
three-case UI invocation itself failed because of the login prerequisite above.

Screenshots were visually inspected: the collision regression shows 1,200 after
relaunch, and the native sheet shows 400 Diamonds / $0.99 and no-charge testing.
Machine-readable results, failed attempts and preservation hash are in
[the result record](local-transaction-collision-results.json).

## Evidence and limits

- Red bundle: `/private/tmp/toti-collision-20261102-red-regression.xcresult`.
- Native-sheet rerun: `/private/tmp/toti-collision-20261102-native-ui.xcresult`.
- Screenshots and attachment manifests: `Assets/Verification/StoreKitCollision20261102/`.
- UI bundle: `/private/tmp/toti-collision-20261102-ui-ui.xcresult`.
- Green service bundle: `/private/tmp/toti-collision-20261102-green-regression.xcresult`.
- Local StoreKit results do not verify Apple sandbox, production payment or device signing.
- A previously finished consumable that was never recorded is not recreated by
  changing the deduplication key. This patch does not invent a compensating
  credit for the earlier missed 800-diamond test purchase. Existing saved credit
  and history remain intact.

Apple references:
[SKPaymentTransaction](https://developer.apple.com/documentation/storekit/skpaymenttransaction)
and [clearTransactions](https://developer.apple.com/documentation/storekittest/sktestsession/cleartransactions()).

## Final running state

At 15:06 Asia/Shanghai, Xcode reported `Running toti on Toti UI Acceptance`
using scheme `toti` with its local StoreKit fixture. The latest app visibly
showed the normal welcome screen. Strict verification of the installed ad-hoc
signature passed. A final read confirmed that the normal manual wallet still
matched its pre-change backup byte for byte (800 diamonds, two activity rows).
No normal-user agreement was accepted during final launch.
