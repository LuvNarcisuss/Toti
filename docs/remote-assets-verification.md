# Remote asset migration verification

Historical record: the Git state described below is superseded by [history cleanup verification](git-history-cleanup.md).

Date: 2026-10-27. Status: complete. All four XCTest schemes and the Python suite passed; local Assets is preserved and excluded from Git tracking.

> Historical verification: the local agreement change on October 27, 2026 supersedes the agreement packaging statements and resource counts below. Agreement HTML now comes directly from the workspace-root Agreements directory, not R2 or Assets. The tests recorded below predate that change. See README.md for current agreement behavior and verification.

## Resource source and build behavior

The user-confirmed origin is `https://pub-e1dd5165c5cf490785389b0538d5d63e.r2.dev/`. It replaces the initially supplied origin, which contained different files and missing Toti resources.

- `TotiMusic/Configuration/RemoteAssets.json` pins 551 HTTPS objects with SHA-256 and byte count. Every object was downloaded and matched the existing Toti bytes.
- `AssetCatalog.json` contains 416 HTTPS source mappings. `AssetLayout.json` contains 550 historical identity-to-URL mappings. Documentation media links use the same origin.
- Xcode downloads 421 required runtime objects into DerivedData, generates the native catalog and stages the five loose bundle files. No build step reads local Assets. Runtime UIKit resource names remain unchanged, so installed applications retain offline imagery, fonts and agreements.
- Resource scripts read verified cached inputs and write editable output under `build/ResourceTools/output`. They do not silently change published manifest hashes or upload files.

## Validation environment and evidence

All simulator operations use **Toti UI Acceptance**, UUID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. The local Assets folder was temporarily moved outside the checkout before the fresh DerivedData build and remained absent throughout acceptance. Before each scheme, the latest application was built, installed and launched on that same device.

Evidence is under `/tmp/toti-r2-migration/`:

| Check | Result | Evidence |
| --- | --- | --- |
| All 551 remote objects | Passed byte count and SHA-256 | `remote-validation.log` |
| Python preparation suite | 12 passed | `python-final.log` |
| Fresh resource download and Xcode build | Passed with local Assets absent | `build.log` |
| Bundle verification | Compiled catalog present; both fonts, both agreements and credits match pinned hashes; no MP4; iPhone only | App under `DerivedData/Build/Products/Debug-iphonesimulator/toti.app` |
| Static audit | No issues | `static-audit.log` |
| Missing-cover-cache regression | Reproduced, fixed, passed | `cover-red.log`, `cover-green.log` |
| Application unit/integration tests | 23 passed, zero failures | `toti.xcresult` |
| Payment and gift service tests | 17 passed, zero failures | `totiPayments.xcresult` |
| Purchase and gift UI tests | 5 passed, zero failures | `totiPurchases.xcresult` |
| General UI tests | 5 passed, zero failures after correcting the obsolete wallet assertion | `totiUI-final.xcresult` |

The initial general UI suite had four passing tests and one failure: `testFivePagesAndProfile` still asserted pre-payment-integration wallet copy. The failure accessibility tree showed zero balance, all seven package identifiers and current gift/free-message text. The test now checks those current behaviors; no application functionality was changed. The complete five-test UI suite passed after rebuilding and reinstalling the latest application. Final XCTest totals are 50 passed, zero failed and zero skipped across the four schemes; Python totals are 12 passed. The latest build was installed and relaunched after testing (PID 19861), and its welcome screen was captured in `latest-running.png`. Initial failure evidence remains in `totiUI.xcresult`.

A separate code review found that static audit inferred video cover paths without fetching them. A regression run with all nine cover cache entries absent reproduced FileNotFoundError. Explicit remote cover resolution fixed it, and the same audit passed.

Purchase/gift and Lounge screenshots were visually inspected: generated icons, avatar, wordmark and custom fonts rendered. Payment checks use local StoreKit Test. A catalog probe returned seven identifiers in this simulator session, but this is not an independent Apple sandbox or production payment verification. No real-money transaction, service deployment or remote upload was performed.

## Git handling

After all tests passed, all 551 local files were restored and checked against the pinned byte counts and SHA-256 hashes. `/Assets/` was added to `.gitignore`; `git rm -r --cached -- Assets` removed only the index entries. Verification confirms 551 local files remain, all are ignored, and zero Assets files remain tracked. The 551 staged deletions represent removal from future Git snapshots, not deletion from disk. Existing Git history was not rewritten; earlier committed assets remain in that history. No commit or push was performed.
