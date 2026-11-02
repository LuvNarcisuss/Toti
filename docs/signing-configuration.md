# Signing configuration

Updated November 2, 2026.

The owner requested the same signing setup as Bibi. Toti's Xcode project already
selected team `JPTS6M4T5B`, but its XcodeGen source omitted the team. The source now
records that selection so project generation preserves it in Debug and Release.

| Setting | Toti value |
| --- | --- |
| Project source | `TotiMusic/project.yml` |
| Application target | `toti` |
| Bundle identifier | `com.toti.music` |
| Development team | `JPTS6M4T5B` |
| Simulator signing | SDK-specific ad-hoc identity `-`, signing enabled |
| Local StoreKit scheme | `toti`, with `Configuration/TotiDiamonds.storekit` |
| Apple catalog scheme | `totiAppStore`, without the local fixture |

## Device and CI signing

Toti keeps its own Bundle ID and product identifiers. Bibi's provisioning profile
cannot be substituted for a Toti profile just because both apps select the same
team. Apple registration and valid device/distribution signing assets are still
required for the corresponding build destination.

The existing Codemagic workflow already uses Bibi's stored-signing-files pattern:
`environment.ios_signing`, `distribution_type: app_store`, Toti's bundle identifier,
and `xcode-project use-profiles`. No CI signing-mode change was needed. The matching
certificate/private key and Toti profile must be configured in Codemagic; their
remote availability has not been verified. No credentials were copied or changed.

## Apple agreement limitation

`PLA Update available` is an Apple membership access error. Selecting the team or
applying existing signing files does not accept or update the Program License
Agreement. The Account Holder must review and accept the updated agreement for
the selected team before restricted membership requests can succeed. The Bibi
records contain local StoreKit verification and signing configuration, not proof
that a PLA restriction was resolved.

Apple reference: https://developer.apple.com/help/account/access/resolving-access-issues

## Verification scope

The project was regenerated with XcodeGen. Static checks confirmed that the source
and both generated application build configurations retain the selected team and
Toti Bundle ID. Simulator signing and the local/Apple StoreKit scheme separation
were preserved. That configuration-only step did not run runtime tests.

The subsequently authorized November 2 revalidation built, installed and launched
current source on Toti UI Acceptance. Strict signature verification passed with
an ad-hoc simulator signature. Both local StoreKit suites passed: two UI cases
and 17 service cases, with zero failures or skips. See the
[purchase revalidation record](payment-verification/signing-iap-20261102.md).
This does not verify device signing or resolve Apple membership access. No
Developer Portal agreement, provisioning profile or CI build was changed.
