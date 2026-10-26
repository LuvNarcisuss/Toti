# Xcode run — October 26, 2026

The user explicitly requested running the completed application in Xcode.

- Xcode 26.0.1 (17A400), scheme `toti`, Debug configuration.
- iPhone 17 Pro simulator, iOS 26.0.1, UDID `05FF5F0E-DA1F-4BFD-9D19-59887F2380FF`.
- Command-line `xcodebuild build` succeeded with simulator signing disabled. The only build warning was skipped App Intents metadata extraction because this app does not depend on AppIntents.
- Opened `Toti.xcodeproj` in Xcode, selected iPhone 17 Pro and invoked Run. Xcode reported `Running toti on iPhone 17 Pro` with the debugger attached.
- The welcome screen rendered the generated music mark, singer/guitarist illustration, English welcome copy and Get Started button. No crash was observed during this launch check.
- Initial console inspection exposed redundant `Fonts/` entries in UIAppFonts and duplicate manual font registration. Removed the nonexistent paths and made manual registration conditional on the font being unavailable.
- Invoked Xcode Run again after those changes: build/install/launch succeeded, debugger attached, and the missing/duplicate-font messages were absent. The console retained an iOS accessibility framework diagnostic about SLHighlightDisambiguationPillViewAccessibility; no corresponding launch failure was observed.
- Welcome screenshot: [welcome.png](../Assets/Screenshots__runtime__welcome.png). The final capture showed Live discovery with the music hero, genre selector, four recording cards and all four dock tabs: [live-home.png](../Assets/Screenshots__runtime__live-home.png). No automated interaction accepted agreements.

This is a build and launch smoke check. It does not certify all feature flows, device sizes, media lifecycle, persistence recovery, accessibility, camera, payments or remote services. No online accounts, purchases, service agreements or distribution submissions were made. Existing service gaps in README.md still apply.
