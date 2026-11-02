# Creation page expansion transition

Updated on 2026-10-30.

The shared `presentExpanded` route previously expanded an empty `StudioCanvas` to the full window and presented the creation controller only after the animation completed. Removing that overlay on the following run-loop turn exposed a different page, producing a visible content switch.

The route now uses a retained UIKit transitioning delegate and a single animator in both directions. The actual destination navigation view is laid out at its final size, placed in the transition container and scaled from the source control's rectangle to its final frame. Closing reverses this operation toward the current source-control position. The page does not switch controllers or replace a background overlay at the end of the animation.

A layer mask clips the page while it expands and contracts, including screens whose background artwork allows overflow. Custom-transition screens use their own canvas bounds to avoid recomputing artwork against transformed window coordinates. The animator restores view ownership on cancellation, handles missing source geometry and honors Reduce Motion. The destination retains its delegate because UIKit's delegate reference is weak. Existing creation validation and unsaved-change close guards remain in their controllers.

The Voice creation plus button already calls this shared route and therefore uses the corrected transition. Other callers of `presentExpanded` receive the same behavior. Ordinary sheets and navigation pushes retain their native animations and now use the shared content preparation described below.

Lounge composer update: the redundant homepage empty-state Write a post card was removed. What's on your mind? and the navigation plus remain the homepage creation actions. A populated official editorial feed no longer has an unrelated empty-personal-post card above it; filtered empty results use concise text without another write action.

The Lounge composer uses a direct vertical presentation rather than plus-button expansion. Its presentation loads the real navigation/root views, applies the Toti background and title, and sizes and lays them out before starting the single cover-vertical transition. This preparation now applies to every app-owned modal route rather than being a Lounge-only option. The same prepared route is used for draft continuation, post editing and editorial Write about this within Lounge. No blank controller or background overlay is presented first. Existing composer save and unsaved-close guards remain in place. These changes are static-only and do not establish that a visible flash has been eliminated at runtime.

Verification is limited to static source/event-flow inspection and `git diff --check`. No build, typecheck, installation, app launch, simulator interaction or tests were performed at the user's request. The absence of flashing and the visual timing still require future authorized runtime acceptance.

## Application-wide transition preparation

All app-owned navigation containers now use `TotiNavigationController`. Pushes, programmatic returns and stack replacement prepare destination views before calling UIKit. Native navigation animations, interactive-pop handling, existing navigation delegates and editor close guards remain in place. Returned pages are already loaded; UIKit retains ownership of interactive return and cancellation.

Every shared `presentScreen` call prepares its real root content, navigation title and layout before presentation, including medium/large sheets, full-screen pages and plus-button expansion. The archive photo-consent route also uses the styled, prepared navigation container. There is no destination placeholder controller or delayed second presentation.

`TotiScreen` and navigation/tab containers have the Toti background from their first frame. The page canvas receives initial bounds and autoresizing immediately, before the first layout. Individual pages retain their own explicitly configured backgrounds. Tab changes attach and lay out the selected page before detaching the old page. Entry/login/tab-root replacements prepare the new controller before assigning it to the window.

The legacy close-animation fallback no longer substitutes an empty canvas when snapshot capture fails; it dismisses the real page with UIKit instead. The main plus-button route continues animating the actual page in both directions.

Static route inspection covers all navigation-container construction and app-owned presentation call sites, including direct Notebook pushes and Chat group stack replacement. Remaining direct presentations are native alerts and system photo pickers; their internals are managed by iOS. Network images and backend results remain asynchronous within the destination page, with existing loading/error behavior; preparation does not wait for network completion or claim service availability.

Verification for this application-wide update: source-route inspection and `git diff --check` only. No compilation, typecheck, app launch, simulator, UI test or visual timing acceptance was performed. All-page first-frame appearance, interactive returns, sheet sizing, keyboard timing and Reduce Motion still require authorized runtime verification.

## Subsequent scoped runtime acceptance

The current source including shared transition preparation was later built and exercised on Toti UI Acceptance during [Notebook and call acceptance](backend/notebook-and-calls-acceptance-20261030.md). Entry/login, Notebook editor push/return, prompt menus, note-to-Lounge composer push/return and Chats conversation/notice routes were exercised. This supersedes the no-build status for the current combined source, while all-page first-frame/animation timing and interactive cancellation acceptance remain uncovered.
