# Architecture: UI

The frames in `UI/` and the temporary `Spike.lua`.

## Indicator

Next action, cast bar, session timer. "No bobber" when the soft interact GUID is not game object 35591; while the
bobber is still flying, up to 3 s after the channel start, no warning.

## Settings

- Canvas pages built from plain widgets, not the Settings setting-type API.
- The "Shared database" subcategory holds the exchange setting, its text and a status line updated every second;
  `SettingsUI.OpenShare()` opens it. While the release has the public channel (`Channel.AVAILABLE`), a second
  checkbox "Use the public channel" sits under the first (greyed out while sharing is off, re-read on
  `SETTINGS_CHANGED`), with the channel's state line (`Share.ChannelLine()`) under it, and the text gains two
  sentences about the channel.
- Bags cannot be opened while the Settings panel is open, so items are added through Alt+Click in bags
  (ItemHooks), not from the panel.

## StatsFrame

- Two tabs below the window: the game's `PanelTabButtonTemplate` or plain buttons, the last one saved in
  `OneKeyFishingDB.statsTab`.
- The statistics page has rows in `ROWS`, cells keyed by row key.
- A 1 s tick does a full refresh when `Stats.GetVersion()` changed or the window is marked dirty by
  `PRICES_CHANGED`, `SETTINGS_CHANGED`, a skill change, a level-up, item info of a caught item or game names
  arriving for the "Next rank" line, and otherwise only redraws the time rows, so nothing moves outside fishing
  mode.

## CatchHere

The "What can be caught here" page ([catch-db.md](catch-db.md)):

- `CatchDB.Query` for the current place, a skill filter that follows the own range until one is picked by hand
  and a source filter, both in memory only;
- redrawn on the 1 s tick when the data, the place or a filter changed;
- the map and the skill range are read again on zone, loading-screen and skill events, the cell every second;
- "N catches from K players" under "All" from 2 players on, and `Share.StatusLine()` at the bottom, updated on the
  tick;
- an item the client does not know yet (`GetItemInfoInstant` nil when the row is drawn) gets the "Unknown item" text,
  a question mark icon (134400), no price, and one `C_Item.RequestLoadItemDataByID`; its tooltip says how many
  players reported it on the map, whether the bundled data has it, and its item ID. `GET_ITEM_INFO_RECEIVED` and
  `ITEM_DATA_LOAD_RESULT` redraw the row with the name once the game knows the item (part 3, FR-017a);
- the miss line uses the view's `missRate` (weighted, part 3).

## Other frames

- Toast: short messages that rise and fade above the indicator (`ns.Toast`): catches and misses (`FISH_CAUGHT` /
  `FISH_MISSED`) and Skill.lua's notices. `ns.Toast(text, r, g, b, always)`: `always` shows it with catch
  notifications off, for an answer to the player's click and the rank reminders, which have their own setting.
- Minimap: the button and the Addon Compartment entry from the TOC.
- MapPin: `MapPin.Target(maps, x, y)` (the first candidate map the client knows and allows pins on, none under the
  game rule that turns pins off); `MapPin.Set(target, placeName)` (the game's pin, the navigation arrow,
  `charDB.pin`, a popup before replacing a pin the player set); `MapPin.Link` (a chat map link).
- ItemHooks: Alt+Click on items through `HandleModifiedItemClick`, plus a tooltip line.
- CopyWindow: a window with read-only, selectable text (`ns.ShowCopyWindow`), used by the `/okf debug` and
  `/okf spike` reports.

## Spike.lua (temporary)

Carries `VERIFY(spike)`. `/okf spike` shows, in the copy window, the game facts the catch database and the exchange
were built on (build, map and position, fishing loot sources, auction results, `PanelTabButtonTemplate`, network
APIs) for the checks in `specs/002-local-catch-db/verification.md` and `specs/003-guild-group-sync/verification.md`.
The file, its TOC line, its Commands.lua entry and `tests/spike_test.lua` go before the release, since
`npm run build` refuses `VERIFY` markers.
