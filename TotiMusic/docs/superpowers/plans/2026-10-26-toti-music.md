# Toti Music Implementation Plan

Goal: Deliver the complete UIKit social application described by the invoked builder skill, adapted to music.
Architecture: Preserve atomic repositories and shared state. Introduce a music-specific catalog and genre metadata, separate brand configuration and a new discovery header/filter. Replace assets without touching private user data.
Tech stack: Swift 5, UIKit, AVFoundation, iOS 16+.
Spec: User request and ../../product-spec.md. Music overrides the template's dance restriction.

- [x] Instantiate the verified template into the empty TotiMusic directory.
- [x] Configure Toti app identity, isolated storage, local agreements and unconfigured commerce.
- [x] Replace dance catalog with sourced singing recordings; unique Live/Shorts assets, real durations, matching covers and source hashes.
- [x] Build music genre discovery, music room roster/copy and shared music discussion content.
- [x] Generate and integrate icon atlas, app mark and welcome artwork; refresh real portraits and room photography.
- [x] Regenerate Xcode metadata and inspect resources, JSON/plist/XML, routes, legacy keys and configuration.

Review focus: Missing media; unconfigured commerce; old brand references; broken resource mappings; private persistence compatibility.
Verification: Static only, per explicitly invoked skill. No compilation, type checking, tests, app launch, simulator or signing.
Execution: Direct implementation authorized by the invoked skill's “直接开始” instructions. Existing functional behavior is reused; application-specific changes are documented.
