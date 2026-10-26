# StoreKit 1 diamond purchases

Configured on 2026-10-26 from the supplied purchase catalog screenshot (40617780). Product IDs were checked with local OCR and visual inspection. These are consumable diamond packages.

| Diamonds | Reference USD price | Product ID |
| ---: | ---: | --- |
| 400 | 0.99 | `jezvdjvpoifednhy` |
| 800 | 1.99 | `uylrrniaqxjtlaie` |
| 2,450 | 4.99 | `oqojxyitbbjeayzj` |
| 5,150 | 9.99 | `skrseirtauvvrsol` |
| 10,800 | 19.99 | `bqrdrlkrlfpzjmod` |
| 29,400 | 49.99 | `psqtqagzmiiyhncr` |
| 63,700 | 99.99 | `bzwmucutltusfxpv` |

`Toti/App/TotiIdentity.swift` owns the product identifiers. `WalletCatalog` defines the matching seven diamond/price tiers. The earlier unconfigured 16,800 and 42,600 diamond tiers are removed. Reference USD prices do not determine the charge: the wallet displays localized prices from `SKProduct.price` and `priceLocale`.

## Payment path

`WalletController` → `WalletStore.purchase` → `StoreKit1Purchasing` → `SKProductsRequest` / `SKPaymentQueue.add(SKPayment(product:))`. This uses the original StoreKit API, without StoreKit 2 or PassKit/Apple Pay.

After the persisted wallet loads, `AppStore.load()` starts the transaction observer. Purchased transactions map back to their diamond tier and payment quantity. Transaction identifiers prevent duplicate credit in the local ledger. The balance, activity and credited identifiers are saved atomically before `finishTransaction`. Failed saves leave the transaction unfinished for a later delivery. Canceled/failed transactions do not credit diamonds; deferred transactions wait for approval. The wallet disables purchase buttons while a purchase request is active. After saving and calling `finishTransaction`, it waits for `removedTransactions` before releasing the waiting purchase; an immediate second purchase of the same consumable can then proceed safely. Re-registering an observer also processes the current unfinished queue snapshot.

Apple describes this transaction lifecycle in [Processing a transaction](https://developer.apple.com/documentation/storekit/processing-a-transaction) and [Setting up the transaction observer](https://developer.apple.com/documentation/storekit/setting-up-the-transaction-observer-for-the-payment-queue).

## Catalog and session safeguards

`StoreProductCatalog.swift` owns the session-scoped StoreKit 1 request delegate and catalog status. States distinguish idle, loading, ready, partial, unavailable, failed and timed out. Only products returned by StoreKit with a formatted localized price enable purchase confirmation. Valid offers remain available after a partial response or failed refresh. Missing offers have an explicit Retry prices action.

Requests coalesce while in flight. Cancellation, timeout and session end invalidate the request generation, resolve waiters and reject old callbacks. After awaiting a product, the purchase service rechecks its session generation before submitting payment. Logout stops the purchase session; entry restarts it. Account deletion is blocked while StoreKit has unresolved transactions. The application still has one device-local wallet, not authenticated multi-account/server ownership.

Debug builds expose Copy store diagnostics. The report includes bundle/version, payments permission, catalog state and requested/returned/invalid product IDs. Error details contain only bounded NSError domain/code chains. Receipts, account identifiers, bank information and unrestricted userInfo are excluded.

## Xcode schemes

| Scheme | Purpose |
| --- | --- |
| `toti` | Local development Run with `Configuration/TotiDiamonds.storekit`; existing unit tests remain attached |
| `totiAppStore` | Run without a local fixture, for Apple's catalog and authorized sandbox checks |
| `totiPayments` | StoreKit service regression and separately selectable Apple catalog probe |
| `totiPurchases` | Isolated XCTest UI purchase and native-sheet tests |
| `totiUI` | Existing general application UI tests |

The StoreKit fixture is copied only into payment test bundles, not production application resources. `project.yml` is the source for shared scheme generation. StoreKit.framework is an explicit SDK dependency. Bundle ID remains `com.toti.music`; no development team was invented. Direct `simctl launch` does not activate a scheme's StoreKit fixture: use Xcode Run with `toti` for interactive local purchasing.

## Verification and remaining services

- Confirm these exact IDs exist as consumables on the intended App Store Connect app. The repository currently uses bundle ID `com.toti.music`; its registration and association with the supplied catalog are not verified.
- No App Store Connect account changes, development-team changes or real-money purchases were performed. The supplied screenshot does not establish product availability in Apple's sandbox or production.
- Receipt validation, server order confirmation, refund reconciliation and account-level balance synchronization are not implemented. Current fulfillment relies on StoreKit transaction callbacks and a device-local ledger. Deleting app data loses that local ledger.
- The user subsequently authorized compilation, simulator execution and payment testing. See [payment verification](payment-verification/README.md) for actual nonzero test counts, observed failures and corrections.
- A query without local StoreKit configuration returned zero products and all seven IDs as invalid on the tested simulator. This blocks an Apple sandbox purchase claim; it does not prove that products are absent in App Store Connect. Registered app identity, signing/provisioning, product metadata/availability and account agreements require owner-side verification.
