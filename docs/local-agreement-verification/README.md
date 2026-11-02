# Local agreement verification

October 27, 2026: **4 UI tests and 1 focused resource test passed, zero failures**.

## Behavior

The user replaced online-only agreements with local HTML in the repository-root Agreements directory. Login and Settings read the same bundled files. WKWebView navigation is restricted to the selected file; inline styles, system fonts and a restrictive content security policy eliminate external resource requests. Retry reopens the local file. Reading requires no internet connection.

The Privacy Policy describes local reading and content-derived acceptance records. Both documents use Toti and retain blank publisher/contact email fields and a draft notice. Google Docs are wording provenance, not runtime dependencies. Their subsequent edits do not update installed copies.

## Environment and coverage

- Toti UI Acceptance, iPhone 17 Pro, iOS 26.0.1 (23A8464).
- UDID: 98658066-C6E0-45B3-A1E7-E8FBD950F0DB.
- App: com.toti.music, Debug, simulator signing disabled.
- Latest working-tree source was built, installed and launched on this simulator before each test invocation. The final build was installed and launched again after testing.
- AgreementUITests: 4 passed in 140.959 seconds. Both agreements opened from Login and Settings; Close/Back returned successfully. Both also opened and reopened with Retry while viewer transport was blocked.
- BundledResourceTests.testAgreementsContainCurrentSelfContainedHTML: 1 passed. Checked current bundled files, titles, date, blank email, CSP, no scripts or stale Tito name, and content-derived acceptance version.
- Static checks found no external src/href/srcset references. git diff --check passed. Bundled HTML matched root HTML byte for byte.
- UI tests used UUID-scoped libraries. No purchase, remote message, account deletion or existing-library mutation was performed.

Offline tests used a Debug-only proxy setting gated by an isolated test library, with network failover disabled. A loopback CONNECT proxy refused connections during each offline case. The [transport log](transport-log.json) records both intervals and no outgoing tunnel requests. This was scoped viewer transport interruption, not device-wide airplane mode. The proxy was stopped afterward.

Missing/corrupt bundle files and WebKit process termination were not injected. Unrelated full application and payment suites were not rerun. Earlier online-viewer attempts are superseded and are not counted as passing acceptance for this implementation.

## Screenshots

| Entry | Terms | Privacy |
| --- | --- | --- |
| Login | [Terms](../../Assets/Screenshots__local-agreement-verification__login-toti-terms-of-service.png) | [Privacy](../../Assets/Screenshots__local-agreement-verification__login-toti-privacy-policy.png) |
| Settings | [Terms](../../Assets/Screenshots__local-agreement-verification__settings-toti-terms-of-service.png) | [Privacy](../../Assets/Screenshots__local-agreement-verification__settings-toti-privacy-policy.png) |
| Login, reopened offline | [Terms](../../Assets/Screenshots__local-agreement-verification__reopened-offline-login-toti-terms-of-service.png) | [Privacy](../../Assets/Screenshots__local-agreement-verification__reopened-offline-login-toti-privacy-policy.png) |
| Settings, reopened offline | [Terms](../../Assets/Screenshots__local-agreement-verification__reopened-offline-settings-toti-terms-of-service.png) | [Privacy](../../Assets/Screenshots__local-agreement-verification__reopened-offline-settings-toti-privacy-policy.png) |

## Evidence

Result bundles: /tmp/toti-local-agreements/ui.xcresult and /tmp/toti-local-agreements/resources.xcresult. Build/test logs are in that directory. DerivedData was reused at /tmp/toti-online-agreements/DerivedData; the directory name is historical.

SHA-256 of both source and built files:

- TermsOfService.html: a36fe7bc47f0b0f73723dc98e3cfff14edea8b86975e15984c64ab3c538de132
- PrivacyPolicy.html: 4162aa8aef7c599ff1912c7eafff60022bbeff4949e1d9f690fe47add0301764

To reproduce when authorized, start TotiMusic/scripts/agreement_test_proxy.py, build totiUI for the exact simulator above, install and launch, then run totiUITests/AgreementUITests with parallel testing disabled. For the resource check, build toti, install and launch, then run the focused test above. Stop the proxy and leave the latest app running afterward.
