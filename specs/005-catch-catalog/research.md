# Research: Catch Catalog, Map Pins and Catch Chances in Tooltips

Decisions taken for the plan, each with the reason and the alternatives that were rejected. The product decisions
were settled with the author in the spec's "Quiz on the gameplay" (2026-10-31). API facts were read from the author's
own client export (build 1.60.1.70685, `_forever_/BlizzardInterfaceCode`) on 2026-10-31. They prove that a function
exists, not how it behaves, so behaviour is an assumption in [verification.md](verification.md) (V30-V40).

## R1. Built now, verified after launch; no ship switch

- **Decision**: as in parts 1 to 3: built before the game opens on 2026-11-04. Every behaviour only the game shows
  is marked `-- VERIFY(Vn)` (V30-V40, numbered after part 3's V19-V29). `/okf spike` gets a "Map pins and areas"
  section (R13). No constant switches anything off: each assumption degrades by itself when it fails.
  - Pins refused everywhere (V30): `Catalog.PinTarget` returns nil, so no row has a pin button.
  - No subzone at the cast position (V34): no area is recorded, and spots show coordinates only.
  - No pool split (V3, part 1): no cell has a pool part, so the "Water" filter never shows.
- **Rationale**: Principle IV. Part 3 needed `Channel.AVAILABLE` because a broken channel would still have joined
  and sent. Here a failed assumption only leaves a button or a name out.
- **Alternatives rejected**: a `Catalog.PINS` switch (nothing would read it that `CanSetUserWaypointOnMap` does not
  already answer).

## R2. Where the code lives

- **Decision**:
  - **CatchDB.lua** keeps owning every sum. It gains:
    - the area of a cast (R4) and the water filter (R5);
    - two views without the little-data fallback: `QueryMap` (one map) and `QueryCells` (the spots of one map);
    - `Maps` (the maps with data), `HasPoolData`;
    - a change stamp per map (R3).
  - **Catalog.lua** (new, after `Share.lua` in the TOC) holds the views across all maps:
    - the item index of a filter, built in frame steps;
    - item names and their search keys;
    - the places of an item;
    - the "Caught in" lines and the minimap lines;
    - zone and spot names;
    - the pin target.
    It has no frames, so the tests drive it without the window.
  - **UI/CatalogTab.lua** (new, after `UI/CatchHere.lua`) is the page: the search box, the filters, the item list,
    the item page with zones and spots, the pin button with its game calls, the replace question and the toast.
  - The pin's game calls live in the page because they answer a click there.
- **Rationale**: Principle VI, one job per module. CatchDB is already 1,271 lines and owns the cells. Cross-map
  indexes and names are a job of their own that both tooltips and the tab need without the window, so they cannot
  sit in the UI.
- **Alternatives rejected**:
  - Everything in CatchDB: it would mix name loading, folding and tooltip text into the data module.
  - Everything in the UI file: the tooltips would need the window's code, and the logic would only be testable
    through frames.

## R3. Sums across every map, smooth with the whole database

Facts: `CatchDB.GetVersion()` grows with every own cast, and `Query` empties its whole cache when it does. A sum
of one map walks the seed's index and other players' entries for that map (indexed), but every own cell (`mine` or
the own record's builds) for every map.

- **Decision**:
  - **A stamp per map.** CatchDB keeps `stamps[mapID]` and one global stamp (`CatchDB.MapStamp(mapID)` returns
    both).
    - A settled cast bumps its map.
    - `SHARED_DATA_CHANGED` with keys bumps the maps of each record's entries before and after the change (the
      index already holds them).
    - Without keys (sharing switched, a store rebuilt), and at login, the global stamp is bumped.
  - **An own-cells index.** CatchDB keeps the own tables' keys by `<mapID>:<range>`, grown by `Settle` (it knows
    the key). A map sum no longer walks every own cell.
  - **Cached map views.** `Catalog` asks `CatchDB.QueryMap(mapID, filter)` for every map and keeps each view with
    the map's stamp.
    - It recomputes only maps whose stamp moved.
    - With up to 4 such maps it does that at once, when asked.
    - With more, it walks them in frame steps through `C_Timer.After(0)`, each step ending once `debugprofilestop`
      shows 3 ms (8 maps per step where the clock is missing, as in fengari).
    - Meanwhile the last complete index answers, marked stale.
  - **When it builds.** The index of the default filter (all ranges, source "All", water "Everywhere") is built 10 s
    after the first `PLAYER_ENTERING_WORLD` of the Lua session (a login or a `/reload`; later loading screens do
    not start it again), so tooltips are ready when the player first hovers an item. Another filter's index is built
    when the catalog asks for it; only the latest such filter is kept.
  - **Every read refreshes.** Each read of an index (`Items`, `Places`, `Spots`, `TooltipLines`) compares the map
    stamps first: up to 4 changed maps are recomputed at once, more start the step build (unless one is running), and
    the read answers from the stale index meanwhile. So tooltips follow new data even when the catalog is never
    opened (FR-028).
  - **Spots.** The spots of one map are summed when a zone is expanded, at once, and cached with that map's stamp.
