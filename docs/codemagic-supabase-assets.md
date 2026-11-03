# Codemagic and Supabase build assets

The Toti release workflow is defined in `codemagic.yaml`. It pins Xcode 26.5, regenerates the shared UIKit project, restores every object listed by `TotiMusic/Configuration/RemoteAssets.json`, checks the Git media guard, resolves the Codemagic signing profiles and publishes through the App Store Connect integration.

The owner reported that CI stopped during project generation with `xcodegen: command not found` (exit 127). The generation step now switches to `CM_BUILD_DIR`, checks whether XcodeGen is available, installs it with `brew install xcodegen` when missing, and prints its version before generating the project. Installation failure stops the step. YAML parsing and shell syntax were checked locally; installation and the corrected workflow have not been run on Codemagic.

## App Store Connect configuration — 2026-11-03

The owner supplied application Apple ID `6830066901` and the exact Codemagic integration reference `Toti`. The workflow binds `integrations.app_store_connect: Toti` and retains `publishing.app_store_connect.auth: integration` to upload the exported IPA. It uses the `toti` scheme in Release, Bundle ID `com.toti.music`, and the existing App Store signing configuration. Xcode is explicitly pinned to the string `26.5`.

Before archiving, the workflow queries the latest TestFlight build number for `APP_STORE_APPLE_ID` and uses the larger of that number plus one and Codemagic's `PROJECT_BUILD_NUMBER`. It passes this value as `CURRENT_PROJECT_VERSION` to the archive command without editing the committed project or Info.plist. A failed API request or a non-integer build number stops the build. Run release builds sequentially to avoid simultaneous uploads selecting the same build number.

Uploading is enabled; automatic TestFlight beta review and App Store review are both disabled. The build must finish uploading and Apple must process it before it can be selected in App Store Connect. The numeric Apple ID is an application identifier, not an Apple account login or a signing credential; IPA association also depends on its Bundle ID matching the Apple app record.

Build success and failure email notifications are configured for the owner-selected recipient `2758057680@qq.com`. Notification delivery has not been verified.

Account-side prerequisites remain: an available integration named exactly `Toti` with App Manager access to this app, the matching Apple Distribution certificate/private key and App Store provisioning profile for `com.toti.music`, and any required Apple agreements. This change has only received local YAML, shell syntax and project-consistency checks. The owner-reported CI attempt failed before compilation; account credentials, archiving and Apple delivery remain unverified.

References: [Codemagic publishing configuration](https://docs.codemagic.io/yaml-publishing/app-store-connect/), [automatic build versioning](https://docs.codemagic.io/knowledge-codemagic/build-versioning/), and [Xcode 26.5 image](https://docs.codemagic.io/specs-macos/xcode-26-5/).

## Public build resources

Build resources belong in the public `toti-build-assets` bucket in the Toti Supabase project `gjodhvpzkdnxdjmorjfw`. Public object URLs use this form:

`https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-build-assets/ci-upload-20261030-guest5430/<filename>`

The manifest stores the URL, byte count and SHA-256 for every object. `remote_assets.py` accepts only HTTPS URLs, rejects query strings and path traversal, and verifies every download before exposing it to Xcode. The downloaded files are disposable CI inputs and are excluded by `.gitignore`; the manifest, scripts and Codemagic workflow remain versioned.

The app and Codemagic workflow contain no Supabase service-role key, bearer header or upload credential. Supabase Storage publishing is an operator action performed outside the repository. A missing public object must fail the resource restore with its manifest URL rather than silently use local source media.

Completed on 2026-10-30: all 549 original resources were uploaded under the stable `ci-upload-20261030-guest5430/` prefix. The three resource manifests now use that public Supabase origin. Every published byte was downloaded anonymously and verified against its original byte count and SHA-256. The two archived design videos exceeding the Free plan's single-file limit are stored as four immutable parts; their `parts` manifest records retain each part's hash, and the downloader reconstructs and verifies the original files. These archived source videos are excluded from the app target. All normal runtime resources retain direct public URLs.

The bucket contains 551 objects totaling 297,084,652 bytes. The operator used a temporary policy restricted to one disposable guest UUID and this upload prefix. That policy was dropped after verification, and the guest's sessions and Auth record were removed. Public reads require no API key, token or signing. No Supabase upload credential is required by the application or Codemagic. Original private user content was not part of this upload.

Verification: `remote_assets.py --all` restored and verified 549 complete resources, including both reassembled original videos. Resource preparation and manifest/static checks are recorded separately from application compilation, simulator acceptance and cloud signing; this upload does not claim a new iOS build or App Store delivery.

The bucket is public for read access and is intended for non-private Toti artwork, fonts, catalog metadata and archived media that the product has approved for distribution. User avatars, private notes, moderation uploads and other account data continue to use the authenticated `toti-media` bucket and are never placed in this build-assets bucket.
