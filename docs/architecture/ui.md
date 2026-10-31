# Architecture: UI

The frames in `UI/` and the temporary `Core/Spike.lua`.

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

- Three tabs below the window (statistics, "What can be caught here", the catch catalog): the game's
  `PanelTabButtonTemplate` or plain buttons, the last one saved in `OneKeyFishingDB.statsTab`.
  `StatsFrame.OpenCatalog(arg)` shows the window on the catalog.
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
  `ITEM_DATA_LOAD_RESULT` redraw the row with the name once the game knows the item (FR-017a of `specs/004-public-channel-sync`);
- the miss line uses the view's `missRate` (weighted), and is left out under a water filter;
- the Water button shows only while `CatchDB.HasPoolData()`, in memory only like the other filters;
- a click on a known item row opens the catalog on it (`StatsFrame.OpenCatalog(itemID)`).

## CatalogTab

The "Catch catalog" page (`specs/005-catch-catalog`, contracts/ui.md), drawn from the reads of
[catalog.md](catalog.md):

- the list: a `SearchBoxTemplate` box (its `OnTextChanged` hooked, not set), the Skill, Source and Water buttons
  (CatchHere's labels and menus), and a `WowScrollBoxList` of `Catalog.Items`; a status line for the index being
  counted and the empty states;
- the item page: `Catalog.Places` as zone rows, each expanding into `Catalog.Spots` rows (indented), with the skill
  span, the chance or "Little data", the catches, and the players on hover;
- without the scroll templates (`pcall`), a fixed pool of rows with "and N more" (V37);
- state in memory only; `Tick` reads the catalog every second and redraws, keeping the scroll, when
  `Catalog.GetVersion()` moved;
- the pin (research R6): a spot row with `spot.pin` gets a button (the atlas `Waypoint-MapPin-Untracked`, or a text
  button); `CatalogTab.Pin` asks before replacing a waypoint that is not `OneKeyFishingCharDB.pin` (within 0.0005),
  then `C_Map.SetUserWaypoint`, `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`, saves the pin, toasts, and opens
  the map with the global `OpenWorldMap` out of combat (`C_Map.OpenWorldMap` is restricted). The navigation CVar is
  never touched.

## Other frames

- Widgets: the frame helpers of every window and page: `ns.CreateButton` (the panel button, which grows to its
  text on every `SetText`), `ns.CreateText`, `ns.ItemDisplay` (an item's link and icon), `ns.ShowItemTooltip`
  (item tooltip with the few-lots auction price), `ns.OpenRadioMenu` (a `MenuUtil` menu of choices).
- Toast: short messages that rise and fade above the indicator (`ns.Toast`): catches and misses (`FISH_CAUGHT` /
  `FISH_MISSED`), the next-rank notices (`SKILL_WARNING`) and the map pin answers (`MAP_PIN_SET`).
  `ns.Toast(text, r, g, b, always)`: `always` shows it with catch notifications off, for an answer to the player's
  click and the rank reminders, which have their own setting.
- AuctionButton: the "Scan fish prices" button above the auction house window, made when it first opens; it
  follows `AUCTION_STATE` through `Auction.GetProgress()` and clicks run `Auction.Scan`.
- ShareNotice: the one-time popup about the catch exchange, shown when `Share.NoticeOwed()` says one is owed
  (after entering the world, after combat, retried when the game had no free dialog frame); closing it calls
  `Share.NoticeRead()`, the Settings button opens the "Shared database" page.
- Minimap: the button and the Addon Compartment entry from the TOC; in fishing mode with
  `settings.tooltipChances` their tooltip adds "Likely catch here:" from `Catalog.MinimapLines()`.
- ItemHooks: Alt+Click on items through `HandleModifiedItemClick`, plus a tooltip line; the item post call adds
  "Caught in:" and `Catalog.TooltipLines(itemID)` for `GameTooltip` and `ItemRefTooltip` before the gear line, with
  `settings.tooltipChances` (V38).
- CopyWindow: a window with read-only, selectable text (`ns.ShowCopyWindow`), used by the `/okf debug` and
  `/okf spike` reports.

## Core/Spike.lua (temporary)

Carries `VERIFY(spike)`. `Spike.Report()` returns the window title and the text that `/okf spike` shows in the
copy window: the game facts the catch database and the exchange
were built on (build, map and position, fishing loot sources, auction results, `PanelTabButtonTemplate`, network
APIs, and "Map pins and areas": pins, areas, item names, folding, templates) for the checks of
[docs/checklists/spike.md](../checklists/spike.md) and the `verification.md` of each part.
The file, its TOC line, its Commands.lua entry and `tests/ui/spike_test.lua` go before the release, since
`npm run build` refuses `VERIFY` markers.
