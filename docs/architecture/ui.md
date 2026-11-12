# Architecture: UI

The frames in `UI/`.

## Indicator

Next action, cast bar, session timer. "No bobber" when the soft interact GUID is not game object 35591; while the
bobber is still flying, up to 3 s after the channel start, no warning. In an instance the GUID is a secret value and
the bobber cannot be told apart (`IsBobberTargeted` answers unknown): no warning, "Hook!" (spec 012). In a fight (`Action.IsPaused()`, spec 009)
it shows "Paused in combat" instead of the next action, with no pulse, bar or key; the fight's end redraws it.

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
- without a bundled seed, "All" adds a hint: "only your own catches are shown", or just "No bundled data in this
  version." when another player's catch is in the numbers (`view.others`, spec 012);
- an item the client does not know yet (`GetItemInfoInstant` nil when the row is drawn) gets the "Unknown item" text,
  a question mark icon (134400), no price, and one `C_Item.RequestLoadItemDataByID`; its tooltip says how many
  players reported it on the map, whether the bundled data has it, and its item ID. `GET_ITEM_INFO_RECEIVED` and
  `ITEM_DATA_LOAD_RESULT` redraw the row with the name once the game knows the item (FR-017a of
  `specs/004-public-channel-sync`);
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
  `Catalog.GetVersion()` moved; a `Show(arg)` while the index of the filter is still building keeps `arg` pending
  (a text already fills the search) and `Tick` passes it on once the index is ready; the player's typing, the search's
  clear button and hiding the page (a closed window, another tab) drop it;
- the pin (research R6): a spot row with `spot.pin` gets a button (the atlas `Waypoint-MapPin-Untracked`, or a text
  button); its click calls `ns.MapPin.Set` (`Core/MapPin.lua`, the same pin as the next rank's): the question before
  replacing a pin the player set, the waypoint and its tracking, the saved pin; the map stays closed. The answer
  comes through `MAP_PIN_SET` as a toast that names the place and says to open the world map (`UI/Toast.lua`, also with catch notifications off: an answer to a
  click). The navigation CVar is never touched.

## Other frames

- Widgets: the frame helpers of every window and page: `ns.CreateButton` (the panel button, which grows to its
  text on every `SetText`), `ns.CreateText`, `ns.ItemDisplay` (an item's link and icon), `ns.ShowItemTooltip`
  (item tooltip with the few-lots auction price), `ns.OpenRadioMenu` (a `MenuUtil` menu of choices), `ns.KeyText`
  (`binding, short, unbound, separator`: every key bound to an action, in the game's order, joined with " / ", or
  a red "not bound"; the minimap tooltip, the settings key line and the indicator use it), `ns.RangeLabel(min, max)`
  (the skill range label of both catch pages: "0-74", "75-224", "300+") and `ns.UpdateScanButton(button, hint)`
  (the auction scan button of the statistics window and the settings). The skill, source and water menus of the two
  catch pages are `CatchHere.OpenSkillMenu`, `OpenSourceMenu` and `OpenWaterMenu`; the catalog tab uses them too.
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
  `settings.tooltipChances` their tooltip adds "Likely catch here:" from `Catalog.MinimapLines()`. The tooltip is
  cleared after `SetOwner`, and every coloured line carries its colour as a code in its text as well as in the
  arguments: the game once reset the line colours (every line white) while text codes survived (spec 012).
- ItemHooks: Alt+Click on items through `HandleModifiedItemClick`, plus a tooltip line; the item post call adds
  "Caught in:" and `Catalog.TooltipLines(itemID)` for `GameTooltip` and `ItemRefTooltip` before the gear line, with
  `settings.tooltipChances` (V38).
- CopyWindow: a window with read-only, selectable text (`ns.ShowCopyWindow`), used by the `/okf debug`
  report; `ns.ShowDebugReport` shows the debug report (the command, the minimap menu and the
  settings page).
