# Voice author profile content

Date: 2026-11-03. This extends the six existing Lounge editorial authors with eighteen room-material authors. These are authored editorial identities with illustrative profile statistics, not verified humans, authenticated accounts, live presence, or a claim that the portrait subjects use Toti. The user requested varied populated profiles while keeping some empty cases.

Both room seats and post author badges resolve the same TotiEditorialAuthor. The same controller owns portrait, biography, statistics, Works, local follow/block preferences and the existing restriction on messaging editorial identities. The preferences screen includes all twenty-four distinct authors, including authors without works. No room/profile avatar substitutions occur.

Eighteen distinct music posts are published in the existing Supabase editorial collection. Thirteen Voice authors have one or two works, and five have none. Empty-work authors have zero illustrative received likes/saves but can have authored following/follower figures. Each post opens the existing full detail page; actual likes, saves, replies and sharing continue to use the existing authenticated backend. Authored profile figures are explicitly identified as illustrative and are separate from actual post reaction counters; they are not represented as sums of real engagement. No reactions, comments, follow records, Auth accounts, or online attendance were fabricated.

Existing licensed music covers are reused. No new portrait downloads or asset uploads are needed. Source metadata: `TotiMusic/Configuration/VoiceEditorialProfiles.json`. Runtime author mappings are compiled in TotiEditorial.swift; post IDs are deterministic editorial IDs, never account IDs. Ordered source `017_voice_editorial_profiles.sql` deployed as `toti_voice_editorial_profiles`, version `20261103023157`. It adds content only and preserves existing records, grants and RLS.

| Profile | Works | Illustrative likes | Illustrative saves | Following | Followers |
| --- | ---: | ---: | ---: | ---: | ---: |
| Avery | 2 | 23 | 3 | 18 | 17 |
| Emma | 1 | 40 | 10 | 42 | 46 |
| Chloe | 0 | 0 | 0 | 7 | 75 |
| Oliver | 1 | 74 | 24 | 61 | 104 |
| Liam | 2 | 91 | 31 | 29 | 133 |
| Jack | 0 | 0 | 0 | 12 | 162 |
| Sophie | 2 | 125 | 45 | 84 | 191 |
| Grace | 1 | 142 | 3 | 36 | 220 |
| Ella | 1 | 159 | 10 | 23 | 9 |
| Mia | 1 | 176 | 17 | 47 | 38 |
| Ruby | 0 | 0 | 0 | 5 | 67 |
| Lucy | 2 | 20 | 31 | 58 | 96 |
| Hazel | 1 | 37 | 38 | 31 | 125 |
| Noah | 0 | 0 | 0 | 9 | 154 |
| Lucas | 1 | 71 | 3 | 64 | 183 |
| Theo | 2 | 88 | 10 | 73 | 212 |
| Finn | 1 | 105 | 17 | 26 | 1 |
| Owen | 0 | 0 | 0 | 4 | 30 |

Static validation checked distinct IDs/titles/portraits, all author-work mappings, empty-author counts and diff formatting. Latest-source totiUI build passed (`/private/tmp/toti-profile-content-build-1103.log`). Installed and launched on Toti UI Acceptance, iPhone 17 Pro / iOS 26.0, UDID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. The focused portrait/profile case passed: one test, zero failures, 57.484 seconds (`/private/tmp/toti-profile-content-ui-1103.xcresult`). Avery, Emma and Chloe retained matching portraits and showed Works (2), Works (1) and Works (0), respectively. The remaining fifteen profiles use the same route and were statically checked, not individually clicked. Existing member interaction services and purchases were not retested. Latest app relaunched after teardown, PID 87488.

[Two-work profile](backend/voice-profile-content-evidence-20261103/avery.png) · [One-work profile](backend/voice-profile-content-evidence-20261103/emma.png) · [Empty-work profile](backend/voice-profile-content-evidence-20261103/chloe.png)
