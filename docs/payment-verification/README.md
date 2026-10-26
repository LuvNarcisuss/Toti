# Toti StoreKit 1 repair verification

Date: October 26, 2026 (Asia/Shanghai). User-authorized builds and tests on **Toti UI Acceptance**, iPhone 17 Pro, iOS 26.0.1 (23A8464), UDID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, x86_64 simulator. Product/target `toti`, bundle `com.toti.music`, Debug, simulator signing disabled only on the command line. The supplied Toti product mapping is retained; no Bibi product ID, bundle ID or team was copied.

## Results

| Layer | Executed result | Evidence |
| --- | --- | --- |
| Static configuration | Seven unique consumables; quantities, IDs and fixture prices match; local and Apple Run schemes separated; fixture excluded from production app resources | [Integration and product mapping](../storekit1-integration.md) |
| Build | Payment service and UI targets compiled successfully; final iPhone-only destination configuration is checked separately in build identity evidence | [Final iPhone-only build and installed binary identity](build-identity.json) |
| Local StoreKit service | **10 passed, 0 failed, 0 skipped** | [Service summary](service-summary.json) |
| Local StoreKit UI | **2 passed, 0 failed, 0 skipped** | [UI summary](ui-summary.json) |
| Existing unit/integration suite | **23 passed, 0 failed, 0 skipped** | [Core summary](core-summary.json) |
| Apple catalog, local fixture disabled | **0 returned products; all seven IDs invalid**. Probe explicitly skipped its sandbox-ready assertion; not a passing sandbox purchase | [Exact response](apple-catalog-response.txt), [probe summary](apple-catalog-summary.json) |
| Apple sandbox / production purchase | Not verified; no real-money purchase performed | Owner-side configuration remains outstanding |

The 35 passing tests exercise the repaired application sources on the specified iPhone simulator. The later user instruction limiting Supported Destinations to iPhone changes build configuration only. The final build passed; Debug and Release disable iPad, Mac compatibility, Catalyst and Apple Vision compatibility. The built `UIDeviceFamily` is `[1]`; the installed binary hash matches the latest build. General community UI tests were not rerun as part of this payment repair.

## Demonstrated failures and corrections

- **Immediate repeat purchase hung:** a second payment for the same product was submitted while the first purchased transaction remained in `SKPaymentQueue`. Tracing showed the old transaction was delivered again and only then removed; the second waiter never completed. The service now saves, calls `finishTransaction`, and waits for `removedTransactions` before completing the purchase. Three immediate purchases now produce three unique credits and 1,200 diamonds.
- **Save failure did not recover when the observer restarted:** registering a new observer did not redeliver an already-seen transaction in the same process. Startup now also processes the unfinished queue snapshot. Persisted transaction IDs prevent duplicate credit.
- **Request lifecycle lacked isolation:** replaced the global fetcher with session-owned requests, strict active-request checks and generation invalidation. Timeout/session end cancel the request and release waiters. Late callbacks cannot replace a retry; a wallet closed during product loading cannot submit a delayed payment.
- **Missing products remained tappable:** catalog phases now distinguish partial, empty, error and timeout outcomes. Only actual returned/localized offers enable confirmation. Retry and bounded, sanitized Debug diagnostics expose the cause without receipts or account data.
- **Terminal-object tracking retained raw addresses:** weak object identities avoid treating a recycled address as an already-finished transaction. Durable IDs remain the source of purchase deduplication.
- **Test-server failure injection:** clearing only the simulated error returned an empty failure payload in this iOS 26 StoreKit 1 environment. Resetting the test session before the subsequent success check corrected the harness; the application still handles the actual cancellation callback.
- **Native-sheet title assertion:** SpringBoard exposed `400 Diamonds ` with trailing whitespace. The assertion now checks the full title with optional trailing whitespace. Screenshots use `XCUIScreen.main` so the system sheet is included.

## Passing service cases

All in `StoreKit1PaymentTests`:

1. `testAllSevenPackagesCreditExactAmountsAndPersist`: exact USD fixture prices, seven individual credits, 112,700 total diamonds, seven IDs/history entries and service restart persistence.
2. `testRepeatConsumablePurchasesCreditEachNewTransaction`: three immediate 400-diamond purchases, 1,200 total, three distinct transaction IDs.
3. `testCancellationDoesNotCreditAndNextPurchaseSucceeds`: canceled callback produces no credit; next purchase succeeds.
4. `testPaymentFailureDoesNotCredit`: injected StoreKit failure produces no balance/history change.
5. `testAskToBuyCreditsOnlyAfterApproval`: no early credit; approval delivers 800 diamonds.
6. `testFailedSaveRecoversOnObserverRestartAndDuplicateDoesNotCreditTwice`: failed atomic delivery remains unfinished; restart recovers 400; replay into a fresh observer does not add a second credit.
7. `testPartialCatalogRetryAndStaleCallbackCannotReplaceNewRequest`: valid partial offers survive a failed refresh; old results do not replace the new request.
8. `testTimeoutCancelsRequestAndLateResultCannotReplaceRetry`: explicit timeout, cancellation, retry and late-result rejection.
9. `testSessionEndWhileLoadingPreventsDelayedPurchase`: pending waiter settles; no StoreKit transaction is submitted after session end.
10. `testEmptyCatalogAndSanitizedErrorDiagnostics`: unavailable state, disabled offers and bounded domain/code diagnostics without supplied private error values.

