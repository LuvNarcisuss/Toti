# Asset migration verification — 2026-10-26

> Historical record: the nested layout below was superseded by the [flat asset layout](flat-assets-verification.md). Current source Assets contains files only.

All application resources and archived media now live under the workspace-root `Assets/` directory. XcodeGen explicitly includes the asset catalog, Fonts, Agreements and MediaCredits.json. Source artwork, retired videos and screenshots remain excluded from the application target.

## Checks completed before deleting originals

- Static audit: no issues; 209 catalog metadata files, 61 icon enum cases, 82 photography records, 9 archived video/cover pairs validated.
- XCTest: 23 tests passed, including 3 new resource tests. All 206 image-set names and the launch background color load, both original font names register, agreements and media credits resolve, AppIcon metadata is present, and no retired MP4 enters the bundle.
- Source integrity: 546 mapped files, including 316 media files. The total includes 3 screenshots added since the earlier 313-file export. Original and destination hashes verified; only the packaging note and community provenance path strings were intentionally updated.
- Independent read-only review found one stale screenshot index; all 20 index paths were corrected and checked.

## Runtime verification

The existing `CommunityUITests.testFivePagesAndProfile` UI test passed in 65.965 seconds with zero failures. It entered the app through the welcome/consent flow, visited Lounge, Voice, Notebook, Chats and Me, saved the unchanged profile and inspected Wallet and Settings. Exported Lounge and Voice screenshots were visually checked; navigation artwork, fonts, avatars and photographic room covers render correctly.

Screenshots: [Lounge](../Assets/Screenshots__asset-migration__lounge.png), [Voice](../Assets/Screenshots__asset-migration__voice.png).

All 546 original files were deleted only after the tests and full hash checks passed. A scan confirms no media file remains outside Assets. The post-cleanup static audit also passes. A fresh `xcodebuild clean build` succeeded after deletion. The rebuilt app was installed and launched on iPhone 17 Pro (iOS 26.0.1); its process remained running (PID 98118). The welcome screen was visually checked: brand icon, illustration, typography and Get started action render correctly. [Final welcome screenshot](../Assets/Screenshots__asset-migration__welcome.png). The clean app bundle contains the new catalog, byte-identical fonts/agreements/credits, and no archived video, source-artwork or screenshot directories.

The initial UI runner received SIGKILL while entering Lounge. No missing-resource failure was reported. The same binary passed on retry without rebuilding; the SIGKILL origin remains unconfirmed and required no application code change; the initial failure is retained in `/tmp/toti-asset-migration/ui-tests.xcresult`.

## Diagnostics and scope

Xcode emits an AppIntents metadata extraction warning because this project has no AppIntents dependency. Some unchanged JPEGs have malformed Photoshop 8BIM metadata warnings during decoding; every image still loaded with nonzero dimensions. The existing invalid-photo input test logs a thumbnail decode error as expected and passes.

This verification covers the iPhone 17 Pro simulator running iOS 26.0.1. It does not establish real-device signing, other screen sizes or unconnected authentication, remote delivery, RTC and purchasing services.

Evidence is saved under `/tmp/toti-asset-migration/`. `AssetSources.json` records historical and current paths plus original/current SHA-256 values. Current directory and file inventories are in the workspace root.

## Final state

- Migrated resources: 546 files, including 316 media files; all old paths removed.
- Three new verification screenshots also live under Assets, bringing the media inventory to 319 files.
- All source-to-destination hashes match, except the two deliberately updated metadata documents whose original/current hashes are both recorded.
- Application production Swift code and persistent user data were not changed by this migration.
- Test evidence: `unit-tests.xcresult` (23 passed), `ui-retry.xcresult` (1 UI scenario passed), `clean-build.xcresult` (clean build succeeded), under `/tmp/toti-asset-migration/`.
