# Fix Specification: The Addon Records the Actions the Game Blocked

**Feature Branch**: `029-blocked-actions` (off `develop`)

**Created**: 2026-11-26

**Status**: Built for 1.7.1; the cause found and checked in game on 2026-11-26

**Input**: A bug the author met in play on 2026-11-26: during an escort quest, most likely in a fight, a raid target
marker could not be set from a unit's menu. The game printed "Interface action failed because of an AddOn" and
offered to disable OneKeyFishing (`ADDON_ACTION_FORBIDDEN`). It did not happen again.

A short spec: no message, no saved field, no translated text. The module's description is in
[docs/architecture/core.md](../../docs/architecture/core.md) (the error log); what the tests prove is in
[quickstart.md](quickstart.md). No `VERIFY` marker: the hook's behaviour (it runs on every block, also after the chat
line stopped showing) was seen in game on 2026-11-18 ([docs/forever-api.md](../../docs/forever-api.md), "Finding what
the game blocked").

## What is known

- `SetRaidTarget` is `HasRestrictions` with `SecretArguments = "AllowedWhenUntainted"` (the client's API
  documentation). `ADDON_ACTION_FORBIDDEN` means the click's path read something the addon's code had written.
- The error log of both accounts was empty after the incident (no addon Lua error); the taint log was off.
- The author's repeat passed: the addon's menus, then a marker in a fight, with fishing mode on and off; the taint log
  at level 1 recorded nothing.
- A read-only audit found nothing of the addon on the unit menu, target frame or raid marker path, and nothing that
  runs at a fight's start near it. The one plausible suspect: the minimap menu's title, built out of combat. The game's
  title, divider and spacer elements set a secure value for gamepad navigation (`SmartNavigation_MarkFrameIgnored`),
  written then by addon code on menu frames the game's own menus reuse. Not proven.
- `ns.Safe` is not involved: its error path follows Blizzard's `CallErrorHandler`, `SetErrorCallstackHeight` is not
  restricted, and it runs only on an addon error.

## The cause, found with this feature (2026-11-26)

The first build of 1.7.1 recorded the refusal in `/okf debug`: `ADDON_ACTION_FORBIDDEN SetRaidTarget()`, "in combat:
yes, last addon menu: minimap 6 s ago" (opened out of combat), and the stack `MenuTemplates.lua:137` (a menu row's
click) -> `Menu.lua:934` (`Pick`) -> `UnitPopupSharedButtonMixins.lua:2589` -> `TargetFrame.lua:701`
(`SetRaidTargetIcon`). An A/B test in game confirmed it: with the addon's menu opened first after a `/reload`, the
marker is refused; with a game menu opened first, then the addon's, it is set. The game's menus take their rows from
pools shared with every menu of the game, and a row the pool creates while addon code opens a menu stays tainted;
the title was not the cause. Recorded in [docs/forever-api.md](../../docs/forever-api.md) ("Verified in game").

## Decisions of the author, 2026-11-26

1. **Record every block in the error log**, so the next one comes with its cause in `/okf debug`, with no `/run`
   prepared beforehand.
2. **Drop the minimap menu's title** in and out of combat: no menu of the addon builds a title, divider or spacer.
3. **Release at once as 1.7.1**; no harvest (seed epoch 12 stays).
4. **The addon's menus are its own** (after the cause was found): `ns.OpenMenu` in `UI/Widgets.lua` with its own frame
   and rows, for the minimap menu, the radio and checkbox menus and the Import and export choice (no longer the game's
   dropdown); the addon opens no game menu.

## Requirements

- **FR-001**: `ADDON_ACTION_FORBIDDEN` and `ADDON_ACTION_BLOCKED` naming OneKeyFishing MUST add an entry to the error log:
  context the event, message the refused function, the state line of FR-003 and the stack the event came with (the
  caller's when the game fires it inside the refused call, else only its delivery). Other addons' events add none.
- **FR-002**: A call of the game's `DisplayInterfaceActionBlockedMessage` whose closest addon on the stack is this one
  (Blizzard's folders skipped) MUST add
  an entry through a `hooksecurefunc` (context `INTERFACE_ACTION_BLOCKED`): its message is the first stack line inside
  the addon's folder, so causes stay apart and a repeat counts into its entry; the stack's first 10 lines follow the
  state line. A call without the addon on its stack (another addon's block, the game's own) adds none.
- **FR-003**: Each such entry MUST start with a state line: in a fight or not, and the menu the addon last opened
  (minimap, radio menu, checkbox menu, the import and export choice), how long ago and whether it opened in a fight. A
  menu counts when it opens, not when its contents are built.
- **FR-004**: No such entry MUST reach the game's error handler: it is not a Lua error.
- **FR-005**: The report's last section MUST be called "Errors and blocked actions"; entries keep the fields, the cap
  of 30 and the rule of the addon version of spec 006.
- **FR-006**: The minimap button's menu MUST build no title.
- **FR-007**: No menu of the addon MUST use the game's menus (`MenuUtil`, `DropdownButton`): its menus use the addon's
  own frame. A radio passes its value and closes the menu, a checkbox keeps it open and redraws its marks, a button
  closes it, a disabled entry does nothing (its highlight dimmed, as the game's); a press elsewhere or Escape closes
  it (Escape with the window behind it, as the addon's windows close), and a second click on its owner too.

## Success criteria

- **SC-001**: After a block caused by the addon, `/okf debug` names what was blocked and the code that led there.
- **SC-002**: The addon's menus write no secure value and create no row of the game's menu pool.
- **SC-004**: After any of the addon's menus, a raid marker set from a unit's menu in a fight works.
- **SC-003**: `npm run check` and `npm test` pass; no visible text needs a translation.

## In-game checks after the release

[docs/checklists/blocked-actions.md](../../docs/checklists/blocked-actions.md) (SC-004, V81, V82).
