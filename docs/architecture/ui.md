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
  `SettingsUI.OpenShare()` opens it. While the public channel is on (`Channel.AVAILABLE`, as it ships since spec
  016; off only with the kill switch), a second
  checkbox "Use the public channel" sits under the first (greyed out while sharing is off, re-read on
  `SETTINGS_CHANGED`), with the channel's state line (`Share.ChannelLine()`) under it, and the text gains two
  sentences about the channel.
- Bags cannot be opened while the Settings panel is open, so items are added through Alt+Click in bags
  (ItemHooks), not from the panel.
- The "Sound effects" subcategory (spec 013, `SettingsUI.OpenSounds()`, `/okf sound`), top to bottom: "Play fishing
  sounds" (`Sound.IsEnabled` / `Sound.SetEnabled`), the volume (Blizzard's `MinimalSliderWithSteppersTemplate`,
  0-100 in steps of 10, greyed while the sounds are off; a value the player picks is stored and plays
  `Sound.Preview()`; a client without the template keeps the page without the slider), "Fishing sound in the
  background" and "Splash focus while fishing" (they write `settings.backgroundSound` / `splashFocus` and fire
  `SETTINGS_CHANGED`, which Mode.lua applies at once while fishing; never greyed). Each has its explanation under
  it; `SETTINGS_CHANGED("fishingSounds")` from the minimap menu updates the shown page.

## StatsFrame

- Three tabs below the window (statistics, "What can be caught here", the catch catalog): the game's
  `PanelTabButtonTemplate` or plain buttons, the last one saved in `OneKeyFishingDB.statsTab`.
  `StatsFrame.OpenCatalog(arg)` shows the window on the catalog.
- The window is set up by `ns.SetupWindow` (Widgets, below) and raised whenever it is shown or opened on the
  catalog.
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
- a click on a known item row opens the catalog on it (`StatsFrame.OpenCatalog(itemID)`);
- the items are grouped under kind headers (`Catalog.Group`, spec 014): a header is a row in header mode (the kind's
  text only, no item, so its hover and click do nothing); headers take rows of the 16, and "and N more" counts the
  items left out; the filter row stays Skill, Source and Water (150 each); the Kinds button sits apart at the top
  right, beside the place's name (400 wide), so the filter row keeps its width in every language;