- **Rationale**: a full rebuild per cast would be about 200 map sums per cast while fishing. Per-map stamps make an
  own catch cost one map. The 3 ms budget matches the 5 ms frame goal of parts 2 and 3 (SC-003). A stale index for a
  second is invisible in a catalog.
- **Alternatives rejected**:
  - Rebuilding on every version: too slow, see above.
  - The seed's numbers only: it misses the player's own and the network's data, against FR-002.
  - Scanning every cell for one item on each tooltip: the whole database per hover.
  - A separate background coroutine library: `C_Timer.After(0)` steps are what Share and the chain already use.

## R4. Subzone names for every player

Facts:
- `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(uiMapID, vector2)` returns the area IDs the player has explored
  at a position (`MapExplorationDocumentation.lua:11-25`; Blizzard's map tooltip uses it in `MapUtil.lua:62-70`).
- `C_Map.GetAreaInfo(areaID)` returns an area's name.
- `C_Map.GetMapInfoAtPosition` returns child maps only.
- There is no API that names an area for an unexplored position (research of 2026-10-31).
- `GetSubZoneText()` is the name the game shows for the player's subzone.

- **Decision**:
  - **Reading the area.** At `FISHING_CAST_START`, when the cast has a position, CatchDB asks
    `GetExploredAreaIDsAtPosition(mapID, CreateVector2D(x, y))`. The player stands there, so the area is explored.
    It keeps the area whose `C_Map.GetAreaInfo` name, folded with `ns.FoldCase`, equals the folded
    `GetSubZoneText()`: Principle II requires matching against localized text to tolerate case changes in
    non-ASCII text. With an empty subzone text or no match, no area is kept.
  - **Storing it.** Settling the cast adds 1 to `cell.a[areaID]`, a new cell field: area ID -> settled casts.
    - It lives in `mine`, the own record, other players' records and the seed.
    - A cell keeps at most 8 areas; a ninth is not added.
    - The sums add `a` like the other counts; another player's part is scaled by the cast factor of the weights
      (R7 of part 3).
  - **Naming a spot.** A spot is named after its area with the most casts, ties to the lower ID, through
    `C_Map.GetAreaInfo` in the client's language.
  - **Checks.** `CheckRecord`, the harvest's `checkCell` and `seedProblems` check `a`: a table of at most 8 entries,
    keys positive 32-bit numbers, counts with a sum no larger than `c + m`. The harvest sums it and scales it with
    the cast factor, and the seed writes it (`a = { [1519] = 40 }`).
- **Rationale**:
  - Matching the client's own `GetSubZoneText` against the client's own `GetAreaInfo` derives the needle from the
    client's localized data, and the folded comparison tolerates case changes. That is Principle II's rule for text,
    and only the ID travels.
  - The area is coarser than the average point a cell already carries, so privacy is unchanged.
  - Nothing is released, so the record and seed formats change without a protocol version (`OKF1` stays) or a
    migration.
  - At 34-47 bytes per encoded place, an area adds about 5-8, so 500 places stay under 28 KB (V18 is re-measured in
    `harvest_test.mjs`).
- **Alternatives rejected**:
  - Storing names: localized, so against Principle II.
  - Naming at display time with the viewer's explored areas: only explored places get names, against the author's
    decision.
  - A name table per language in the seed: ten tables to maintain, and still missing new places.
  - The first area of the list without matching: the list order is not documented, and it may hold the zone itself.

## R5. Pools apart from open water

Facts: a cell's pool part `p = { c, i }` counts catches from a pool, already included in `c` and `i`. A miss has no
loot source (part 1). The harvest scales `p` with the cell (`tools/harvest.mjs` scaledCell).

- **Decision**: `filter.water` is `"all"` (default), `"open"` or `"pool"`.
  - **Sums.** `AddCell` reads a cell through the filter:
    - `"pool"`: `c = p.c`, `i = p.i`, no misses;
    - `"open"`: `c - p.c`, `i - p.i`, no misses;
    - a cell without `p` counts as all open water.
    A seed cell's raw catches `r` give way to the filtered `c`.
  - **Players.** A contribution counts as a player under a water filter when its filtered catches are above zero.
  - **Little data.** The 50-catch fallback counts the filtered catches. `missRate` is nil under `"open"` and
    `"pool"`, and the page hides the miss line.
  - **When the filter shows.** `CatchDB.HasPoolData()` is true once any cell of the seed (scanned once), the own
    tables or the stored records has a pool part. `Settle` sets it with a pool catch; `SHARED_DATA_CHANGED` re-scans
    only while it is still false. Both tabs show the "Water" button only then.
  - **Tooltips** always use `"all"`.
- **Rationale**: no data change. The pool part is already recorded, shared and seeded, and only a view needed it.
  Misses cannot be split, so showing them under a water filter would be made up.
- **Alternatives rejected**:
  - Pool places as their own keys: a data change that doubles places.
  - A per-item pool mark: the author chose the filter.

## R6. The map pin

Facts:
- `C_Map.CanSetUserWaypointOnMap`, `C_Map.SetUserWaypoint(UiMapPoint)`, `C_Map.HasUserWaypoint`,
  `C_Map.GetUserWaypoint`, `C_SuperTrack.SetSuperTrackedUserWaypoint` and `UiMapPoint.CreateFromCoordinates` are in
  the export with no restriction flag beyond the default `AllowedWhenUntainted`. Blizzard's `/mappin` uses exactly
  this sequence (`WaypointLocationDataProvider.lua:213-230`).
- `Enum.GameRule.WorldMapTrackingPinDisabled` gates Blizzard's pin UI (`C_GameRules.IsGameRuleActive`).
- `C_Map.OpenWorldMap` is marked `HasRestrictions`. The global `OpenWorldMap(mapID)` is plain FrameXML
  (`Blizzard_WorldMap.lua:1413-1419`).
- Forever hides the "Show In-Game Navigation" checkbox (CVar `showInGameNavigation`).
- `C_Map.GetWorldPosFromMapPos` and `C_Map.GetMapPosFromWorldPos(continentID, worldPos, overrideMapID)` convert a
  position between maps.

- **Decision**:
  - **The target.** `Catalog.PinTarget(mapID, spot)` is pure apart from the reads; it is nil without a spot point.
    - With the game rule active, or without the functions, there is no target. When `Enum.GameRule` or its
      `WorldMapTrackingPinDisabled` value is missing, the rule check is skipped, not treated as a refusal.
    - The spot's own map, when `CanSetUserWaypointOnMap(mapID)` is true.
    - Otherwise only for a map of type Micro (a cave or a building): the spot's position goes to world coordinates
      and back onto the parent map (`GetMapPosFromWorldPos` with the parent as the override), when the parent
      allows pins and the point lands inside 0..1.
    - Dungeons and other map types never fall back, so an instance gets no pin.
    - The point is the spot's average catch point.
  - **Pressing the button.**
    - **Asking first.** When `HasUserWaypoint()` and the waypoint is not the one in `OneKeyFishingCharDB.pin`
      (same map, positions within 0.0005), `ns.ShowPopup` asks "Replace your map pin with this place?". "Cancel"
      does nothing.
    - **Setting the pin.** `SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))`. When it returns true:
      `SetSuperTrackedUserWaypoint(true)`; the pin saved in `charDB.pin`; a toast "Map pin: <place>"; and, unless
      `InCombatLockdown()`, `OpenWorldMap(map)`.
    - A false return shows the toast "The game did not accept the map pin." and keeps nothing.
  - **Left alone.** The CVar is never touched.
- **Rationale**: the brief requires the game's own waypoint. Copying Blizzard's sequence is the safest use. A pin is
  set only by the player's click (Principle I). Remembering the addon's last pin per character tells it apart from
  the player's own, also after a login. Instances cannot take pins, and their parent zone is the wrong place.
- **Alternatives rejected**:
  - A `|Hworldmap:` link in chat for the player to click: one more step and a chat line.
  - An arrow of our own: not the game's, outside the brief.
  - `C_Map.OpenWorldMap`: restricted.
  - Turning the navigation CVar on: changes a setting the player cannot see in Forever.
  - A pin on a dungeon's parent zone: points to the wrong water.

## R7. Item names, search and order

Facts:
- `C_Item.GetItemNameByID`, `C_Item.GetItemQualityByID`, `C_Item.RequestLoadItemDataByID` and the events
  `ITEM_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED` are in the export; no throttle is documented.
- The game has `CaseAccentInsensitiveParse(name)` (`LocalizationDocumentation.lua:58`) and `strcmputf8i(a, b)`
  (used in `AddonList.lua:527`).
- `string.lower` handles ASCII letters only (`Gear.lua`, Principle II).

- **Decision**:
  - **Names.** Catalog keeps one entry per item for the session: name, search key, quality and whether it is known.
    An item is known when `GetItemInfoInstant` returns it and `GetItemNameByID` gives a name, as for the "Unknown
    item" row of part 3. Unknown items are asked once per session through a queue of 20 requests per frame step, and
    the load events fill the entry and mark the list dirty. Items stay out of the list and the search until known
    (FR-005).
  - **Search key.** `ns.FoldCase(CaseAccentInsensitiveParse and CaseAccentInsensitiveParse(name) or name)`.
    - `ns.FoldCase` (Data.lua) lowers ASCII, Latin-1 Supplement (U+00C0-U+00DE except U+00D7) and Cyrillic
      (U+0400-U+042F), the scripts of the clients with letter case, by byte patterns that work in Lua 5.1 and 5.3.
    - The typed text goes through the same function.
    - The match is a plain substring find.
  - **Order.** `strcmputf8i` when present, else the search keys' byte order (the tests). Grey means
    `GetItemQualityByID(itemID) == Enum.ItemQuality.Poor` (0). Grey items stay out of the list unless the search
    text is not empty.
- **Rationale**: the client's names in the client's language are what the player knows. The game's own folding
  also ignores accents (a typed "e" finds an "é"), and the fallback keeps the case rule testable without the game.
  The request queue keeps a first opening of hundreds of items from asking the server in one frame (Principle I,
  light server-facing work).
- **Alternatives rejected**:
  - `string.lower` only: fails ruRU, deDE, frFR and the other accented clients.
  - A full Unicode table: large, and it would duplicate the game.
  - Search by item ID: not chosen by the author.

## R8. The tab's layout

Facts: the window is 580 x 660. `WowScrollBoxList`, `CreateScrollBoxListLinearView`,
`ScrollUtil.InitScrollBoxListWithScrollBar`, `MinimalScrollBar`, `CreateDataProvider` and `SearchBoxTemplate` load in
Forever (`Blizzard_SharedXML.toc`, no game-type limit), and Forever's own friends list uses them.

- **Decision**: one page that drills down.
  - **The list.**
    - A search box, then the filter buttons: Skill (default "All"), Source, and Water when there is pool data.
      They work like the buttons of "What can be caught here".
    - The scrolling item list: icon, name, number of zones.
    - A status line: "Counting the catch..." while the first index builds, or the empty states.
  - **The item page.**
    - A header: back button, icon and name.
    - Column headers: Place, Skill, Chance, Catches, then an empty column for the pin buttons.
    - Zone rows with "+"/"-" to expand, and the zone's spots under them, indented.
    - A spot row: "Subzone (45, 72)" or "45, 72", or "No exact spot".
    - A zone row's tooltip says "N catches from K players"; a spot row's adds the subzone and the coordinates.
  - **Where state lives.** All of it stays in memory: search text, chosen item, expanded zones and filters.
  - **Pin button.** The atlas `Waypoint-MapPin-Untracked`, with a text button as the fallback when the atlas is
    missing.
  - **Fallback.** When the scroll templates are missing (`pcall` around their creation), the page keeps a fixed pool
    of rows with "and N more", as CatchHere does, and the search narrows the list.
- **Rationale**: five columns do not fit next to an item list in 580 px, and a drill-down keeps every column
  readable. The game's own scroll list keeps hundreds of rows cheap.
- **Alternatives rejected**:
  - Two panes: too narrow.
  - A wider window: the other tabs are laid out for 580.
  - A separate catalog window: the brief asks for a tab.

## R9. Tooltips

- **Decision**:
  - **The item tooltip.** The existing `TooltipDataProcessor` post call in `UI/ItemHooks.lua` adds the catch lines
    before its gear check (any item, not only equippable ones), for `GameTooltip` and `ItemRefTooltip`, with
    `settings.tooltipChances` on.
    - **Lines.** `Catalog.TooltipLines(itemID)`, from the default index, stale or not: a header "Caught in:", then
      up to three double lines "<zone>" / "12%".
    - **Players.** With 2 players or more the right side reads "12% (14 players)".
    - **Order.** Zones with 50 catches or more first, by chance. Without any such zone, little-data zones by the
      item's catches, with "little data" on the right.
    - Nothing while no index exists yet.
  - **The minimap tooltip.** `Minimap.lua` `ShowTooltip`, in fishing mode with the setting on, adds a blank line,
    "Likely catch here:" and up to three double lines "<item>" / "34%". They come from `CatchDB.Query` for the
    current place with the tab's defaults; grey and unknown items are skipped.
    - Under them: "N catches from K players" (from 2 players on), or "little data", or "Nothing has been caught here
      yet."
  - **The setting.** `settings.tooltipChances` (default true), one checkbox on the main settings page, in the
    feature list.
- **Rationale**: the post call already exists, and adding lines there is how the game wants tooltips extended. The
  default index makes a hover a table lookup. "(N players)" honours part 3's FR-025 in one short suffix.
- **Alternatives rejected**:
  - `OnTooltipSetItem` hooks: replaced by `TooltipDataProcessor` in the modern client.
  - Computing a hovered item's zones on demand: every map's sum, see R3.

## R10. Ways into the catalog

- **Decision**:
  - **Opening it.** `StatsFrame.OpenCatalog(arg)` shows the window, selects the catalog tab and passes `arg`: an item
    ID chooses the item, a text fills the search.
  - **From the "What can be caught here" tab.** A click on an item row (a known item) calls it with the item ID.
  - **From the command.** `/okf catalog [text]` is declared in Commands.lua and calls it with the rest of the line:
    - an item link (`|Hitem:(%d+)`) gives its ID;
    - other text goes into the search, and when exactly one known item matches, it is chosen;
    - a linked item that is not in the index puts its name in the search, which then finds nothing.
  - The catalog's filters stay its own.
- **Rationale**: FR-024 and FR-025 with the existing command and window functions; no new message.

## R11. Measuring smoothness

- **Decision**:
  - **Load test.** `tests/catalog_load_test.lua` fills the largest database the addon allows: 3,000 seed cells,
    20,000 places of other players over 1,000 records, and 2,000 own cells on 150 maps. It then checks:
    - a full build ends in steps that each stay within 8 maps;
    - one own catch costs one map;
    - a tooltip, a search over every name and expanding the largest zone each finish in one call.
  - **In game.** `/okf debug` gains the catalog's state: items, maps, stale or ready, the last build's duration, the
    longest step and the queued name requests. The goal for every step stays under 5 ms (V39).
  - **Record size.** `tests/harvest_test.mjs` encodes a 500-place record with two areas per place and expects it
    under 28 KB (V18 with the new field). The repository has no CBOR encoder and Node has none built in, so the test
    carries a minimal one: maps, arrays, unsigned and negative integers and text strings, the subset a record uses.
    It is followed by `zlib.deflateRawSync` and Base64. The game's encoder may differ by a few bytes, so V18 still
    confirms the size in game.
- **Rationale**: the frame budget cannot be measured in fengari, but the work per step can be bounded; the game run
  of V39 measures the time.

## R12. What leaves the plan

- **Decision**: shared auction prices are out of 1.2.0 and go to `docs/ROADMAP.md` with the open question of which
  auction house a player uses. The source mark is dropped. `docs/shared-db-plan.md` records the part 4 decisions
  (done with the spec). No `DB_SCHEMA` bump: only new fields (`settings.tooltipChances`, `charDB.pin`, the cell
  field `a`).
- **Rationale**: the author's decisions of 2026-10-31.

## R13. The spike

- **Decision**: `/okf spike` gets a section "Map pins and areas (V30-V36)". It changes nothing in the game. It
  prints:
  - for the current map: `CanSetUserWaypointOnMap`, its type and parent, and the parent's answer;
  - whether the game rule `WorldMapTrackingPinDisabled` is active;
  - `showInGameNavigation`;
  - `HasUserWaypoint` and `GetUserWaypoint`;
  - `GetExploredAreaIDsAtPosition` at the player's position with each area's name, `GetSubZoneText()` and the area
    the addon would keep;
  - `CaseAccentInsensitiveParse` of a mixed-case accented sample and `strcmputf8i` order;
  - whether the scroll and search templates exist;
  - the load state of three catalog items.
  The pin itself, the arrow, the map and the tooltips are checked through the catalog in the checklist
  ([quickstart.md](quickstart.md)).
- **Rationale**: one report on launch day, as in parts 1 to 3; the pin is checked where the player uses it.
