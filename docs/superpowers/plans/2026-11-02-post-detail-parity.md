# Post detail parity implementation plan

User direction: match Bibi post-detail content and interaction, including unspecified details discovered in its source, while retaining Toti's theme and real Guest service behavior. Existing author material identities remain editorial, never Auth accounts. No new identities or fabricated reactions/replies are introduced.

Reference: Bibi CircleControllers.swift (CirclePostController, circleAuthorRow, circleStoryArtwork), AppStore+Community.swift and existing Toti LoungeDetailController. Bibi's circle detail includes author navigation, counts, artwork/source credits, bookmark persistence, reply validation, own-reply deletion and report/block; explicit Toti requirements also include Like and Share/Forward on detail. Retired video routes and unavailable gifts are not copied into the music post flow.

- [x] Add narrowly scoped authenticated editorial reactions, comments and reports with active-session checks, default-deny RLS, account-deletion cascades, idempotent writes, server counts and bounded comment pagination. Preserve all existing post/content IDs.
- [x] Add a client service and full editorial detail: author/avatar/follow, title/topic/date/body/photo/source, real counts, like/save/comment/share, persistent reply draft while refreshing, own-comment delete, other-comment report/block, author block and report submission. Keep the view attached to the entry account generation.
- [x] Include saved editorial posts in Lounge Saved and Me Saved. Preserve private member content and existing device author preferences.
- [x] Add genuine-post share/forward, received save count, comment avatar navigation and comment focus while preserving real member edit/delete and moderation.
- [x] Build/install/launch latest source on Toti UI Acceptance and verify real state transitions, persistence, saved routes, author/comment routes and share choices using retained isolated Guests. Retain test accounts/data; record exact coverage and remaining dependencies.

All delivery/source/test text is English. No commits or pushes. Reuse the existing signed simulator build setup and fixed dependency versions.
