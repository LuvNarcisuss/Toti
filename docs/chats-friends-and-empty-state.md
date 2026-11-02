# Chats friends and empty states

Updated on 2026-10-30.

Reference: the user-selected Codex conversation "运行 Bibi 全功能测试" (`01a18114-5c47-7111-aed0-2c221d92bc98`) and `/Users/apple/Desktop/Bibi/BibiApp/Bibi/Features/Chats/ChatControllers.swift`. The conversation explicitly requests a composed welcome state rather than an empty page and hides classification controls until friends exist.

Toti keeps its existing music theme, cream/plum/coral colors, generated raster icons, backend account and real chat delivery path. Bibi artwork, account identifiers and service configuration are not imported.

## States and actions

- With no friends, hide the All / Unread / Pinned / Drafts strip and move content into the available space. If a previously selected category becomes unavailable, reset to All.
- With no conversations or available friend rows, show a scrollable welcome card with music/chat artwork and Find a friend, followed by Create a group, Group invitations in online mode, or Scan a friend code in local mode. Each action routes to its existing controller.
- With friends, show classification controls and the conversation list. In online mode, mutual contacts who have not opened a conversation appear as Friends rows. Contact rows are deduplicated against existing conversation peer IDs and exclude the current user and blocked profiles.
- Opening a contact explicitly calls the existing canonical conversation-opening operation, then navigates to the acknowledged conversation. Merely reading the directory or rendering the list does not create conversations. Pending or failed reads do not fabricate a message history.
- Existing incoming conversations and groups remain visible even when the account has no mutual friends. Hiding the classification strip does not discard those messages.
- Search, unread, pinned and draft categories have contextual no-results cards with Back to all chats. Search and category changes recalculate both the visible rows and the empty state.
- The empty scroll view retains pull-to-refresh, read-error Retry and explicit pagination controls. The populated list retains its existing online controls and group invitation access.

New accounts receive no synthetic friends, conversations, unread messages, personal content or wallet state. Existing swipe actions, message sending, persistence and relationship rules remain unchanged.

## Verification scope

The Bibi conversation and source were read, navigation and account guards were inspected, existing icon resource references were checked and `git diff --check` passed. No build, typecheck, installation, simulator launch, app run or tests were performed, following the user's ongoing no-run instruction. Dynamic Type, rendered spacing, friend-state transitions and actual contact-to-conversation navigation require future authorized runtime acceptance.
