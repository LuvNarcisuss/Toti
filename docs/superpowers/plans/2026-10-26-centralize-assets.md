# Centralize Assets Implementation Plan

> Execute inline with superpowers:executing-plans; verify with superpowers:verification-before-completion.

**Goal:** Make root `Assets/` the only source of media and application resources, verify the app, then delete the old files.

**Architecture:** Preserve native asset catalog identifiers, font filenames, agreement bundle paths and licensing records. Keep runtime resources, original artwork, retired videos and screenshots under one Assets root; only explicitly selected runtime resources enter the app bundle.

**Spec:** User request in this chat: update project references to the new asset folder, ensure normal operation, then delete originals. Build, Simulator and tests are authorized by this request.

**Tech stack:** UIKit, Swift 5, iOS 16+, XcodeGen, XCTest.

## Constraints and decisions

- Work in the requested existing workspace; the entire TotiMusic folder is untracked, so a new Git checkout would not contain it. No commits or unrelated changes.
- Retain Xcode-required asset catalog subdirectories under Assets. Runtime names and app behavior do not change.
- Retired videos remain outside the app target. Source copies and agreement font duplicates remain preserved.
- Stage and hash-check every file before changing references; retain originals until tests pass.
- This is a configuration/file relocation. Add focused runtime resource regression coverage and run existing UI flows; no production behavior is added.

## Tasks

- [x] Inventory resources; stage catalog, fonts, agreements, credits, source media and screenshots under Assets; record original/current paths and hashes.
- [x] Update project.yml and regenerate Xcode project. Update media scripts, current manifests, documentation and inventories.
- [x] Verify catalog JSON, image files, font registration, agreements, credits, and no retired video bundled; run unit tests and UI smoke test on iPhone 17 Pro.
- [x] Review migration. Only after successful runtime validation, hash-check and delete original files, remove empty directories, and reverify from a clean build.

## Review focus

- Duplicate image.png and welcome.png preserve their distinct bytes and catalog identities.
- Asset catalog colors and AppIcon metadata survive migration.
- UIFont PostScript names and agreement URLs remain valid.
- Source videos, screenshots and generation inputs must not enter the runtime bundle.
- Scripts and relative screenshot links must resolve after original folders are removed.

## Verification ledger

- Initial simulator discovery needed sandbox escalation; approved simctl access found iPhone 17 Pro booted.
- Staging preserves all 313 exported media files; originals retained for now.

- Unit/integration/resource tests: 23 passed. UI five-page/profile/wallet/settings test: passed on unchanged-binary retry; first runner received SIGKILL.
- Independent review: screenshot index paths fixed; no other findings. All 546 original resource files removed after successful tests and per-file hash verification. Post-cleanup static audit passes; clean build and final Simulator launch passed.

- Final: clean build succeeded with old paths absent; app installed/launched as PID 98118 and welcome screenshot visually verified. All 316 migrated media files plus 3 verification screenshots are under Assets. Runtime Swift behavior unchanged.
