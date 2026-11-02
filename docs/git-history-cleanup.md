# Git history and local media cleanup

Date: 2026-10-27. Status: complete; no GitHub push performed.

## Preserved local files

The original 549 files in Assets were retained byte-for-byte. Another 23 verification screenshots were moved from docs/payment-verification, docs/gift-verification and docs/local-agreement-verification into the flat Assets archive with English source prefixes. All moved hashes match their originals. The archive now contains 572 files, including 344 media/font files. No source media or file larger than 5 MiB remains outside Assets; generated build/test caches are excluded from this source inventory.

Known hosted documentation resources use their verified HTTPS URLs. The newly consolidated screenshots are local evidence only, not runtime resources; they have not been uploaded to R2. Their documentation links point to the ignored local archive. Existing Agreements HTML and unrelated untracked work were preserved.

## Rewritten history

A complete copy of the original repository, including its Git database and working files, was saved outside the repository at:

`/tmp/toti-history-cleanup-20261027-114228/snapshot`

Filtering was prepared in a separate bare repository. Both main commits and all seven internal Codex tree snapshot refs were filtered. Native commit filtering skips tree-valued refs, so those snapshots were separately rebuilt with the same exclusions. Clean refs were imported without resetting or checking out working files. File hashes before and after importing history were identical. Old reflogs were expired and unreachable objects pruned after the external backup was verified.

- Main tip: `fd63b5333147be9ea243f7e535e872bbaaca8644` → `ec5428b02a47ace33bef994977fe6e03502160b0` (use `git rev-parse HEAD` for the current full tip).
- The two existing commit messages and code history are retained; source-media entries are removed.
- All refs: 228 historical blobs; largest 195,558 bytes. No Assets paths, media filenames/signatures or blobs over 5 MiB remain.
- Object pack: approximately 292.28 MiB before, 566.98 KiB after.
- `git fsck --full`: passed. Finder metadata at `.git/refs/.DS_Store` was moved to the external backup because it is not a Git ref.
- Local `git push --dry-run` to an empty temporary bare repository passed with the installed hook. The destination remained empty; this was not a push or publication.

The full commit map, original refs, rewritten internal-tree map, media movement hashes and verification output remain alongside the external snapshot. The backup contains the original media history and must remain outside this repository.

## Future push checks

`/Assets/`, media extensions and generated test/archive bundles are ignored. No Assets files are tracked. `core.hooksPath=.githooks` enables the local pre-push check, which inspects every historical tree entry and blob reachable from each pushed ref. It rejects Assets paths, media formats and files larger than 5 MiB, including unchanged renames and multiple paths sharing identical contents. Deleting media only from the latest commit is insufficient and is detected.

After cloning, enable this check with `git config core.hooksPath .githooks`. Audit all local refs using `python3 TotiMusic/scripts/check_git_media.py --all`. The threshold is a repository policy, not a claim about a hosting provider's file-size limit.

There is no configured Git remote. Source changes, manifests, hooks and documentation remain uncommitted; create a normal source commit before pushing those changes. No additional commit or remote force-push was performed by this task. The rewrite has already changed local historical commit IDs.

## Resource configuration and validation

The working tree initially had reverted to local Assets build references. Resource-specific configuration and scripts were restored to use `https://pub-e1dd5165c5cf490785389b0538d5d63e.r2.dev/` with pinned hashes. The 416 catalog mappings and three loose resource files are materialized in DerivedData from HTTPS; all entries resolve within the 549-object remote manifest. Agreement HTML remains in the separate Agreements source folder. No application image/video dependency points at the local Assets archive.

A new DerivedData directory was used to build the latest source. The latest app was installed and launched before each test invocation on **Toti UI Acceptance**, UUID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`.

- Fresh Xcode build: passed, downloading and verifying 419 runtime resource inputs.
- Application unit/integration/resource tests: 23 passed, zero failures.
- `CommunityUITests.testFivePagesAndProfile`: 1 passed, zero failures.
- Python resource and Git protection suite: 19 passed, zero failures.
- Latest app installed and relaunched after testing, PID 63151.
- Existing purchase suites and the separate agreement UI suite were not rerun in this task. This is not a new Apple sandbox or production payment verification.

Runtime evidence: `/tmp/toti-history-cleanup-20261027-114228/validation/`. Build log: `/tmp/toti-git-cleanup-build.log`. Git/media checks, dry-run output and file hashes are in the external backup directory. A reviewer independently verified media preservation and identified a same-blob/path alias gap in the initial guard. Two failing regressions reproduced it; per-tree inspection fixed both, and the complete Python suite passed.
