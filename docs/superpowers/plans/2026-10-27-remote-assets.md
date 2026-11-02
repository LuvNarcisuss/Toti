# Remote Assets Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace local resource dependencies with verified HTTPS resources and exclude local Assets from future Git snapshots only after acceptance passes.

**Architecture:** Use the user-confirmed Toti R2 origin https://pub-e1dd5165c5cf490785389b0538d5d63e.r2.dev/. Pin all existing resource hashes in a versioned manifest. Download required bundle resources to DerivedData at build time, then generate the native catalog and stage the five loose resources. Preserve native resource names and offline app behavior. Documentation links use the same public URLs. Preparation tools read verified remote cache entries and write editable output to a separate build workspace.

**Tech Stack:** Python standard library, system curl with TLS verification, XcodeGen, UIKit, XCTest.

**Spec:** User request in this conversation: replace all Assets resource references with HTTPS URLs, test, then ignore Assets without uploading local resources to GitHub. The corrected Toti origin supersedes the initially supplied origin.

## Constraints and decisions

- Preserve Toti identity, resource bytes, metadata, credits, private data and iPhone-only configuration.
- AppIcon and fonts must remain bundled; resource-name UIKit APIs are preserved. URLs are resolved at build time.
- No network failure or hash mismatch may silently fall back to source Assets.
- Downloads use a temporary file and atomic rename; validate cached bytes before reuse.
- Do not publish, upload, commit, push or rewrite Git history. After tests pass, untrack Assets with local files preserved.
- Run the latest app and all existing test schemes on Toti UI Acceptance only.

## Review focus

- Missing or corrupt remote files must fail preparation without replacing valid generated outputs.
- Warm cache must work offline; corrupted cache must be repaired or rejected.
- Paths must not escape the managed cache; only HTTPS resource URLs are accepted.
- A checkout without Assets must build from an empty resource cache.
- Git exclusion must not remove local files or accidentally include unrelated changes.

## Task 1: Remote resource preparation

- [x] Add downloader tests covering valid content, reuse, corruption repair, mismatch, HTTP failure and path validation; run RED.
- [x] Add a versioned RemoteAssets.json URL/hash/size manifest, update catalog/layout source URLs, implement verified atomic downloading and DerivedData staging.
- [x] Update preparation scripts, XcodeGen resource references and documentation links.
- [x] Run all Python tests and static inspection; validate all remote manifest objects.

## Task 2: Acceptance and Git exclusion

- [x] Hide the local Assets directory temporarily, build from empty DerivedData, install and launch on Toti UI Acceptance.
- [x] Run toti, totiPayments, totiPurchases and totiUI test schemes on that device; inspect the latest resource UI screenshot.
- [x] Restore Assets, leave the latest build running, and record evidence.
- [x] Review changes; after all checks pass add /Assets/ to .gitignore and remove only Assets from the Git index while preserving local bytes.

## Execution ledger

- Pre-flight: catalog URL entries and RemoteAssets URL records share one resolver; five direct bundle files use the same verified download cache.
- User corrected the R2 origin; six representative files match local SHA-256 hashes.

- All 551 remote objects downloaded and matched the existing SHA-256 and byte count; 12 Python preparation tests pass.

- Independent review found a missing remote cover fetch in the static auditor. Reproduced FileNotFoundError with the nine cover cache entries absent, then changed cover lookup to asset_file; the same regression check passed with zero issues.
- Fresh DerivedData build succeeded while Assets was absent. Bundle contains matching fonts, agreements and credits, compiled catalog and no retired MP4s. toti scheme: 23 tests passed. Remaining schemes are running.

- Runtime UI RED: testFivePagesAndProfile asserted retired wallet copy ("Diamond purchases are not available yet." and "gifts in voice rooms"). Current product code and approved payment docs support seven configured packages and gifts on posts as well as rooms. Updated only the test to assert the existing wallet accessibility IDs, zero starting balance, seven tiers and free messages/replies. Product behavior is unchanged; a complete UI rerun is required.

- Final verification: 23 application tests, 17 payment/service tests, 5 purchase UI tests and 5 general UI tests passed; 12 Python tests passed. No skipped tests. General UI initial failure is retained as evidence, followed by a full passing rerun.
- Final review issue fixed and regression verified. The local archive was restored byte-for-byte, /Assets/ was ignored, and exactly 551 index entries were removed while local files remain. No commit, push or history rewrite was performed. The latest app was relaunched on Toti UI Acceptance.
