# Navigation search and content states

Updated on 2026-10-30.

Chats, Lounge and Notebook now place Search and the plus action inside one compact navigation item. Removing UIKit's additional spacing between separate bar items brings the icons closer together while retaining separate 44-by-44-point touch targets and accessibility labels. Toti's existing bare icon styling is preserved.

Lounge no longer contains a permanently visible search text field. Its Search posts button uses the shared expanding search control, just like Chats. Editing the query refreshes the feed; closing search clears only the query and preserves the selected feed and topic.

The former two rows served different purposes: For you / Following / Saved selected a feed, while the second row selected a topic. Lounge now shows only the feed row. The adjacent Filter by topic button opens a menu containing All topics and every existing Lounge topic, with a checkmark and an accessibility value for the current selection. A selected topic highlights the filter button. Feed, topic and query still compose in the existing filtering logic.

Static source/event inspection and `git diff --check` passed. No build, typecheck, simulator launch, app run or tests were performed. Actual spacing, search animation and menu behavior require future authorized UI acceptance.

## Notebook welcome and list states

Notebook no longer has a permanent search field. The Search private notes button expands the shared navigation search control beside New note, with separate 44-point touch targets. Query changes update the existing private-note matching logic; closing search clears the query and keeps the selected category.

When the account/device has no private notes and no active search, Notebook hides the category strip and shows a composed welcome state in the existing scroll view. It includes the generated Notebook artwork, Write your first note, a separate writing-prompt card and a privacy card. These actions open the existing editor/template flow. Prompts remain editable unsaved content until the user saves; no personal notes are seeded.

When private notes exist, the welcome cards are replaced by the category strip, result count, prompt action and note list. Existing pinned ordering, timestamps, note actions, private persistence and explicit Lounge draft conversion are retained. Deleting the last note returns to the welcome state. A search/category with no matches shows a separate No matching notes card with Clear filters, rather than the first-note welcome message.

The shared scroll view retains online pull-to-refresh, read-error Retry and pagination in both welcome and populated states. A failed read still shows its existing error controls; empty local state does not establish that all cloud pages have loaded.

This Notebook update was checked through source/state-flow inspection and `git diff --check` only. No build, typecheck, tests, app launch or simulator interaction was performed. Rendered spacing, keyboard/search animation, persistence and state transitions require future authorized runtime acceptance.

## Subsequent scoped runtime acceptance

The current source was rebuilt, installed and exercised on Toti UI Acceptance after the static-only implementation recorded above. Notebook welcome/list states, navigation search and clear, category/mood flows and note management now have the scoped runtime evidence in [Notebook and call acceptance](backend/notebook-and-calls-acceptance-20261030.md). This does not establish all-page visual timing or all filter behavior across unrelated screens.
