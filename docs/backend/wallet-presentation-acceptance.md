# Wallet presentation acceptance

Date: 2026-10-30. Scope: restore and verify the online wallet layout while purchases and gifts remain unavailable.

## Environment and prerequisites

- Current workspace source, Xcode 26.0.1 (17A400), Debug, bundle `com.toti.music`.
- Toti UI Acceptance: `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, iPhone 17 Pro, iOS 26.0.1 (23A8464), x86_64.
- `totiAppStore` built successfully with project-configured simulator ad-hoc signing. `codesign --verify --strict` passed. The latest artifact was installed and launched on the specified simulator before testing.
- The user explicitly authorized one disposable cloud Guest account and its cleanup. The test used a fresh UUID under `TOTI_GUEST_ACCEPTANCE` and `TOTI_LIVE_GUEST_ACCEPTANCE=1`, keeping the test session separate from existing accounts and using the non-user-consent test marker.

## Result

`totiUI` / `OnlineReadinessUITests.testOnlineWalletShowsAllPackagesWithoutEnablingPurchases` passed: **1 test, 0 failures, 0 skips**. The test method took 34.513 seconds. The completed xcresult summary confirms the exact simulator and result.

The test entered through the welcome/login flow and opened Me > Wallet. Assertions covered:

- The balance area is present and reports `Balance unavailable`, without a fabricated zero balance.
- The page explicitly says purchases and gifts are temporarily unavailable.
- Exactly seven package controls exist, all disabled, each showing the matching USD reference price and `Unavailable`.
- No ineffective price-retry control appears in online mode.
- Scrolling reveals the Activity section with an unavailable-history explanation, rather than an empty-ledger claim.
- Teardown navigated to Settings, deleted only the disposable test account, and observed the return to Log in after the deletion flow completed.

| Diamonds | Reference USD price |
|---:|---:|
| 400 | $0.99 |
| 800 | $1.99 |
| 2,450 | $4.99 |
| 5,150 | $9.99 |
| 10,800 | $19.99 |
| 29,400 | $49.99 |
| 63,700 | $99.99 |

The exported screenshots were visually inspected. The initial viewport shows the balance explanation and payment notice; scrolling shows all seven full package cards and Activity. Amounts, prices and unavailable labels are not truncated. Screenshots remain in the ignored local evidence archive:

- `Assets/Verification/WalletRestoration/balance-and-notice.png`
- `Assets/Verification/WalletRestoration/seven-packages-and-activity.png`

After testing, the latest signed build was installed and launched again without the disposable account override. The normal cold-launch welcome remains the expected final screen after test-account cleanup.

## Evidence and limits

- Build log: `/private/tmp/toti-wallet-restoration-build.log`
- Test log: `/private/tmp/toti-wallet-restoration-ui.log`
- Result bundle: `/private/tmp/toti-wallet-restoration-ui.xcresult`
- Exported attachments: `/private/tmp/toti-wallet-restoration-attachments/`
- Derived data: `/private/tmp/TotiBackendAcceptance`

This verifies simulator presentation and disabled purchasing in online mode. It does not verify Apple catalog availability, local StoreKit transactions, Apple sandbox or production payments, server wallet balances, transaction delivery, account synchronization, other screen sizes or iOS 16. Historical local wallet credits and activity were not loaded or transferred. Cloud cleanup was observed through the successful application deletion flow, not independently queried through an administrative database connection.
