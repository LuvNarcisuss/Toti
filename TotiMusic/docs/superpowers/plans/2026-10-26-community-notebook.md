# Toti Community and Notebook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Live/Shorts with Lounge and Notebook, preserving Voice/Chats/Me and private data, then build and run in Xcode.
**Architecture:** Add optional Codable states to LocalLibrary and mutate through AppStore.commit for shared atomic persistence. Feature-specific AppStore extensions own mutations; UIKit controllers consume those shared states. Preserve legacy decoding while removing active video routes and bundled MP4s.
**Tech Stack:** UIKit, Swift 5, iOS 16+, Combine, PhotosUI, existing XcodeGen.
**Spec:** ../../music-community-redesign.md (approved by user).

## Global Constraints
- Five tabs Lounge / Voice / Notebook / Chats / Me; English UI; cream/plum/coral; generated bitmap icons.
- Local interactions do not claim remote publishing, moderation or delivery; no starting currency or payments.
- Preserve old library fields/files; only explicit account deletion removes owned private data.
- User explicitly authorized implementation, builds, tests, Simulator runs and repair of errors.
- Work in existing uncommitted project, as requested; do not move or discard user's working files. No commits/push required for delivery.

## Review Focus
- Atomic save failure retains prior state and edits: repository tests and editor checks.
- Block/report changes remove items consistently: Lounge visibility tests.
- Empty/oversized/Unicode input is handled without truncation: feature validation tests.
- Legacy snapshots decode with absent new fields: repository migration test.
- Five-tab hit testing and retired deep routes: source route audit and Simulator checks.

### Task 1 — Lounge
Files: create Toti/Features/Lounge/{LoungeModels,LoungeStore,LoungeControllers}.swift and Tests/LoungeTests.swift.
Interfaces: LocalLibrary.lounge: LoungeState?; AppStore.loungePosts: [LoungePost], loungeDrafts: [LoungePost], savedLoungePosts: [LoungePost]; LoungePost.id: UUID, author: CreatorProfile, body: String, isDraft: Bool; AppStore.loungePosts(for authorID: String) -> [LoungePost]; LoungeController(store: AppStore); LoungeComposerController(store: AppStore, post: LoungePost? = nil, initialText: String = ""); LoungeDetailController(store: AppStore, postID: UUID).
- [x] Write model validation/visibility/draft tests first; run against missing feature, then implement.
- [x] Implement Codable state, authored seeds, atomic AppStore mutations, normalized photo attachments embedded in the same atomic library snapshot; shared block/report visibility.
- [x] Implement feed filters/search/topics, composer photo/draft/edit, detail/comments/interactions/safety/linked Voice, meaningful error/empty states.
- [x] Verify tests and review sources; no edits to shared navigation/profile/library files.

### Task 2 — Notebook
Files: create Toti/Features/Notebook/{NotebookModels,NotebookStore,NotebookControllers}.swift and Tests/NotebookTests.swift.
Interfaces: LocalLibrary.notebook: NotebookState?; AppStore.notebookNotes: [InspirationNote]; NotebookController(store: AppStore); NotebookEditorController(store: AppStore, note: InspirationNote? = nil). Conversion uses LoungeComposerController(store:store, initialText:text).
- [x] Write validation/roundtrip/edit/duplication tests first.
- [x] Implement private notes in shared library, categories/mood/search/pin/duplicate/delete, explicit atomic saves and limits.
- [x] Implement cards, templates and editor with Save/Discard/Keep editing on all exits; failed saves retain text; explicit conversion to separate Lounge draft.
- [x] Verify tests and source review; no edits to shared files.

### Task 3 — Integration and retirement
Files: Toti/App/TotiApplication.swift, AppStore.swift, Domain/LocalLibrary.swift, ProfileControllers.swift, ChatControllers.swift, Safety/ContentSafety.swift, project.yml, Tests/LibraryMigrationTests.swift, docs and Agreements.
- [x] Add optional states and post safety kind, Xcode test target; migration and save/deletion boundary tests.
- [x] Replace four-tab constants with five-item dynamic layout; use new generated Lounge/Notebook icons.
- [x] Replace Me/video member Works with posts, saved posts, drafts, notebook and room drafts; remove shared video launch controls.
- [x] Exclude retired video UI from target; preserve only types required by legacy storage; remove MP4/covers from app bundle and active media credits.
- [x] Update onboarding/settings/agreements and product documentation; retain private files and legacy serializers.
- [x] Build, fix compile errors and run targeted tests; review new features and source route audit.

### Task 4 — Artwork and delivery
- [x] Generate transparent Lounge and Notebook bitmap icons using imagegen, save source/prompt/output into project; inspect icons.
- [x] Run Xcode on existing iPhone 17 Pro and verify the welcome screen without erasing existing user data or accepting agreements; validate representative local flows through AppStore tests. Interactive main-page checks remain unperformed.
- [x] Fix errors and rerun affected verification. Record actual evidence and outstanding service boundaries.

## Delivery scope
Implementation and tests completed. Xcode Run succeeded and the welcome page was captured. Interactive checks past the agreement screen were not performed; no agreement was accepted by automation. Detailed evidence: ../../community-verification.md.
