# Lounge music scene photographs

Date: 2026-11-02. Six editorial post covers now use distinct music scenes instead of repeated portraits. Author avatars, stable editorial IDs, author routing, private member content and existing figures are preserved. The same cover is used in Lounge, its author's Works collection and editorial detail.

| Editorial post | Asset | Scene | Photographer | Pexels photo |
| --- | --- | --- | --- | --- |
| Listening together | LoungeVinylListening | Vinyl turntable | Yulia Polyakova | [10648396](https://www.pexels.com/photo/10648396/) |
| A first line | LoungePianoMelody | Piano keyboard | Markus Spiske | [97973](https://www.pexels.com/photo/97973/) |
| Finding a bandmate | LoungeGuitarRehearsal | Electric guitar | Brett Sayles | [1205062](https://www.pexels.com/photo/1205062/) |
| A room for the chorus | LoungeStudioMixing | Recording studio and mixing console | cottonbro studio | [7088044](https://www.pexels.com/photo/7088044/) |
| The concert afterglow | LoungeConcertLights | Concert audience and stage lighting | Lisa Fotios | [13230507](https://www.pexels.com/photo/13230507/) |
| Start with listening | LoungeMusicCorner | Piano and guitar in a music room | Flávia Vicentini | [32218646](https://www.pexels.com/photo/32218646/) |

The six source photos and the [Pexels license](https://www.pexels.com/license/) were checked on the selection date. All actual images were visually inspected together. These are illustrative editorial photographs, not evidence of app membership, event attendance or endorsement. Existing photography disclosures remain.

## Resources and backend

Original JPEGs and generated catalog JSON files are archived in the ignored repository-root Assets directory. `TotiMusic/Configuration/LoungePhotoAssets.json` records sources, photographers, license links, dimensions, exact byte lengths, SHA-256 values, public URLs and stable post mappings. Updated MediaCredits.json includes the six photo credits.

The six JPEGs, six catalog JSON files and updated MediaCredits.json were uploaded to the root of the existing public `toti-build-assets` bucket in Toti project `gjodhvpzkdnxdjmorjfw`. Original versioned resources remain intact. No bucket policy, Auth setting, account or application credential was changed. Anonymous HTTPS downloads of all 13 files matched local bytes and SHA-256 values exactly; see [download verification](backend/music-photo-evidence-20261102/public-download-verification.json).

RemoteAssets.json, AssetCatalog.json and AssetLayout.json reference the new public resources. Builds download and verify them into DerivedData and package the catalog; they do not read the ignored local archive at runtime. Public links require no download key. The new resource names use the existing flat-resource URL format without changing the downloader.

Ordered SQL source `TotiMusic/Backend/sql/013_lounge_music_scene_photos.sql` was deployed as `toti_lounge_music_scene_photos`, remote version `20261102054628`. It adds the six names to the existing editorial photo constraint and changes only the six known editorial cover fields. The first attempted data update was rejected by the original three-name constraint and rolled back. After the scoped constraint migration, all six mappings were independently read back. RLS, public grants, member accounts, relationships, private posts, notes and messages were not changed.

## Verification scope

Static checks confirmed six distinct JPEG hashes, valid decoded images, provenance/credit records, all three manifest references and exact generated asset-catalog bytes. The manifests validate 561 integrity records and 431 runtime resources. Current-source signed UI test build succeeded for Toti UI Acceptance, iPhone 17 Pro, iOS 26.0, device `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, Bundle ID `com.toti.music`; that build was installed and launched.

The focused `testEditorialAvatarsOpenOnlyTheirAuthorsWorks` UI case passed: one test, zero failures, 61.978 seconds. It checks Ava and Ethan avatar-to-profile routing, one matching Works cover per author, cover-to-detail navigation and return, absent editorial Message, and two follow toggles restoring the starting preference. It does not exercise all six authors individually. Result bundle: `/private/tmp/toti-music-photos-ui-1102.xcresult`; build/test logs use the matching `/private/tmp/toti-music-photos-*-1102.log` names. This change does not validate RTC, purchases, production release, every image crop on every device or personal-media moderation. Existing test accounts and cloud fixtures remain retained for manual testing. After testing, the same latest build was relaunched on the designated simulator (PID 20059). The exported Lounge screenshot was visually inspected and confirms the piano and guitar scene covers alongside the retained author avatar. The result includes the existing Supabase Swift initial-session diagnostic notice; it did not fail the test, and the SDK version/configuration was not changed.

![Six selected music scenes](backend/music-photo-evidence-20261102/music-scenes-contact-sheet.jpg)

![Files in the existing public bucket](backend/music-photo-evidence-20261102/supabase-public-assets.jpg)

![Latest-build Lounge with music covers](backend/music-photo-evidence-20261102/lounge-current-build.png)
