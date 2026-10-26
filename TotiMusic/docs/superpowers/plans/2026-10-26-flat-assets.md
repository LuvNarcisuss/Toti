# Flat Assets Implementation Plan

> Execute inline, with resource tests and final verification before completion.

**Goal:** Store every source asset directly in the workspace-root Assets folder, with no subdirectories, and keep the app working.

**Architecture:** Preserve flat image/font filenames and archive provenance with collision-free English prefixes. Store a catalog mapping in Configuration/AssetCatalog.json; a pre-build script recreates the native catalog only in DERIVED_FILE_DIR. Xcode compiles that generated catalog through its normal resource build phase. Agreements and fonts are copied directly from flat Assets into the bundle root.

**Spec:** The user's latest instruction explicitly replaces the previous nested Assets layout with a flat folder and requires project references to follow it. Prior build/run/test authorization remains applicable.

## Tasks

- [x] Verify XcodeGen and Xcode accept a generated catalog in DERIVED_FILE_DIR using a throwaway probe.
- [x] Test and implement catalog generation, including changed/missing inputs and stale outputs.
- [x] Flatten files with recorded hashes; update configuration, preparation scripts, runtime agreement lookup and documentation links.
- [x] Run static checks, Python tests, the app's resource/unit tests and a five-page UI test from a clean derived-data directory.
- [x] Verify zero subdirectories, preserve every original media byte, refresh inventories and record results.

## Constraints

- All durable media remains in Assets, with no source-side catalog or archive subdirectories.
- Runtime image identifiers, app icon, launch color, font PostScript names and agreement bytes remain unchanged.
- Only runtime assets, fonts, agreements and credits are bundled; retired videos, source artwork and verification screenshots are excluded.
- Preserve user data and unrelated edits. Back up the current files under /tmp before flattening.
- Build generation must be reproducible after deleting DerivedData; it must not depend on a prior XcodeGen/build run.

## Verification ledger

- Probe build succeeded using a file reference at $(DERIVED_FILE_DIR)/FlatAssets.xcassets and a pre-build script declaring that directory as its output.

- New-cache app build and 23 XCTest cases passed. All 550 logical paths resolve to direct Assets children; all 320 original media hashes match. Independent review found no actionable defect. UI test passed (56.369 seconds, zero failures).

- Final screenshot reviewed. All source assets remain flat; optional manual relaunch after testing encountered a shutdown simulator, so no running-app claim is made.
