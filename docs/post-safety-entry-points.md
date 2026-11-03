# Post report and block entry points — November 3, 2026

## Current interaction

Other authors' member posts and editorial posts show **Report post** and **Block author** directly below the author header. Both detail screens also expose the same actions through the upper-right **Post options** control. Accessible text sizes stack the two visible controls vertically.

Owned member posts retain Edit post and Delete post and do not offer self-block/report actions. Reply safety controls remain separate and target the selected reply and its author.

Member reports reuse the existing SafetyController and authenticated report operation. Member blocks reuse the existing account relationship operation. Editorial reports reuse the deployed private editorial report RPC; editorial author blocks remain account-scoped device preferences, as before. No report endpoint, authentication behavior or backend schema changed.

After a successful block, the detail closes and affected collections refresh. No success or navigation occurs on failed persistence. **Settings > Blocked** now also lists blocked editorial authors, with explicit Unblock confirmation; the existing Editorial preferences screen remains usable. Unblocking preserves other preferences and does not silently restore a follow relationship.

## Verification scope

The signed current-source build targets **Toti UI Acceptance**, UDID `98658066-C6E0-45B3-A1E7-E8FBD950F0DB`. Selected UI cases cover the ordinary-post local controller's report form/block cancellation/menu, and the retained online Guest's editorial report form/block cancellation/menu block/Saved hiding/Settings unblock/restoration. The editorial case restores an existing follow preference if its block removed it.

No false moderation report is submitted. Real member-account report/block writes, moderation staffing, backend report receipt behavior and production release readiness are outside this UI change's acceptance scope. Existing accounts, cloud reactions, private notes and chats are preserved.

Final result: **2 UI tests passed, 0 failures** (112.869 seconds), result bundle `/private/tmp/toti-post-safety-ui.xcresult`. The current source was rebuilt, installed and launched before testing. Ordinary-post controller acceptance used an isolated local library; editorial acceptance reused the authorized retained Guest namespace `26F9BA6F-44AC-4A36-9B37-DF739B215A3C`. Both report forms were opened and closed without submission. Editorial blocking hid the saved post, and Settings unblocking restored it. No account was deleted.

Screenshots: `Assets/Verification/PostSafety20261103/member-post-actions.png` and `editorial-post-actions.png`. `git diff --check` passed. The latest signed app was relaunched on Toti UI Acceptance after the suite.