- the Kinds button reads "Kinds: all" or "Kinds: N of 5" and opens `CatchHere.OpenKindMenu`: `ns.OpenCheckboxMenu`
  (`UI/Widgets.lua`, which shares its body with `ns.OpenRadioMenu`) with one checkbox per kind; a click goes
  through `Catalog.SetKindShown`, and each tab redraws itself at once on `SETTINGS_CHANGED("hiddenKinds")` (a hidden
  one when shown again); the menu stays open (the game's checkbox answers `MenuResponse.Refresh`); the choice is saved
  (`settings.hiddenKinds`) and shared with the catalog; with items in the view and every kind hidden the message
  is "The kind filter hides every item."

## CatalogTab

The "Catch catalog" page (`specs/005-catch-catalog`, contracts/ui.md), drawn from the reads of
[catalog.md](catalog.md):

- the list: three rows of controls over a `WowScrollBoxList` of `Catalog.Items` (spec 017): a `SearchBoxTemplate`
  box (its `OnTextChanged` hooked, not set); the Skill, Source and Water buttons (CatchHere's labels and menus; with
  the longest translations they fill the row); the Sort button (a radio menu of `Catalog.SORTS`, the choice through
  `Catalog.SetSort`) and the Kinds button; a status line for the index being counted and the empty states;
- an item row's right column shows what the list is ordered by: `Zones: N` by name, the price per piece
  (`ns.FormatMoney(Prices.Get)`, or "No price" in grey) by price, the best place's chance (`Catalog.ChanceText`) by
  chance; its color is set on every draw, as rows are reused. `SETTINGS_CHANGED("catalogSort")` redraws the list
  from its top; by price, `GET_ITEM_INFO_RECEIVED` of an item the list shows marks the page dirty (a vendor price
  that arrives late; other items are ignored, as on the other tabs);
- the item page: `Catalog.Places` as zone rows, each expanding into `Catalog.Spots` rows (indented), with the skill
  span, the chance or "Little data", the catches, and the players on hover;
- without the scroll templates (`pcall`), a fixed pool of rows with "and N more" (V37; kind headers not counted);
- the list is grouped like CatchHere's (spec 014): `{ header = kind }` elements before each kind's items, drawn as a
  gold label without icon, zones, hover or click; the same Kinds button (CatchHere's menu) in the third row, after Sort; the fallback rows never end with
  a header (it needs room for one of its items, as in CatchHere); the status says "The kind
  filter hides every item." or, with a search, "The kind filter hides the matches." when rows exist but none is
  shown; `Show(itemID)` opens an item whatever its kind, while a name with one match chooses it only when its kind
  is shown;
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

- The minimap button's menu has a button "Turn fishing sounds on" / "Turn fishing sounds off" (its text follows
  `Sound.IsEnabled()`, a click calls `Sound.SetEnabled`), like the fishing mode entry; spec 013.

- Widgets: the frame helpers of every window and page: `ns.SetupWindow(frame, globalName)` (what the statistics
  window and the copy window share: the global name, Escape through `UISpecialFrames`, the `HIGH` strata (below the game's popups, which are `DIALOG` and top-level: a click on a window would otherwise cover the question it opened),
  dragging, top-level so that a click raises the window with its children, and the close button, the template's
  or a new one, whose click hides the frame directly: the game's own script goes through `HideUIPanel`, which
  refuses addon code in combat), `ns.CreateButton` (the panel button, which grows to its
  text on every `SetText`), `ns.CreateText`, `ns.ItemDisplay` (an item's link and icon), `ns.ShowItemTooltip`
  (item tooltip with the addon's auction price, `Prices.AddTooltipLine`), `ns.OpenRadioMenu` (a `MenuUtil` menu of choices), `ns.KeyText`
  (`binding, short, unbound, separator`: every key bound to an action, in the game's order, joined with " / ", or
  a red "not bound"; the minimap tooltip, the settings key line and the indicator use it), `ns.RangeLabel(min, max)`
  (the skill range label of both catch pages: "0-74", "75-224", "300+"), `ns.UpdateScanButton(button)`
  (the auction scan button of the statistics window and above the auction window; the settings page has none,
  since opening the settings closes the auction house window: enabled by `Auction.CanScan()`, the reason
  `Auction.WhyNot()` on hover, also while disabled) and
  `ns.ShowReasonOnHover(button)` (a button's `reason` in the tooltip, also while disabled; `ns.SetReason(button,
  reason)` sets it and updates a tooltip the button shows). The skill, source and water menus of the two
  catch pages are `CatchHere.OpenSkillMenu`, `OpenSourceMenu` and `OpenWaterMenu`; the catalog tab uses them too.
- Toast: short messages that rise and fade above the indicator (`ns.Toast`): catches and misses (`FISH_CAUGHT` /
  `FISH_MISSED`), the next-rank notices (`SKILL_WARNING`) and the map pin answers (`MAP_PIN_SET`).
  `ns.Toast(text, r, g, b, always)`: `always` shows it with catch notifications off, for an answer to the player's
  click and the rank reminders, which have their own setting.
- AuctionButton: the "Scan fish prices" button above the auction house window, made when it first opens; it
  follows `AUCTION_STATE` through `Auction.GetState()` and `GetProgress()`: "Scanning n/m" while a scan runs,
  "Auction house not answering" (disabled, the reason on hover) while stalled; clicks run `Auction.Scan`. The
  minimap menu's scan entry reads the same while stalled.
- ShareNotice: the one-time popup about the catch exchange, shown when `Share.NoticeOwed()` says one is owed
  (after entering the world, after combat, retried when the game had no free dialog frame); closing it calls
  `Share.NoticeRead()`, the Settings button opens the "Shared database" page.
- Minimap: the button and the Addon Compartment entry from the TOC; the right-click menu leaves its title out in
  combat (the game refuses its secure value to addon code then, docs/forever-api.md); in fishing mode with
  `settings.tooltipChances` their tooltip adds "Likely catch here:" from `Catalog.MinimapLines()`. The tooltip is
  cleared after `SetOwner`, and every coloured line carries its colour as a code in its text as well as in the
  arguments: the game once reset the line colours (every line white) while text codes survived (spec 012).
- ItemHooks: Alt+Click on items through `HandleModifiedItemClick`, plus a tooltip line; the item post call adds
  "Caught in:" and `Catalog.TooltipLines(itemID)` for `GameTooltip` and `ItemRefTooltip` before the gear line, with
  `settings.tooltipChances` (V38).
- CopyWindow: a window with read-only, selectable text (`ns.ShowCopyWindow`), used by the `/okf debug`
  report; `ns.ShowDebugReport` shows the debug report (the command, the minimap menu and the
  settings page). Set up by `ns.SetupWindow`; every `ns.ShowCopyWindow` raises it.
