# Voice room music portraits

Date: 2026-11-02. The user requested different music-person photographs for Voice characters and matching portraits on the corresponding profile pages. Eighteen distinct photographs replace the earlier character portraits across six room materials. They are separate from the six Lounge editorial-author photos. Existing room/person ordering, stable IDs, names and cover images remain unchanged.

| Room | Character | Asset | Photographer | Pexels photo |
| --- | --- | --- | --- | --- |
| The Pop Lounge | Avery | PortraitVoiceAvery | Ninari | [Source](https://www.pexels.com/photo/20765278/) |
| The Pop Lounge | Emma | PortraitVoiceEmma | Martin Lopez | [Source](https://www.pexels.com/photo/2157171/) |
| The Pop Lounge | Chloe | PortraitVoiceChloe | shahin khalaji | [Source](https://www.pexels.com/photo/17744395/) |
| Soul After Hours | Oliver | PortraitVoiceOliver | ἐμμανυελ  | [Source](https://www.pexels.com/photo/12600484/) |
| Soul After Hours | Liam | PortraitVoiceLiam | Guilman | [Source](https://www.pexels.com/photo/5939382/) |
| Soul After Hours | Jack | PortraitVoiceJack | Teja J | [Source](https://www.pexels.com/photo/13781227/) |
| Blue Note Room | Sophie | PortraitVoiceSophie | Yan Krukau | [Source](https://www.pexels.com/photo/9002783/) |
| Blue Note Room | Grace | PortraitVoiceGrace | Toni Canaj | [Source](https://www.pexels.com/photo/25254328/) |
| Blue Note Room | Ella | PortraitVoiceElla | Vika Glitter | [Source](https://www.pexels.com/photo/1650076/) |
| Acoustic Corner | Mia | PortraitVoiceMia | Vika Glitter | [Source](https://www.pexels.com/photo/29564499/) |
| Acoustic Corner | Ruby | PortraitVoiceRuby | Pavel Danilyuk | [Source](https://www.pexels.com/photo/7120409/) |
| Acoustic Corner | Lucy | PortraitVoiceLucy | Hatice Baran | [Source](https://www.pexels.com/photo/16907547/) |
| Piano & Strings | Hazel | PortraitVoiceHazel | Vlad Fonsark | [Source](https://www.pexels.com/photo/5195651/) |
| Piano & Strings | Noah | PortraitVoiceNoah | Ivan S | [Source](https://www.pexels.com/photo/8128009/) |
| Piano & Strings | Lucas | PortraitVoiceLucas | Aleksandr Neplokhov | [Source](https://www.pexels.com/photo/2601187/) |
| Electronic Frequencies | Theo | PortraitVoiceTheo | Paloma Clarice | [Source](https://www.pexels.com/photo/12835521/) |
| Electronic Frequencies | Finn | PortraitVoiceFinn | Pedro Woch | [Source](https://www.pexels.com/photo/16401243/) |
| Electronic Frequencies | Owen | PortraitVoiceOwen | Ivo Rosenberg | [Source](https://www.pexels.com/photo/13121369/) |

## Shared identity and image rendering

The authenticated room-material response supplies each character's asset name and public URL. `CommunityVoiceRoom.room` creates one stable `PartyParticipant` per room/index. Voice cards and seats use that participant's asset and artworkURL; `openArtist` passes the same participant to `CommunityRoomCharacterController`, which uses the same two image references. There is no separate profile fallback mapping to drift from the seat. Stable accessibility identifiers were added for the seat and character photograph to verify this route. Character portraits remain illustrative photography, not Auth identities or evidence of live attendance.

The signed-in user's seat continues to use `AppStore.configureOwnerAvatar`, matching Me and preserving the last approved uploaded avatar. Actual member avatars and retained Guest profiles were not modified. This update does not create accounts, member relationships or RTC sessions.

## Sources and public delivery

All selected photographs were visually inspected together, including avatar crop composition. Two initially selected images without a visible face in the crop were replaced before publication. The sources above and the [Pexels license](https://www.pexels.com/license/) were checked on the selection date. No subject nationality is inferred from appearance and pictured people are not represented as account holders or endorsers.

Original JPEGs and catalog files are archived in repository-root Assets. `TotiMusic/Configuration/CommunityRoomAssets.json` records every source, photographer, license, dimension, hash, byte length and public URL. MediaCredits.json includes the new photo credits. The three build-resource manifests point to the existing public `toti-build-assets` bucket under the immutable `voice-musicians-20261102/` prefix. Earlier credit objects remain intact. The downloader recognizes this additional explicit prefix and retains the flat-filename, host/scheme and integrity checks.

All 37 uploaded objects (18 JPEGs, 18 catalog JSON files and updated MediaCredits.json) were anonymously downloaded and matched local bytes/SHA-256 exactly. See [download verification](backend/voice-portrait-evidence-20261102/public-download-verification.json). No bucket policy, client key or authentication setting was changed. Runtime room artwork uses public links; bundled images are fetched and verified during build as the initial image.

## Backend deployment

Ordered source `TotiMusic/Backend/sql/014_voice_music_portraits.sql` was deployed as `toti_voice_music_portraits`, remote version `20261102061858`. It replaces only the people artwork arrays of the six existing material records, preserving person names/order and every other content field. A readback confirmed 18 people, 18 unique assets, 18 unique public URLs and the expected asset-to-URL correspondence. There is no schema, RLS or grant change. Original temporary test accounts and their personal data are retained.

## Verification scope

Static validation confirmed 18 distinct valid JPEGs, all source/manifest mappings, no duplicate hashes among the 18 or overlap with the six Lounge author avatars, and 609 pinned integrity records / 479 runtime resources. Current-source signed UI test build succeeded for Toti UI Acceptance (iPhone 17 Pro, iOS 26.0, device `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`, Bundle ID `com.toti.music`) and was installed/launched there. Build log: `/private/tmp/toti-voice-portraits-build-1102.log`. The focused `testVoiceMusicPortraitsOpenMatchingCharacterProfiles` UI test passed: one test, zero failures, 51.080 seconds. On The Pop Lounge, Avery, Emma and Chloe each opened from the correct seat to the profile with the matching asset identifier and name, then returned to the room. Room/profile screenshots were captured; the room and Avery profile were visually inspected and use the same photograph. All eighteen generated catalog images were byte-compared with the selected originals. The other fifteen profile routes were checked by shared data-flow inspection, not individually clicked in this run. Test log/result: `/private/tmp/toti-voice-portraits-ui-1102.log` and `/private/tmp/toti-voice-portraits-ui-1102.xcresult`. The latest build was relaunched on the same simulator after testing (PID 26771). `git diff --check` passed. No new account, personal content, note or relationship is needed for this read-only navigation case. RTC, purchases, production acceptance and every-device crop coverage remain outside this change.

![Selected Voice music portraits](backend/voice-portrait-evidence-20261102/portrait-selection.jpg)

![Uploaded public portrait resources](backend/voice-portrait-evidence-20261102/supabase-upload.jpg)

![Current room with matching music portraits](backend/voice-portrait-evidence-20261102/pop-room.png)

![Avery profile using the same photograph](backend/voice-portrait-evidence-20261102/avery-profile.png)
