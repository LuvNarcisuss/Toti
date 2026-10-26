# Toti music iOS application

- Music social application adapted from build-teto-social-ios. Five tabs Lounge / Voice / Notebook / Chats / Me. Live and Shorts are retired. No Phrases routes or teaching features.
- iOS 16+, Swift 5, UIKit, AVFoundation. No SwiftUI, Objective-C, Flutter or React Native.
- Product Toti, target/scheme toti, Bundle ID com.toti.music (local identifier; registration unconfirmed). Configuration source TotiMusic/project.yml.
- Repository rules, README and docs live at the repository root. Xcode project, source, configuration, tests and scripts remain under TotiMusic/; shared resources remain under Assets/. Application-relative paths in technical or historical documents refer to TotiMusic/ unless stated otherwise.
- Read docs/music-community-redesign.md for the approved current feature design, and README.md for verification status. docs/template-baseline is historical material, not current brand/media/configuration.
- All app-owned visible text is English. No demonstration labels or fabricated online activity.
- Warm cream/plum/coral design. Own icons are generated transparent bitmaps via TotiIcon, not system symbols. Portraits use sourced real photography.
- Bundled photography must retain credits and license evidence. Portrait subjects are not represented as actual app accounts or endorsers. Retired video assets stay outside the app target.
- Keep stable IDs and atomic persistence. isDance, danceCategory, savedDemoVideoIDs and legacy Phrase models are compatibility fields; do not expose Phrases or erase private data.
- Diamonds only. Ordinary messages/comments are free. No fake payment success or starting credit. Configure owned products in TotiIdentity.
- No build, typecheck, app launch, Simulator, Preview or tests without explicit user authorization. Authorization to run tests includes the build, Simulator, installation and launch steps required below. Static file/resource/configuration checks and XcodeGen metadata generation are permitted.
- Every test run must use the **Toti UI Acceptance** simulator. Before testing, build the latest Toti from the current working tree, install that build on this simulator, and launch it; select this same simulator explicitly for simulator-based test destinations. After testing, ensure this latest build is running on Toti UI Acceptance. If the simulator is unavailable or any required step fails, report the blocker instead of substituting another simulator or an older build.
- Report exact service gaps and verification scope. No signing or deployment credentials are included.