Catalog edge cases use a controlled transport to deliver real products fetched from the StoreKit fixture. They verify application behavior, not Apple's network infrastructure. Purchases and transaction callbacks use StoreKitTest; wallet delivery uses the actual `LocalLibraryRepository` atomic persistence implementation.

## Passing UI cases

- `testSevenPurchasesPricesCancellationAndRelaunchHistory`: ordinary welcome/entry/Me/Wallet navigation in a UUID-isolated test library; seven exact fixture prices; seven purchases totaling 112,700; app-confirmation cancellation submits no extra payment; StoreKit cancellation does not credit; relaunch preserves balance and seven activity entries.
- `testNativePaymentSheetShowsProductPriceAndCancelsWithoutCredit`: dialogs enabled; SpringBoard shows **400 Diamonds**, **Toti**, **$0.99** and Xcode's no-charge test notice. Dismissal produces the cancellation message, leaves zero diamonds and enables purchasing again.

The application has no production free-credit or bypass path. UI tests pair fresh StoreKit history with a fresh UUID-scoped library. The normal wallet and private library are preserved.

## Screenshots

- [Loaded catalog](catalog.png)
- [App confirmation](purchase-confirmation.png)
- [Seven completed purchases](seven-purchases.png)
- [Native Xcode StoreKit sheet](native-payment-sheet.png)
- [Native-sheet cancellation](native-cancellation.png)
- [Injected StoreKit cancellation](storekit-cancellation.png)
- [Balance and history after relaunch](relaunch-balance.png)
- [System accessibility evidence](native-sheet-hierarchy.txt), [attachment provenance](attachment-manifest.json)

Screenshots were opened and visually inspected. System-owned controls may use the simulator's language; Toti-authored copy remains English.

The final application was reinstalled and launched on Toti UI Acceptance (PID 61142); [launch screenshot](final-launch.png). This direct launch uses no local StoreKit fixture. To interactively test local payments, run the `toti` scheme from Xcode.

## Repeating the checks

Read the current global/project rules first. Use the specified simulator and current working tree. Build the selected test scheme with `build-for-testing`, install and launch that resulting `toti.app`, then execute `test-without-building` with the same scheme/destination/derived-data path. Use fresh result paths, serial tests and `CODE_SIGNING_ALLOWED=NO` for simulator commands only. After tests, launch the latest build again on Toti UI Acceptance.

- `totiPayments` + `-only-testing:totiPaymentTests/StoreKit1PaymentTests`: the ten local service cases.
- `totiPurchases`: both purchase UI cases.
- `toti`: all existing unit/integration cases.
- `totiPayments` + `-only-testing:totiPaymentTests/CatalogAvailabilityTests`: Apple catalog probe, with no local Run configuration; run separately from local StoreKit tests.
- Xcode Run scheme `toti`: interactive local StoreKit fixture.
- Xcode Run scheme `totiAppStore`: no local fixture, for authorized Apple-side verification.

Final result bundles: `/private/tmp/toti-payments-repaired-v2.xcresult`, `/private/tmp/toti-purchase-ui-final.xcresult`, `/private/tmp/toti-core-regression-final.xcresult`. Apple probe: `/private/tmp/toti-apple-catalog.xcresult`. Temporary logs share the corresponding names with `.log`; the core build log is `/private/tmp/toti-core-build.log`, and final destination-only build log is `/private/tmp/toti-iphone-final-build.log`. Durable summaries and selected screenshots are retained here; raw StoreKit logs containing system-generated receipt payloads are not copied into the project.

## Remaining boundaries

Apple catalog readiness must be checked against the intended registered app, exact consumable IDs, availability/metadata, signing/provisioning and account agreements. Invalid IDs in this unsigned simulator probe do not establish which Apple-side prerequisite is missing. No App Store Connect account configuration was modified.

Server receipt validation, authoritative account ownership, refund reconciliation and cross-device wallet recovery remain unimplemented. Current delivery validates product mapping, quantity, transaction identity and durable deduplication from StoreKit 1 callbacks; it does not add cryptographic receipt verification. iOS 16 runtime behavior, parental purchase restrictions, deferred rejection and physical-device sandbox payments were not exercised. No destructive account deletion was performed.
