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
- The main page's row "Warn when a camp bonus is ending" (`settings.campBonusWarning`, spec 020; a label, no hint)
  switches the notices of `Fishing/Camp.lua` ([fishing-mode.md](fishing-mode.md)).
- Bags cannot be opened while the Settings panel is open, so items are added through Alt+Click in bags
  (ItemHooks), not from the panel.
- The "Sound effects" subcategory (spec 013, `SettingsUI.OpenSounds()`, `/okf sound`), top to bottom: "Play fishing
  sounds" (`Sound.IsEnabled` / `Sound.SetEnabled`), the volume (Blizzard's `MinimalSliderWithSteppersTemplate`,
  0-100 in steps of 10, greyed while the sounds are off; a value the player picks is stored and plays
  `Sound.Preview()`; a client without the template keeps the page without the slider), "Fishing sound in the
  background" and "Splash focus while fishing" (they write `settings.backgroundSound` / `splashFocus` and fire
  `SETTINGS_CHANGED`, which Mode.lua applies at once while fishing; never greyed). Each has its explanation under
  it; `SETTINGS_CHANGED("fishingSounds")` from the minimap menu updates the shown page.
- The "Auction prices" subcategory (spec 019), top to bottom: "Use scanned auction prices for catch value" (moved
  here from the main page's features), nested under it "Take prices from Auctionator" (inactive and grey while the
  first is off or `Prices.HasAuctionator()` is false; a grey note then says "Auctionator is not installed.", or
  after a failing call "Auctionator failed this session: the addon's own scan is in use."), a line with the source
  in use (`Prices.GetSource()`: Auctionator; the own scan with the time of its last scan or "no scan yet"; auction
  prices off) and a line with the counts of `Prices.CountSources()`. The two checkboxes write through
  `Prices.SetAuctionPrices` / `Prices.SetAuctionator`. The page redraws on `OnShow`, on `SETTINGS_CHANGED` of the
  two keys and on `PRICES_CHANGED`, while shown. No scan button (opening the settings closes the auction house)
  and no reset button.

## StatsFrame

