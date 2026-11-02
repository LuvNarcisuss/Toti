# Signing and StoreKit revalidation — November 2, 2026

## Environment and scope

The user requested a new build and purchase verification after aligning the
development team with Bibi. The selected destination is **Toti UI Acceptance**,
UUID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, iPhone 17 Pro, iOS 26.0.1 (23A8464).
Xcode is 26.0.1 (17A400). The source uses team `JPTS6M4T5B`, target `toti` and
Bundle ID `com.toti.music`.

This covers simulator signing and local StoreKit 1 purchases only. It does not
verify device signing, Apple-hosted sandbox products, production transactions or
resolution of the team's Apple Program License Agreement restriction.

The retained Guest namespace `26F9BA6F-44AC-4A36-9B37-DF739B215A3C` is reused.
Purchase UI cases create fresh UUID-scoped local wallets. Existing accounts,
social records, manual test wallets and the legacy archive are preserved.

## Observed results

- The latest source built successfully, passed `codesign --verify --strict`, and
  was installed and launched before testing. Its signature is `adhoc` with
  identifier `com.toti.music`. `TeamIdentifier=not set` is expected for this local
  simulator signature; it is not evidence of a device development certificate.
- The seven-tier UI case passed: all prices and enabled offers, exact cumulative
  credit of 112,700 diamonds, both app and StoreKit cancellation, and process
  relaunch retaining the balance and seven activity records.
- The initial native-sheet case failed when XCTest queried `isHittable` while
  SpringBoard's dismiss-button frame was still moving. The recorded frames moved
  from approximately y=598 to y=522. The failure screenshot showed the correct
  local Xcode payment sheet. The test now waits for an on-screen frame that stays
  unchanged for at least 0.5 seconds before requesting a hit point. Purchase
  product/price, cancellation and zero-credit assertions remain intact.
- The next native-sheet attempt stopped before reaching the wallet: the live
  login remained at `Logging in…` beyond the existing 30-second expectation.
  This result is a failed prerequisite, not a payment pass. The login timeout was
  not increased and no authentication bypass was added.

- Once the shared simulator was idle, native-sheet revalidation passed, including
  the product/price assertions, cancellation notice and unchanged zero balance.
- That run exposed a second XCTest hit-point lookup exception on the 5,150 offer.
  The failure screenshot and hierarchy show the control was visible. This is not
  evidence of a missing offer or failed transaction. The reveal helper now checks
  the control's geometry against the scroll viewport before an ordinary XCTest
  tap, rather than calling `isHittable` as its scroll-condition probe. It still
  fails if the control cannot be brought into view; payment assertions are intact.

## Final test results

Both revised suites passed on the named simulator with **19 tests, zero failures
and zero skips**. Each suite was preceded by a current-source build, strict
signature verification, installation and launch.

| Suite | Passed | Coverage |
| --- | ---: | --- |
| `totiPurchases` | 2 | Seven prices and purchases, 112,700 diamonds, app and StoreKit cancellations, native sheet product/price and dismissal, relaunch with seven records |
| `totiPayments` / `StoreKit1PaymentTests` | 17 | Exact credit, repeat consumables, failed/canceled/deferred payments, atomic persistence recovery, duplicate delivery, owner isolation, catalog retry/timeout/stale callbacks, session end, local spend consistency |

The passing UI run finished at 14:33 and the service run at 14:34, Asia/Shanghai.
Screenshots were visually reviewed: all seven prices are shown, the local-test
notice is readable, and the native sheet identifies 400 Diamonds / $0.99 with
Apple's no-charge testing notice. History count is asserted through accessibility;
the top-of-wallet screenshot does not show every activity row.

The earlier failures above are retained as failed attempts, not counted as
successful coverage. No production payment logic, authentication timeout or
purchase-success assertions were changed during this revalidation.

Machine-readable counts and destination metadata are in
[the result summaries](signing-iap-20261102-results.json).

## Evidence

- Initial result: `/private/tmp/toti-signing-iap-20261102-ui.xcresult` (one passed
  seven-tier case and one failed native-sheet case).
- Login timeout: `/private/tmp/toti-signing-iap-20261102-retry-ui.xcresult`.
- Initial build and signature:
  `/private/tmp/toti-signing-iap-20261102-ui-build.log` and
  `/private/tmp/toti-signing-iap-20261102-ui-signature.txt`.
- Screenshots and attachment manifests are retained under
  `Assets/Verification/SigningIAP20261102/` in the ignored local media archive.

- Final UI result: `/private/tmp/toti-signing-iap-20261102-verified-ui.xcresult`.
- Final service result: `/private/tmp/toti-signing-iap-20261102-verified-service.xcresult`.
- Final build/signature logs share the `/private/tmp/toti-signing-iap-20261102-verified-` prefix.
- Passing screenshots and manifest: `Assets/Verification/SigningIAP20261102/passed/`.

## Final running state

After testing, Xcode ran the current `toti` scheme on **Toti UI Acceptance**.
The toolbar reported `Running toti on Toti UI Acceptance` at 14:35, and the
Simulator visibly displayed Toti's welcome screen. The scheme enables
`TOTI_LOCAL_STOREKIT_TESTING=1` and `TotiDiamonds.storekit`. The installed app's
strict signature verification also passed. The normal entry flow is retained;
manual access continues through Log in, then Me > Wallet. No agreement was
accepted on behalf of the normal user during the final launch.
