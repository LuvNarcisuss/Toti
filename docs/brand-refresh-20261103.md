# Toti logo and Notebook header — November 3, 2026

## Current user decision

Use the original user-supplied `/Users/apple/Downloads/228/logo.png`, including its black background. The user canceled the subsequent background-removal request. Neither generated cutout is included in the resource manifests or the application.

Restore the original launch, loading, welcome and login appearance. The temporary black entry canvas, light status bars, amber agreement text and changed artwork sizing have been removed. The original cream launch color and existing UIKit entry code are restored. Authentication, agreement handling, private data and the main app theme are unchanged.

Notebook now installs `barButton(totiMark())` as its upper-left navigation item, matching Lounge and the other home tabs. Its search and create actions remain on the right.

## Active brand assets

The supplied image is 1024 × 1024 RGBA with all alpha values equal to 255. AppIcon removes only that fully opaque alpha channel, preserving the RGB pixels. TotiMark and TotiWordmark preserve the original bytes. No generated replacement artwork is active.

Public URL prefix: `https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-build-assets/`.

| Resource | Object |
| --- | --- |
| App icon | `Brand20261103-AppIcon.png` |
| Shared mark and fallback avatar | `Brand20261103-TotiMark.png` |
| Entry/loading wordmark | `Brand20261103-TotiWordmark.png` |
| Supplied original | `Brand20261103-Original.png` |
| Provenance and hashes | `Brand20261103-Provenance.json` |

The original cream launch color again references `ci-upload-20261030-guest5430/Catalog-TotiLaunchBackground.json`. The earlier uploaded `Brand20261103-LaunchBackground.json` is superseded and is not a build input. Historical public objects were not deleted.

`AssetCatalog.json`, `AssetLayout.json` and `RemoteAssets.json` preserve stable catalog names and pin their active resources by URL, byte count and SHA-256. All local source copies remain under project-root `Assets/`. No upload credentials are included in the app.

## Verification

- The previous upload verification checked all six uploaded objects anonymously with HTTP 200 and matching bytes/SHA-256; the active logo files are unchanged from that verification.
- Static catalog preparation resolves all 476 entries, including the original cream launch color.
- Original/mark/wordmark bytes match; AppIcon has matching RGB pixels and no alpha channel.
- Entry and shared navigation source match their pre-refresh versions; Notebook uses the existing shared brand component.
- `git diff --check` passed.
- Earlier upload evidence remains in `Assets/Verification/Brand20261103/`.

No compilation, typecheck, simulator installation, launch or runtime tests were performed for this correction. The earlier 41-case runtime report predates the logo and Notebook header changes.