- Four tabs below the window (statistics, "What can be caught here", the catch catalog, the best places): the game's
  `PanelTabButtonTemplate` or plain buttons, the last one saved in `OneKeyFishingDB.statsTab`.
  `StatsFrame.OpenCatalog(arg)` shows the window on the catalog, `OpenStats` on the statistics (the minimap
  menu, the settings' "Open statistics"; `Toggle` keeps the last tab), `OpenBest` on the best places; a closed
  window opens straight on that tab.
- The window is set up by `ns.SetupWindow` (Widgets, below) and raised whenever it is shown or opened on the
  catalog.
- The statistics page has rows in `ROWS`, cells keyed by row key. The last two rows of the "Results" block (spec
  020) are "Casts with a camp bonus" and "Bonus catches" (`bonusCasts`, `bonusCatches` of the buckets, 0 when
  missing; [catch-and-stats.md](catch-and-stats.md)); they are marked `bonusOnly` and, through `f.rowParts` (each
  row's label, hover frame and cells), hidden as a whole while the total has no bonus cast, their place kept, so
  nothing below moves. `HEIGHT` is 736 for them, so the zone lines keep their room above the buttons. A row without
  a `tip` shows only its label on hover.
- A 1 s tick does a full refresh when `Stats.GetVersion()` changed or the window is marked dirty by
  `PRICES_CHANGED`, `SETTINGS_CHANGED`, a skill change, a level-up, item info of a caught item or game names
  arriving for the "Next rank" line, and otherwise only redraws the time rows, so nothing moves outside fishing
  mode.
- The line about the values: with `Prices.UsesAuctionator()` it reads "Values: higher of vendor and Auctionator
  price." and, when some of the own catches have no Auctionator price (`missing` of `Prices.CountSources()`: without
  grey junk), their number with the advice to run its scan (the next-rank line then keeps two lines); otherwise the scan's line as before. The
  scan button is hidden while Auctionator is in use.

## CatchHere

The "What can be caught here" page ([catch-db.md](catch-db.md)):

- `CatchDB.Query` for the current place, a skill filter that follows the own range (`CatchDB.SkillFilter`: 300+ is
  "all") until one is picked by hand and a source filter, both in memory only;
- the Skill button (spec 021) in both tabs: `ns.SkillFilterLabel` ("Skill: Up to 224", "Skill: All"), the menu of
  `CatchHere.OpenSkillMenu` ("Up to 74" ... "All (300+)", `ns.SkillMenuText`, the own range marked "(yours)" from
  the rank, so also without a map), and `ns.ShowSkillTooltip` on hover (what the list sums, the one range its misses
  come from);
- redrawn on the 1 s tick when the data, the place or a filter changed;
- the map and the skill range are read again on zone, loading-screen and skill events, the cell every second;
- the layout, top to bottom (spec 020 decisions 22, 28 and 29; the y offsets are constants at the top of the file):
  the place (one line, 540 wide), the scope line, the hints (`page.hint`, up to three lines, their room always
  kept, so nothing below moves), the exchange line (`Share.StatusLine()`, updated on the tick), the counts, row A
  (Skill, Source), row B (the slot of Water or Camp bonus, then Kinds), the column headers and the list;
- the list is `ns.CreateList` (`UI/Widgets.lua`, the catalog's too): a scroll list whose initializer draws an item
  row or a kind header; only its fallback without the scroll templates has "and N more";
- "N catches from K players" under "All" from 2 players on;
- without a bundled seed, "All" adds a hint: "only your own catches are shown", or just "No bundled data in this
  version." when another player's catch is in the numbers (`view.others`, spec 012);
- an item the client does not know yet (`GetItemInfoInstant` nil when the row is drawn) gets the "Unknown item" text,
  a question mark icon (134400), no price, and one `C_Item.RequestLoadItemDataByID`; its tooltip says how many
  players reported it on the map, whether the bundled data has it, and its item ID. `GET_ITEM_INFO_RECEIVED` and
  `ITEM_DATA_LOAD_RESULT` redraw the row with the name once the game knows the item (FR-017a of
  `specs/004-public-channel-sync`);
- the miss line uses the view's `missRate` (weighted, the chosen range's alone), "Nothing caught: little data" when
  `missLittleData`, and is left out under a water filter;
- the Water button shows only while `CatchDB.HasPoolData()`, in memory only like the other filters;
- the Camp bonus button (spec 020, research R8) takes the Water button's slot at the start of row B: shown while
  `CatchDB.HasBonusData()`, and then the Water button is hidden and the water reads as "all" (the two filters do not
  combine). Both tabs make the slot's buttons with `CatchHere.CreateWaterButton(parent, x, y, current, choose)` and
  `CatchHere.CreateBonusButton(parent, x, y, current, choose)`, and `CatchHere.UpdateFilterSlot(waterButton,
  bonusButton, water, bonus, nextButton)` shows the right one, sets both texts, places `nextButton` (Kinds) right of
  the shown one, or at the slot when none shows, and returns the water and the bonus the tab keeps. The value
  (`"all"`, `"none"`, `"bonusOnly"` or a bonus key) is in memory only; the button reads "Camp bonus: " with the value
  in short, a whole text per value (`Catalog.BonusButtonText`: "Camp bonus: All", "No bonus", "Bonus only",
  "Rack", "Hut"). `CatchHere.OpenBonusMenu(owner, current, choose)` (also the catalog's) is a radio menu of the full
  labels (`Catalog.BonusLabel`): "All catches", "No camp bonus", "Bonus catches only" and each bonus with data
  (`CatchDB.BonusKeys`, `HasBonusData(key)`). `CatchHere.OfferedBonus` falls back to "all" without bonus data or for
  a bonus no longer offered (FR-027). Its tooltip (`ShowBonusButtonTooltip`): the title "Camp bonus", what the
  filter shows, and that "No camp bonus" also holds older catches for which the bonus is not known;
- "Bonus catches only" (`"bonusOnly"`, research R20) is a filter of the list: the query gets `bonus = "all"`
  (`CatchHere.QueryBonus`) and `CatchHere.BonusItems` keeps the items whose `item.bonus` is not `plain` before
  `Catalog.Group`, so the counts line and every chance are those of "All catches"; with items in the view and none
  tagged the message is "No bonus catch has been recorded here yet."; under "No camp bonus" (`"none"`) the same
  function keeps the items without any tag, plain ones left out too (decision 35, `Catalog.BonusShown`);
- the tag (research R19): a row whose item carries `item.bonus` shows the camp feature's icon (`Catalog.BonusIcon`,
  `TAG_SIZE` 14 px) at the right end of the name column, the name keeping the rest (`ns.CreateTagIcon` and
  `ns.ShowTag` of `UI/Widgets.lua`, for both tabs); its chance cell shows the chance under the bonus (`item.bonus.chance`, "Little data" when
  `item.bonus.littleData`), without the words, unless the tag is `plain`; the row hands its bonus to
  `ns.ShowItemTooltip`, and the "Unknown item" tooltip calls `ns.AddBonusLines`;
- the "Per catch" cell is `ns.FormatCount(item.pieces)` ([core.md](core.md)): "1", "1.3";
- a click on a known item row opens the catalog on it (`StatsFrame.OpenCatalog(itemID)`);
- the items are grouped under kind headers (`Catalog.Group`, spec 014): a header is a row in header mode (the kind's
  text only, no item, so its hover and click do nothing), elements of the scroll list like the items; the Kinds
  button is the second of row B (spec 020 decision 22; before it stood at the top right, beside the place's name);
- the Kinds button reads "Kinds: All" or "Kinds: N of 7" and opens `CatchHere.OpenKindMenu`: `ns.OpenCheckboxMenu`
  (`UI/Widgets.lua`, which shares its body with `ns.OpenRadioMenu`) with one checkbox per kind; a click goes
  through `Catalog.SetKindShown`, and each tab redraws itself at once on `SETTINGS_CHANGED("hiddenKinds")` (a hidden
  one when shown again); the menu stays open (the game's checkbox answers `MenuResponse.Refresh`); the choice is saved
  (`settings.hiddenKinds`) and shared with the catalog; with items in the view and every kind hidden the message
  is "The kind filter hides every item."

## CatalogTab

The "Catch catalog" page (`specs/005-catch-catalog`, contracts/ui.md), drawn from the reads of
[catalog.md](catalog.md):

- the list, top to bottom (spec 017; spec 020 decisions 22 and 30): a `SearchBoxTemplate` box (its `OnTextChanged`
  hooked, not set); the status line (two lines: the index being counted and the empty states); row A, the Skill and
  Source buttons (CatchHere's labels and menus); row B, the slot of Water or Camp bonus (CatchHere's
  `CreateWaterButton`, `CreateBonusButton`, `UpdateFilterSlot`), the Kinds button and the Sort button (a radio menu
  of `Catalog.SORTS`, the choice through `Catalog.SetSort`), each right of the one before, so a longer translation
  pushes the next along; then the list of `Catalog.Items` through `ns.CreateList`. On an item's page the same status
  line sits where the zones begin;
- an item row's right column shows what the list is ordered by: `Zones: N` by name, the price per piece
  (`ns.FormatMoney(Prices.Get)`, or "No price" in grey) by price, the best place's chance (`Catalog.ChanceText`) by
  chance; its color is set on every draw, as rows are reused. `SETTINGS_CHANGED("catalogSort")` redraws the list
  from its top; by price, `GET_ITEM_INFO_RECEIVED` of an item the list shows marks the page dirty (a vendor price
  that arrives late; other items are ignored, as on the other tabs);
- the item page: `Catalog.Places` as zone rows, each expanding into `Catalog.Spots` rows (indented), with the skill
  span, the chance or "Little data", the catches, and the players on hover;
- the Camp bonus (spec 020): the same button as CatchHere's for the tab's own filter (`CatalogTab.SetBonus`, in
  memory), in the Water button's slot once `CatchDB.HasBonusData()`; under "Bonus catches only" `Catalog.Items` keeps
  the tagged rows ([catalog.md](catalog.md)), an item's page shows all its zones, and an empty list without search
  text says "No bonus catch has been recorded yet."; the tag's icon (`ns.ShowTag` and `ns.CreateTagIcon` of
  `UI/Widgets.lua`, 14 px at the right end of the name column) in the list rows, the zone rows and the spot rows; a
  list row hands its bonus to `ns.ShowItemTooltip`, a place's tooltip adds `ns.AddBonusLines` after its catches
  line, and the right column writes "Little data" for a tagged item without a chance;
- without the scroll templates (`pcall`), the fixed pool of rows of `ns.CreateList` with "and N more" (V37; kind
  headers not counted);
- the list is grouped like CatchHere's (spec 014): `{ header = kind }` elements before each kind's items, drawn as a
  gold label without icon, zones, hover or click; the same Kinds button (CatchHere's menu) in row B, before Sort;
  the fallback rows never end with a header (it needs room for one of its items, as in CatchHere); the status says
  "The kind filter hides every item." or, with a search, "The kind filter hides the matches." when rows exist but none is
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

- The "Import and export" subcategory (spec 027, `UI/TransferPage.lua`), registered through
  `SettingsUI.AddPage(frame, title)` (pages of other files: subcategories after the addon's own; one added before the
  `PLAYER_LOGIN` registration waits for it, one added later, as this page from its own `PLAYER_LOGIN` handler, is
  registered at once; it returns the page's opener). A choice button (`ns.OpenRadioMenu`: Import,
  the default, or Export), a scroll frame with one multi-line edit box (`SetMaxLetters(0)`), the hint under it and,
  on Import, an Import button (disabled while a transfer runs). Export calls `Share.Export()` and shows the string
  selected and focused, read-only (typing restores it); Import empties the box and focuses it, the button calls
  `Share.Import`. An `OnUpdate` while shown polls `Share.TransferState()` for the hint (instructions, progress, the
  counts or the error). `SettingsUI.OpenTransfer(choice)` opens the page on a choice (`/okf share import|export`).

## Other frames

- The minimap button's menu takes entries added at runtime: `ns.MinimapMenu.AddEntries(fn)`, each `fn(root)` run
  through `ns.Safe` after "Debug report" (spec 027, an extension point for code loaded after the addon).

- The minimap button's menu has a button "Turn fishing sounds on" / "Turn fishing sounds off" (its text follows
  `Sound.IsEnabled()`, a click calls `Sound.SetEnabled`), like the fishing mode entry; spec 013.

- Widgets: the frame helpers of every window and page: `ns.SetupWindow(frame, globalName)` (what the statistics
  window and the copy window share: the global name, Escape through `UISpecialFrames`, the `HIGH` strata (below the game's popups, which are `DIALOG` and top-level: a click on a window would otherwise cover the question it opened),
  dragging, top-level so that a click raises the window with its children, and the close button, the template's
  or a new one, whose click hides the frame directly: the game's own script goes through `HideUIPanel`, which
  refuses addon code in combat), `ns.CreateButton` (the panel button, which grows to its
  text on every `SetText`), `ns.CreateText`, `ns.ItemDisplay` (an item's link and icon), `ns.ShowItemTooltip(owner,
  itemID, withPrice, bonus)` (item tooltip with the addon's auction price, `Prices.AddTooltipLine`, and with a bonus
  table `ns.AddBonusLines` after the item's own lines), `ns.AddColoredLine(tooltip, text, r, g, b, wrap)` (spec 020
  decision 34: `AddLine` with the text in `ns.ColoredText` and the colour arguments, so a reset of the line colours
  leaves it coloured), `ns.AddBonusLines(tooltip, bonus)` (spec 020: the tag's name through `ns.AddColoredLine`, its
  explanation, `Catalog.BonusTip(bonus.key, bonus.several)`, and, unless `plain`, the chance with the bonus and its
  players, whatever `settings.tooltipChances`), `ns.TooltipHasBonus(tooltip, itemID)` (`ShowItemTooltip` keeps
  `{ owner, itemID }` after `SetOwner` and before `SetItemByID`, which runs the game's item hook, on every call: nil
  without a bonus; a `GameTooltip:HookScript("OnHide")` clears it; true when something is kept, the tooltip is
  `GameTooltip` and its owner and item match, so ItemHooks adds no doubled explanation line), `ns.CreateList(parent, top, initialize)`
  (spec 020, moved from `UI/CatalogTab.lua`: the list of both catch pages, a `WowScrollBoxList` with a
  `MinimalScrollBar` from `top` to the window's bottom, or without the templates a fixed pool of rows with "and N
  more"; `list.Show(elements, retain)`), `ns.OpenRadioMenu` (a `MenuUtil` menu of choices), `ns.KeyText`
  (`binding, short, unbound, separator`: every key bound to an action, in the game's order, joined with " / ", or
  a red "not bound"; the minimap tooltip, the settings key line and the indicator use it), `ns.RangeLabel(min, max)`
  (a real skill range's label: "0-74", "75-224", "300+"; the catalog's Skill column, the Skill tooltip's miss range),
  `ns.SkillFilterLabel`, `ns.SkillMenuText`, `ns.ShowSkillTooltip` (the Skill button of both catch pages, spec 021),
  `ns.UpdateScanButton(button)`
  (the auction scan button of the statistics window and above the auction window; the settings page has none,
  since opening the settings closes the auction house window: enabled by `Auction.CanScan()`, the reason
  `Auction.WhyNot()` on hover, also while disabled) and
  `ns.ShowReasonOnHover(button)` (a button's `reason` in the tooltip, also while disabled; `ns.SetReason(button,
  reason)` sets it and updates a tooltip the button shows). The skill, source and water menus of the two
  catch pages are `CatchHere.OpenSkillMenu`, `OpenSourceMenu` and `OpenWaterMenu`; the catalog tab uses them too.
- PlaceList (`UI/PlaceList.lua`, spec 024): the three-level list of the catalog's item page and of the best places:
  zone rows open into subzone groups and spots, groups into spots (`Catalog.GroupSpots`), an indent per level, a
  "+"/"-" mark on zones and groups, the pin button (the atlas or a text button) on groups and spots; the caller gives
  the columns with their headers (`PlaceList.Headers`), each row's cells and the tooltip. Expanded zones and groups
  live in memory (`Toggle(key)`, `Fold()`).
- Best places tab (`UI/BestPlacesTab.lua`, the window's fourth page `best`, spec 024): row A Skill, Source, Safe for
  me; row B Water or Camp bonus, Kinds, Continent; the columns Place, Skill, Level (red above the character's level),
  Gold per hour ("*" when much of the catch has no price, "Little data"), Catches; the tooltip of a row lists the
  items that bring the gold, the players and the unpriced share. Skill, Source, Water and Camp bonus live in memory;
  it redraws on `SETTINGS_CHANGED` of `hiddenKinds` and `bestPlaces` and polls `BestPlaces.GetVersion()`. The minimap
  menu opens it ("Best places") and the catalog ("Catalog") next to "Statistics" (`StatsFrame.OpenBest`,
  `OpenCatalog`); its "Statistics" opens the statistics tab (`OpenStats`).
- Toast: short messages that rise and fade above the indicator (`ns.Toast`): catches and misses (`FISH_CAUGHT` /
  `FISH_MISSED`), the next-rank notices (`SKILL_WARNING`), the map pin answers (`MAP_PIN_SET`) and the camp bonus notices
  (`CAMP_BONUS_WARNING`, spec 020: always, in gold `1, 0.82, 0`), and a trophy new to the account (spec 023):
  `ITEM_FIRST_CAUGHT` of a trophy (`Catalog.ItemKind`) is remembered for its cast, and the cast's `FISH_CAUGHT`
  then leaves it out of the catch line and shows "New trophy: <link> (n/36)" always, in gold, n being the count after
  that trophy (`Catalog.TrophyCount` already holds the cast's new ones).
  `ns.Toast(text, r, g, b, always)`: `always` shows it with catch notifications off, for an answer to the player's
  click and the rank reminders, which have their own setting.
- The catalog tab's trophies (spec 023): the Trophies header reads "Trophies (n/36)" (`Catalog.TrophyCount`), and an
  item row of a trophy the account caught (`CatchDB.IsOwnItem`) shows the atlas `common-icon-checkmark` (12 px; the
  texture `ReadyCheck-Ready` on a client without it) on its icon's bottom right corner; header rows and other items hide it.
- AuctionButton: the "Scan fish prices" button above the auction house window, made when it first opens; it
  follows `AUCTION_STATE` through `Auction.GetState()` and `GetProgress()`: "Scanning n/m" while a scan runs,
  "Auction house not answering" (disabled, the reason on hover) while stalled; clicks run `Auction.Scan`. The
  minimap menu's scan entry reads the same while stalled. While the prices come from Auctionator
  (`Prices.UsesAuctionator()`, spec 019) the button is hidden (it also follows `SETTINGS_CHANGED` and
  `PRICES_CHANGED`) and the minimap menu has no scan entry.
- ShareNotice: the one-time popup about the catch exchange, shown when `Share.NoticeOwed()` says one is owed
  (after entering the world, after combat, retried when the game had no free dialog frame); closing it calls
  `Share.NoticeRead()`, the Settings button opens the "Shared database" page.
- Minimap: the button and the Addon Compartment entry from the TOC; the right-click menu leaves its title out in
  combat (the game refuses its secure value to addon code then, docs/forever-api.md); in fishing mode with
  `settings.tooltipChances` their tooltip adds "Likely catch here:" from `Catalog.MinimapLines()`. The tooltip is
  cleared after `SetOwner`, and every coloured line carries its colour as a code in its text as well as in the
  arguments (`ns.ColoredText`, `ns.AddColoredLine`): the game once reset the line colours (every line white) while
  text codes survived (spec 012).
- ItemHooks: Alt+Click on items through `HandleModifiedItemClick`, plus a tooltip line; the item post call adds
  "Caught in:" and `Catalog.TooltipLines(itemID)` for `GameTooltip` and `ItemRefTooltip` before the gear line, with
  `settings.tooltipChances` (V38). A tagged place's chance is in the bonus form, and for a tagged item (the second
  value of `TooltipLines`) one more line, the tag's explanation (`Catalog.BonusTip(bonus.key, bonus.several)`),
  unless `ns.TooltipHasBonus(tooltip, itemID)` says the addon's row tooltip already holds it. "Caught in:" and the
  two fishing gear lines go through `ns.AddColoredLine` in `ns.TOOLTIP_COLOR` (spec 020 decision 34: another addon
  or the game reset the line colours of the catalog's item tooltips on 2026-11-20).
- CopyWindow: a window with read-only, selectable text (`ns.ShowCopyWindow`), used by the `/okf debug`
  report; `ns.ShowDebugReport` shows the debug report (the command, the minimap menu and the
  settings page). Set up by `ns.SetupWindow`; every `ns.ShowCopyWindow` raises it.
