# Verification: The Addon Records the Actions the Game Blocked

The code built on assumptions only the game can confirm carries `-- VERIFY(<id>): <what>`; the IDs continue the V
series (V80 was spec 027's; this spec has V81 and V82). A marker is removed after the author confirms the behaviour
in game, or when the author accepts the assumption without a check (the row then says "Accepted" and what happens if
it is wrong).

Already seen in game, no marker: the hook on `DisplayInterfaceActionBlockedMessage` runs on every block and
`debugstack(2, ...)` in it starts at its caller, with paths `Interface/AddOns/<folder>/...` (2026-11-18,
[docs/forever-api.md](../../docs/forever-api.md), "Finding what the game blocked"); `ADDON_ACTION_FORBIDDEN` fires
inside the refused call, so its handler's stack holds the callers (2026-11-26, the recorded `SetRaidTarget` entry).

To close an item: run its check, record the answer in `docs/forever-api.md`, adjust the code if the game differs,
remove the marker.

| ID | What is assumed | Where | If wrong | Check | Status |
|---|---|---|---|---|---|
| V81 | `GLOBAL_MOUSE_DOWN` reaches the addon's menu before its owner's `OnClick`, which comes with the release | `UI/Widgets.lua` (`CreateMenuFrame`, `ns.OpenMenu`) | A second click on the owner closes the menu and opens it again; then close it on the owner's `PreClick` or on `GLOBAL_MOUSE_UP` | Right-click the minimap button (the menu opens), right-click it again: the menu closes; again: it opens. The same with a filter button of the statistics window | Open |
| V82 | The radio's marks are the second (on) and first (off) quarter of `Interface\Buttons\UI-RadioButton` (64 x 16) | `UI/Widgets.lua` (`RADIO_ON`, `RADIO_OFF`) | The marks show the wrong state or another part of the texture; then use the checkbox marks for radios too | Open a filter menu with choices (Water, Skill): the chosen one shows a filled radio, the others an empty one | Open |
