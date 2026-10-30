# Architecture: UI

The frames in `UI/` and the temporary `Spike.lua`.

## Indicator

Next action, cast bar, session timer. "No bobber" when the soft interact GUID is not game object 35591; while the
bobber is still flying, up to 3 s after the channel start, no warning.

## Settings

- Canvas pages built from plain widgets, not the Settings setting-type API.
- The "Shared database" subcategory holds the exchange setting, its text and a status line updated every second;
  `SettingsUI.OpenShare()` opens it.
- Bags cannot be opened while the Settings panel is open, so items are added through Alt+Click in bags
  (ItemHooks), not from the panel.

## StatsFrame

- Two tabs below the window: the game's `PanelTabButtonTemplate` or plain buttons, the last one saved in
  `OneKeyFishingDB.statsTab`.
- The statistics page has rows in `ROWS`, cells keyed by row key.
- A 1 s tick does a full refresh when `Stats.GetVersion()` changed or the window is marked dirty by
  `PRICES_CHANGED`, `SETTINGS_CHANGED`, a skill change or item info of a caught item, and otherwise only redraws
  the time rows, so nothing moves outside fishing mode.

## CatchHere

The "What can be caught here" page ([catch-db.md](catch-db.md)):

- `CatchDB.Query` for the current place, a skill filter that follows the own range until one is picked by hand
  and a source filter, both in memory only;
- redrawn on the 1 s tick when the data, the place or a filter changed;
- the map and the skill range are read again on zone, loading-screen and skill events, the cell every second;
- "N catches from K players" under "All" from 2 players on, and `Share.StatusLine()` at the bottom, updated on the
  tick.

## Other frames

- Toast: short messages that rise and fade above the indicator (`ns.Toast`): catches and misses (`FISH_CAUGHT` /
  `FISH_MISSED`) and Skill.lua's warnings.
- Minimap: the button and the Addon Compartment entry from the TOC.
- ItemHooks: Alt+Click on items through `HandleModifiedItemClick`, plus a tooltip line.
- CopyWindow: a window with read-only, selectable text (`ns.ShowCopyWindow`), used by the `/okf debug` and
  `/okf spike` reports.

## Spike.lua (temporary)

Carries `VERIFY(spike)`. `/okf spike` shows, in the copy window, the game facts the catch database and the exchange
were built on (build, map and position, fishing loot sources, auction results, `PanelTabButtonTemplate`, network
APIs) for the checks in `specs/002-local-catch-db/verification.md` and `specs/003-guild-group-sync/verification.md`.
The file, its TOC line, its Commands.lua entry and `tests/spike_test.lua` go before the release, since
`npm run build` refuses `VERIFY` markers.
