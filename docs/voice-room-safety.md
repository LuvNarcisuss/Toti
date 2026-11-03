# Voice room information and safety

## Behavior — November 3, 2026

The information button in a Voice room opens room details with safety actions. Material rooms previously returned early after their descriptive content, skipping both actions. Their details now include **Block room** and **Report room** above the description.

| Room type | Block | Report |
| --- | --- | --- |
| Real member room | Existing online owner block; a room owner is not offered self-block | Existing authenticated room report submission |
| Material room | Hide this room artwork for the current account on this device | Save the selected reason and optional details locally and hide the room; explicitly not submitted for online review |

Material photographs are not member accounts. Blocking a material room does not block a photographed person, alter a member relationship, or fabricate a Supabase account. Real member rooms retain their existing backend paths.

Material-room blocks are reversible in **Settings > Blocked**. Saved material-room reports appear separately in **Settings > Reported**, labeled as device-local and not submitted; Remove report reverses that local preference. Removing one restriction leaves any independent block/report restriction active.

## Persistence and failure handling

Optional `blockedRoomTitles` and `roomReports` fields extend the existing account-scoped `EditorialPreferences` file. Older preference files decode without these fields. Updates preserve author follows, author blocks and private draft compatibility data, and use the existing atomic write path. Screens close and discovery refreshes only after successful persistence. Corrupt data is retained; the UI reports the read/write failure instead of replacing it. Material discovery stays hidden if its safety preferences cannot be read.

Safety actions check the captured account generation. The report form preserves its selected reason and details while background store updates occur. No database schema, Supabase RPC, moderation service or real user statistics changed.

## Verification scope

The current source compiled for Toti UI Acceptance. Focused verification covers legacy preference decoding, account separation, atomic rejection of invalid data, and the material-room cancel/block/unblock/report/remove-report UI loop. Final results are recorded below. These checks do not establish a new backend reporting capability or a staffed review service.

The four `EditorialPreferenceStorageTests` passed with zero failures on the designated simulator (`/private/tmp/toti-room-safety-storage.xcresult`). They cover the added legacy-file/room-preference round trip, account isolation, preserved corrupt files, and rejected oversized drafts without replacing saved data.

The first UI attempt verified block cancellation, room hiding, and unblocking, then failed because the test tried Back behind a Settings modal instead of its Close control. This was a test navigation error; the room had already been unblocked. Initial evidence: `/private/tmp/toti-room-safety-ui.xcresult`. The test was corrected and rebuilt before rerunning.

The corrected latest-source UI run passed **1 test, 0 failures** in 106.911 seconds (`/private/tmp/toti-room-safety-ui-final.xcresult`). It verified both information-page actions, canceling a block, blocking/hiding, unblocking from Settings, saving a local report/hiding, removing that report in Settings, and the restored room card. Together with the four storage cases, final selected runs total **5 passed, 0 failed**. Real member-room backend mutations and remote moderation were not exercised. Existing accounts and other retained data were preserved; the test restored only its own room safety changes.

The latest signed build remains running on **Toti UI Acceptance**, UDID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. Information-page screenshot: `Assets/Verification/VoiceSafety20261103/room-info-actions.png`.
