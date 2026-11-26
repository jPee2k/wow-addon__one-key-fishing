# Quickstart: The Addon Records the Actions the Game Blocked

**Spec**: [spec.md](spec.md)

## Run

```text
npm run check    # luacheck (DisplayInterfaceActionBlockedMessage is a read global), layers, locales, Markdown
npm test         # fengari, Lua 5.3
npm test -- core/blocked
```

## What the tests prove

`tests/core/blocked_test.lua` (stubs `hooksecurefunc` and the game's message function before the files load):

- the hook is set while `Core/Core.lua` loads, and a block before the saved variables load is kept (FR-002);
- `ADDON_ACTION_FORBIDDEN` naming the addon gives one entry with the refused function, and nothing reaches the game's
  error handler (FR-001, FR-004);
- another addon's `ADDON_ACTION_BLOCKED` gives none (FR-001);
- two blocks from one place count into one entry, a block from another place gets its own (FR-002);
- the state line names the fight and the last addon menu (FR-003);
- `ns.RecordEntry` never fails its caller.

`tests/ui/minimap_menu_test.lua`: the menu has no title, and the same entries out of combat and in it (FR-006).
`tests/core/errors_test.lua` and `tests/ui/extension_points_test.lua`: the report's last section is "Errors and
blocked actions" (FR-005).

`tests/ui/menu_test.lua` (FR-007): the addon's menus (radio, checkbox, the minimap menu) never call `MenuUtil`; a radio
passes its value and closes the menu, a checkbox keeps it open and redraws, a button closes it and a disabled one
does nothing, its highlight dimmed (and full again when its row is reused for an enabled entry); a press elsewhere
closes it, a press and click on its owner close it, another owner opens it; opening a menu is the "last addon menu"
of a blocked action's state line. The other UI tests read the entries of the addon's menu through `menu_entries`
(`tests/wow.lua`, set when `ns.OpenMenu` runs).
