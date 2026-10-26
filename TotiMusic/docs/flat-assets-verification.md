# Flat asset verification — 2026-10-26

The workspace-root Assets folder contains only files. All source images, SVGs, videos, fonts, source artwork, screenshots, agreements, credits and provenance records are direct children. English prefixes resolve filename collisions; all 320 original media files remain byte-identical.

## Build behavior

Configuration/AssetCatalog.json maps flat source files to 416 native catalog entries. The Prepare flat asset catalog phase calls scripts/prepare_asset_catalog.py and writes FlatAssets.xcassets exclusively in DERIVED_FILE_DIR. Xcode compiles it through the normal resource phase, preserving 206 image-set identities, AppIcon, SVGs and the launch color. This was verified both in a probe and by building the actual app from an empty DerivedData path.

The generated catalog is disposable. The preparation script runs each build, updates changed input bytes and removes stale generated entries. It never creates subdirectories in source Assets. Fonts, agreements and credits are direct file references; agreements now load from the bundle root without changing their bytes or acceptance hash. Archived videos, duplicate agreement fonts, source artwork and screenshots remain excluded from the app bundle.

## Verification

- Python catalog preparation tests: 4 passed (names/bytes preserved, modified inputs and stale outputs, missing inputs preserve the prior output, source-side output prohibited).
- Static audit: zero issues, including a flat-directory assertion, 209 catalog metadata records, 61 icon cases, 82 photography records and archived video/cover checks.
- Actual app built from empty `/tmp/toti-flat-assets/DerivedData`; all 23 XCTest tests passed, including all 206 images, AppIcon/launch color, fonts, agreements and media credits.
- Independent read-only review found no actionable defect: 550 source files map one-to-one without directory or filename collisions. Three metadata/docs files changed intentionally to update references; media bytes did not change.
- Five-page UI verification: 1 scenario passed with zero failures in 56.369 seconds. Welcome/consent, Lounge, Voice, Notebook, Chats, Me, profile save, Wallet and Settings were exercised. The exported Lounge screenshot was visually checked. [Lounge screenshot](../../Assets/Screenshots__flat-assets__lounge.png).

Evidence: `/tmp/toti-flat-assets/unit-tests.xcresult`, `unit-tests.log`, `/tmp/toti-flat-assets/ui-tests.xcresult` and `AssetFlattening.json` in the workspace root. Current inventory and directory tree are also in the workspace root.

Existing non-blocking AppIntents metadata and JPEG Photoshop-metadata diagnostics are documented in the earlier migration record. This check covers iPhone 17 Pro Simulator (iOS 26.0.1); it does not claim real-device signing or connected remote services.

The simulator was in Shutdown state when an optional post-test manual launch was attempted; this did not affect the completed UI test result. The application was not left running.
