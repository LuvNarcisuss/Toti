# Codemagic and Supabase build assets

The Toti release workflow is defined in `codemagic.yaml`. It pins Xcode 26.5, regenerates the shared UIKit project, restores every object listed by `TotiMusic/Configuration/RemoteAssets.json`, checks the Git media guard, resolves the Codemagic signing profiles and publishes through the App Store Connect integration.

Build resources belong in the public `toti-build-assets` bucket in the Toti Supabase project `gjodhvpzkdnxdjmorjfw`. Public object URLs use this form:

`https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-build-assets/ci-upload-20261030-guest5430/<filename>`

The manifest stores the URL, byte count and SHA-256 for every object. `remote_assets.py` accepts only HTTPS URLs, rejects query strings and path traversal, and verifies every download before exposing it to Xcode. The downloaded files are disposable CI inputs and are excluded by `.gitignore`; the manifest, scripts and Codemagic workflow remain versioned.

The app and Codemagic workflow contain no Supabase service-role key, bearer header or upload credential. Supabase Storage publishing is an operator action performed outside the repository. A missing public object must fail the resource restore with its manifest URL rather than silently use local source media.

Completed on 2026-10-30: all 549 original resources were uploaded under the stable `ci-upload-20261030-guest5430/` prefix. The three resource manifests now use that public Supabase origin. Every published byte was downloaded anonymously and verified against its original byte count and SHA-256. The two archived design videos exceeding the Free plan's single-file limit are stored as four immutable parts; their `parts` manifest records retain each part's hash, and the downloader reconstructs and verifies the original files. These archived source videos are excluded from the app target. All normal runtime resources retain direct public URLs.

The bucket contains 551 objects totaling 297,084,652 bytes. The operator used a temporary policy restricted to one disposable guest UUID and this upload prefix. That policy was dropped after verification, and the guest's sessions and Auth record were removed. Public reads require no API key, token or signing. No Supabase upload credential is required by the application or Codemagic. Original private user content was not part of this upload.

Verification: `remote_assets.py --all` restored and verified 549 complete resources, including both reassembled original videos. Resource preparation and manifest/static checks are recorded separately from application compilation, simulator acceptance and cloud signing; this upload does not claim a new iOS build or App Store delivery.

The bucket is public for read access and is intended for non-private Toti artwork, fonts, catalog metadata and archived media that the product has approved for distribution. User avatars, private notes, moderation uploads and other account data continue to use the authenticated `toti-media` bucket and are never placed in this build-assets bucket.
