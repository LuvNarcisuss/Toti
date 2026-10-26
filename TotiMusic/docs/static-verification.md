# Static verification — October 26, 2026

**Scope: source, configuration, resource and media-file inspection only.** This records the initial static delivery. Build and Simulator execution were subsequently authorized by the user; see [runtime verification](runtime-verification.md) for the separate results.

## Recorded results
- The builder's instantiate script verified and extracted its template manifest into the new project directory.
- XcodeGen generated Toti.xcodeproj from project.yml. Target/scheme toti, com.toti.music, iOS 16, Swift 5. Shared scheme exists and is not ignored. No signing team is set.
- plutil accepted Info.plist and project.pbxproj; the shared scheme XML parsed.
- `scripts/audit_static.py` completed with no issues. The detailed machine-readable result is [static-audit.json](static-audit.json). It checks JSON, catalog file references, literal image/icon references, media identity/hashes/durations/audio, photographic hashes, selected source constraints and project configuration.
- 46 Swift files; 59 enum icon cases resolve to generated bitmap assets (the atlas supplies 64 cells, including additional instrument icons). 207 asset-catalog metadata files parsed.
- Nine unique video IDs/assets/hashes: four Live and five Shorts. Matching covers, source URLs, authors, license URLs, original/runtime hashes and three representative inspection times per clip are registered.
- The 27 extracted frames were visually inspected. All show people performing at microphones; no visible non-English overlay copy was observed in those frames. This is not a complete frame-by-frame review.
- ffprobe confirms all nine recordings lack audio tracks. More explains that the recording is silent. No audio was invented, replaced or attached.
- Eleven new photographic assets: eight portraits and three music-studio photographs. Additional retained sourced portraits are recorded separately. The current photography register has 82 records; in-app Media credits includes these and the nine videos.
- All 64 exported icon cells were visually inspected. Initial equal-row extraction clipped microphone/headphone silhouettes; extraction was corrected to use observed transparent row gutters and per-icon alpha bounds. The final inspection sheet is Design/GeneratedMusic/icon-inspection.jpg.
- App icon is 1024×1024 RGB. Generated transparent icon/welcome outputs and prompts are saved in Design/GeneratedMusic. Existing registered fonts remain under their original PostScript names.
- No active inherited store IDs, old agreement URLs or prior support email. Local agreements describe the current device-only capabilities and the missing publisher configuration. Empty owned-product mapping prevents purchases.
- Stable IDs, atomic repositories, savedDemoVideoIDs, isDance, danceCategory and read-only legacy Phrase compatibility remain. No Phrases screen or navigation was added.

## Independent static review
One actionable issue was reported: a selected music genre could remain active after its final visible clip was reported/blocked while the selector showed For you. The controller now clears unavailable selection before rendering/filtering. The reviewed rename, resource, optional agreement URL and empty-product paths had no other reported introduced issues. Media-credits UI and final documentation were inspected locally after that review.

## Unverified and unavailable
At the time of this static review, compilation and device behavior were unverified. Layout, safe areas, Dynamic Type, VoiceOver, Reduce Motion, keyboard behavior, playback lifecycle, camera permission/interruption, persistence failure recovery and StoreKit transactions are not certified by file checks. Later checks are recorded separately in runtime-verification.md.

No authentication service, live broadcast, RTC, remote chat delivery, server moderation, public publishing or server-authoritative wallet is connected. Voice gift recipients are local selections. Support/privacy contact, owned App Store products, developer signing and distribution agreements still require the application's publisher. The Bundle ID is configured locally, not confirmed as registered.

This static record does not claim build success or App Store readiness.
