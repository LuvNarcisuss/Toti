# Toti — music community for iOS

Open **TotiMusic/Toti.xcodeproj**, scheme **toti**. UIKit, Swift 5, iOS 16+, iPhone only. The `toti` Run scheme enables local StoreKit testing; use **totiAppStore** without a local fixture for Apple catalog/sandbox verification.

Five tabs: **Lounge / Voice / Notebook / Chats / Me**. Live and Shorts playback/creation are retired, including profile and chat routes. Retired source and media are excluded from the app target; historical private records are preserved.

- **Lounge:** music topics, search, following/saved views, image posts, drafts/editing, likes/saves/comments, reports/blocks and links to voice rooms. Posts and replies are saved on this device.
- **Notebook:** private lyrics/chords/ideas, moods, search, pinned notes, templates, duplicate/delete, guarded editing and explicit conversion to a separate Lounge draft.
- **Voice / Chats:** existing room, conversation, relationship, moderation, camera-call and wallet flows retained.
- **Diamond gifts:** Lounge post details and existing Voice rooms reuse the nine-gift picker. Confirmation shows the recipient, total and remaining balance. Gifts create a local effect and wallet record; recipient delivery and earnings are not connected. Profiles and Chats have no gifting entry point. Ordinary posts, replies, messages and Notebook use remain free.
- **Me:** posts, saved posts, drafts, notebook shortcut, room drafts, profile and wallet.

New states are optional fields in the existing atomic library. Bounded normalized post photos are embedded in the same snapshot, so a failed save cannot leave a mismatched photo and text. Logout retains data; explicit account deletion clears all owned state. Original Photos items remain untouched.

Authentication, remote publishing/moderation, RTC and message delivery are not connected. The seven supplied diamond product IDs are configured in `TotiIdentity` and use the existing StoreKit 1 purchase flow. The StoreKit 1 client has local service and UI regression coverage; Apple sandbox purchases remain unverified. App Store Connect availability, signing and the matching bundle ID still need confirmation. Wallet balances are device-local, with no server receipt validation or account synchronization. See [StoreKit 1 integration](docs/storekit1-integration.md). Publisher identity/contact and final distribution terms are still required.

Design: [approved specification](docs/music-community-redesign.md). Plan: [implementation steps](docs/superpowers/plans/2026-10-26-community-notebook.md). [Earlier community verification](docs/community-verification.md): all 20 XCTest tests passed; Xcode built and launched the updated app on iPhone 17 Pro. A subsequent computer-controlled five-page pass verified key local flows and fixed room activity, delivery wording and stale copy; details and screenshots are in the current verification record. Previous runtime records describe the retired version.

Latest payment repair: [35 passing tests and evidence](docs/payment-verification/README.md). Apple sandbox purchases remain unverified.

Latest existing-surface gifts: [42 passing tests and screenshots](docs/gift-verification/README.md). Lounge post gifts and recipient-aware Voice gifts are local effects and records; Profiles and Chats have no gift entry point.

## Repository layout

`AGENTS.md`, `README.md`, `.gitignore` and `docs/` live at the repository root. `TotiMusic/` contains the Xcode project, application source, configuration, tests and scripts; `Assets/` contains the shared resources. Commands in this README run from the repository root. Existing technical and historical documents that use application-relative paths such as `Toti/`, `Configuration/` or `Toti.xcodeproj` refer to `TotiMusic/`; run their application commands from that directory unless stated otherwise.

## XCTest UI automation

Open `TotiMusic/Toti.xcodeproj`, select the **totiUI** scheme and **Toti UI Acceptance**, then choose **Product → Test** (⌘U). The existing **toti** scheme continues to run the unit/integration tests.

```sh
xcodebuild -project TotiMusic/Toti.xcodeproj -scheme totiUI \
  -destination 'platform=iOS Simulator,id=98658066-C6E0-45B3-A1E7-E8FBD950F0DB' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

`TotiMusic/UITests/CommunityUITests.swift` drives the real screens and saves screenshots in the test result bundle. Every test uses a UUID-scoped library under the app's `Application Support/UIAutomation` directory, retained for restart checks. This storage override is Debug-only; Release ignores it. Existing user content remains in its original library. The suite exercises local state, not remote delivery, RTC or purchases.

See the [UI acceptance report and screenshots](docs/xctest-ui/README.md) for coverage, the Notebook keyboard fix, and recorded results.

## Shared assets

All resources live directly in the workspace-root [`Assets/`](Assets) folder, with **no subdirectories**. Keep this sibling folder together with `TotiMusic/` when copying the project. Runtime bitmap filenames use their existing asset names; archive files use English source prefixes to avoid collisions.

Xcode's **Prepare flat asset catalog** build phase uses `TotiMusic/scripts/prepare_asset_catalog.py` and `TotiMusic/Configuration/AssetCatalog.json` to recreate `FlatAssets.xcassets` inside `DERIVED_FILE_DIR`. Xcode then compiles it normally, preserving `UIImage(named:)`, AppIcon, vector assets and launch colors. The generated catalog is disposable; it is never stored under source Assets. Both fonts, both agreement HTML files and MediaCredits.json are copied directly from flat Assets into the app bundle root. Archived media is excluded from the bundle.

Run `xcodegen generate --spec TotiMusic/project.yml` from the workspace root after changing project configuration. The media-processing scripts use `TotiMusic/Configuration/AssetLayout.json` to keep their inputs and outputs flat. Adding a catalog resource requires updating the catalog/layout mappings and its Catalog-*.json metadata.

See [flat asset verification](docs/flat-assets-verification.md), [earlier migration verification](docs/asset-migration-verification.md), and [asset preparation tests](TotiMusic/scripts/tests/test_prepare_asset_catalog.py).
